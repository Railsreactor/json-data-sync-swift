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
    
    var data: Data?       { set get }
    
    var tempImage: UIImage? { set get }
}


open class DummyAttachment: DummyLinkableEntity, Attachment {     
    open var name: String?
    open var fileUrl: String?
    open var thumbUrl: String?
    
    open var data: Data?
    
    open var tempImage: UIImage?
}
