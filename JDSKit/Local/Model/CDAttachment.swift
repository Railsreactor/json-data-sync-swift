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
open class CDAttachment: CDLinkableEntity, Attachment  {
    @NSManaged open var fileUrl: String?
    @NSManaged open var name: String?
    @NSManaged open var thumbUrl: String?

    open var tempImage: UIImage?
    open var data: Data?
}
