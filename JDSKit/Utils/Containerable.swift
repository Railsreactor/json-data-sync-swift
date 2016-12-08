//
//  Containerable.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/9/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit

@objc public protocol Containerable {
    func objectContainer() -> Container
}

open class Container: NSObject {
    open var content: Any
    
    public init(contained: Any) {
        content = contained
    }
    
    open func containedObject<T>() throws -> T? {
        return content as? T
    }
}

