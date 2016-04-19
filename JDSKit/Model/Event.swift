//
//  Event.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/1/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import Foundation

public struct Action {
    public static let Updated = "updated"
    public static let Deleted = "deleted"
}

@objc public protocol Event: ManagedEntity {
    var relatedEntityName: String? { get }
    var relatedEntityId: String?   { get }
    
    var action: String      { get }
}