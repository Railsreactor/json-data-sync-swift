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


public typealias RemoteResultBlock = (_ result: Any?, _ error: Error?) -> (Void)
public typealias AuthCheckBlock = (_ completion: RemoteResultBlock) -> (Void)


public enum RemoteError: Int {
    case serializationFailure           = -2
    case unknown                        = -1
    
    case authFailed                     = 401
    case noAccess                       = 403
    case notFound                       = 404
    case validationFailure              = 422
    case serverException                = 500
    case serverNotResponding            = 502
}


public var BaseJSONAPIManagerErrorDomain = "com.jdskit.BaseJSONAPIManager"


public struct BaseAPI {
    static let Auth = "oauth/token"
}

open class BaseJSONAPIManager: NSObject {

    let baseURLString   : String
    let clientToken     : String
    let clientSecret    : String
    
    open let spine : Spine;
    
    open var sessionInfo : JSONAPISession? {
        didSet {
            didRefreshSessionInfo()
        }
    }

    open let authLock = NSRecursiveLock()
    
    public init(urlString: String, clientToken token: String, clientSecret secret: String) {
        baseURLString = urlString
        spine = Spine(baseURL: URL(string: urlString)!)
        clientToken = token
        clientSecret = secret
        
        super.init()
        
        Spine.setLogLevel(.debug, forDomain: .networking)
        
        self.registerClasses()
    }
    
    // MARK: Entities Mapping
    
    open var jsonClassByEntityName: [String : JSONManagedEntity.Type] = [:]
    
    open func registerClasses() {
        
        spine.registerTransformer(Base64Transformer())
        spine.registerTransformer(NumberTransformer())
        
        for case let resource as JSONManagedEntity.Type in ExtractAllReps(JSONManagedEntity.self) {
            spine.registerResource(resource.resourceType()) { resource.init() }
        }
    }
    
    open func asJsonClass(_ type: ManagedEntity.Type) -> JSONManagedEntity.Type {
        return type.extractRepresentation(JSONManagedEntity.self)
    }
    
    open func asJsonEntity(_ entity: ManagedEntity) -> JSONManagedEntity {
        
        let result = (ExtractRep(entity.entityType, subclassOf: JSONManagedEntity.self) as! JSONManagedEntity.Type).init()
        
        let entityObj = entity as! NSObject
        
        result.setValue(entityObj.value(forKey: "id") as Any?, forField: "id")
        for field in type(of: result).fields() {
            if !field.skip {
                let name = field.mappedName
                result.setValue(entityObj.value(forKey: name) as Any?, forField: name)
            }
        }
        
        return result
    }
    

    // MARK: Base Operations
    
    fileprivate func didRefreshSessionInfo() {
        let networkClient = spine.networkClient as! HTTPClient
        if let session = sessionInfo?.sessionToken {
            networkClient.setHeader(header: "Authorization", to: "Bearer \(session)")
        } else {
            networkClient.removeHeader(header: "Authorization")
        }
    }
    
    open func generateError(_ code: Int, cause: NSError?, desc: String? = nil) -> Error {
        
        var wrappedError: Error?
        
        if cause?.domain == NSURLErrorDomain {
            wrappedError = CoreError.connectionProblem(description: "Seems there are some problems with connection", cause: cause)
        } else {
            switch code {
            case RemoteError.authFailed.rawValue:
                wrappedError = CoreError.wrongCredentials
            case RemoteError.noAccess.rawValue, RemoteError.notFound.rawValue:
                wrappedError = CoreError.serviceError(description: desc ?? "You have no access to this feature.", cause: cause)
            case RemoteError.validationFailure.rawValue:
                let apiErrors = cause?.userInfo[SNAPIErrorsKey] as? [NSError]
                wrappedError = CoreError.validationError(apiErrors: apiErrors ?? [NSError]())
            case RemoteError.serverNotResponding.rawValue:
                wrappedError = CoreError.serviceError(description: "Server is not available at this time. Please try again later.", cause: cause)
            case RemoteError.serverException.rawValue:
                fallthrough
            default:
                wrappedError = CoreError.serviceError(description: desc ?? "Server cannot process request. Please try again later or provide steps to reproduce this issue to the development team.", cause: cause)
            }
        }
        
        return wrappedError!
    }
    
