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
open class CDLinkableEntity: CDManagedEntity, LinkableEntity {
    @NSManaged open var parentId: String?
    @NSManaged open var parentType: String?
    
    @NSManaged open var parent: ManagedEntity?
}
