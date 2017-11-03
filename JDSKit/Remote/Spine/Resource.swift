//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 25-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

public typealias ResourceType = String

/**
A ResourceIdentifier uniquely identifies a resource that exists on the server.
*/
public struct ResourceIdentifier: Equatable {
	var type: ResourceType
	var id: String
	
	init(type: ResourceType, id: String) {
		self.type = type
		self.id = id
	}
	
	init(dictionary: NSDictionary) {
		type = dictionary["type"] as! ResourceType
		id = dictionary["id"] as! String
	}
	
	func toDictionary() -> NSDictionary {
		return ["type": type, "id": id]
	}
}

public func ==(lhs: ResourceIdentifier, rhs: ResourceIdentifier) -> Bool {
	return lhs.type == rhs.type && lhs.id == rhs.id
}

/**
A base recource class that provides some defaults for resources.
You can create custom resource classes by subclassing from Resource.
*/
open class Resource: NSObject, NSCoding {
    
	open class func resourceType() -> ResourceType {
		fatalError("Override resourceType() in a subclass.")
	}
    
    fileprivate var _internalResourceType: ResourceType?
    
    final public func resourceType() -> ResourceType {
        if _internalResourceType == nil {
            _internalResourceType = type(of: self).resourceType()
        }
        return _internalResourceType!
    }

	
	open class func fields() -> [Field] { return [] }
	final public func fields() -> [Field] { return type(of: self).fields() }
	
    @objc open var id: String?
	open var URL: Foundation.URL?
	
    @objc open var isLoaded: NSNumber? = 0
	
	open var meta: [String: Any]?
	
	public required override init() {}
	
	public required init(coder: NSCoder) {
		super.init()
		self.id = coder.decodeObject(forKey: "id") as? String
		self.URL = coder.decodeObject(forKey: "URL") as? Foundation.URL
		self.isLoaded = coder.decodeBool(forKey: "isLoaded") as NSNumber?
	}
	
	open func encode(with coder: NSCoder) {
		coder.encode(self.id, forKey: "id")
		coder.encode(self.URL, forKey: "URL")
		coder.encode(self.isLoaded!.boolValue, forKey: "isLoaded")
	}
	
	open func valueForField(_ field: String) -> Any? {
		return value(forKey: field) as Any?
	}
	
	open func setValue(_ value: Any?, forField field: String) {
		setValue(value, forKey: field)
	}
	
	/// Sets all fields of resource `resource` to nil and sets `isLoaded` to false.
	open func unload() {
		for field in self.fields() {
			self.setValue(nil, forField: field.name)
		}
		
		isLoaded = false
	}
}

extension Resource {
	override open var description: String {
		return "\(self.resourceType())(\(self.id), \(self.URL))"
	}
	
	override open var debugDescription: String {
		return description
	}
}

public func == <T: Resource> (left: T, right: T) -> Bool {
	return (left.id == right.id) && (left.resourceType() == right.resourceType())
}
