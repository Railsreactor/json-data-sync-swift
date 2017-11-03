//
//  JSONLinkableEntity.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/10/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

open class JSONLinkableEntity: JSONManagedEntity {
    
    @objc open var parentId: String?
    @objc open var parentType: String?
    
    @objc open var parent: ManagedEntity? {
        get {
            return linkedEntity as? ManagedEntity
        }
        set {
            parentId = newValue?.id
            parentType = newValue?.entityName
        }
    }
    
    
    open var linkedEntity: JSONManagedEntity?
    
    open override class func fields() -> [Field] {
        return super.fields() + fieldsFromDictionary([
            "parentId":              Attribute().serializeAs("entity_id").skipMap(),
            "parentType":            Attribute().serializeAs("entity_type").skipMap(),
            "linkedEntity":          ToOneRelationship(JSONManagedEntity.resourceType()).serializeAs("entity").mapAs("parent")
        ])
    }
}
