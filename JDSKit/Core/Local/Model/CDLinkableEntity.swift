//
//  CDLinkableEntity.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/10/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import CoreData


@objc (CDLinkableEntity)
public class CDLinkableEntity: CDManagedEntity, LinkableEntity {
    @NSManaged public var parentId: String?
    @NSManaged public var parentType: String?
    
    @NSManaged public var parent: ManagedEntity?
}
