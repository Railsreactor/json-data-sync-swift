//
//  MultiDelegate.swift
//  MulticastDelegateTest
//
//  Created by Dmitriy on 6/28/15.
//  Copyright (c) 2015 Dmitry K. All rights reserved.
//

import Foundation

open class MulticastDelegate<T: AnyObject> {
    open let delegates = NSHashTable<AnyObject>(options: NSHashTableWeakMemory, capacity: 3)
    
    open func add(_ object: T) {
        delegates.add(object)
    }
    
    open func remove(_ object: T) {
        delegates.remove(object)
    }
    
    open func removeAll() {
        delegates.removeAllObjects()
    }
    
    open func call(_ block: (T) -> Void) {
        for object in delegates.objectEnumerator().allObjects {
            let delegate = object as! T
            block(delegate)
        }
    }
}
