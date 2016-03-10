//
//  ManagedEntity.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/13/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation


@objc public protocol ManagedEntity:class, NSObjectProtocol, Containerable {
    
    var id: String?             { get set }

    var createDate: NSDate?     { get set }
    var updateDate: NSDate?     { get set }

    var attachments: NSSet?     { get set }
    
    var pendingDelete: NSNumber?{ get set }
    var isLoaded: NSNumber?     { get set }
    
    func refresh()
    
    func isTemp() -> Bool
}


public extension ManagedEntity {
    
    static var entityType: ManagedEntity.Type       { return ExtractModel(self) }
    var entityType: ManagedEntity.Type              { return Self.entityType }
    
    
    public static var entityName: String    {
        return String(entityType)
    }
    
    public var entityName: String           {
        return Self.entityName
    }
    
    public static var resourceName: String  {
        return entityName.lowercaseString + "s"
    }
    
    public var resourceName: String        {
        return Self.resourceName
    }
    
    static func extractRepresentation<T>(subclassOf: T.Type) -> T.Type {
        return ExtractRep(self, subclassOf: subclassOf) as! T.Type
    }
    
    func extractRepresentation<T>(subclassOf: T.Type) -> T.Type {
        return Self.extractRepresentation(subclassOf)
    }
    
    public func latestAttachment() -> Attachment? {
        return AttachmentService.sharedService().latestAttachment(self)
    }
}


public class DummyManagedEntity: NSObject, ManagedEntity  {
    
    public var id: String?
    public var createDate: NSDate?
    public var updateDate: NSDate?
    
    public var attachments: NSSet?
    public var locations:  NSSet?
    
    
    public var pendingDelete: NSNumber?
    public var isLoaded: NSNumber? = false
    
    public func objectContainer() -> Container {
        return Container(contained: self)
    }

    public func refresh() {

    }
    
    public required override init() {
        super.init()
    }
    
    public func isTemp() -> Bool {
        return true
    }
}
