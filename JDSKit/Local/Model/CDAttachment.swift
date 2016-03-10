//
//  CDAttachment.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/24/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import CoreData


@objc(CDAttachment)
public class CDAttachment: CDLinkableEntity, Attachment  {
    @NSManaged public var fileUrl: String?
    @NSManaged public var name: String?
    @NSManaged public var thumbUrl: String?

    public var tempImage: UIImage?
    public var data: NSData?
}
