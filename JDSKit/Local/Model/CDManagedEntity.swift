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
open class CDManagedEntity: NSManagedObject, ManagedEntity {
    @NSManaged open var id: String?
    
    @NSManaged open var createDate: Date?
    @NSManaged open var updateDate: Date?
    
    @NSManaged open var locations: NSSet?
    @NSManaged open var attachments: NSSet?
    
    @NSManaged open var pendingDelete: NSNumber?
    @NSManaged open var isLoaded: NSNumber?
    
    
    open func objectContainer() -> Container {
        return ObjectIDContainer(contained: self.objectID)
    }
    
    open func refresh()  {
        BaseDBService.sharedInstance.contextForCurrentThread().refresh(self, mergeChanges: false)
    }
    
    open func isTemp() -> Bool {
        return self.managedObjectContext != nil && self.id == nil
    }
}

