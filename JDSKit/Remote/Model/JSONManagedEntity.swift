//
//  JSONManagedEntity.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/13/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation



open class JSONManagedEntity: Resource, ManagedEntity {

    open var createDate: Date?
    open var updateDate: Date?
    
    open var pendingDelete: NSNumber?
    
    
    open var linkedAttachments:    LinkedResourceCollection?
    open var attachments : NSSet? {
        get {
            return NSSet(array: linkedAttachments?.resources.map { $0 as! Attachment } ?? [])
        }
        set {
            //setupLinkage(linkedAttachments!, resources: newValue, type: JSONAttachment.self)
        }
    }
    
    override open class func fields() -> [Field] {
        return super.fields() + fieldsFromDictionary([
                "createDate":           DateAttribute().serializeAs("created_at"),
                "updateDate":           DateAttribute().serializeAs("updated_at"),
                "linkedAttachments":    ToManyRelationship(JSONAttachment.resourceType()).serializeAs("attachments").mapAs("attachments"),
            ])
    }
    
    open class var fieldKeyMap: [String: String] {
        var _fieldKeyMap = [String: String]()
        
        for field in fields() {
            var varName = field.mappedName
            if varName.hasPrefix("_") {
                varName = String(varName.characters.dropFirst())
            }
            _fieldKeyMap[varName] = field.serializedName
        }
        
        return _fieldKeyMap
    }
    
    public required init() {
        super.init()
    }
    
    override open class func resourceType() -> String {
        return resourceName
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func objectContainer() -> Container {
        return Container(contained: self)
    }
    
    open func refresh() {

    }
    
    open func isTemp() -> Bool {
        return self.id == nil
    }
}