    open func findAndExtractErrors(_ userInfo: [AnyHashable: Any]) -> [NSError]? {
        var apiErrors = [NSError]()
        if let errors = userInfo["errors"] as? [String: Any] {
            for case let (errorTitle, errorMsg as [String]) in errors {
                apiErrors.append(NSError(domain: BaseJSONAPIManagerErrorDomain, code: 422, userInfo: [SNAPIErrorSourceKey : ["pointer": errorTitle], NSLocalizedDescriptionKey: errorMsg.first ?? ""]))
            }
            return apiErrors
        }
        
        return nil
    }
    
    open func wrapErrorIfNeed(_ error: Error) -> Error {
        if error is CoreError {
            return error
        }
        let error = (error as Any) as! NSError
        return self.generateError(error.code, cause: error)
    }
    
    open func call(_ method: String, path: String, request: [String: Any], rawCompletion: @escaping NetworkClientCallback) {
        var urlString = baseURLString + path
        var data: Data?
        
        switch method {
        case "GET":
            urlString = urlString + "?" + request.stringFromHttpParameters()
        default:
            do {
                data = try JSONSerialization.data(withJSONObject: request, options: JSONSerialization.WritingOptions())
            }
            catch _ {
                let errorCode = RemoteError.serializationFailure.rawValue
                rawCompletion(errorCode, nil, NSError(domain: BaseJSONAPIManagerErrorDomain, code: errorCode, userInfo: nil))
                return
            }
        }
        
        spine.networkClient.request(method: method, url: URL(string: urlString)!, payload: data!, callback: rawCompletion)
    }
    
    open func call(_ method: String, path: String, request: [String: Any], completion: @escaping RemoteResultBlock) {
        call(method, path: path, request: request, rawCompletion: { (statusCode, data, error) -> Void in
            
            var result: Any? = nil
            var serrializeError: Error?
            var finalError = error
            
            if let data = data {
                do {
                    result = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                } catch {
                    serrializeError = self.generateError(RemoteError.serializationFailure.rawValue, cause: nil)
                }
            }
            
            if let code = statusCode, !(200 ... 203 ~= code)  {
                if let userInfo = result as? [String: Any], userInfo["errors"] != nil {
                    if let apiErrors = self.findAndExtractErrors(userInfo) {
                        if finalError == nil {
                            finalError = NSError(domain: "shine.service.error", code: 422, userInfo: [SNAPIErrorsKey: apiErrors])
                        }
                    }
                }
                completion(nil, self.generateError(code, cause: finalError))
                return
            } else if finalError != nil {
                completion(nil, self.generateError(RemoteError.unknown.rawValue, cause: finalError))
                return
            }
            
            completion(result, serrializeError)
        })
    }
    
    
    // MARK: API
    
