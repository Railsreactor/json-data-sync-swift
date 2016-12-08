//
//  BaseDBService.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/27/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//


import Foundation
import PromiseKit
import CoreData
import CocoaLumberjack

enum CoreDataError: Error {
    case storeOutdated
}

open class BaseDBService: NSObject, ManagedObjectContextProvider {
    
    open static var sharedInstance: BaseDBService!
    
    var modelURL: URL
    var storeURL: URL
    
    public init(modelURL aModelURL: URL, storeURL aStoreURL: URL) {
        modelURL = aModelURL
        storeURL = aStoreURL
        super.init()
        
        if BaseDBService.sharedInstance == nil {
            BaseDBService.sharedInstance = self
        }
        
        initilizePredefinedGateways()
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(BaseDBService.mergeChangesOnMainThread(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: backgroundManagedObjectContext)
    }
    
    // ******************************************************

    fileprivate lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    fileprivate lazy var managedObjectModel: NSManagedObjectModel = {
        return NSManagedObjectModel(contentsOf: self.modelURL)!
    }()
    
    fileprivate lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        DDLogDebug("Initializing store...")
        
        let url = self.storeURL
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        
//        Clean up DB for debug purpose:
//        do {
//            try FileManager.default.removeItem(at: url);
//        } catch {
//        }
//        
        do {
            // Cleanup local cache if store going to migrate. Hack to avoid bug when newly added properties not set during sync, because existed entities wasn't updated since last sync.
            // Options to use with any delta-sync mechanism: [NSMigratePersistentStoresAutomaticallyOption:true, NSInferMappingModelAutomaticallyOption:true]
            let meta = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url, options: nil)
            if !self.managedObjectModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: meta) {
                throw CoreDataError.storeOutdated
            }
            DDLogDebug("Store meta is compatible.")
        } catch {
            DDLogError("Failed to init store coordinator with existing database. Trying to reinitialize store...")
            do {
                try FileManager.default.removeItem(at: url);
            } catch {}
        }
        
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
            DDLogDebug("Store Initialized.")
        } catch {
            DDLogError("Failed to initialize sore: \(error)")
            abort()
        }
        
        return coordinator
    }()
    
    
    lazy var backgroundManagedObjectContext: NSManagedObjectContext = {
        var backgroundManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundManagedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        backgroundManagedObjectContext.mergePolicy = NSOverwriteMergePolicy
        return backgroundManagedObjectContext
    }()
    
    lazy var mainUIManagedObjectContext: NSManagedObjectContext = {
        var mainUIManagedObjectContext : NSManagedObjectContext?
        let initBlock = {() -> Void in
            mainUIManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            mainUIManagedObjectContext!.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            mainUIManagedObjectContext!.persistentStoreCoordinator = self.persistentStoreCoordinator
        }
        
        if Thread.isMainThread {
            initBlock()
        } else {
            DispatchQueue.main.sync(execute: { () -> Void in
                initBlock()
            })
        }
        
        return mainUIManagedObjectContext!
    }()
    
    //MARK: - Entity Gateways

    fileprivate var syncObject = NSObject()
    fileprivate var entityGatewaysByType: [String : GenericEntityGateway] =  [:]

    func initilizePredefinedGateways () {
        synchronized(syncObject) { () -> () in
            for gateway in AbstractRegistryService.mainRegistryService._predefinedEntityGateways {
                self.entityGatewaysByType[String(gateway.managedObjectType.entityName)] = gateway
            }
        }
    }
    
    open func entityGatewayByEntityTypeKey(_ typeKey: String) -> GenericEntityGateway? {
        var gateway = entityGatewaysByType[typeKey]
        if gateway == nil {
            synchronized(syncObject) { () -> () in
                gateway = self.entityGatewaysByType[typeKey]
                if gateway == nil {
                    if let type = ExtractRep(ExtractModel(typeKey), subclassOf: CDManagedEntity.self) as? CDManagedEntity.Type {
                        gateway = GenericEntityGateway(type)
                        self.entityGatewaysByType[typeKey] = gateway
                    }
                }
            }
        }
        return gateway
    }

    open func entityGatewayByEntityType(_ type: ManagedEntity.Type) -> GenericEntityGateway? {
        return entityGatewayByEntityTypeKey(String(describing: type))
    }
    
    open func entityGatewayByMOType(_ type: CDManagedEntity.Type) -> GenericEntityGateway? {
        return entityGatewayByEntityTypeKey(String(describing: type.entityType))
    }
    
    //MARK: - Merge
    @objc internal func mergeChangesOnMainThread(_ didSaveNotification: Notification) {
        let context = self.mainUIManagedObjectContext
        
        context.perform { () -> Void in
            let timestamp = Date()
            
            let inserted = didSaveNotification.userInfo?[NSInsertedObjectsKey] as? NSSet
            let updated  = didSaveNotification.userInfo?[NSUpdatedObjectsKey] as? NSSet
            let deleted  = didSaveNotification.userInfo?[NSDeletedObjectsKey] as? NSSet
            
            context.mergeChanges(fromContextDidSave: didSaveNotification)
            if let updated = didSaveNotification.userInfo?["updated"] as? NSSet {
                for unasafeMO in updated {
                    if let unasafeMO = unasafeMO as? NSManagedObject {
                        do {
                            let safeMO = try context.existingObject(with: unasafeMO.objectID)
                            context.refresh(safeMO, mergeChanges: true)
                        } catch {
                            DDLogError("Managed Object not found: \(unasafeMO.objectID)")
                        }
                    }
                }
            }
            
            DDLogDebug("Merged changes: { I: \(inserted?.count ?? 0), U: \(updated?.count ?? 0) D: \(deleted?.count)}  in \(abs(timestamp.timeIntervalSinceNow))")
        }
    }
    
    //MARK: - Save
    internal func saveUnsafe(_ context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch let error as NSError {
            DDLogError("Failed to save to data store: \(error.localizedDescription)")
            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    DDLogError("DetailedError: \(detailedError.userInfo)")
                }
            }
            abort();
        }
    }
    
    open func saveContextSyncSafe(_ context: NSManagedObjectContext) {
        context.performAndWait { () -> Void in
            self.saveUnsafe(context)
        }
    }
    
    open func saveContextSafe(_ context: NSManagedObjectContext) {
        context.perform { () -> Void in
            self.saveUnsafe(context)
        }
    }
    
    open func saveSyncSafe() {
        self.saveContextSyncSafe(self.backgroundManagedObjectContext)
    }
    
    open func saveBackgroundUnsafe() {
        self.saveUnsafe(self.backgroundManagedObjectContext)
    }
    
    open func performBlockOnBackgroundContext(_ block: @escaping () -> Void) {
        backgroundManagedObjectContext.perform(block)
    }
    
    open func performPromiseOnBackgroundContext<T>(_ block: @escaping () throws -> T) -> Promise<T> {
        return Promise<T> { fulfill, reject in
            self.performBlockOnBackgroundContext({ () -> () in
                do {
                    fulfill (try block())
                } catch {
                    reject(error)
                }
            })
        }
    }
    
    //MARK: -
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - Entities
    open func contextForCurrentThread() -> NSManagedObjectContext {
        let context: NSManagedObjectContext = Thread.isMainThread ? mainUIManagedObjectContext : backgroundManagedObjectContext
        return context
    }
    
    open func fetchEntity(_ managedObjectID: NSManagedObjectID) throws -> NSManagedObject? {
        let context = contextForCurrentThread()
        return try context.existingObject(with: managedObjectID)
    }
    
    open func fetchEntities(_ managedObjectIDs: [NSManagedObjectID]) -> [NSManagedObject] {
        let context = contextForCurrentThread()
        var array = [NSManagedObject]()
        for managedObjectID in managedObjectIDs {
            array.append(context.object(with: managedObjectID))
        }
        return array
    }
    
    //MARK: - Entities
    
    open func createEntity(_ type: NSManagedObject.Type, temp: Bool = false) -> NSManagedObject {
        let context = contextForCurrentThread()
        let name = String(describing: type)
        if !temp {
            return NSEntityDescription.insertNewObject(forEntityName: name, into: context)
        } else {
            let entityDesc = NSEntityDescription.entity(forEntityName: name, in: context)
            return NSManagedObject(entity: entityDesc!, insertInto: nil)
        }
    }
    
    open func generateFetchRequestForEntity(_ enitityType : NSManagedObject.Type, context: NSManagedObjectContext) -> NSFetchRequest<NSFetchRequestResult> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let name = String(describing: enitityType)
        
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: name, in: context)
        return fetchRequest
    }
    
    open func fetchEntity(_ predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> NSManagedObject? {
        let context = contextForCurrentThread()
        let fetchRequest = generateFetchRequestForEntity(ofType, context: context)
        
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        
        var entity: NSManagedObject? = nil
        if try context.count(for: fetchRequest) > 0 {
            entity = try context.fetch(fetchRequest).last as? NSManagedObject
        }
        return entity
    }
    
    open func fetchEntities(_ predicate: NSPredicate?, ofType: NSManagedObject.Type, sortDescriptors: [NSSortDescriptor]?) throws -> [NSManagedObject] {
        
        let context = contextForCurrentThread()
        let fetchRequest = generateFetchRequestForEntity(ofType, context: context)
        
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        
        var entities: [CDManagedEntity] = []
        if try context.count(for: fetchRequest) > 0 {
            entities = try context.fetch(fetchRequest) as! [CDManagedEntity]
        }
        return entities
    }
    
    open func countEntities(_ ofType: NSManagedObject.Type) -> Int {
        let context = contextForCurrentThread()
        let fetchRequest = generateFetchRequestForEntity(ofType, context: context)
    
        let count = (try? context.count(for: fetchRequest)) ?? 0
        
        if(count == NSNotFound) {
            return 0
        }
        
        return count
    }
    
    //MARK: - Delete
    open func deleteEntities(_ predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> Void {
        
        let entities = try fetchEntities(predicate, ofType:ofType, sortDescriptors: nil)
        
        for entity in entities {
            try deleteEntity(entity)
        }
    }
    
    open func deleteEntity(_ object: NSManagedObject) throws -> Void {
        let context = contextForCurrentThread()
        context.delete(object)
    }
}



public extension Promise {
    public func thenInBGContext<U>(_ body: @escaping (T) throws -> U) -> Promise<U> {
        return firstly { return self }.then(on: .global()) { value in
            return BaseDBService.sharedInstance.performPromiseOnBackgroundContext{ () -> U in
                return try body(value)
            }
        }
    }
}


