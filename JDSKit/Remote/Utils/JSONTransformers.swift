//
//  Base64Transformer.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/22/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

public struct Base64Transformer: Transformer {

    public func deserialize(_ value: String, attribute: DataAttribute) -> AnyObject {
        return Data(base64Encoded: value, options:NSData.Base64DecodingOptions(rawValue: 0))! as AnyObject
    }
    
    public func serialize(_ value: Data, attribute: DataAttribute) -> AnyObject {
        return value.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) as AnyObject
    }
}

open class DataAttribute: Attribute {

}


public struct NumberTransformer: Transformer {
    
    let formatter: NumberFormatter
    
    init () {
        formatter = NumberFormatter()
        formatter.numberStyle = NumberFormatter.Style.decimal
    }
    
    public func deserialize(_ value: String, attribute: NumberAttribute) -> AnyObject {
        return formatter.number(from: value) ?? 0
    }
    
    public func serialize(_ value: NSNumber, attribute: NumberAttribute) -> AnyObject {
        return value
    }
}


open class NumberAttribute: Attribute {
    
}

