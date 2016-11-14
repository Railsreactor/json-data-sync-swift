//
//  SyncService.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/1/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import Foundation
import PromiseKit
import CocoaLumberjack

public enum SyncError: ErrorType {
    case CheckForUpdates(NSDate)
}

public typealias SyncInfo = [String]

private let ZeroDate = NSDate(timeIntervalSince1970: 0)
private let EventKey = String(Event.self)

public class AbstractSyncService: CoreService {
    
    public var liteSyncEnabled = false
    
    // *************************** Override *******************************
    // if you want to split some update info between different users or something...
    
    public func filterIDForEntityKey(key: String) -> String? {
        return nil
    }
    
    public func shouldSyncEntityOfType(managedEntityKey: String, lastUpdateDate: NSDate?) -> Bool {
        return true
    }
    
    // *************************************************************************
    
    public var lastSyncDate = ZeroDate
    public var lastSuccessSyncDate = ZeroDate

    public lazy var updateInfoGateway: UpdateInfoGateway = {
        return UpdateInfoGateway(self.localManager)
    } ()
    
    internal func entitiesToSync() -> [String] {
        let extracted = ExtractAllReps(CDManagedEntity.self)
        return extracted.flatMap {
            let name = ($0 as! CDManagedEntity.Type).entityName
            if name == "ManagedEntity" {
                return nil
            }
            return name
        }
    }

    internal func checkForUpdates(eventSyncDate: NSDate) -> Promise<SyncInfo> {
        DDLogDebug("Checking for updates... \(eventSyncDate)")
        let predicate = NSComparisonPredicate(format: "created_at_gt == %@", eventSyncDate.toSystemString());
        return self.remoteManager.loadEntities(Event.self, filters: [predicate], include: nil, fields: liteSyncEnabled ? ["relatedEntityName", "relatedEntityId", "action"] : nil).thenInBGContext { (events: [Event]) -> SyncInfo in
            var itemsToSync = Set<String>()
            let requiredItems = Set(self.entitiesToSync())
            
            for event in events {
                guard let entityName = event.relatedEntityName else { continue }
                
                if let date = event.updateDate where self.lastSyncDate.compare(date) == NSComparisonResult.OrderedAscending {
                    self.lastSyncDate = date
                }
                
                if let id = event.relatedEntityId where event.action == Action.Deleted {
                    do {
                        try AbstractRegistryService.mainRegistryService.entityServiceByKey(entityName).entityGatway()?.deleteEntityWithID(id)
                        DDLogDebug("Deleted \(entityName) with id: \(id)")
                    } catch {
                    }
                } else if requiredItems.contains(entityName) {
                    if !itemsToSync.contains(entityName) {
                        DDLogDebug("Will sync: \(entityName)...")
                    }
                    itemsToSync.insert(event.relatedEntityName!)
                }
            }
            
            return Array(itemsToSync)
        }
    }
    
    internal func syncInternal() -> Promise<Void> {
        return self.runOnBackgroundContext { () -> SyncInfo in
            
            if let eventSyncInfo = try self.updateInfoGateway.updateInfoForKey(EventKey, filterID: self.filterIDForEntityKey(EventKey)) {
                throw SyncError.CheckForUpdates(eventSyncInfo.updateDate!)
            } else {
                DDLogDebug("Going to sync at first time...")
                return self.entitiesToSync()
            }
        }.recover(on: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { error -> Promise<SyncInfo> in
            switch error {
            case SyncError.CheckForUpdates(let syncInfo):
                return self.checkForUpdates(syncInfo)
            default:
                throw error
            }
        }.thenInBGContext { updateEntitiesKeys -> [Promise<NSDate>] in
            var syncPromises = [Promise<NSDate>]()

            for entityKey in updateEntitiesKeys {
                let service = AbstractRegistryService.mainRegistryService.entityServiceByKey(entityKey)
                let filter = self.filterIDForEntityKey(entityKey)
                let syncDate = try self.updateInfoGateway.updateInfoForKey(entityKey, filterID: filter)?.updateDate ?? ZeroDate
                
                if !self.shouldSyncEntityOfType(entityKey, lastUpdateDate: syncDate) {
                    continue
                }
                
                let syncPromise = service.syncEntityDelta(syncDate).thenInBGContext { _ -> NSDate in
                    let updateInfo: CDUpdateInfo = try self.updateInfoGateway.updateInfoForKey(entityKey, filterID: filter, createIfNeed: true)!
                    
                    var finalSyncDate = ZeroDate
                    if self.lastSyncDate == ZeroDate {
                        let topMostEntity: ManagedEntity? = try service.entityGatway()?.fetchEntities(nil, sortDescriptors: ["-updateDate"].sortDescriptors()).first
                        finalSyncDate = topMostEntity?.updateDate ?? syncDate
                    } else {
                        finalSyncDate = self.lastSyncDate
                    }
                    updateInfo.updateDate = finalSyncDate
                    return finalSyncDate
                }
                syncPromises.append(syncPromise)
            }
            
            return syncPromises
        }.thenInBackground { promises in
            return when(promises)
        }.thenInBGContext { dates -> Void in
            let eventSyncInfo = try self.updateInfoGateway.updateInfoForKey(EventKey, filterID: self.filterIDForEntityKey(EventKey), createIfNeed: true)
            if let eventSync = eventSyncInfo?.updateDate {
                if self.lastSyncDate == ZeroDate {
                    var latestDate = ZeroDate
                    
                    dates.forEach {
                        if latestDate.compare($0) == NSComparisonResult.OrderedAscending {
                            latestDate = $0
                        }
                    }
                    self.lastSyncDate = latestDate.timeIntervalSince1970 > eventSync.timeIntervalSince1970 ? latestDate : eventSync
                }
            }
            
            self.lastSuccessSyncDate = self.lastSyncDate
            eventSyncInfo?.updateDate = self.lastSyncDate
        }.always (on: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
            self.localManager.saveSyncSafe()
        }
    }
    
    public func sync() -> Promise<Void> {
        return dispatch_promise {}.thenInBackground {
            if self.trySync() {
                return self.syncInternal().always {
                    self.endSync()
                }
            } else {
                self.waitForSync()
                return Promise<Void>()
            }
        }
    }
}
