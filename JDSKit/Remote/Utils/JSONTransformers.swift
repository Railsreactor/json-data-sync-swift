//
//  Base64Transformer.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/22/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

public struct Base64Transformer: Transformer {

    public func deserialize(value: String, attribute: DataAttribute) -> AnyObject {
        return NSData(base64EncodedString: value, options:NSDataBase64DecodingOptions(rawValue: 0))!
    }
    
    public func serialize(value: NSData, attribute: DataAttribute) -> AnyObject {
        return value.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }
}

public class DataAttribute: Attribute {

}


public struct NumberTransformer: Transformer {
    
    let formatter: NSNumberFormatter
    
    init () {
        formatter = NSNumberFormatter()
        formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
    }
    
    public func deserialize(value: String, attribute: NumberAttribute) -> AnyObject {
        return formatter.numberFromString(value) ?? 0
    }
    
    public func serialize(value: NSNumber, attribute: NumberAttribute) -> AnyObject {
        return value
    }
}


public class NumberAttribute: Attribute {
    
}

