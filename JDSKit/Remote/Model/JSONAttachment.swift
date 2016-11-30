//
//  JSONAttachment.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/12/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation


open class JSONAttachment : JSONLinkableEntity, Attachment {
    
    open var name: String?
    open var fileUrl: String?
    open var thumbUrl: String?
    
    open var data: Data?
    
    open var tempImage: UIImage?
    
    open override class func fields() -> [Field] {
        return super.fields() + fieldsFromDictionary([
            "name":                 Attribute(),
            "fileUrl":              Attribute().serializeAs("file_url"),
            "thumbUrl":             Attribute().serializeAs("thumb_url"),
            "data":                 DataAttribute().serializeAs("file").mapAs("data"),
            ])
    }
}
