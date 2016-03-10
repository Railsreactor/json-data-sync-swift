//
//  Attachment.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/13/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

@objc public protocol Attachment: LinkableEntity {
    var name: String?       { set get }
    var fileUrl: String?    { set get }
    var thumbUrl: String?   { set get }
    
    var data: NSData?       { set get }
    
    var tempImage: UIImage? { set get }
}


public class DummyAttachment: DummyLinkableEntity, Attachment {     
    public var name: String?
    public var fileUrl: String?
    public var thumbUrl: String?
    
    public var data: NSData?
    
    public var tempImage: UIImage?
}