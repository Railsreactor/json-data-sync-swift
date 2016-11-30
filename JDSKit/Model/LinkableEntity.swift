//
//  PolymorphicEntity.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/10/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import UIKit

@objc public protocol LinkableEntity: ManagedEntity {

    var parentId: String?       { set get }
    var parentType: String?     { set get }
  
    var parent: ManagedEntity?  { set get }
}


open class DummyLinkableEntity : DummyManagedEntity, LinkableEntity {
    
    open var parentId: String?
    open var parentType: String?
    
    open var parent: ManagedEntity?
}
