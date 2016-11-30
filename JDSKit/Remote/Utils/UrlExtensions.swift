//
//  Extensions.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/13/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

public extension String {
    
    public func stringByAddingPercentEncodingForURLQueryValue() -> String? {
        let characterSet = NSMutableCharacterSet.alphanumeric()
        characterSet.addCharacters(in: "-._~")
        
        return self.addingPercentEncoding(withAllowedCharacters: characterSet as CharacterSet)
    }
    
}

public extension Dictionary {
    
    public func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = (key as! String).stringByAddingPercentEncodingForURLQueryValue()!
            
            var percentEscapedValue: String? = nil
            
            if let value = value as? [AnyObject] {
                percentEscapedValue = value.map { "\($0)" }.joined(separator: ",").stringByAddingPercentEncodingForURLQueryValue()!
            } else {
                percentEscapedValue = (String(describing: value)).stringByAddingPercentEncodingForURLQueryValue()!
            }
            
            return "\(percentEscapedKey)=\(percentEscapedValue ?? NSNull().description)"
        }
        return parameterArray.joined(separator: "&")
    }
}

