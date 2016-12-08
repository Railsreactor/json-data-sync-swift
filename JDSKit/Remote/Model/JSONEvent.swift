//
//  JSONEvent.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/2/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit

open class JSONEvent: JSONManagedEntity, Event {
    
    open var relatedEntityId: String?
    
    var _relatedEntityName: String?
    open var relatedEntityName: String? {
        get {
            if _relatedEntityName == "ZipCode" { return "Zip" }
            return _relatedEntityName
        }
    }
    
    var _action: String?
    open var action: String {
        get {
            if let normalizedName = _relatedEntityName?.lowercased(), let nativeString: String = _action, nativeString.contains("\(normalizedName).deleted") {
                return Action.Deleted
            }
            return Action.Updated
        }
    }

    override open class func fields() -> [Field] {
        return super.fields() + fieldsFromDictionary([
            "_relatedEntityName":    Attribute().serializeAs("entity_type"),
            "relatedEntityId":       Attribute().serializeAs("entity_id"),
            "_action":               Attribute().serializeAs("action"),
        ])
    }
}
