//
//  Transformer.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The Transformer protocol declares methods and properties that a transformer must implement.
A transformer transforms values between the serialized and deserialized form.
*/
public protocol Transformer {
	associatedtype SerializedType
	associatedtype DeserializedType
	associatedtype AttributeType
	
	/**
	Returns the deserialized form of the given value for the given attribute.
	
	- parameter value:     The value to deserialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The deserialized form of `value`.
	*/
	func deserialize(_ value: SerializedType, attribute: AttributeType) -> Any
	
	/**
	Returns the serialized form of the given value for the given attribute.
	
	- parameter value:     The value to serialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The serialized form of `value`.
	*/
	func serialize(_ value: DeserializedType, attribute: AttributeType) -> Any
}

/**
A transformer directory keeps a list of transformers, and chooses between these transformers
to transform values between the serialized and deserialized form.
*/
struct TransformerDirectory {
	/// Registered serializer functions.
	fileprivate var serializers: [(Any, Attribute) -> Any?] = []
	
	/// Registered deserializer functions.
	fileprivate var deserializers: [(Any, Attribute) -> Any?] = []
	
	/**
	Returns a new transformer directory configured with the build in default transformers.
	
	- returns: TransformerDirectory
	*/
	static func defaultTransformerDirectory() -> TransformerDirectory {
		var directory = TransformerDirectory()
		directory.registerTransformer(URLTransformer())
		directory.registerTransformer(DateTransformer())
		return directory
	}
	
	/**
	Registers the given transformer.
	
	- parameter transformer: The transformer to register.
	*/
	mutating func registerTransformer<T: Transformer>(_ transformer: T) {
		serializers.append { (value: Any, attribute: Attribute) -> Any? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.DeserializedType {
					return transformer.serialize(typedValue, attribute: typedAttribute)
				}
			}
			
			return nil
		}
		
		deserializers.append { (value: Any, attribute: Attribute) -> Any? in
			if let typedAttribute = attribute as? T.AttributeType {
				if let typedValue = value as? T.SerializedType {
					return transformer.deserialize(typedValue, attribute: typedAttribute)
				}
			}
			
			return nil
		}
	}
	
	/**
	Returns the deserialized form of the given value for the given attribute.
	
	The actual transformer used is the first registered transformer that supports the given
	value type for the given attribute type.
	
	- parameter value:     The value to deserialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The deserialized form of `value`.
	*/
	func deserialize(_ value: Any, forAttribute attribute: Attribute) -> Any {
		for deserializer in deserializers {
			if let deserialized: Any = deserializer(value, attribute) {
				return deserialized
			}
		}
		
		return value
	}
	
	/**
	Returns the serialized form of the given value for the given attribute.
	
	The actual transformer used is the first registered transformer that supports the given
	value type for the given attribute type.
	
	- parameter value:     The value to serialize.
	- parameter attribute: The attribute to which the value belongs.
	
	- returns: The serialized form of `value`.
	*/
	func serialize(_ value: Any, forAttribute attribute: Attribute) -> Any {
		for serializer in serializers {
			if let serialized: Any = serializer(value, attribute) {
				return serialized
			}
		}
		
		return value
	}
}


// MARK: - Built in transformers

/**
URLTransformer is a transformer that transforms between NSURL and String, and vice versa.
If a baseURL has been configured in the URLAttribute, and the given String is not an absolute URL,
it will return an absolute NSURL, relative to the baseURL.
*/
private struct URLTransformer: Transformer {
	func deserialize(_ value: String, attribute: URLAttribute) -> Any {
		return URL(string: value, relativeTo: attribute.baseURL as URL?)! as Any
	}
	
	func serialize(_ value: URL, attribute: URLAttribute) -> Any {
		return value.absoluteString as Any
	}
}

/**
URLTransformer is a transformer that transforms between NSDate and String, and vice versa.
It uses the date format configured in the DateAttribute.
*/
private struct DateTransformer: Transformer {
	func formatter(_ attribute: DateAttribute) -> DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = attribute.format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
		return formatter
	}
	
	func deserialize(_ value: String, attribute: DateAttribute) -> Any {
		return formatter(attribute).date(from: value)! as Any
	}
	
	func serialize(_ value: Date, attribute: DateAttribute) -> Any {
		return formatter(attribute).string(from: value) as Any
	}
}
