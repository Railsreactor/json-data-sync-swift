//
//  BaseJSONAPIManager.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/12/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import PromiseKit
import CocoaLumberjack


public typealias RemoteResultBlock = (result: AnyObject?, error: ErrorType?) -> (Void)
public typealias AuthCheckBlock = (completion: RemoteResultBlock) -> (Void)


public enum RemoteError: Int {
    case SerializationFailure           = -2
    case Unknown                        = -1
    
    case AuthFailed                     = 401
    case NoAccess                       = 403
    case NotFound                       = 404
    case ValidationFailure              = 422
    case ServerException                = 500
    case ServerNotResponding            = 502
}


public var BaseJSONAPIManagerErrorDomain = "com.jdskit.BaseJSONAPIManager"


public struct BaseAPI {
    static let Auth = "oauth/token"
}

public class BaseJSONAPIManager: NSObject {

    let baseURLString   : String
    let clientToken     : String
    let clientSecret    : String
    
    private let spine : Spine;
    
    private var sessionInfo : JSONAPISession? {
        didSet {
            didRefreshSessionInfo()
        }
    }

    private let authLock = NSRecursiveLock()
    init(urlString: String, clientToken token: String, clientSecret secret: String) {
        baseURLString = urlString
        spine = Spine(baseURL: NSURL(string: urlString)!)
        clientToken = token
        clientSecret = secret
        
        super.init()
        
        Spine.setLogLevel(.Debug, forDomain: .Networking)
        
        self.registerClasses()
    }
    
    // MARK: Entities Mapping
    
    private var jsonClassByEntityName: [String : JSONManagedEntity.Type] = [:]
    
    private func registerClasses() {
        
        spine.registerTransformer(Base64Transformer())
        spine.registerTransformer(NumberTransformer())
        
        for case let resource as JSONManagedEntity.Type in ExtractAllReps(JSONManagedEntity.self) {
            spine.registerResource(resource.resourceType) { resource.init() }
        }
    }
    
    internal func asJsonClass(type: ManagedEntity.Type) -> JSONManagedEntity.Type {
        return type.extractRepresentation(JSONManagedEntity.self)
    }
    
    internal func asJsonEntity(entity: ManagedEntity) -> JSONManagedEntity {
        
        let result = (ExtractRep(entity.entityType, subclassOf: JSONManagedEntity.self) as! JSONManagedEntity.Type).init()
        
        let entityObj = entity as! NSObject
        
        result.setValue(entityObj.valueForKey("id"), forField: "id")
        for field in result.dynamicType.fields {
            if !field.skip {
                let name = field.mappedName
                result.setValue(entityObj.valueForKey(name), forField: name)
            }
        }
        
        return result
    }
    

    // MARK: Base Operations
    
    private func didRefreshSessionInfo() {
        let networkClient = spine.networkClient as! HTTPClient
        if let session = sessionInfo?.sessionToken {
            networkClient.setHeader("Authorization", to: "Bearer \(session)")
        } else {
            networkClient.removeHeader("Authorization")
        }
    }
    
    private func generateError(code: Int, cause: NSError?, desc: String? = nil) -> ErrorType {
        
        var wrappedError: ErrorType?
        
        if cause?.domain == NSURLErrorDomain {
            wrappedError = CoreError.ConnectionProblem(description: "Seems there are some problems with connection", cause: cause)
        } else {
            switch code {
            case RemoteError.AuthFailed.rawValue:
                wrappedError = CoreError.WrongCredentials
            case RemoteError.NoAccess.rawValue, RemoteError.NotFound.rawValue:
                wrappedError = CoreError.ServiceError(description: desc ?? "You have no access to this feature.", cause: cause)
            case RemoteError.ValidationFailure.rawValue:
                let apiErrors = cause?.userInfo[SNAPIErrorsKey] as? [NSError]
                wrappedError = CoreError.ValidationError(apiErrors: apiErrors ?? [NSError]())
            case RemoteError.ServerNotResponding.rawValue:
                wrappedError = CoreError.ServiceError(description: "Server is not available at this time. Please try again later.", cause: cause)
            case RemoteError.ServerException.rawValue:
                fallthrough
            default:
                wrappedError = CoreError.ServiceError(description: desc ?? "Server cannot process request. Please try again later or provide steps to reproduce this issue to the development team.", cause: cause)
            }
        }
        
        return wrappedError!
    }
    
