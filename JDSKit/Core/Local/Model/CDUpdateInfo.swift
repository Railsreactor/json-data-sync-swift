//
//  CDUpdateInfo.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/3/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import Foundation
import CoreData

@objc(CDUpdateInfo)

public class CDUpdateInfo: NSManagedObject, Containerable {
    @NSManaged public var filterID:    String?
    @NSManaged public var entityType:  String?
    @NSManaged public var updateDate:  NSDate?
    
    public func objectContainer() -> Container {
        return ObjectIDContainer(contained: self.objectID)
    }
}
