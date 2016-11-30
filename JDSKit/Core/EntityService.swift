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


open class EntityService: CoreService {
    
    open var entityType: ManagedEntity.Type

    public required init (entityType: ManagedEntity.Type) {
        self.entityType = entityType
    }
    
    open class func sharedService<T: ManagedEntity>(_ entityType: T.Type = T.self) -> EntityService {
        return AbstractRegistryService.mainRegistryService.entityService(entityType)
    }
    
    open func entityGatway() -> GenericEntityGateway? {
        return self.localManager.entityGatewayByEntityType(self.entityType)
    }
    
    fileprivate func cachedEntity(_ inputQuery: String = "", arguments: [AnyObject]? = nil, sortKeys: [String]? = nil) -> [ManagedEntity] {
        
        let descriptors: [NSSortDescriptor] = sortKeys?.sortDescriptors() ?? [NSSortDescriptor(key: "createDate", ascending: false)]
        
        var query = inputQuery
        
        if !query.isEmpty {
            query += " && "
        }
        
        query += "isLoaded == true && pendingDelete != true"
        
        do {
            if let entitiyGateway = self.entityGatway() {
                let entities = try entitiyGateway.fetchEntities(query, arguments: (arguments ?? [AnyObject]()), sortDescriptors: descriptors) as [ManagedEntity]
                return entities
            }
        } catch {
            DDLogDebug("Failed to fetch cars: \(error)")
        }
        
        return [ManagedEntity]()
    }

    open func syncEntityInternal(_ query: String = "", arguments: [AnyObject]? = nil, remoteFilters: [NSComparisonPredicate]?=nil, includeRelations: [String]?=nil) -> Promise<Void> {
        return self.remoteManager.loadEntities(self.entityType, filters: remoteFilters, include: includeRelations).then(on: .global()) { (input) -> Promise<Void> in
            
            return self.runOnBackgroundContext { () -> Void in
                let start = NSDate()
                DDLogDebug("Will Insert \(input.count) Entities of type: \(String(describing: self.entityType))" )
                if let entityGateway = self.entityGatway() {
                    let newItems: [ManagedEntity] = try entityGateway.insertEnities(input, isFirstInsert: false) ?? []
                    DDLogDebug("Did Insert \(newItems.count ?? 0) Entities of type: \(String(describing: self.entityType)) Time Spent: \(abs(start.timeIntervalSinceNow))" )
                } else {
                    DDLogDebug("No gateway for Entities of type: \(String(describing: self.entityType)). Skipped. Time Spent: \(abs(start.timeIntervalSinceNow))" )
                }
            }
        }
    }
    
    open func syncEntityDelta(_ updateDate: Date?) -> Promise<Void> {
        return Promise<Void>(value:()).then(on: .global()) { _ -> Promise<Void> in
            
            if self.trySync() {
                
                var predicates: [NSComparisonPredicate]? = nil
                if updateDate != nil {
                    predicates = [NSComparisonPredicate(format: "updated_at_gt == %@", updateDate!.toSystemString())]
                }
                DDLogDebug("Will download \(self.entityType) Delta From: \(updateDate)")
                return self.syncEntityInternal("", arguments: nil, remoteFilters: predicates, includeRelations: nil).always {
                    self.endSync()
                }
            } else {
                self.waitForSync()
                return Promise<Void>(value:())
            }
        }
    }
    
    
    open func syncEntity(_ query: String = "", arguments: [AnyObject]? = nil, remoteFilters: [NSComparisonPredicate]?=nil, includeRelations: [String]?=nil, includeEntities: [ManagedEntity.Type]?=nil, skipSave: Bool = false) -> Promise<Void> {
        
        let promiseChain = Promise<Void>(value:())
        
        if includeEntities != nil {
            for type in includeEntities! {
                let includeService = AbstractRegistryService.mainRegistryService.entityService(type)
                promiseChain.then(on: .global()) {
                    return includeService.syncEntity("", arguments: nil, remoteFilters: nil, includeRelations: nil, includeEntities: nil, skipSave: true)
                }
            }
        }
        
        return promiseChain.then(on: .global()) { _ -> Promise<Void> in
            
            if self.trySync() {
                return self.syncEntityInternal(query, arguments: arguments, remoteFilters: remoteFilters, includeRelations: includeRelations).then(on: .global()) { () -> Void in
                    if !skipSave {
                        self.localManager.saveSyncSafe()
                    }
                }.always {
                    self.endSync()
                }
            } else {
                self.waitForSync()
                return Promise<Void>(value:())
            }
        }
    }
    
