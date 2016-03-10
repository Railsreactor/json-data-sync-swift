//
//  CDUtils.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/14/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import CoreData

public extension Array {
    
    public func sortDescriptors() -> [NSSortDescriptor] {
        return self.flatMap {
            if let value = $0 as? String {
                var final = ""
                var accending = true
                if ( value.hasPrefix("-") ) {
                    final = value.substringFromIndex(value.startIndex.advancedBy(1))
                    accending = false
                } else {
                    final = value
                    accending = true
                }
                
                return NSSortDescriptor(key: final, ascending: accending);
            }
            return nil
        }
    }
}

public class ObjectIDContainer: Container {
    public override init(contained: AnyObject) {
        super.init(contained: contained)
    }
    
    public override func containedObject<T: ManagedEntity>() throws -> T? {
        return try BaseDBService.sharedInstance.fetchEntity(content as! NSManagedObjectID) as? T
    }
}

