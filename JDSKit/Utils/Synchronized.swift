//
//  Synchronized.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/3/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

public func synchronized(_ lock: AnyObject, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

