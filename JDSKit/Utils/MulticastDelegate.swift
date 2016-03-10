//
//  MultiDelegate.swift
//  MulticastDelegateTest
//
//  Created by Dmitriy on 6/28/15.
//  Copyright (c) 2015 Dmitry K. All rights reserved.
//

import Foundation

public class MulticastDelegate<T: AnyObject> {
    public let delegates = NSHashTable(options: NSHashTableWeakMemory, capacity: 3)
    
    public func add(object: T) {
        delegates.addObject(object)
    }
    
    public func remove(object: T) {
        delegates.removeObject(object)
    }
    
    public func removeAll() {
        delegates.removeAllObjects()
    }
    
    public func call(block: (T) -> Void) {
        for object in delegates.objectEnumerator().allObjects {
            let delegate = object as! T
            block(delegate)
        }
    }
}
