//
//  Routing.swift
//  Spine
//
//  Created by Ward van Teijlingen on 24-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The RouterProtocol declares methods and properties that a router should implement.
The router is used to build URLs for API requests.
*/
public protocol Router {
	/// The base URL of the API.
	var baseURL: URL! { get set }
	
	/**
	Returns an NSURL that points to the collection of resources with a given type.
	
	- parameter type: The type of resources.
	
	- returns: The NSURL.
	*/
	func URLForResourceType(_ type: ResourceType) -> URL
	
	func URLForRelationship<T: Resource>(_ relationship: Relationship, ofResource resource: T) -> URL
	
	/**
	Returns an NSURL that represents the given query.
	
	- parameter query: The query to turn into an NSURL.
	
	- returns: The NSURL.
	*/
	func URLForQuery<T: Resource>(_ query: Query<T>) -> URL
}

/**
The built in JSONAPIRouter builds URLs according to the JSON:API specification.

Filters
=======
Only 'equal to' filters are supported. You can subclass Router and override
`queryItemForFilter` to add support for other filtering strategies.

Pagination
==========
Only PageBasedPagination and OffsetBasedPagination are supported. You can subclass Router
and override `queryItemsForPagination` to add support for other pagination strategies.
*/
open class JSONAPIRouter: Router {
	open var baseURL: URL!

	public init() { }
	
	open func URLForResourceType(_ type: ResourceType) -> URL {
		return baseURL.appendingPathComponent(type)
	}
	
	open func URLForRelationship<T: Resource>(_ relationship: Relationship, ofResource resource: T) -> URL {
		let resourceURL = resource.URL ?? URLForResourceType(type(of: resource).resourceType()).appendingPathComponent("/\(resource.id!)")
		return resourceURL.appendingPathComponent("/links/\(relationship.serializedName)")
	}

	open func URLForQuery<T: Resource>(_ query: Query<T>) -> URL {
		var URL: Foundation.URL!
		var preBuiltURL = false
		
		// Base URL
		if let URLString = query.URL?.absoluteString {
			URL = Foundation.URL(string: URLString, relativeTo: baseURL)
			preBuiltURL = true
		} else if let type = query.resourceType {
			URL = URLForResourceType(type)
		} else {
			assertionFailure("Cannot build URL for query. Query does not have a URL, nor a resource type.")
		}
		
		var URLComponents = Foundation.URLComponents(url: URL, resolvingAgainstBaseURL: true)!
		var queryItems: [URLQueryItem] = URLComponents.queryItems ?? []
		
		// Resource IDs
		if !preBuiltURL {
			if let IDs = query.resourceIDs {
				if IDs.count == 1 {
					URLComponents.path = (URLComponents.path as NSString).appendingPathComponent(IDs.first!)
				} else {
					let item = URLQueryItem(name: "filter[id]", value: IDs.joined(separator: ","))
					setQueryItem(item, forQueryItems: &queryItems)
				}
			}
		}
		
		// Includes
		if !query.includes.isEmpty {
			let item = URLQueryItem(name: "include", value: query.includes.joined(separator: ","))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Filters
		for filter in query.filters {
			let item = queryItemForFilter(filter)
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Fields
		for (resourceType, fields) in query.fields {
			let item = URLQueryItem(name: "fields[\(resourceType)]", value: fields.joined(separator: ","))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Sorting
		if !query.sortDescriptors.isEmpty {
			let descriptorStrings = query.sortDescriptors.map { descriptor -> String in
				if descriptor.ascending {
					return "+\(descriptor.key!)"
				} else {
					return "-\(descriptor.key!)"
				}
			}
			
			let item = URLQueryItem(name: "sort", value: descriptorStrings.joined(separator: ","))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Pagination
		if let pagination = query.pagination {
			for item in queryItemsForPagination(pagination) {
				setQueryItem(item, forQueryItems: &queryItems)
			}
		}

		// Compose URL
		if !queryItems.isEmpty {
			URLComponents.queryItems = queryItems
		}
		
		return URLComponents.url!
	}
	
	/**
	Returns an NSURLQueryItem that represents the given comparison predicate in an URL.
	By default this method only supports 'equal to' predicates. You can override
	this method to add support for other filtering strategies.
	
	- parameter filter: The NSComparisonPredicate.
	
	- returns: The NSURLQueryItem.
	*/
	open func queryItemForFilter(_ filter: NSComparisonPredicate) -> URLQueryItem {
		assert(filter.predicateOperatorType == .equalTo, "The built in router only supports Query filter expressions of type 'equalTo'")
        
        var format = "filter[\(filter.leftExpression.keyPath)]"
        if let optionals = filter.optionals {
            for value in optionals {
                format += "[\(value)]"
            }
        }
        
        if let value = filter.rightExpression.constantValue {
            return URLQueryItem(name: format, value: "\(value)")
        } else {
            fatalError("The built in router only supports Query filter expressions of type 'equalTo' with both values")
        }
	}

	/**
	Returns an array of NSURLQueryItems that represent the given pagination configuration.
	By default this method only supports the PageBasedPagination and OffsetBasedPagination configurations.
	You can override this method to add support for other pagination strategies.
	
	- parameter pagination: The QueryPagination configuration.
	
	- returns: Array of NSURLQueryItems.
	*/
	open func queryItemsForPagination(_ pagination: Pagination) -> [URLQueryItem] {
		var queryItems = [URLQueryItem]()
		
		switch pagination {
		case let pagination as PageBasedPagination:
			queryItems.append(URLQueryItem(name: "page[number]", value: String(pagination.pageNumber)))
			queryItems.append(URLQueryItem(name: "page[size]", value: String(pagination.pageSize)))
			
		case let pagination as OffsetBasedPagination:
			queryItems.append(URLQueryItem(name: "page[offset]", value: String(pagination.offset)))
			queryItems.append(URLQueryItem(name: "page[limit]", value: String(pagination.limit)))
			
			
		default:
			assertionFailure("The built in router only supports PageBasedPagination and OffsetBasedPagination")
		}
		
		return queryItems
	}
	
	fileprivate func setQueryItem(_ queryItem: URLQueryItem, forQueryItems queryItems: inout [URLQueryItem]) {
		queryItems = queryItems.filter { return $0.name != queryItem.name }
		queryItems.append(queryItem)
	}
}


public extension NSComparisonPredicate {
    
    fileprivate struct AssociatedKeys {
        static var OptionalsName = "OptionalsName"
    }
    
    var optionals : [Any]? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.OptionalsName) as? [Any]
        }
        set(value) {
            objc_setAssociatedObject(self,&AssociatedKeys.OptionalsName, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    convenience init(format: String, optionals: [Any]?=nil) {
        self.init(format: format, optionals: [Any]())
        self.optionals = optionals
    }
    
}



