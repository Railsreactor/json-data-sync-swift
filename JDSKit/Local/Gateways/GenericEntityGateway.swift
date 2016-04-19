//
//  GenericEntityGateway.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/26/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import CoreData
import CocoaLumberjack

public protocol ManagedObjectContextProvider: class {
    
    func entityGatewayByEntityTypeKey(typeKey: String) -> GenericEntityGateway
    
    func contextForCurrentThread() -> NSManagedObjectContext
    
    func saveContext(context: NSManagedObjectContext)
    
    func generateFetchRequestForEntity(enitityType : NSManagedObject.Type, context: NSManagedObjectContext) -> NSFetchRequest
    
    func createEntity(type: NSManagedObject.Type, temp: Bool) -> NSManagedObject
    
    func fetchEntities(predicate: NSPredicate?, ofType: NSManagedObject.Type, sortDescriptors: [NSSortDescriptor]?) throws -> [NSManagedObject]
    
    func fetchEntity(predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> NSManagedObject?
    
    func deleteEntities(predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> Void
    
    func deleteEntity(object: NSManagedObject) throws -> Void
    
    func countEntities(ofType: NSManagedObject.Type) -> Int
}


public class MappingConstans {
    public static let SyncOR = "syncOR"
    public static let SkipAttribute = "skip"
    public static let ReverceRelation: String = "reverse"
    public static let PrefetchedEntities: String = "prefetched"
}


public class GenericEntityGateway: NSObject {

    public var contextProvider : ManagedObjectContextProvider {
        return BaseDBService.sharedInstance
    }
    
    public var managedObjectType: CDManagedEntity.Type

    public init(_ managedObjectType: CDManagedEntity.Type) {
        self.managedObjectType = managedObjectType
        super.init()
    }
    
    public func entityWithID<T: ManagedEntity>(id: String, createNewIfNeeded: Bool = false) throws -> T? {
        
        guard let entity = try contextProvider.fetchEntity(NSPredicate(format: "id == %@", id), ofType:managedObjectType) as? T else {
            let newEntity = contextProvider.createEntity(managedObjectType, temp: false) as? T
            newEntity?.id = id
            return newEntity
        }
        
        return entity
    }
    
    public func createEntity(isTemp: Bool = false) -> ManagedEntity  {
        return contextProvider.createEntity(managedObjectType, temp: isTemp) as! ManagedEntity
    }
    
    public func fetchEntities<T: ManagedEntity>(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?) throws -> [T] {
        return try contextProvider.fetchEntities(predicate, ofType: managedObjectType, sortDescriptors: sortDescriptors).map { $0 as! T }
    }
    
    public func fetchEntities<T: ManagedEntity>(predicateString: String, arguments: [AnyObject]? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [T] {
        return try fetchEntities(NSPredicate(format: predicateString, argumentArray: arguments), sortDescriptors: sortDescriptors)
    }
    
    public func fetchEntity<T: ManagedEntity>(predicate: NSPredicate?) throws -> T? {
        return try (contextProvider.fetchEntity(predicate, ofType: managedObjectType) as? T)
    }
    
    public func fetchEntity<T: ManagedEntity>(predicateString: String, arguments: [AnyObject]? = nil) throws -> T? {
        return try fetchEntity(NSPredicate(format: predicateString, argumentArray: arguments))
    }
    
    public func fetchedResultsProvider(predicate: NSPredicate, sortBy:[String], groupBy: String?=nil) -> NSFetchedResultsController {
        let ctx = self.contextProvider.contextForCurrentThread()
        let request = self.contextProvider.generateFetchRequestForEntity(self.managedObjectType, context: ctx)
        
        request.predicate = predicate
        request.sortDescriptors = sortBy.sortDescriptors()
        
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: ctx, sectionNameKeyPath: groupBy, cacheName: nil)
    }
    
    //MARK: - Count
    public func countEntities(predicate: NSPredicate?) -> Int {
        let context = contextProvider.contextForCurrentThread()
        let fetchRequest = contextProvider.generateFetchRequestForEntity(managedObjectType, context: context)
        
        fetchRequest.fetchLimit = 0
        fetchRequest.predicate = predicate
        
        var error: NSError? = nil
        return context.countForFetchRequest(fetchRequest, error: &error)
    }
    
    //MARK: - Delete
    public func deleteEntities(predicate: NSPredicate?) throws {
        try contextProvider.deleteEntities(predicate, ofType: managedObjectType)
    }
    
    public func deleteEntity(object: ManagedEntity) throws -> Void {
        if let object = object as? CDManagedEntity {
            try contextProvider.deleteEntity(object)
        } else {
            if let entity: CDManagedEntity = try entityWithID(object.id!) {
                try contextProvider.deleteEntity(entity)
            }
        }
    }
    
    public func deleteEntityWithID(id: String) throws -> Void {
        if let entity: CDManagedEntity = try entityWithID(id) {
            try contextProvider.deleteEntity(entity)
        }
    }
    
    public func insertEntity<T: ManagedEntity>(entity: T, mergeWith: T?=nil, isFirstInsert: Bool = false, userInfo:[String : AnyObject] = [:]) throws -> T {
        
        if entity.dynamicType.entityName != self.managedObjectType.entityName {
            throw CoreError.EntityMisstype(input: entity.dynamicType.entityName, target: self.managedObjectType.entityName)
        }
        
        guard let id = entity.id else {
            throw CoreError.RuntimeError(description: "Entity must have an ID", cause: nil)
        }
        
        var managedObject : CDManagedEntity? = nil
        
        if let prefetchedEntities = userInfo[MappingConstans.PrefetchedEntities], let prefetchedMO = prefetchedEntities[id] as? CDManagedEntity {
            managedObject = prefetchedMO
        } else if isFirstInsert {
            managedObject = (contextProvider.createEntity(managedObjectType, temp: false) as! CDManagedEntity)
        } else {
            managedObject = try entityWithID(id, createNewIfNeeded: true)
        }
        
        try mapEntity(entity, managedObject: managedObject!, userInfo: userInfo)
        return managedObject as! T
    }
    
    public func insertEnities( entities : [ManagedEntity], isFirstInsert: Bool = false, userInfo inputUserInfo:[String : AnyObject] = [:]) throws -> [ManagedEntity]? {
        
        var insertedItems: [ManagedEntity] = []
        
        do {
            var userInfo = inputUserInfo
            // Lets try to prefetch all existing entities to speed-up mapping
            let ids: [String] = entities.flatMap { $0.id }
            if ids.count > 0 {
                let prefetchedEntites = try fetchEntities("id in %@", arguments: [ids]) as [CDManagedEntity]
                if prefetchedEntites.count > 0 {
                    var prefetchedByKey = [String: CDManagedEntity]()
                    prefetchedEntites.forEach( { entity in
                        if let id = entity.id {
                            prefetchedByKey[id] = entity
                        }
                    })
                    userInfo[MappingConstans.PrefetchedEntities] = prefetchedByKey
                }
            }
            
            for entity in entities {
                let mapped: ManagedEntity = try insertEntity(entity, mergeWith: nil, isFirstInsert: isFirstInsert, userInfo: userInfo)
                insertedItems.append(mapped)
            }
        } catch (CoreError.EntityMisstype(let input, let target)) {
            let msg = "Insert Error - Input object: \(input) Target was: \(target)"
            DDLogError(msg)
        }
        return insertedItems
    }
    
    public func mapEntity (entity: ManagedEntity, managedObject: CDManagedEntity, userInfo:[String : AnyObject] = [:]) throws {
        mapEntityProperties(entity, managedObject: managedObject)
        try mapEntityRelations(entity, managedObject: managedObject, exceptRelationship:nil, userInfo: userInfo)
    }
    
    
    public func mapEntityProperties(entity: ManagedEntity, managedObject: CDManagedEntity, userInfo:[String : AnyObject] = [:]) {
        
        //Skip not loaded objects
        guard let newDate = entity.updateDate else {
            return
        }
        let oldDate = managedObject.updateDate
        // Skip not updated objects
        if oldDate != nil && oldDate!.compare(newDate) == .OrderedSame {
            return
        }
        
        let isLoaded = entity.isLoaded?.boolValue ?? false
        
        if let entity = entity as? NSObject {
            let object = managedObject as NSObject
            for attribute in managedObject.entity.attributesByName.values {
                
                if asBool(attribute.userInfo?[MappingConstans.SkipAttribute]) {
                    continue;
                }
                
                var value:AnyObject? = entity.valueForKey(attribute.name)
                
                if !isLoaded && value == nil {
                    value = object.valueForKey(attribute.name) ?? attribute.defaultValue
                } else if value == nil {
                    value = attribute.defaultValue
                }
                
                if asBool(attribute.userInfo?[MappingConstans.SyncOR]) {
                    if let value = object.valueForKey(attribute.name) as? NSNumber where value.boolValue {
                        continue;
                    }
                }
                
                object.setValue(value, forKey: attribute.name)
            }
        }
    }
    
    public func gatewayForEntity(inputEntity: ManagedEntity, fromRelationship: NSRelationshipDescription) -> GenericEntityGateway? {
        return fromRelationship.destinationEntity?.gateway()
    }
    
    public func mapEntityRelations(inputEntity: ManagedEntity, managedObject: CDManagedEntity, exceptRelationship inExceptRelationship: NSRelationshipDescription?, userInfo:[String : AnyObject] = [:] ) throws {
        
        if let isLoaded = inputEntity.isLoaded?.boolValue where !isLoaded {
            return
        }
        
        var key : String?
        let managedNSObject = managedObject as NSObject
        
        if let inputEntityObj = inputEntity as? NSObject {
            for relationship in managedObject.entity.relationshipsByName.values  {
            
                let exceptRelationship = inExceptRelationship ?? userInfo[MappingConstans.ReverceRelation] as? NSRelationshipDescription
            
                if exceptRelationship != nil && exceptRelationship!.isEqual(relationship) {
                    continue;
                }
                
                key = relationship.name;
                
                if let value = relationship.userInfo?[MappingConstans.SkipAttribute] as? String where NSString(string: value).boolValue {
                    continue;
                }
                
                
                var value : AnyObject?
                var nativeValue: AnyObject?
                
                do {
                    try SNExceptionWrapper.tryBlock({ () -> Void in
                        value = inputEntityObj.valueForKey(key!)
                    })
                } catch {
                    //DDLogDebug("Not found: \(key) error: \(error)")
                }
                
                if value != nil && !(value is NSNull) {
                    
                    let existingValue = managedNSObject.valueForKey(key!)
                    
                    if let gateway: GenericEntityGateway = gatewayForEntity(inputEntity, fromRelationship: relationship) {
                        
                        if let value = value as? NSSet where relationship.toMany {
                            
                            let mapped = try gateway.insertEnities(value.allObjects as! [ManagedEntity], isFirstInsert: false, userInfo: [MappingConstans.ReverceRelation : relationship.inverseRelationship!])
                            
                            if (relationship.ordered) {
                                fatalError("Ordered sets in unsupported. LoL")
                            }
                            else {
                                nativeValue = NSSet(array: mapped!)
                                
                                if let set = managedNSObject.valueForKey(key!) as? NSSet where set.count == 0 {
                                    nativeValue = NSSet(array: mapped!)
                                }
                                else if let set = managedNSObject.valueForKey(key!) as? NSSet {
                                    let mutableSet = set.mutableCopy() as? NSMutableSet
                                    mutableSet?.addObjectsFromArray(mapped!)
                                    nativeValue = mutableSet
                                }
                            }
                        } else if let value = value as? ManagedEntity {
                            let localInfo = [MappingConstans.ReverceRelation : relationship.inverseRelationship!]
                            nativeValue = try gateway.insertEntity(value, mergeWith: existingValue as? ManagedEntity, isFirstInsert: false , userInfo: localInfo)
                        }
                    }
    
                    if nativeValue != nil && ( existingValue == nil || !existingValue!.isEqual(nativeValue!)) {
                        managedNSObject.setValue(nativeValue!, forKey: key!)
                    }
                }
            }
        }
    }
}

public extension NSEntityDescription {
    public func gateway() -> GenericEntityGateway {
        return BaseDBService.sharedInstance.entityGatewayByMOType((NSClassFromString(self.managedObjectClassName) as! CDManagedEntity.Type))
    }
}
