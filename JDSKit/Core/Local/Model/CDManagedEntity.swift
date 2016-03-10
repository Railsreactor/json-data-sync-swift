//
//  CDManagedEntity.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/24/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import CoreData


@objc(CDManagedEntity)
public class CDManagedEntity: NSManagedObject, ManagedEntity {
    @NSManaged public var id: String?
    
    @NSManaged public var createDate: NSDate?
    @NSManaged public var updateDate: NSDate?
    
    @NSManaged public var locations: NSSet?
    @NSManaged public var attachments: NSSet?
    
    @NSManaged public var pendingDelete: NSNumber?
    @NSManaged public var isLoaded: NSNumber?
    
    
    public func objectContainer() -> Container {
        return ObjectIDContainer(contained: self.objectID)
    }
    
    public func refresh()  {
        BaseDBService.sharedInstance.contextForCurrentThread().refreshObject(self, mergeChanges: false)
    }
    
    public func isTemp() -> Bool {
        return self.managedObjectContext != nil && self.id == nil
    }
}

