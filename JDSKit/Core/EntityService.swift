//
//  EntityService.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/8/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import PromiseKit
import CocoaLumberjack


public class EntityService: CoreService {
    
    public var entityType: ManagedEntity.Type

    public required init (entityType: ManagedEntity.Type) {
        self.entityType = entityType
    }
    
    public class func sharedService<T: ManagedEntity>(entityType: T.Type = T.self) -> EntityService {
        return AbstractRegistryService.mainRegistryService.entityService(entityType)
    }
    
    public func entityGatway() -> GenericEntityGateway? {
        return self.localManager.entityGatewayByEntityType(self.entityType)
    }
    
    private func cachedEntity(inputQuery: String = "", arguments: [AnyObject]? = nil, sortKeys: [String]? = nil) -> [ManagedEntity] {
        
        let descriptors: [NSSortDescriptor] = sortKeys?.sortDescriptors() ?? [NSSortDescriptor(key: "createDate", ascending: false)]
        
        var query = inputQuery
        
        if !query.isEmpty {
            query += " && "
        }
        
        query += "isLoaded == %@ && pendingDelete != %@"
        
        do {
            if let entitiyGateway = self.entityGatway() {
                let entities = try entitiyGateway.fetchEntities(query, arguments: (arguments ?? [AnyObject]()) + [true, true], sortDescriptors: descriptors) as [ManagedEntity]
                return entities
            }
        } catch {
            DDLogDebug("Failed to fetch cars: \(error)")
        }
        
        return [ManagedEntity]()
    }

    public func syncEntityInternal(query: String = "", arguments: [AnyObject]? = nil, remoteFilters: [NSComparisonPredicate]?=nil, includeRelations: [String]?=nil) -> Promise<Void> {
        return self.remoteManager.loadEntities(self.entityType, filters: remoteFilters, include: includeRelations).thenInBackground { (input) -> Promise<Void> in
            
            return self.runOnBackgroundContext { () -> Void in
                let start = NSDate()
                DDLogDebug("Will Insert \(input.count) Entities of type: \(String(self.entityType))" )
                if let entityGateway = self.entityGatway() {
                    let newItems: [ManagedEntity] = try entityGateway.insertEnities(input, isFirstInsert: false) ?? []
                    DDLogDebug("Did Insert \(newItems.count ?? 0) Entities of type: \(String(self.entityType)) Time Spent: \(abs(start.timeIntervalSinceNow))" )
                } else {
                    DDLogDebug("No gateway for Entities of type: \(String(self.entityType)). Skipped. Time Spent: \(abs(start.timeIntervalSinceNow))" )
                }
            }
        }
    }
    
    public func syncEntityDelta(updateDate: NSDate?) -> Promise<Void> {
        return Promise<Void>().thenInBackground { _ -> Promise<Void> in
            
            if self.trySync() {
                
                var predicates: [NSComparisonPredicate]? = nil
                if updateDate != nil {
                    predicates = [NSComparisonPredicate(format: "updated_at_gt == %@", updateDate!.toSystemString())]
                }
                DDLogDebug("Will download \(self.entityType) Delta From: \(updateDate ?? "nil")")                
                return self.syncEntityInternal("", arguments: nil, remoteFilters: predicates, includeRelations: nil).always {
                    self.endSync()
                }
            } else {
                self.waitForSync()
                return Promise<Void>()
            }
        }
    }
    
    
    public func syncEntity(query: String = "", arguments: [AnyObject]? = nil, remoteFilters: [NSComparisonPredicate]?=nil, includeRelations: [String]?=nil, includeEntities: [ManagedEntity.Type]?=nil, skipSave: Bool = false) -> Promise<Void> {
        
        let promiseChain = Promise<Void>(Void())
        
        if includeEntities != nil {
            for type in includeEntities! {
                let includeService = AbstractRegistryService.mainRegistryService.entityService(type)
                promiseChain.thenInBackground {
                    return includeService.syncEntity("", arguments: nil, remoteFilters: nil, includeRelations: nil, includeEntities: nil, skipSave: true)
                }
            }
        }
        
        return promiseChain.thenInBackground { _ -> Promise<Void> in
            
            if self.trySync() {
                return self.syncEntityInternal(query, arguments: arguments, remoteFilters: remoteFilters, includeRelations: includeRelations).thenInBackground { () -> Void in
                    if !skipSave {
                        self.localManager.saveSyncSafe()
                    }
                }.always {
                    self.endSync()
                }
            } else {
                self.waitForSync()
                return Promise<Void>()
            }
        }
    }
    
