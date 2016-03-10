//
//  Extensions.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/25/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import UIKit

public func asBool(value: Any?) -> Bool {
    if let value = value as? String where NSString(string: value).boolValue {
        return true
    }
    return false
}

public extension NSSet {
    public func asArray<T>() -> [T] {
        return self.allObjects.map { $0 as! T }
    }
}

public extension UIViewController {
    
    public class func fromStoryboard(storyboardNamed: String, identifier: String = "") -> Self {
        return fromStoryboardGeneric(UIStoryboard(name: storyboardNamed, bundle: nil), identifier: identifier)
    }
    
    public class func fromStoryboard(storyboard instance: UIStoryboard, identifier: String = "") -> Self {
        return fromStoryboardGeneric(instance, identifier: identifier)
    }
    
    internal class func fromStoryboardGeneric<T: UIViewController>(storyboard: UIStoryboard, var identifier: String = "") -> T {
        if identifier.isEmpty {
            identifier = String(self)
        }
        return storyboard.instantiateViewControllerWithIdentifier(identifier) as! T
    }
}

public extension NSDate {
    
    public func toSystemString() -> String {
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(abbreviation: "GMT")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter.stringFromDate(self)
    }
    
}