    private func findAndExtractErrors(userInfo: [NSObject: AnyObject]) -> [NSError]? {
        var apiErrors = [NSError]()
        if let errors = userInfo["errors"] as? [String: AnyObject] {
            for case let (errorTitle, errorMsg as [String]) in errors {
                apiErrors.append(NSError(domain: BaseJSONAPIManagerErrorDomain, code: 422, userInfo: [SNAPIErrorSourceKey : ["pointer": errorTitle], NSLocalizedDescriptionKey: errorMsg.first ?? ""]))
            }
            return apiErrors
        }
        
        return nil
    }
    
    private func wrapErrorIfNeed(error: ErrorType) -> ErrorType {
        if error is CoreError {
            return error
        }
        let error = (error as Any) as! NSError
        return self.generateError(error.code, cause: error)
    }
    
    public func call(method: String, path: String, request: [String: AnyObject], rawCompletion: NetworkClientCallback) {
        var urlString = baseURLString + path
        var data: NSData?
        
        switch method {
        case "GET":
            urlString = urlString + "?" + request.stringFromHttpParameters()
        default:
            do {
                data = try NSJSONSerialization.dataWithJSONObject(request, options: NSJSONWritingOptions())
            }
            catch _ {
                let errorCode = RemoteError.SerializationFailure.rawValue
                rawCompletion(statusCode: errorCode, data: nil, error: NSError(domain: BaseJSONAPIManagerErrorDomain, code: errorCode, userInfo: nil))
                return
            }
        }
        
        spine.networkClient.request(method, URL: NSURL(string: urlString)!, payload: data, callback: rawCompletion)
    }
    
    public func call(method: String, path: String, request: [String: AnyObject], completion: RemoteResultBlock) {
        
        call(method, path: path, request: request) { (statusCode, data, var error) -> Void in
            
            var result: AnyObject? = nil
            var serrializeError: ErrorType?
            
            if let data = data {
                do {
                    result = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
                } catch {
                    serrializeError = self.generateError(RemoteError.SerializationFailure.rawValue, cause: nil)
                }
            }
            
            if let code = statusCode where !(200 ... 203 ~= code)  {
                if let userInfo = result as? [String: AnyObject] where userInfo["errors"] != nil {
                    if let apiErrors = self.findAndExtractErrors(userInfo) {
                        if error == nil {
                            error = NSError(domain: "shine.service.error", code: 422, userInfo: [SNAPIErrorsKey: apiErrors])
                        }
                    }
                }
                completion(result: nil, error: self.generateError(code, cause: error))
                return
            } else if error != nil {
                completion(result: nil, error: self.generateError(RemoteError.Unknown.rawValue, cause: error))
                return
            }
            
            completion(result: result, error: serrializeError)
        }
    }
    
    
    // MARK: API
    