    private func refreshEntity(entity: ManagedEntity, includeRelations: [String]?=nil) -> Promise<Void> {
        guard let id = entity.id else {
            return Promise(error: CoreError.RuntimeError(description: "Entity must have an id", cause: nil))
        }
        let predicate = NSComparisonPredicate(format: "id_eq == \(id)", optionals: nil)
        return self.remoteManager.loadEntities(self.entityType, filters: [predicate],  include: includeRelations).thenInBackground { entities -> Promise<Void> in
            return self.runOnBackgroundContext {
                if let entity = entities.first {
                    try self.entityGatway()?.insertEntity(entity)
                }
                self.localManager.saveSyncSafe()
            }
        }
    }
    
    //MARK: - Other
    private func saveEntity(entity: ManagedEntity) -> Promise<ManagedEntity> {
        return self.remoteManager.saveEntity(entity).thenInBackground { (remoteEntity) -> Promise<Container> in
            return self.runOnBackgroundContext { () -> Container in
                let result = try self.entityGatway()?.insertEntity(remoteEntity) ?? remoteEntity
                self.localManager.saveBackgroundUnsafe()
                return result.objectContainer()
            }
        }.then { (container) -> ManagedEntity in
            let entity = try (container.containedObject()! as ManagedEntity)
            entity.refresh()
            return entity
        }
    }
    
    private func deleteEntity(entity: ManagedEntity) -> Promise<Void> {
        entity.pendingDelete = true
        let countainer = entity.objectContainer()
        
        return self.remoteManager.deleteEntity(entity).recover({ (error) -> Void in
            switch error {
            case CoreError.ServiceError(_, _):
                return
            default:
                entity.pendingDelete = nil
                throw error
            }
        }).thenInBackground({ () -> Void in
            return self.runOnBackgroundContext { () -> Void in
                try self.entityGatway()?.deleteEntity(countainer.containedObject()!)
                self.localManager.saveBackgroundUnsafe()
            }
        })
    }
    
    private func createBlankEntity() -> ManagedEntity {
        let dummyClass: DummyManagedEntity.Type = ModelRegistry.sharedRegistry.extractRep(entityType, subclassOf: DummyManagedEntity.self) as! DummyManagedEntity.Type
        return dummyClass.init()
    }
    
    private func patchEntity(entity: ManagedEntity, applyPatch: (entity: ManagedEntity) -> Void ) -> Promise<ManagedEntity> {
        let patch: ManagedEntity = self.createBlankEntity()
        
        patch.id = entity.id!

        applyPatch(entity: patch)
        
        return self.remoteManager.saveEntity(patch).thenInBackground { (remoteEntity) -> Promise<Container> in
            return self.runOnBackgroundContext { () -> Container in
                let result = try self.entityGatway()?.insertEntity(remoteEntity) ?? remoteEntity
                self.localManager.saveBackgroundUnsafe()
                return result.objectContainer()
            }
        }.then { (container) -> ManagedEntity in
            let entity = try (container.containedObject()! as ManagedEntity)
            entity.refresh()
            return entity
        }
    }
    
    private func createOrUpdate(entity: ManagedEntity, updateClosure: ((entity: ManagedEntity) -> Void)? = nil) -> Promise<ManagedEntity> {
        if entity.isTemp() {
            if updateClosure != nil {
                updateClosure!(entity: entity)
            }
            return saveEntity(entity)
        } else {
            return patchEntity(entity, applyPatch: updateClosure! )
        }
    }
}



public class GenericService<T: ManagedEntity>: EntityService {
    
    public required init() {
        super.init(entityType: T.self)
    }
    
    public class func sharedService() -> GenericService<T> {
        return AbstractRegistryService.mainRegistryService.entityService()
    }
    
    public func cachedEntity(let query: String = "", arguments: [AnyObject]? = nil, sortKeys: [String]?=nil) -> [T] {
        return super.cachedEntity(query, arguments: arguments, sortKeys: sortKeys) as! [T]
    }

    public func createOrUpdate(entity: T, updateClosure: ((entity: T) -> Void)? = nil) -> Promise<T> {
        return super.createOrUpdate(entity, updateClosure: updateClosure != nil ? { updateClosure!(entity: $0 as! T) } : nil).then { $0 as! T }
    }
    
    public func refreshEntity(entity: T, includeRelations: [String]?=nil) -> Promise<Void> {
        return super.refreshEntity(entity, includeRelations: includeRelations)
    }
    
    public func deleteEntity(entity: T) -> Promise<Void> {
        return super.deleteEntity(entity)
    }
    
    public func createBlankEntity() -> T {
        return super.createBlankEntity() as! T
    }
}
