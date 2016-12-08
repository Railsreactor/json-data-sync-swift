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

    var createDate: Date?     { get set }
    var updateDate: Date?     { get set }

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
        return String(describing: entityType)
    }
    
    public var entityName: String           {
        return Self.entityName
    }
    
    public static var resourceName: String  {
        return entityName.pluralize().lowercased()
    }
    
    public var resourceName: String        {
        return Self.resourceName
    }
    
    static func extractRepresentation<T>(_ subclassOf: T.Type) -> T.Type {
        return ExtractRep(self, subclassOf: subclassOf) as! T.Type
    }
    
    func extractRepresentation<T>(_ subclassOf: T.Type) -> T.Type {
        return Self.extractRepresentation(subclassOf)
    }
    
    public func latestAttachment() -> Attachment? {
        return AttachmentService.sharedService().latestAttachment(self)
    }
}


open class DummyManagedEntity: NSObject, ManagedEntity  {
    
    open var id: String?
    open var createDate: Date?
    open var updateDate: Date?
    
    open var attachments: NSSet?
    open var locations:  NSSet?
    
    
    open var pendingDelete: NSNumber?
    open var isLoaded: NSNumber? = false
    
    open func objectContainer() -> Container {
        return Container(contained: self)
    }

    open func refresh() {

    }
    
    public required override init() {
        super.init()
    }
    
    open func isTemp() -> Bool {
        return true
    }
}
