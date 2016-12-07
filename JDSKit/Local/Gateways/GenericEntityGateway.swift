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
    
    func entityGatewayByEntityTypeKey(_ typeKey: String) -> GenericEntityGateway?
    
    func contextForCurrentThread() -> NSManagedObjectContext
    
    func generateFetchRequestForEntity(_ enitityType : NSManagedObject.Type, context: NSManagedObjectContext) -> NSFetchRequest<NSFetchRequestResult>
    
    func createEntity(_ type: NSManagedObject.Type, temp: Bool) -> NSManagedObject
    
    func fetchEntities(_ predicate: NSPredicate?, ofType: NSManagedObject.Type, sortDescriptors: [NSSortDescriptor]?) throws -> [NSManagedObject]
    
    func fetchEntity(_ predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> NSManagedObject?
    
    func deleteEntities(_ predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> Void
    
    func deleteEntity(_ object: NSManagedObject) throws -> Void
    
    func countEntities(_ ofType: NSManagedObject.Type) -> Int
}


open class MappingConstans {
    open static let SyncOR = "syncOR"
    open static let SkipAttribute = "skip"
    open static let ReverceRelation: String = "reverse"
    open static let PrefetchedEntities: String = "prefetched"
}


open class GenericEntityGateway: NSObject {

    open var contextProvider : ManagedObjectContextProvider {
        return BaseDBService.sharedInstance
    }
    
    open var managedObjectType: CDManagedEntity.Type

    public init(_ managedObjectType: CDManagedEntity.Type) {
        self.managedObjectType = managedObjectType
        super.init()
    }
    
    open func entityWithID<T: ManagedEntity>(_ id: String, createNewIfNeeded: Bool = false) throws -> T? {
        
        guard let entity = try contextProvider.fetchEntity(NSPredicate(format: "id == %@", id), ofType:managedObjectType) as? T else {
            let newEntity = contextProvider.createEntity(managedObjectType, temp: false) as? T
            newEntity?.id = id
            return newEntity
        }
        
        return entity
    }
    
    open func createEntity(_ isTemp: Bool = false) -> ManagedEntity  {
        return contextProvider.createEntity(managedObjectType, temp: isTemp) as! ManagedEntity
    }
    
    open func fetchEntities<T: ManagedEntity>(_ predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?) throws -> [T] {
        return try contextProvider.fetchEntities(predicate, ofType: managedObjectType, sortDescriptors: sortDescriptors).map { $0 as! T }
    }
    
    open func fetchEntities<T: ManagedEntity>(_ predicateString: String, arguments: [Any]? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [T] {
        return try fetchEntities(NSPredicate(format: predicateString, argumentArray: arguments), sortDescriptors: sortDescriptors)
    }
    
    open func fetchEntity<T: ManagedEntity>(_ predicate: NSPredicate?) throws -> T? {
        return try (contextProvider.fetchEntity(predicate, ofType: managedObjectType) as? T)
    }
    
    open func fetchEntity<T: ManagedEntity>(_ predicateString: String, arguments: [Any]? = nil) throws -> T? {
        return try fetchEntity(NSPredicate(format: predicateString, argumentArray: arguments))
    }
    
    open func fetchedResultsProvider(_ predicate: NSPredicate, sortBy:[String], groupBy: String?=nil) -> NSFetchedResultsController<NSFetchRequestResult> {
        let ctx = self.contextProvider.contextForCurrentThread()
        let request = self.contextProvider.generateFetchRequestForEntity(self.managedObjectType, context: ctx)
        
        request.predicate = predicate
        request.sortDescriptors = sortBy.sortDescriptors()
        
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: ctx, sectionNameKeyPath: groupBy, cacheName: nil)
    }
    
    //MARK: - Count
    open func countEntities(_ predicate: NSPredicate?) -> Int {
        let context = contextProvider.contextForCurrentThread()
        let fetchRequest = contextProvider.generateFetchRequestForEntity(managedObjectType, context: context)
        
        fetchRequest.fetchLimit = 0
        fetchRequest.predicate = predicate
        
        return (try? context.count(for: fetchRequest)) ?? 0
    }
    
    //MARK: - Delete
    open func deleteEntities(_ predicate: NSPredicate?) throws {
        try contextProvider.deleteEntities(predicate, ofType: managedObjectType)
    }
    
    open func deleteEntity(_ object: ManagedEntity) throws -> Void {
        if let object = object as? CDManagedEntity {
            try contextProvider.deleteEntity(object)
        } else {
            if let entity: CDManagedEntity = try entityWithID(object.id!) {
                try contextProvider.deleteEntity(entity)
            }
        }
    }
    
    open func deleteEntityWithID(_ id: String) throws -> Void {
        if let entity: CDManagedEntity = try entityWithID(id) {
            try contextProvider.deleteEntity(entity)
        }
    }
    
    @discardableResult
    open func insertEntity<T: ManagedEntity>(_ entity: T, mergeWith: T?=nil, isFirstInsert: Bool = false, userInfo:[String : AnyObject] = [:]) throws -> T {
        
        if type(of: entity).entityName != self.managedObjectType.entityName {
            throw CoreError.entityMisstype(input: type(of: entity).entityName, target: self.managedObjectType.entityName)
        }
        
        guard let id = entity.id else {
            throw CoreError.runtimeError(description: "Entity must have an ID", cause: nil)
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
    
    open func insertEnities( _ entities : [ManagedEntity], isFirstInsert: Bool = false, userInfo inputUserInfo:[String : Any] = [:]) throws -> [ManagedEntity]? {
        
        var insertedItems: [ManagedEntity] = []
        
        do {
            var userInfo = inputUserInfo
            // Lets try to prefetch all existing entities to speed-up mapping
            let ids: [String] = entities.flatMap { $0.id }
            if ids.count > 0 {
                let prefetchedEntites = try fetchEntities("id in %@", arguments: [ids as Any]) as [CDManagedEntity]
                if prefetchedEntites.count > 0 {
                    var prefetchedByKey = [String: CDManagedEntity]()
                    prefetchedEntites.forEach( { entity in
                        if let id = entity.id {
                            prefetchedByKey[id] = entity
                        }
                    })
                    userInfo[MappingConstans.PrefetchedEntities] = prefetchedByKey as Any?
                }
            }
            
            for entity in entities {
                let mapped: ManagedEntity = try insertEntity(entity, mergeWith: nil, isFirstInsert: isFirstInsert, userInfo: userInfo as [String : AnyObject])
                insertedItems.append(mapped)
            }
        } catch (CoreError.entityMisstype(let input, let target)) {
            let msg = "Insert Error - Input object: \(input) Target was: \(target)"
            DDLogError(msg)
        }
        return insertedItems
    }
    
    open func mapEntity (_ entity: ManagedEntity, managedObject: CDManagedEntity, userInfo:[String : Any] = [:]) throws {
        mapEntityProperties(entity, managedObject: managedObject)
        try mapEntityRelations(entity, managedObject: managedObject, exceptRelationship:nil, userInfo: userInfo)
    }
    
    
    open func mapEntityProperties(_ entity: ManagedEntity, managedObject: CDManagedEntity, userInfo:[String : Any] = [:]) {
        
        //Skip not loaded objects
        guard let newDate = entity.updateDate else {
            return
        }
        let oldDate = managedObject.updateDate
        // Skip not updated objects
        if oldDate != nil && oldDate!.compare(newDate as Date) == .orderedSame {
            return
        }
        
        let isLoaded = entity.isLoaded?.boolValue ?? false
        
        if let entity = entity as? NSObject {
            let object = managedObject as NSObject
            for attribute in managedObject.entity.attributesByName.values {
                
                if asBool(attribute.userInfo?[MappingConstans.SkipAttribute]) {
                    continue;
                }
                
                var value:Any? = entity.value(forKey: attribute.name) as Any?
                
                if !isLoaded && value == nil {
                    value = object.value(forKey: attribute.name) as Any?? ?? attribute.defaultValue as Any?
                } else if value == nil {
                    value = attribute.defaultValue as Any?
                }
                
                if asBool(attribute.userInfo?[MappingConstans.SyncOR]) {
                    let storedValue = object.value(forKey: attribute.name)
                    if storedValue != nil {
                        
                        if let boolValue = storedValue as? NSNumber, boolValue.boolValue {
                            continue
                        } else if value == nil {
                            continue
                        }
                    }
                }
                
                object.setValue(value, forKey: attribute.name)
            }
        }
    }
    
    open func gatewayForEntity(_ inputEntity: ManagedEntity, fromRelationship: NSRelationshipDescription) -> GenericEntityGateway? {
        return fromRelationship.destinationEntity?.gateway()
    }
    
    open func mapEntityRelations(_ inputEntity: ManagedEntity, managedObject: CDManagedEntity, exceptRelationship inExceptRelationship: NSRelationshipDescription?, userInfo:[String : Any] = [:] ) throws {
        
        if let isLoaded = inputEntity.isLoaded?.boolValue, !isLoaded {
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
                
                if let value = relationship.userInfo?[MappingConstans.SkipAttribute] as? String, NSString(string: value).boolValue {
                    continue;
                }
                
                
                var value : Any?
                var nativeValue: Any?
                
                do {
                    try SNExceptionWrapper.try({ () -> Void in
                        value = inputEntityObj.value(forKey: key!) as Any?
                    })
                } catch {
                    //DDLogDebug("Not found: \(key) error: \(error)")
                }
                
                if value != nil && !(value is NSNull) {
                    
                    let existingValue = managedNSObject.value(forKey: key!)
                    
                    if let gateway: GenericEntityGateway = gatewayForEntity(inputEntity, fromRelationship: relationship) {
                        
                        if let value = value as? NSSet, relationship.isToMany {
                            
                            let mapped = try gateway.insertEnities(value.allObjects as! [ManagedEntity], isFirstInsert: false, userInfo: [MappingConstans.ReverceRelation : relationship.inverseRelationship!])
                            
                            if (relationship.isOrdered) {
                                fatalError("Ordered sets in unsupported. LoL")
                            }
                            else {
                                nativeValue = NSSet(array: mapped!)
                                
                                if let set = managedNSObject.value(forKey: key!) as? NSSet, set.count == 0 {
                                    nativeValue = NSSet(array: mapped!)
                                }
                                else if let set = managedNSObject.value(forKey: key!) as? NSSet {
                                    let mutableSet = set.mutableCopy() as? NSMutableSet
                                    mutableSet?.addObjects(from: mapped!)
                                    nativeValue = mutableSet
                                }
                            }
                        } else if let value = value as? ManagedEntity {
                            let localInfo = [MappingConstans.ReverceRelation : relationship.inverseRelationship!]
                            nativeValue = try gateway.insertEntity(value, mergeWith: existingValue as? ManagedEntity, isFirstInsert: false , userInfo: localInfo)
                        }
                    }
    
                    if nativeValue != nil && ( existingValue == nil || !(existingValue! as AnyObject).isEqual(nativeValue!)) {
                        managedNSObject.setValue(nativeValue!, forKey: key!)
                    }
                }
            }
        }
    }
}

public extension NSEntityDescription {
    public func gateway() -> GenericEntityGateway? {
        return BaseDBService.sharedInstance.entityGatewayByMOType((NSClassFromString(self.managedObjectClassName) as! CDManagedEntity.Type))
    }
}
