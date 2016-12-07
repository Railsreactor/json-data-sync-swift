//
//  Base64Transformer.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/22/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

public struct Base64Transformer: Transformer {

    public func deserialize(_ value: String, attribute: DataAttribute) -> Any {
        return Data(base64Encoded: value, options:NSData.Base64DecodingOptions(rawValue: 0))! as Any
    }
    
    public func serialize(_ value: Data, attribute: DataAttribute) -> Any {
        return value.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) as Any
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
    
    public func deserialize(_ value: String, attribute: NumberAttribute) -> Any {
        return formatter.number(from: value) ?? 0
    }
    
    public func serialize(_ value: NSNumber, attribute: NumberAttribute) -> Any {
        return value
    }
}


open class NumberAttribute: Attribute {
    
}

