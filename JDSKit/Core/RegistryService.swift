//
//  AbstractRegistryService.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/2/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit

open class AbstractRegistryService: NSObject {
    
    // Setup here your implementation of RegistryService
    open static var mainRegistryService: AbstractRegistryService!
    
    
    // JSON-API url string
    open var apiURLString: String {
        fatalError("Var 'apiURLString' should be overriden")
    }
    
    open var apiToken: String {
        fatalError("Var 'apiToken' should be overriden")
    }
    
    open var apiSecret: String {
        fatalError("Var 'apiSecret' should be overriden")
    }

    // Path to Core Data store file
    open var storeModelURL: URL {
        fatalError("Var 'storeModelURL' should be overriden")
    }
    
    // Path to Core Data Managed Object Model
    open var storeURL: URL {
        fatalError("Var 'storeURL' should be overriden")
    }

    //
    
    open func createRemoteManager() -> BaseJSONAPIManager {
        return BaseJSONAPIManager(urlString: "http://\(apiURLString)/", clientToken: apiToken, clientSecret: apiSecret)
    }
    
    open func createLocalManager() -> BaseDBService {
        return BaseDBService(modelURL: AbstractRegistryService.mainRegistryService.storeModelURL, storeURL: AbstractRegistryService.mainRegistryService.storeURL)
    }
    
    // ********************************************* Model ********************************************* //
    // Registered representations for models. WARNING! Model Protocol should be always the first one!
    // In most cases you only need to register your models and reps here. Other stuff like DB Gateways or JSON Manager will handle if out of the box.
    
    open var _modelRepresentations: [[ManagedEntity.Type]] {
        return [
            [ManagedEntity.self,    DummyManagedEntity.self,        JSONManagedEntity.self,     CDManagedEntity.self],
            [Attachment.self,       DummyAttachment.self,           JSONAttachment.self,        CDAttachment.self],
            [Event.self,                                            JSONEvent.self]
        ]
    }
    
    // ********************************************* Services ********************************************* //
    // List of predefined enitity services.
    
    open var _predefinedEntityServices: [String: EntityService] {
        return [ String(describing: Attachment.self) : AttachmentService() ]
    }
    
    internal var _sharedEntityServices: [String: EntityService] = [:]
    
    // This function returns registered entity service or creates GenericService for requested entity type
    open func entityService<T: ManagedEntity>() -> GenericService<T> {
        let key = String(describing: T.self)
        var service = (_sharedEntityServices[key]) as? GenericService<T>
        if service == nil {
            service = GenericService<T>()
            _sharedEntityServices[key] = service
        }
        return service!
    }
    
    open func entityService(_ type: ManagedEntity.Type) -> EntityService {
        let key = String(describing: type)
        var service = _sharedEntityServices[key]
        if service == nil {
            service = EntityService(entityType: type)
            _sharedEntityServices[key] = service
        }
        return service!
    }
    
    open func entityServiceByKey(_ key: String) -> EntityService {
        return entityService(ExtractModel(key))
    }
    
    internal func performServiceIndexation() {
        for (key, service) in _predefinedEntityServices {
            _sharedEntityServices[key] = service
        }
    }
    
    
    // ****************************************** EntityGateways ************************************************** //
    // List of predefined entity gateways. Other gateways will be dynamycaly initialized when requested.

    open var _predefinedEntityGateways: [GenericEntityGateway] {
        return [ LinkableEntitiyGateway(CDAttachment.self) ]
    }
    
    // ************************************************************************************************************ //
    
    
    internal func performRepresentationsIndexation() {
        for modelReps in _modelRepresentations {
            for i in 1 ... modelReps.count-1 {
                _ = RegisterRepresenation(modelReps.first!, repType: modelReps[i])
            }
        }
    }
    
    public override init() {
        super.init()
        if AbstractRegistryService.mainRegistryService == nil {
            AbstractRegistryService.mainRegistryService = self
        }
        performRepresentationsIndexation()
        performServiceIndexation()
    }
}


class ModelRegistry: NSObject {
    static let sharedRegistry = ModelRegistry()
    
    var registeredModelByType  = [String : ManagedEntity.Type]()
    var registeredModelByKey   = [String : ManagedEntity.Type]()
    var registeredKeyByModel   = [String : String]()
    
    var registeredModelByRep    = [String : ManagedEntity.Type]()
    var registeredRepsByModel   = [String : [ManagedEntity.Type]]()
    
    func register(_ modelType: ManagedEntity.Type, key inKey: String? = nil) -> Bool {
        let key = inKey ?? String(describing: modelType)
        let typeKey = String(describing: modelType)
        
        registeredModelByType[typeKey]  = modelType
        
        registeredKeyByModel[typeKey]   = key
        registeredModelByKey[key] = modelType
        
        return true
    }
    
    func registerRep(_ modelType: ManagedEntity.Type, repType: ManagedEntity.Type, modelKey: String?=nil) -> Bool {
        
        let typeKey = String(describing: modelType)
        if registeredModelByType[typeKey] == nil {
           _ = register(modelType, key: modelKey)
        }
        
        registeredModelByRep[String(describing: repType)] = modelType
        
        
        if registeredRepsByModel[typeKey] == nil {
            registeredRepsByModel[typeKey] = [ManagedEntity.Type]()
        }
        registeredRepsByModel[typeKey]! += [repType]
        return true
    }
    
    func extractModel(_ repType: ManagedEntity.Type) -> ManagedEntity.Type {
        let key = String(describing: repType)
        if registeredRepsByModel[key] != nil {
            return repType
        }
        return registeredModelByRep[key]!
    }
    
    func extractModelByKey(_ key: String) -> ManagedEntity.Type {
        return registeredModelByKey[key]!
    }
    
    func extractRep<R>(_ modelType: ManagedEntity.Type, subclassOf: R.Type?=nil) -> ManagedEntity.Type {
        let key = String(describing: modelType)
        let reps: [ManagedEntity.Type] = registeredRepsByModel[key]!
        
        if subclassOf != nil {
            for repClass in reps {
                if let _ = repClass as? R.Type {
                    return repClass
                }
            }
        }
        
        return reps.first!
    }
    
    func extractAllReps<R>(_ subclassOf: R.Type) -> [ManagedEntity.Type] {
        var result = [ManagedEntity.Type]()
        
        for (_, reps) in registeredRepsByModel {
            for repClass in reps {
                if let _ = repClass as? R.Type {
                    result.append(repClass)
                }
            }
        }
        return result
    }
}

func RegisterRepresenation(_ modelType: ManagedEntity.Type, repType: ManagedEntity.Type) -> Bool {
    return ModelRegistry.sharedRegistry.registerRep(modelType, repType: repType)
}

func ExtractModel(_ repType: ManagedEntity.Type) -> ManagedEntity.Type {
    return ModelRegistry.sharedRegistry.extractModel(repType)
}

func ExtractModel(_ key: String) -> ManagedEntity.Type {
    return ModelRegistry.sharedRegistry.extractModelByKey(key)
}

func ExtractRep<R>(_ modelType: ManagedEntity.Type, subclassOf: R.Type?=nil) -> ManagedEntity.Type {
    return ModelRegistry.sharedRegistry.extractRep(modelType, subclassOf: subclassOf)
}

func ExtractAllReps<R>(_ subclassOf: R.Type) -> [ManagedEntity.Type] {
    return ModelRegistry.sharedRegistry.extractAllReps(subclassOf)
}
