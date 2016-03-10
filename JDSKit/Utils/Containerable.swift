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

public class Container: NSObject {
    public var content: AnyObject
    
    public init(contained: AnyObject) {
        content = contained
    }
    
    public func containedObject<T>() throws -> T? {
        return content as? T
    }
}

