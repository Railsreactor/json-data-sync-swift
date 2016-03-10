//
//  CoreService.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/17/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import PromiseKit
import CocoaLumberjack


public class CoreService: NSObject {
    
    private static var sharedRemoteManager: BaseJSONAPIManager?
    private static var sharedLocalManager: BaseDBService?
    
    private static let lockObject = NSObject()
    
    public var remoteManager: BaseJSONAPIManager {
        if self.dynamicType.sharedRemoteManager == nil {
            synchronized(CoreService.lockObject) {
                if self.dynamicType.sharedRemoteManager == nil {
                    self.dynamicType.sharedRemoteManager = AbstractRegistryService.mainRegistryService.createRemoteManager()
                }
            }
        }
        return self.dynamicType.sharedRemoteManager!
    }
    
    public var localManager: BaseDBService {
        if self.dynamicType.sharedLocalManager == nil {
            synchronized(CoreService.lockObject) {
                if self.dynamicType.sharedLocalManager == nil {
                    self.dynamicType.sharedLocalManager = AbstractRegistryService.mainRegistryService.createLocalManager()                    
                }
            }
        }
        return self.dynamicType.sharedLocalManager!
    }

    
    // MARK: Helpers
    
    public func runOnBackgroundContext<R> (executeBlock: () throws -> R) -> Promise<R> {
        return self.localManager.performPromiseOnBackgroundContext { () throws -> R in
            return try executeBlock()
        }
    }
    
    //MARK: - Sync lock
    
    internal var syncLock: Bool = false
    internal let syncSemaphore = dispatch_semaphore_create(1)
    internal let lockQueue = dispatch_queue_create("com.jdskit.LockQueue.\(self)", nil)
    
    public func trySync() -> Bool {
        var shouldSync = false
        if !self.syncLock {
            dispatch_sync(self.lockQueue) {
                if !self.syncLock {
                    self.syncLock = true
                    shouldSync = true
                    dispatch_semaphore_wait(self.syncSemaphore, DISPATCH_TIME_FOREVER)
                }
            }
        }
        return shouldSync
    }
    
    public func endSync() {
        dispatch_sync(self.lockQueue) {
            if self.syncLock {
                self.syncLock = false
                dispatch_semaphore_signal(self.syncSemaphore)
            }
        }
    }
    
    public func waitForSync() {
        dispatch_semaphore_wait(self.syncSemaphore, DISPATCH_TIME_FOREVER)
        dispatch_semaphore_signal(self.syncSemaphore)
    }
    
    
}


