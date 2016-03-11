//
//  JSONEvent.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/2/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit

class JSONEvent: JSONManagedEntity, Event {    
    
    var relatedEntityId: String?
    
    var _relatedEntityName: String?
    var relatedEntityName: String? {
        get {
            if _relatedEntityName == "ZipCode" { return "Zip" }
            return _relatedEntityName
        }
    }
    
    var _action: String?
    var action: String {
        get {
            if let nativeString: String = _action where nativeString.containsString("deleted") {
                return Action.Deleted
            }
            return Action.Updated
        }
    }

    override class func fields() -> [Field] {
        return super.fields() + fieldsFromDictionary([
            "_relatedEntityName":    Attribute().serializeAs("entity_type"),
            "relatedEntityId":       Attribute().serializeAs("entity_id"),
            "_action":               Attribute().serializeAs("action"),
        ])
    }
}
