//
//  CDUpdateInfo.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/3/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import Foundation
import CoreData

@objc open class CDUpdateInfo: NSManagedObject, Containerable {
    @NSManaged open var filterID:    String?
    @NSManaged open var entityType:  String?
    @NSManaged open var updateDate:  Date?
    
    open func objectContainer() -> Container {
        return ObjectIDContainer(contained: self.objectID)
    }
}

