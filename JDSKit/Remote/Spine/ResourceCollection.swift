//
//  ResourceCollection.swift
//  Spine
//
//  Created by Ward van Teijlingen on 30-12-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
A ResourceCollection represents a collection of resources.
It contains a URL where the resources can be fetched.
For collections that can be paginated, pagination data is stored as well.
*/
open class ResourceCollection: NSObject, NSCoding {
	/// Whether the resources for this collection are loaded
	open var isLoaded: Bool
	
	/// The URL of the current page in this collection.
	open var resourcesURL: URL?
	
	/// The URL of the next page in this collection.
	open var nextURL: URL?
	
	/// The URL of the previous page in this collection.
	open var previousURL: URL?
	
	/// The loaded resources
	open internal(set) var resources: [Resource] = []
	
	
	// MARK: Initializers
	
	public init(resources: [Resource], resourcesURL: URL? = nil) {
		self.resources = resources
		self.resourcesURL = resourcesURL
		self.isLoaded = !resources.isEmpty
	}
	
	init(document: JSONAPIDocument) {
		self.resources = document.data ?? []
		self.resourcesURL = document.links?["self"] as URL?
		self.nextURL = document.links?["next"] as URL?
		self.previousURL = document.links?["previous"] as URL?
		self.isLoaded = true
	}
	
	
	// MARK: NSCoding
	
	public required init?(coder: NSCoder) {
		isLoaded = coder.decodeBool(forKey: "isLoaded")
		resourcesURL = coder.decodeObject(forKey: "resourcesURL") as? URL
		resources = coder.decodeObject(forKey: "resources") as! [Resource]
	}
	
	open func encode(with coder: NSCoder) {
		coder.encode(isLoaded, forKey: "isLoaded")
		coder.encode(resourcesURL, forKey: "resourcesURL")
		coder.encode(resources, forKey: "resources")
	}
	
	
	// MARK: Subscript and count
	
	/// Returns the loaded resource at the given index.
	open subscript (index: Int) -> Resource {
		return resources[index]
	}
	
	/// Returns a loaded resource identified by the given type and id,
	/// or nil if no loaded resource was found.
	open subscript (type: String, id: String) -> Resource? {
		return resources.filter { $0.id == id && $0.resourceType() == type }.first
	}
	
	/// Returns how many resources are loaded.
	open var count: Int {
		return resources.count
	}
}

extension ResourceCollection: Sequence {
	public typealias Iterator = IndexingIterator<[Resource]>
	
	public func makeIterator() -> Iterator {
		return resources.makeIterator()
	}
}

/**
A LinkedResourceCollection represents a collection of resources that is linked from another resource.
The main differences with ResourceCollection is that it is mutable,
and the addition of `linkage`, and a self `URL` property.

A LinkedResourceCollection keeps track of resources that are added to and removed from the collection.
This allows Spine to make partial updates to the collection when it is persisted.
*/
open class LinkedResourceCollection: ResourceCollection {
	/// The type/id pairs of resources present in this link.
	open var linkage: [ResourceIdentifier]?
	
	/// The URL of the link object of this collection.
	open var linkURL: URL?
	
	/// Resources added to this linked collection, but not yet persisted.
	open internal(set) var addedResources: [Resource] = []
	
	/// Resources removed from this linked collection, but not yet persisted.
	open internal(set) var removedResources: [Resource] = []
	
	public required init() {
		super.init(resources: [], resourcesURL: nil)
	}
	
	public init(resourcesURL: URL?, linkURL: URL?, linkage: [ResourceIdentifier]?) {
		super.init(resources: [], resourcesURL: resourcesURL)
		self.linkURL = linkURL
		self.linkage = linkage
	}
	
	public convenience init(resourcesURL: URL?, linkURL: URL?, homogenousType: ResourceType, IDs: [String]) {
		self.init(resourcesURL: resourcesURL, linkURL: linkURL, linkage: IDs.map { ResourceIdentifier(type: homogenousType, id: $0) })
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		linkURL = coder.decodeObject(forKey: "linkURL") as? URL
		addedResources = coder.decodeObject(forKey: "addedResources") as! [Resource]
		removedResources = coder.decodeObject(forKey: "removedResources") as! [Resource]
		
		if let encodedLinkage = coder.decodeObject(forKey: "linkage") as? [NSDictionary] {
			linkage = encodedLinkage.map { ResourceIdentifier(dictionary: $0) }
		}
	}
	
	open override func encode(with coder: NSCoder) {
		super.encode(with: coder)
		coder.encode(linkURL, forKey: "linkURL")
		coder.encode(addedResources, forKey: "addedResources")
		coder.encode(removedResources, forKey: "removedResources")
		
		if let linkage = linkage {
			let encodedLinkage = linkage.map { $0.toDictionary() }
			coder.encode(encodedLinkage, forKey: "linkage")
		}
	}
	
	// MARK: Mutators
	
	/**
	Adds the given resource to this collection. This marks the resource as added.
	
	- parameter resource: The resource to add.
	*/
	open func addResource(_ resource: Resource) {
		resources.append(resource)
		addedResources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
	}
	
	/**
	Adds the given resources to this collection. This marks the resources as added.
	
	- parameter resources: The resources to add.
	*/
	open func addResources(_ resources: [Resource]) {
		for resource in resources {
			addResource(resource)
		}
	}

	/**
	Removes the given resource from this collection. This marks the resource as removed.
	
	- parameter resource: The resource to remove.
	*/
	open func removeResource(_ resource: Resource) {
		resources = resources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
		removedResources.append(resource)
	}
	
	/**
	Adds the given resource to this collection, but does not mark it as added.
	
	- parameter resource: The resource to add.
	*/
	internal func addResourceAsExisting(_ resource: Resource) {
		resources.append(resource)
		removedResources = removedResources.filter { $0 !== resource }
		addedResources = addedResources.filter { $0 !== resource }
	}
}