    // MARK: Private auth
    public func authenticate(var request : [String: String], completion: RemoteResultBlock) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)) { () -> Void in
            if self.authLock.tryLock() {
                self.sessionInfo = nil

                request["client_id"] = self.clientToken
                request["client_secret"] = self.clientSecret
                
                let fd_sema = dispatch_semaphore_create(0)
                
                
                self.call("POST", path: BaseAPI.Auth, request: request, completion: { (result: AnyObject?, error: ErrorType?) -> Void in
                    if let dictionary = result as? [String : AnyObject] where error == nil {
                        if let token = dictionary["access_token"] {
                            self.sessionInfo = JSONAPISession(sessionToken: token as! String, refreshToken: dictionary["refresh_token"] as? String)
                        }
                    }
                    dispatch_semaphore_signal(fd_sema);
                    completion(result: self.sessionInfo?.sessionToken != nil, error: error)
                })
                
                dispatch_semaphore_wait(fd_sema, DISPATCH_TIME_FOREVER);
                self.authLock.unlock()
            } else {
                self.authLock.lock()
                self.authLock.unlock()
                completion(result: self.sessionInfo?.sessionToken != nil, error: nil)
            }
        }
    }
    
    public func authorizeClient(completion: RemoteResultBlock) {
        let request = ["grant_type"    : "client_credentials"]
        self.authenticate(request, completion: completion)
    }
    
    public func authorizeUser(userName: String, password: String, completion: RemoteResultBlock) {
        let request : [String: String] = [
            "grant_type"    : "password",
            "username"      : userName,
            "password"      : password]
        self.authenticate(request) { (result, error) -> (Void) in
            completion(result: result, error: error)
        }

    }
    
    public func refreshSessionToken(refreshToken: String, completion: RemoteResultBlock) -> Void {
        let request : [String: String] = [
            "grant_type"    : "refresh_token",
            "refresh_token" : refreshToken]
        
        self.authenticate(request, completion: completion)
    }
    
    public func renewSession(completion: RemoteResultBlock) -> Void {
        if let refreshToken = sessionInfo?.refreshToken {
            refreshSessionToken(refreshToken, completion: completion)
        } else if sessionInfo?.sessionToken != nil  {
            authorizeClient(completion)
        } else {
            if self.authLock.tryLock() {
                self.authLock.unlock()
                completion(result: nil, error: generateError(RemoteError.AuthFailed.rawValue, cause: nil))
            } else {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), { () -> Void in
                    self.authLock.lock()
                    self.authLock.unlock()
                    completion(result: self.sessionInfo?.sessionToken != nil, error: nil)
                })
            }
        }
    }
    
    public func executeRequestWithSessionCheck<B>(requestBlock: (Void -> Promise<B>)) -> Promise<B> {
        return firstly {
            return requestBlock()
        }.recoverOnAuthError { (_) -> Promise<B> in
            return Promise<Void> { fulfill, reject in
                self.renewSession { (result, error) in
                    if let error = error {
                        reject(error)
                    } else {
                        fulfill()
                    }
                }
            }.thenInBackground { () -> Promise<B> in
                return requestBlock()
            }
        }.recover { (error) throws -> Promise<B> in
            throw self.wrapErrorIfNeed(error)
        }
    }
    
    // MARK: Public API: Auth
    
    public func authenticate(username: String?, password: String?) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if let username = username, let password = password {
                authorizeUser(username, password: password, completion: { (result, error) -> (Void) in
                    error != nil ? reject(error!) : fulfill()
                })
            } else {
                authorizeClient({ (result, error) -> (Void) in
                    error != nil ? reject(error!) : fulfill()
                })
            }
        }
    }
    
    // MARK: Public API: Resources
    
    public func saveEntity<T: ManagedEntity>(entity : T) -> Promise<T> {
        let jsonEnitity = self.asJsonEntity(entity)
        
        return executeRequestWithSessionCheck({
            return self.spine.save(jsonEnitity).then({ (resource) -> T in
                return resource as! T
            })
        })
    }
    
    public func deleteEntity<T: ManagedEntity>(entity : T) -> Promise<Void> {
        let serialized = self.asJsonEntity(entity) as JSONManagedEntity
        return executeRequestWithSessionCheck({
            return self.spine.delete(serialized)
        })
    }
    
    public func loadEntity(id: String, ofType: ManagedEntity.Type, include: [ManagedEntity.Type]?=nil) -> Promise<ManagedEntity> {
        return executeRequestWithSessionCheck({
            return self.spine.findOne(id, ofType: self.asJsonClass(ofType)).then({ (resource, meta, jsonapi) -> ManagedEntity in
                return resource
            })
        })
    }
    
    public func loadEntity<T: ManagedEntity>(id: String, ofType: T.Type, include: [ManagedEntity.Type]?=nil) -> Promise<T> {
        return loadEntity(id, ofType: ofType, include: include).then { $0 as! T }
    }
    
    public func loadEntities(ofType: ManagedEntity.Type, filters: [NSComparisonPredicate]?, include: [String]?=nil) -> Promise<[ManagedEntity]> {
        return executeRequestWithSessionCheck({
            let entityClass = self.asJsonClass(ofType)
            
            let mappedRelations = include?.map { entityClass.fieldKeyMap[$0]! }
            let pagination = OffsetBasedPagination(offset: 0, limit: 500)
            
            return self.spine.findAll(entityClass, filters: filters, include: mappedRelations, pagination: pagination).then({ (resources, meta, jsonapi) -> [ManagedEntity] in
                return resources.map { $0 as! ManagedEntity }
            })
        })
    }

    public func loadEntities<T: ManagedEntity>(ofType: T.Type = T.self, filters: [NSComparisonPredicate]?, include: [String]?=nil) -> Promise<[T]> {
        return loadEntities(ofType, filters: filters, include: include).then { (resources: [ManagedEntity]) -> [T] in
            return resources as! [T]
        }
    }
 }



public extension Promise {
    
    public func recoverOnAuthError(body: (ErrorType) throws -> Promise) -> Promise {
        return self.recover { (error) throws -> Promise in
            let anError = (error as Any) as! NSError
            
            if let shineError = error as? CoreError {
                switch(shineError) {
                case .WrongCredentials:
                    return try body(error)
                default: break;
                }
            }
            
            if anError.code == RemoteError.AuthFailed.rawValue {
                return try body(error)
            }
            
            throw error
        }
    }
}
