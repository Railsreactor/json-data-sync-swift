//
//  JSONAttachment.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/12/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation


public class JSONAttachment : JSONLinkableEntity, Attachment {
    
    public var name: String?
    public var fileUrl: String?
    public var thumbUrl: String?
    
    public var data: NSData?
    
    public var tempImage: UIImage?
    
    public override class var fields: [Field] {
        return super.fields + fieldsFromDictionary([
            "name":                 Attribute(),
            "fileUrl":              Attribute().serializeAs("file_url"),
            "thumbUrl":             Attribute().serializeAs("thumb_url"),
            "data":                 DataAttribute().serializeAs("file").mapAs("data"),
            ])
    }
}
