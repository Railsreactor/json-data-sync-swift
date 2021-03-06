//
//  SerializeOperation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
A SerializeOperation is responsible for serializing resource into a multidimensional dictionary/array structure.
The resouces are converted to their serialized form using a layered process.

This process is the inverse of that of the DeserializeOperation.
*/
class SerializeOperation: Operation {
	fileprivate let resources: [Resource]
	var transformers = TransformerDirectory()
	var options = SerializationOptions()
	
	var result: Data?
	
	
	// MARK: Initializers
	
	init(resources: [Resource]) {
		self.resources = resources
	}
	
	
	// MARK: NSOperation
	
	override func main() {
		if resources.count == 1 {
			let serializedData = serializeResource(resources.first!)
			result = try? JSONSerialization.data(withJSONObject: ["data": serializedData], options: JSONSerialization.WritingOptions(rawValue: 0))
			
		} else  {
			let data = resources.map { resource in
				self.serializeResource(resource)
			}
			
			result = try? JSONSerialization.data(withJSONObject: ["data": data], options: JSONSerialization.WritingOptions(rawValue: 0))
		}
	}
	
	
	// MARK: Serializing
	
	fileprivate func serializeResource(_ resource: Resource) -> [String: Any] {
		Spine.logDebug(.serializing, "Serializing resource \(resource) of type '\(resource.resourceType())' with id '\(resource.id)'")
		
		var serializedData: [String: Any] = [:]
		
		// Serialize ID
		if let ID = resource.id, options.includeID {
			serializedData["id"] = ID as Any?
		}
		
		// Serialize type
		serializedData["type"] = resource.resourceType() as Any?
		
		// Serialize fields
		addAttributes(&serializedData, resource: resource)
		addRelationships(&serializedData, resource: resource)
		
		return serializedData
	}

	
	// MARK: Attributes
	
	/**
	Adds the attributes of the the given resource to the passed serialized data.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and formats the value of the attribute. It then passes
	the key and value to the addAttribute method.
	
	- parameter serializedData: The data to add the attributes to.
	- parameter resource:       The resource whose attributes to add.
	*/
	fileprivate func addAttributes(_ serializedData: inout [String: Any], resource: Resource) {
		var attributes = [String: Any]();
		
		for case let field as Attribute in resource.fields() {
			let key = field.serializedName
			
			Spine.logDebug(.serializing, "Serializing attribute \(field) with name '\(field.name) as '\(key)'")
			
			//TODO: Dirty checking
			if let unformattedValue: Any = resource.valueForField(field.name) {
				addAttribute(&attributes, key: key, value: self.transformers.serialize(unformattedValue, forAttribute: field))
			}
//            else {
//				addAttribute(&attributes, key: key, value: NSNull())
//			}
		}
		
		serializedData["attributes"] = attributes as Any?
	}
	
	/**
	Adds the given key/value pair to the passed serialized data.
	
	- parameter serializedData: The data to add the key/value pair to.
	- parameter key:            The key to add to the serialized data.
	- parameter value:          The value to add to the serialized data.
	*/
	fileprivate func addAttribute(_ serializedData: inout [String: Any], key: String, value: Any) {
		serializedData[key] = value
	}
	
	
	// MARK: Relationships
	
	/**
	Adds the relationships of the the given resource to the passed serialized data.
	
	This method loops over all the relationships in the passed resource, maps the attribute name
	to the key for the serialized form and gets the related attributes. It then passes the key and
	related resources to either the addToOneRelationship or addToManyRelationship method.
	
	
	- parameter serializedData: The data to add the relationships to.
	- parameter resource:       The resource whose relationships to add.
	*/
	fileprivate func addRelationships(_ serializedData: inout [String: Any], resource: Resource) {
		for case let field as Relationship in resource.fields() {
			let key = field.serializedName
			
			Spine.logDebug(.serializing, "Serializing relationship \(field) with name '\(field.name) as '\(key)'")
			
			switch field {
			case let toOne as ToOneRelationship:
				if options.includeToOne {
					addToOneRelationship(&serializedData, key: key, type: toOne.linkedType, linkedResource: resource.valueForField(field.name) as? Resource)
				}
			case let toMany as ToManyRelationship:
				if options.includeToMany {
					addToManyRelationship(&serializedData, key: key, type: toMany.linkedType, linkedResources: resource.valueForField(field.name) as? ResourceCollection)
				}
			default: ()
			}
		}
	}
	
	/**
	Adds the given resource as a to to-one relationship to the serialized data.
	
	- parameter serializedData:  The data to add the related resource to.
	- parameter key:             The key to add to the serialized data.
	- parameter relatedResource: The related resource to add to the serialized data.
	*/
	fileprivate func addToOneRelationship(_ serializedData: inout [String: Any], key: String, type: ResourceType, linkedResource: Resource?) {
        if linkedResource != nil {
            let serializedRelationship: [String: [String: Any]] = [
                "data": [
                    "type": type,
                    "id": linkedResource?.id ?? NSNull().description
                ]
            ]
            
            if serializedData["relationships"] == nil {
                serializedData["relationships"] = [key : serializedRelationship] as Any?
            } else {
                var relationships = serializedData["relationships"] as! [String: Any]
                relationships[key] = serializedRelationship as Any?
                serializedData["relationships"] = relationships as Any?
            }
        }
	}
	
	/**
	Adds the given resources as a to to-many relationship to the serialized data.
	
	- parameter serializedData:   The data to add the related resources to.
	- parameter key:              The key to add to the serialized data.
	- parameter relatedResources: The related resources to add to the serialized data.
	*/
	fileprivate func addToManyRelationship(_ serializedData: inout [String: Any], key: String, type: ResourceType, linkedResources: ResourceCollection?) {
		
        if linkedResources != nil {
            var resourceIdentifiers: [ResourceIdentifier] = []
            
            if let resources = linkedResources?.resources {
                resourceIdentifiers = resources.filter { $0.id != nil }.map { resource in
                    return ResourceIdentifier(type: resource.resourceType(), id: resource.id!)
                }
            }
            
            let serializedRelationship = [
                "data": resourceIdentifiers.map { $0.toDictionary() }
            ]
            
            if serializedData["relationships"] == nil {
                serializedData["relationships"] = [key: serializedRelationship] as Any?
            } else {
                var relationships = serializedData["relationships"] as! [String: Any]
                relationships[key] = serializedRelationship as Any?
                serializedData["relationships"] = relationships as Any?
            }
        }        
	}
}