    fileprivate func refreshEntity(_ entity: ManagedEntity, includeRelations: [String]?=nil) -> Promise<Void> {
        guard let id = entity.id else {
            return Promise(error: CoreError.runtimeError(description: "Entity must have an id", cause: nil))
        }
        let predicate = NSComparisonPredicate(format: "id_eq == \(id)", optionals: nil)
        return self.remoteManager.loadEntities(self.entityType, filters: [predicate],  include: includeRelations).then(on: .global()) { entities -> Promise<Void> in
            return self.runOnBackgroundContext {
                if let entity = entities.first {
                    try self.entityGatway()?.insertEntity(entity)
                }
                self.localManager.saveSyncSafe()
            }
        }
    }
    
    //MARK: - Other
    fileprivate func saveEntity(_ entity: ManagedEntity) -> Promise<ManagedEntity> {
        return self.remoteManager.saveEntity(entity).then(on: .global()) { (remoteEntity) -> Promise<Container> in
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
    
    fileprivate func deleteEntity(_ entity: ManagedEntity) -> Promise<Void> {
        entity.pendingDelete = true
        let countainer = entity.objectContainer()
        
        return self.remoteManager.deleteEntity(entity).recover(execute:{ (error) -> Void in
            switch error {
            case CoreError.serviceError(_, _):
                return
            default:
                entity.pendingDelete = nil
                throw error
            }
        }).then(on: .global())(execute:{ () -> Void in
            return self.runOnBackgroundContext { () -> Void in
                try self.entityGatway()?.deleteEntity(countainer.containedObject()!)
                self.localManager.saveBackgroundUnsafe()
            }
        })
    }
    
    fileprivate func createBlankEntity() -> ManagedEntity {
        let dummyClass: DummyManagedEntity.Type = ModelRegistry.sharedRegistry.extractRep(entityType, subclassOf: DummyManagedEntity.self) as! DummyManagedEntity.Type
        return dummyClass.init()
    }
    
    fileprivate func patchEntity(_ entity: ManagedEntity, applyPatch: (_ entity: ManagedEntity) -> Void ) -> Promise<ManagedEntity> {
        let patch: ManagedEntity = self.createBlankEntity()
        
        patch.id = entity.id!

        applyPatch(patch)
        
        return self.remoteManager.saveEntity(patch).then(on: .global()) { (remoteEntity) -> Promise<Container> in
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
    
    fileprivate func createOrUpdate(_ entity: ManagedEntity, updateClosure: ((_ entity: ManagedEntity) -> Void)? = nil) -> Promise<ManagedEntity> {
        if entity.isTemp() {
            if updateClosure != nil {
                updateClosure!(entity)
            }
            return saveEntity(entity)
        } else {
            return patchEntity(entity, applyPatch: updateClosure! )
        }
    }
}



open class GenericService<T: ManagedEntity>: EntityService {
    
    public required init() {
        super.init(entityType: T.self)
    }

    public required init(entityType: ManagedEntity.Type) {
        fatalError("init(entityType:) has not been implemented")
    }
    
    open class func sharedService() -> GenericService<T> {
        return AbstractRegistryService.mainRegistryService.entityService()
    }
    
    open func cachedEntity(_ query: String = "", arguments: [AnyObject]? = nil, sortKeys: [String]?=nil) -> [T] {
        return super.cachedEntity(query, arguments: arguments, sortKeys: sortKeys) as! [T]
    }

    open func createOrUpdate(_ entity: T, updateClosure: ((_ entity: T) -> Void)? = nil) -> Promise<T> {
        return super.createOrUpdate(entity, updateClosure: updateClosure != nil ? { updateClosure!($0 as! T) } : nil).then { $0 as! T }
    }
    
    open func refreshEntity(_ entity: T, includeRelations: [String]?=nil) -> Promise<Void> {
        return super.refreshEntity(entity, includeRelations: includeRelations)
    }
    
    open func deleteEntity(_ entity: T) -> Promise<Void> {
        return super.deleteEntity(entity)
    }
    
    open func createBlankEntity() -> T {
        return super.createBlankEntity() as! T
    }
}
