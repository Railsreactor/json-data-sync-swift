//
//  Event.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/1/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import Foundation

//struct Action {
//    static let Updated = "updated"
//    static let Deleted = "deleted"
//}

struct Action {
    static let Updated = "updated"
    static let Deleted = "deleted"
}

@objc protocol Event: ManagedEntity {
    var relatedEntityName: String? { get }
    var relatedEntityId: String?   { get }
    
    var action: String      { get }
}