    // MARK: Private auth
    open func authenticate(_ inputRequest: [String: String], completion: @escaping RemoteResultBlock) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive).async { () -> Void in
            if self.authLock.try() {
                self.sessionInfo = nil

                var request = inputRequest
                
                request["client_id"] = self.clientToken
                request["client_secret"] = self.clientSecret
                
                let fd_sema = DispatchSemaphore(value: 0)
                
                
                self.call("POST", path: BaseAPI.Auth, request: request as [String : Any], completion: { (result: Any?, error: Error?) -> Void in
                    if let dictionary = result as? [String : Any], error == nil {
                        if let token = dictionary["access_token"] {
                            self.sessionInfo = JSONAPISession(sessionToken: token as! String, refreshToken: dictionary["refresh_token"] as? String)
                        }
                    }
                    fd_sema.signal();
                    completion(self.sessionInfo?.sessionToken != nil, error)
                } as! RemoteResultBlock)
                
                fd_sema.wait(timeout: DispatchTime.distantFuture);
                self.authLock.unlock()
            } else {
                self.authLock.lock()
                self.authLock.unlock()
                completion(self.sessionInfo?.sessionToken != nil, nil)
            }
        }
    }
    
    open func authorizeClient(_ completion: @escaping RemoteResultBlock) {
        let request = ["grant_type"    : "client_credentials"]
        self.authenticate(request, completion: completion)
    }
    
    open func authorizeUser(_ userName: String, password: String, completion: @escaping RemoteResultBlock) {
        let request : [String: String] = [
            "grant_type"    : "password",
            "username"      : userName,
            "password"      : password]
        self.authenticate(request) { (result, error) -> (Void) in
            completion(result, error)
        }

    }
    
    open func refreshSessionToken(_ refreshToken: String, completion: @escaping RemoteResultBlock) -> Void {
        let request : [String: String] = [
            "grant_type"    : "refresh_token",
            "refresh_token" : refreshToken]
        
        self.authenticate(request, completion: completion)
    }
    
    open func renewSession(_ completion: @escaping RemoteResultBlock) -> Void {
        if let refreshToken = sessionInfo?.refreshToken {
            refreshSessionToken(refreshToken, completion: completion)
        } else if sessionInfo?.sessionToken != nil  {
            authorizeClient(completion)
        } else {
            if self.authLock.try() {
                self.authLock.unlock()
                completion(nil, generateError(RemoteError.authFailed.rawValue, cause: nil))
            } else {
                DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive).async(execute: { () -> Void in
                    self.authLock.lock()
                    self.authLock.unlock()
                    completion(self.sessionInfo?.sessionToken != nil, nil)
                })
            }
        }
    }
    
    open func executeRequestWithSessionCheck<B>(_ requestBlock: @escaping ((Void) -> Promise<B>)) -> Promise<B> {
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
            }.then(on: .global()) { () -> Promise<B> in
                return requestBlock()
            }
        }.recover { (error) throws -> Promise<B> in
            throw self.wrapErrorIfNeed(error)
        }
    }
    
    // MARK: Public API: Auth
    
    open func authenticate(_ username: String?, password: String?) -> Promise<Void> {
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
    
    open func saveEntity<T: ManagedEntity>(_ entity : T) -> Promise<T> {
        let jsonEnitity = self.asJsonEntity(entity)
        
        return executeRequestWithSessionCheck({
            return self.spine.save(resource: jsonEnitity).then(execute:{ (resource) -> T in
                return resource as! T
            })
        })
    }
    
    open func deleteEntity<T: ManagedEntity>(_ entity : T) -> Promise<Void> {
        let serialized = self.asJsonEntity(entity) as JSONManagedEntity
        return executeRequestWithSessionCheck({
            return self.spine.delete(serialized)
        })
    }
    
    open func loadEntity(_ id: String, ofType: ManagedEntity.Type, include: [ManagedEntity.Type]?=nil) -> Promise<ManagedEntity> {
        return executeRequestWithSessionCheck({
            return self.spine.findOne(id, ofType: self.asJsonClass(ofType)).then (execute:{ (resource, meta, jsonapi) -> ManagedEntity in
                return resource
            })
        })
    }
    
    open func loadEntity<T: ManagedEntity>(_ id: String, ofType: T.Type, include: [ManagedEntity.Type]?=nil) -> Promise<T> {
        return loadEntity(id, ofType: ofType, include: include).then { $0 as! T }
    }
    
    open func loadEntities(_ ofType: ManagedEntity.Type, filters: [NSComparisonPredicate]?, include: [String]?=nil, fields: [String]?=nil) -> Promise<[ManagedEntity]> {
        return executeRequestWithSessionCheck({
            let entityClass = self.asJsonClass(ofType)

            var query = Query(resourceType: entityClass)
            
            query.filters = filters ?? [NSComparisonPredicate]()
            query.includes = include?.map { entityClass.fieldKeyMap[$0]! } ?? [String]()
            query.paginate(OffsetBasedPagination(offset: 0, limit: 500))
            
            if let fields = fields {
                query.fields = [entityClass.resourceType() : fields.map { entityClass.fieldKeyMap[$0]! }]
            }
            
            return self.spine.find(query).then(execute:{ (resources, meta, jsonapi) -> [ManagedEntity] in
                return resources.map { $0 as! ManagedEntity }
            })
        })
    }

    open func loadEntities<T: ManagedEntity>(_ ofType: T.Type = T.self, filters: [NSComparisonPredicate]?, include: [String]?=nil, fields: [String]?=nil) -> Promise<[T]> {
        return loadEntities(ofType, filters: filters, include: include, fields: fields).then { (resources: [ManagedEntity]) -> [T] in
            return resources as! [T]
        }
    }
 }



public extension Promise {
    
    public func recoverOnAuthError(_ body: @escaping (Error) throws -> Promise) -> Promise {
        return self.recover { (error) throws -> Promise in
            let anError = (error as Any) as! NSError
            
            if let shineError = error as? CoreError {
                switch(shineError) {
                case .wrongCredentials:
                    return try body(error)
                default: break;
                }
            }
            
            if anError.code == RemoteError.authFailed.rawValue {
                return try body(error)
            }
            
            throw error
        }
    }
}
