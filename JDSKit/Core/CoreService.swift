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


open class CoreService: NSObject {
    
    fileprivate static var sharedRemoteManager: BaseJSONAPIManager?
    fileprivate static var sharedLocalManager: BaseDBService?
    
    fileprivate static let lockObject = NSObject()
    
    open var remoteManager: BaseJSONAPIManager {
        if type(of: self).sharedRemoteManager == nil {
            synchronized(CoreService.lockObject) {
                if type(of: self).sharedRemoteManager == nil {
                    type(of: self).sharedRemoteManager = AbstractRegistryService.mainRegistryService.createRemoteManager()
                }
            }
        }
        return type(of: self).sharedRemoteManager!
    }
    
    open var localManager: BaseDBService {
        if type(of: self).sharedLocalManager == nil {
            synchronized(CoreService.lockObject) {
                if type(of: self).sharedLocalManager == nil {
                    type(of: self).sharedLocalManager = AbstractRegistryService.mainRegistryService.createLocalManager()                    
                }
            }
        }
        return type(of: self).sharedLocalManager!
    }
    
    
    public override init() {
        super.init()
        // Initialize managers if need
        self.remoteManager
        self.localManager
    }


    
    // MARK: Helpers
    
    open func runOnBackgroundContext<R> (_ executeBlock: @escaping () throws -> R) -> Promise<R> {
        return self.localManager.performPromiseOnBackgroundContext { () throws -> R in
            return try executeBlock()
        }
    }
    
    //MARK: - Sync lock
    
    internal var syncLock: Bool = false
    internal let syncSemaphore = DispatchSemaphore(value: 1)
    internal let lockQueue = DispatchQueue(label: "com.jdskit.LockQueue.\(self)", attributes: [])
    
    open func trySync() -> Bool {
        var shouldSync = false
        if !self.syncLock {
            self.lockQueue.sync {
                if !self.syncLock {
                    self.syncLock = true
                    shouldSync = true
                    self.syncSemaphore.wait(timeout: DispatchTime.distantFuture)
                }
            }
        }
        return shouldSync
    }
    
    open func endSync() {
        self.lockQueue.sync {
            if self.syncLock {
                self.syncLock = false
                self.syncSemaphore.signal()
            }
        }
    }
    
    open func waitForSync() {
        self.syncSemaphore.wait(timeout: DispatchTime.distantFuture)
        self.syncSemaphore.signal()
    }
    
    
}


