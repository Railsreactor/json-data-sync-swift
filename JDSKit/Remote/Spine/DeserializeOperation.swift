//
//  DeserializeOperation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
A DeserializeOperation is responsible for deserializing a single server response.
The serialized data is converted into Resource instances using a layered process.

This process is the inverse of that of the SerializeOperation.
*/
class DeserializeOperation: Operation {
	
	// Input
	let data: JSON
	var transformers: TransformerDirectory = TransformerDirectory()
	var resourceFactory: ResourceFactory
	
	// Output
	var result: Failable<JSONAPIDocument>?
	
	// Extracted objects
	fileprivate var extractedPrimaryResources: [Resource] = []
	fileprivate var extractedIncludedResources: [Resource] = []
	fileprivate var extractedErrors: [NSError]?
	fileprivate var extractedMeta: [String: Any]?
	fileprivate var extractedLinks: [String: URL]?
	fileprivate var extractedJSONAPI: [String: Any]?
	
    fileprivate var resourcePool: [String: Resource] = [:]
	
	
	// MARK: Initializers
	
	init(data: Data, resourceFactory: ResourceFactory) {
		self.data = JSON(data: data)
		self.resourceFactory = resourceFactory
	}
	
	
	// MARK: Mapping targets
	
	func addMappingTargets(_ targets: [Resource]) {
		// We can only map onto resources that are not loaded yet
		for resource in targets {
			assert(resource.isLoaded == false, "Cannot map onto loaded resource \(resource)")
            cacheResource(&resourcePool, resource: resource)
		}
	}
	
	
	// MARK: NSOperation
	
