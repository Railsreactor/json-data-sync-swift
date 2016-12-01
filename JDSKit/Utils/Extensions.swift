//
//  Extensions.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/25/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import UIKit
import PromiseKit


public func asBool(_ value: Any?) -> Bool {
    if let value = value as? String, NSString(string: value).boolValue {
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
    
    public class func fromStoryboard(_ storyboardNamed: String, identifier: String? = nil) -> Self {
        return fromStoryboardGeneric(UIStoryboard(name: storyboardNamed, bundle: nil), identifier: identifier)
    }
    
    public class func fromStoryboard(storyboard instance: UIStoryboard, identifier: String? = nil) -> Self {
        return fromStoryboardGeneric(instance, identifier: identifier)
    }
    
    internal class func fromStoryboardGeneric<T: UIViewController>(_ storyboard: UIStoryboard, identifier: String? = nil) -> T {
        let identifier = identifier ?? String(describing: self)
        return storyboard.instantiateViewController(withIdentifier: identifier) as! T
    }
}

public extension Date {
    
    public func toSystemString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = Constants.APIDateTimeFormat
        return formatter.string(from: self)
    }
}


