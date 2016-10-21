//
//  Extensions.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/25/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import UIKit
import PromiseKit


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
    
    public class func fromStoryboard(storyboardNamed: String, identifier: String? = nil) -> Self {
        return fromStoryboardGeneric(UIStoryboard(name: storyboardNamed, bundle: nil), identifier: identifier)
    }
    
    public class func fromStoryboard(storyboard instance: UIStoryboard, identifier: String? = nil) -> Self {
        return fromStoryboardGeneric(instance, identifier: identifier)
    }
    
    internal class func fromStoryboardGeneric<T: UIViewController>(storyboard: UIStoryboard, identifier: String? = nil) -> T {
        let identifier = identifier ?? String(self)
        return storyboard.instantiateViewControllerWithIdentifier(identifier) as! T
    }
}

public extension NSDate {
    
    public func toSystemString() -> String {
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(abbreviation: "GMT")
        formatter.dateFormat = Constants.APIDateTimeFormat
        return formatter.stringFromDate(self)
    }
}

public extension Promise {
    public func rawError() -> Promise {
        return self.recover { (error) throws -> Promise in
            switch error {
            case PromiseKit.Error .When(_, let err):
                throw err
            default:
                throw error
            }
        }
    }
}