	override func main() {
		// Validate document
		guard data.dictionary != nil else {
			let errorMessage = "The given JSON is not a dictionary (hash).";
			Spine.logError(.serializing, errorMessage)
			result = Failable(NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		guard data["errors"] != JSON.null || data["data"] != JSON.null || data["meta"] != JSON.null else {
			let errorMessage = "Either 'data', 'errors', or 'meta' must be present in the top level.";
			Spine.logError(.serializing, errorMessage)
			result = Failable(NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		guard (data["errors"] == JSON.null && data["data"] != JSON.null) || (data["errors"] != JSON.null && data["data"] == JSON.null) else {
			let errorMessage = "Top level 'data' and 'errors' must not coexist in the same document.";
			Spine.logError(.serializing, errorMessage)
			result = Failable(NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidDocumentStructure, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
			return
		}
		
		// Extract resources
		do {
			if let data = self.data["data"].array {
				for (_, representation) in data.enumerated() {
                    try extractedPrimaryResources.append(deserializeSingleRepresentation(representation))
				}
			} else if let _ = self.data["data"].dictionary {
                try extractedPrimaryResources.append(deserializeSingleRepresentation(self.data["data"]))
			}

			if let data = self.data["included"].array {
				for representation in data {
					try extractedIncludedResources.append(deserializeSingleRepresentation(representation))
				}
			}
		} catch let error as NSError {
			result = Failable(error)
			return
		}
		
		// Extract errors
		extractedErrors = self.data["errors"].array?.map { error -> NSError in
			let code = error["code"].intValue
			
            var userInfo = [String: Any]()
            
			if let details = error["detail"].string {
                userInfo[NSLocalizedDescriptionKey] = details as Any?
			}
            
            if let source = error["source"].dictionaryObject {
                userInfo[SNAPIErrorSourceKey] = source as Any?
            }
			
            if let title = error["title"].string {
                userInfo[SNLocalizedTitleKey] = title as Any?
            }
            
            if userInfo.isEmpty {
                userInfo = error.dictionaryObject! as [String : Any]
            }
            
			return NSError(domain: SpineServerErrorDomain, code: code, userInfo: userInfo)
		}
		
		// Extract meta
		extractedMeta = self.data["meta"].dictionaryObject as [String : Any]?
		
		// Extract links
		if let links = self.data["links"].dictionary {
			extractedLinks = [:]
			
			for (key, value) in links {
				extractedLinks![key] = NSURL(string: value.stringValue)! as URL
			}
		}
		
		// Extract jsonapi
		extractedJSONAPI = self.data["jsonapi"].dictionaryObject as [String : Any]?
		
		// Resolve relations in the store
		resolveRelations()
		
		// Create a result
		var responseDocument = JSONAPIDocument(data: nil, included: nil, errors: extractedErrors, meta: extractedMeta, links: extractedLinks as [String : URL]?, jsonapi: extractedJSONAPI)
		if !extractedPrimaryResources.isEmpty {
			responseDocument.data = extractedPrimaryResources
		}
		if !extractedIncludedResources.isEmpty {
			responseDocument.included = extractedIncludedResources
		}
		result = Failable(responseDocument)
	}
	
	
	// MARK: Deserializing
	
	/**
	Maps a single resource representation into a resource object of the given type.
	
	:param: representation     The JSON representation of a single resource.
	:param: mappingTargetIndex The index of the matching mapping target.
	
	:returns: A Resource object with values mapped from the representation.
	*/
	fileprivate func deserializeSingleRepresentation(_ representation: JSON) throws -> Resource {
		guard representation.dictionary != nil else {
			throw NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.InvalidResourceStructure, userInfo: nil)
		}
		
		guard let type: ResourceType = representation["type"].string else {
			throw NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.ResourceTypeMissing, userInfo: nil)
		}
		
		guard let id = representation["id"].string else {
			throw NSError(domain: SpineSerializingErrorDomain, code: SpineErrorCodes.ResourceIDMissing, userInfo: nil)
		}
		
		// Dispense a resource
		let resource = resourceFactory.dispense(type, id: id, pool: &resourcePool)
		
		// Extract data
		resource.id = id
		resource.URL = representation["links"]["self"].url
		resource.meta = representation["meta"].dictionaryObject as [String : Any]?
		extractAttributes(representation, intoResource: resource)
		extractRelationships(representation, intoResource: resource)
		
		resource.isLoaded = true
		
		return resource
	}
	
	
	// MARK: Attributes
	
	/**
	Extracts the attributes from the given data into the given resource.
	
	This method loops over all the attributes in the passed resource, maps the attribute name
	to the key for the serialized form and invokes `extractAttribute`. It then formats the extracted
	attribute and sets the formatted value on the resource.
	
	:param: serializedData The data from which to extract the attributes.
	:param: resource       The resource into which to extract the attributes.
	*/
	fileprivate func extractAttributes(_ serializedData: JSON, intoResource resource: Resource) {
		for case let field as Attribute in resource.fields() {
			if let extractedValue: Any = self.extractAttribute(serializedData, key: field.serializedName) {
				let formattedValue: Any = self.transformers.deserialize(extractedValue, forAttribute: field)
				resource.setValue(formattedValue, forField: field.name)
			}
		}
	}
	
	/**
	Extracts the value for the given key from the passed serialized data.
	
	:param: serializedData The data from which to extract the attribute.
	:param: key            The key for which to extract the value from the data.
	
	:returns: The extracted value or nil if no attribute with the given key was found in the data.
	*/
	fileprivate func extractAttribute(_ serializedData: JSON, key: String) -> Any? {
        
        let value = extractKeyPath(serializedData["attributes"], keyPath: key)
		
		if let _ = value.null {
			return nil
		} else {
			return value.rawValue as Any?
		}
	}
    
    fileprivate func extractKeyPath(_ serializedData: JSON, keyPath: String) -> JSON {
        var keys = keyPath.components(separatedBy:".")
        
        
        guard let first = keys.first else { print("Key not found"); return JSON.null }
        
        guard let value: JSON = serializedData[first], value.null == nil else { return JSON.null }
        
        keys.remove(at: 0)
        
        if !keys.isEmpty {
            let rejoined = keys.joined(separator: ".")
            return extractKeyPath(value, keyPath: rejoined)
        }
        
        return value
    }
	
	
	// MARK: Relationships
	
	/**
	Extracts the relationships from the given data into the given resource.
	
	This method loops over all the relationships in the passed resource, maps the relationship name
	to the key for the serialized form and invokes `extractToOneRelationship` or `extractToManyRelationship`.
	It then sets the extracted ResourceRelationship on the resource.
	
	:param: serializedData The data from which to extract the relationships.
	:param: resource       The resource into which to extract the relationships.
	*/
	fileprivate func extractRelationships(_ serializedData: JSON, intoResource resource: Resource) {
		for field in resource.fields() {
			switch field {
			case let toOne as ToOneRelationship:
				if let linkedResource = extractToOneRelationship(serializedData, key: toOne.serializedName, linkedType: toOne.linkedType, resource: resource) {
					resource.setValue(linkedResource, forField: toOne.name)
				}
			case let toMany as ToManyRelationship:
				if let linkedResourceCollection = extractToManyRelationship(serializedData, key: toMany.serializedName, resource: resource) {
					resource.setValue(linkedResourceCollection, forField: toMany.name)
				}
			default: ()
			}
		}
	}
	
	/**
	Extracts the to-one relationship for the given key from the passed serialized data.
	
	This method supports both the single ID form and the resource object forms.
	
	:param: serializedData The data from which to extract the relationship.
	:param: key            The key for which to extract the relationship from the data.
	
	:returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	fileprivate func extractToOneRelationship(_ serializedData: JSON, key: String, linkedType: ResourceType, resource: Resource) -> Resource? {
		var resource: Resource? = nil
		
		if let linkData = serializedData["relationships"][key].dictionary {
            
            if let data = linkData["data"], data.null != NSNull() {
                
                let type = linkData["data"]?["type"].string ?? linkedType
                
                if let id = linkData["data"]?["id"].string {
                    resource = resourceFactory.dispense(type, id: id, pool: &resourcePool)
                } else {
                    resource = resourceFactory.instantiate(type)
                }
                
                if let resourceURL = linkData["links"]?["related"].url {
                    resource!.URL = resourceURL
                }
            }
		}
		
		return resource
	}
	
	/**
	Extracts the to-many relationship for the given key from the passed serialized data.
	
	This method supports both the array of IDs form and the resource object forms.
	
	:param: serializedData The data from which to extract the relationship.
	:param: key            The key for which to extract the relationship from the data.
	
	:returns: The extracted relationship or nil if no relationship with the given key was found in the data.
	*/
	fileprivate func extractToManyRelationship(_ serializedData: JSON, key: String, resource: Resource) -> LinkedResourceCollection? {
		var resourceCollection: LinkedResourceCollection? = nil

		if let linkData = serializedData["relationships"][key].dictionary {
			let resourcesURL: URL? = linkData["links"]?["related"].url
			let linkURL: URL? = linkData["links"]?["self"].url
			
			if let linkage = linkData["data"]?.array {
				let mappedLinkage = linkage.map { ResourceIdentifier(type: $0["type"].stringValue, id: $0["id"].stringValue) }
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: mappedLinkage)
			} else {
				resourceCollection = LinkedResourceCollection(resourcesURL: resourcesURL, linkURL: linkURL, linkage: nil)
			}
		}
		
		return resourceCollection
	}
	
	/**
	Resolves the relations of the primary resources.
	*/
	fileprivate func resolveRelations() {
        for (_,resource) in resourcePool {
			for case let field as ToManyRelationship in resource.fields() {
				if let linkedResource = resource.valueForField(field.name) as? LinkedResourceCollection {
					
					// We can only resolve if the linkage is known
					if let linkage = linkedResource.linkage {
                        var localPool = [String: Resource]()
                        var usedFaults = false
						let targetResources = linkage.flatMap { link -> [Resource] in
                            
                            if link.id.isEmpty {
                                return [Resource]()
                            }
                            
                            let cached = findResource(localPool, type: link.type, id: link.id)
                            if cached != nil {
                                return [cached!]
                            }
                            
                            let fault = self.resourceFactory.dispense(link.type, id: link.id, pool: &localPool)
                            usedFaults = true
							return [fault]
						}
						
						if !targetResources.isEmpty {
							linkedResource.resources = targetResources
                            linkedResource.isLoaded = !usedFaults
                        }
					} else {
						Spine.logInfo(.serializing, "Cannot resolve to-many link \(resource.resourceType()):\(resource.id ?? "nil") - \(field.name) because the foreign IDs are not known.")
					}
				} else {
					Spine.logInfo(.serializing, "Cannot resolve to-many link \(resource.resourceType()):\(resource.id ?? "nil") - \(field.name) because the link data is not fetched.")
				}
			}
		}
	}
}
