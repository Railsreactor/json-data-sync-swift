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

enum CoreDataError: ErrorType {
    case StoreOutdated
}

public class BaseDBService: NSObject, ManagedObjectContextProvider {
    
    public static var sharedInstance: BaseDBService!
    
    var modelURL: NSURL
    var storeURL: NSURL
    
    public init(modelURL aModelURL: NSURL, storeURL aStoreURL: NSURL) {
        modelURL = aModelURL
        storeURL = aStoreURL
        super.init()
        
        if BaseDBService.sharedInstance == nil {
            BaseDBService.sharedInstance = self
        }
        
        initilizePredefinedGateways()
        
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(BaseDBService.mergeChangesOnMainThread(_:)), name: NSManagedObjectContextDidSaveNotification, object: backgroundManagedObjectContext)
    }
    
    // ******************************************************

    private lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        return NSManagedObjectModel(contentsOfURL: self.modelURL)!
    }()
    
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        DDLogDebug("Initializing store...")
        
        let url = self.storeURL
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        
//        Clean up DB for debug purpose:
        do {
            try NSFileManager.defaultManager().removeItemAtURL(url);
        } catch {
        }
        
        do {
            // Cleanup local cache if store going to migrate. Hack to avoid bug when newly added properties not set during sync, because existed entities wasn't updated since last sync.
            // Options to use with any delta-sync mechanism: [NSMigratePersistentStoresAutomaticallyOption:true, NSInferMappingModelAutomaticallyOption:true]
            let meta = try NSPersistentStoreCoordinator.metadataForPersistentStoreOfType(NSSQLiteStoreType, URL: url, options: nil)
            if !self.managedObjectModel.isConfiguration(nil, compatibleWithStoreMetadata: meta) {
                throw CoreDataError.StoreOutdated
            }
            DDLogDebug("Store meta is compatible.")
        } catch {
            DDLogError("Failed to init store coordinator with existing database. Trying to reinitialize store...")
            do {
                try NSFileManager.defaultManager().removeItemAtURL(url);
            } catch {}
        }
        
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
            DDLogDebug("Store Initialized.")
        } catch {
            DDLogError("Failed to initialize sore: \(error)")
            abort()
        }
        
        return coordinator
    }()
    
    
    lazy var backgroundManagedObjectContext: NSManagedObjectContext = {
        var backgroundManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundManagedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        backgroundManagedObjectContext.mergePolicy = NSOverwriteMergePolicy
        return backgroundManagedObjectContext
    }()
    
    lazy var mainUIManagedObjectContext: NSManagedObjectContext = {
        var mainUIManagedObjectContext : NSManagedObjectContext?
        let initBlock = {() -> Void in
            mainUIManagedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            mainUIManagedObjectContext!.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            mainUIManagedObjectContext!.persistentStoreCoordinator = self.persistentStoreCoordinator
        }
        
        if NSThread.isMainThread() {
            initBlock()
        } else {
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                initBlock()
            })
        }
        
        return mainUIManagedObjectContext!
    }()
    
    //MARK: - Entity Gateways

    private var syncObject = NSObject()
    private var entityGatewaysByType: [String : GenericEntityGateway] =  [:]

    func initilizePredefinedGateways () {
        synchronized(syncObject) { () -> () in
            for gateway in AbstractRegistryService.mainRegistryService._predefinedEntityGateways {
                self.entityGatewaysByType[String(gateway.managedObjectType.entityName)] = gateway
            }
        }
    }
    
    public func entityGatewayByEntityTypeKey(typeKey: String) -> GenericEntityGateway {
        var gateway = entityGatewaysByType[typeKey]
        if gateway == nil {
            synchronized(syncObject) { () -> () in
                gateway = self.entityGatewaysByType[typeKey]
                if gateway == nil {
                    let type = ExtractRep(ExtractModel(typeKey), subclassOf: CDManagedEntity.self) as! CDManagedEntity.Type
                    gateway = GenericEntityGateway(type)
                    self.entityGatewaysByType[typeKey] = gateway
                }
            }
        }
        return gateway!
    }

    public func entityGatewayByEntityType(type: ManagedEntity.Type) -> GenericEntityGateway {
        return entityGatewayByEntityTypeKey(String(type))
    }
    
    public func entityGatewayByMOType(type: CDManagedEntity.Type) -> GenericEntityGateway {
        return entityGatewayByEntityTypeKey(String(type.entityType))
    }
    
    //MARK: - Merge
    @objc internal func mergeChangesOnMainThread(didSaveNotification: NSNotification) {
        let context = self.mainUIManagedObjectContext
        
        context.performBlock { () -> Void in
            let timestamp = NSDate()
            
            let inserted = didSaveNotification.userInfo?[NSInsertedObjectsKey] as? NSSet
            let updated  = didSaveNotification.userInfo?[NSUpdatedObjectsKey] as? NSSet
            let deleted  = didSaveNotification.userInfo?[NSDeletedObjectsKey] as? NSSet
            
            context.mergeChangesFromContextDidSaveNotification(didSaveNotification)
            if let updated = didSaveNotification.userInfo?["updated"] as? NSSet {
                for unasafeMO in updated {
                    if let unasafeMO = unasafeMO as? NSManagedObject {
                        do {
                            let safeMO = try context.existingObjectWithID(unasafeMO.objectID)
                            context.refreshObject(safeMO, mergeChanges: true)
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
    internal func saveUnsafe(context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch let error as NSError {
            print("Failed to save to data store: \(error.localizedDescription)")
            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("DetailedError: \(detailedError.userInfo)")
                }
            }
            abort();
        }
    }
    
    public func saveContextSync(context: NSManagedObjectContext) {
        context.performBlockAndWait { () -> Void in
            self.saveUnsafe(context)
        }
    }
    
    public func saveContext(context: NSManagedObjectContext) {
        context.performBlock { () -> Void in
            self.saveUnsafe(context)
        }
    }
    
    public func saveSync() {
        self.saveContextSync(self.contextForCurrentThread())
    }
    
    public func save() {
        self.backgroundManagedObjectContext.performBlock { () -> Void in
            self.saveUnsafe(self.backgroundManagedObjectContext)
            self.saveContext(self.mainUIManagedObjectContext)
        }
    }
    
    //MARK: - Entities
    public func contextForCurrentThread() -> NSManagedObjectContext {
        let context: NSManagedObjectContext = NSThread.isMainThread() ? mainUIManagedObjectContext : backgroundManagedObjectContext
        return context
    }
    
    public func performBlockOnBackgroundContext(block: () -> Void) {
        if NSThread.isMainThread() {
            abort()
        }
        backgroundManagedObjectContext.performBlock(block)
    }
    
    public func performPromiseOnBackgroundContext<T>(block: () throws -> T) -> Promise<T> {
        
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

    //MARK: - Reset
    public func resetUIContext() {
        self.mainUIManagedObjectContext.reset()
    }
    
    public func resetMainBackgroundContext() {
        self.backgroundManagedObjectContext.reset()
    }
    
    //MARK: -
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public func fetchEntity(managedObjectID: NSManagedObjectID) throws -> NSManagedObject? {
        let context = contextForCurrentThread()
        return try context.existingObjectWithID(managedObjectID)
    }
    
    public func fetchEntities(managedObjectIDs: [NSManagedObjectID]) -> [NSManagedObject] {
        let context = contextForCurrentThread()
        var array = [NSManagedObject]()
        for managedObjectID in managedObjectIDs {
            array.append(context.objectWithID(managedObjectID))
        }
        return array
    }
    
    //MARK: - Entities
    
    public func createEntity(type: NSManagedObject.Type, temp: Bool = false) -> NSManagedObject {
        let context = contextForCurrentThread()
        let name = String(type)
        if !temp {
            return NSEntityDescription.insertNewObjectForEntityForName(name, inManagedObjectContext: context)
        } else {
            let entityDesc = NSEntityDescription.entityForName(name, inManagedObjectContext: context)
            return NSManagedObject(entity: entityDesc!, insertIntoManagedObjectContext: nil)
        }
    }
    
    public func generateFetchRequestForEntity(enitityType : NSManagedObject.Type, context: NSManagedObjectContext) -> NSFetchRequest {
        
        let fetchRequest = NSFetchRequest()
        let name = String(enitityType)
        
        fetchRequest.entity = NSEntityDescription.entityForName(name, inManagedObjectContext: context)
        return fetchRequest
    }
    
    public func fetchEntity(predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> NSManagedObject? {
        let context = contextForCurrentThread()
        let fetchRequest = generateFetchRequestForEntity(ofType, context: context)
        
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        
        var error: NSError? = nil
        var entity: NSManagedObject? = nil
        if context.countForFetchRequest(fetchRequest, error: &error) > 0 {
            entity = try context.executeFetchRequest(fetchRequest).last as? NSManagedObject
        } else {
            if let error = error {
                throw error
            }
        }
        return entity
    }
    
    public func fetchEntities(predicate: NSPredicate?, ofType: NSManagedObject.Type, sortDescriptors: [NSSortDescriptor]?) throws -> [NSManagedObject] {
        
        let context = contextForCurrentThread()
        let fetchRequest = generateFetchRequestForEntity(ofType, context: context)
        
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        var error: NSError? = nil
        var entities: [CDManagedEntity] = []
        if context.countForFetchRequest(fetchRequest, error: &error) > 0 {
            entities = try context.executeFetchRequest(fetchRequest) as! [CDManagedEntity]
        } else {
            if let error = error {
                throw error
            }
        }
        return entities
    }
    
    public func countEntities(ofType: NSManagedObject.Type) -> Int {
        let context = contextForCurrentThread()
        let fetchRequest = generateFetchRequestForEntity(ofType, context: context)
    
        let count = context.countForFetchRequest(fetchRequest, error: nil)
        
        if(count == NSNotFound) {
            return 0
        }
        
        return count
    }
    
    //MARK: - Delete
    public func deleteEntities(predicate: NSPredicate?, ofType: NSManagedObject.Type) throws -> Void {
        
        let entities = try fetchEntities(predicate, ofType:ofType, sortDescriptors: nil)
        
        for entity in entities {
            try deleteEntity(entity)
        }
    }
    
    public func deleteEntity(object: NSManagedObject) throws -> Void {
        let context = contextForCurrentThread()
        context.deleteObject(object)
    }
}



public extension Promise {
    public func thenInBGContext<U>(body: (T) throws -> U) -> Promise<U> {
        return firstly { return self }.thenInBackground { value in
            return BaseDBService.sharedInstance.performPromiseOnBackgroundContext{ () -> U in
                return try body(value)
            }
        }
    }
}


