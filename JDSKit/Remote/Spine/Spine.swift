//
//  Resource.swift
//  Spine
//
//  Created by Ward van Teijlingen on 21-08-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation
import PromiseKit
//import BrightFutures

public typealias Metadata = [String: Any]
public typealias JSONAPIData = [String: Any]


/// The main class
open class Spine {
	
	/// The router that builds the URLs for requests.
	let router: Router
	
	/// The HTTPClient that performs the HTTP requests.
	open let networkClient: NetworkClient
	
	/// The serializer to use for serializing and deserializing of JSON representations.
	let serializer: JSONSerializer = JSONSerializer()
	
	/// The operation queue on which all operations are queued.
	let operationQueue = OperationQueue()
	
	
	// MARK: Initializers
	
	/**
	Creates a new Spine instance using the given router and network client.
	*/
	public init(router: Router, networkClient: NetworkClient) {
		self.router = router
		self.networkClient = networkClient
		self.operationQueue.name = "com.wardvanteijlingen.spine"
	}
	
	/**
	Creates a new Spine instance using the default Router and HTTPClient classes.
	*/
	public convenience init(baseURL: URL) {
		let router = JSONAPIRouter()
		router.baseURL = baseURL
		self.init(router: router, networkClient: HTTPClient())
	}
	
	/**
	Creates a new Spine instance using a specific router and the default HTTPClient class.
	Use this initializer to specify a custom router.
	*/
	public convenience init(router: Router) {
		self.init(router: router, networkClient: HTTPClient())
	}
	
	/**
	Creates a new Spine instance using a specific network client and the default Router class.
	Use this initializer to specify a custom network client.
	*/
	public convenience init(baseURL: URL, networkClient: NetworkClient) {
		let router = JSONAPIRouter()
		router.baseURL = baseURL
		self.init(router: router, networkClient: networkClient)
	}
	
	
	// MARK: Operations
	
	/**
	Adds the given operation to the operation queue.
	This sets the spine property of the operation to this Spine instance.
	
	:param: operation The operation to enqueue.
	*/
	func addOperation(_ operation: ConcurrentOperation) {
		operation.spine = self
		operationQueue.addOperation(operation)
	}
	
	
	// MARK: Fetching
	
	/**
	Fetch multiple resources using the given query..
	
	:param: query The query describing which resources to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	open func find<T: Resource>(_ query: Query<T>) -> Promise<(resources: ResourceCollection, meta: Metadata?, jsonapi: JSONAPIData?)> {
        
        return Promise { fulfill, reject in
            
            let operation = FetchOperation(query: query, spine: self)
            operation.completionBlock = {
                
                switch operation.result! {
                case .success(let document):
                    let response = (ResourceCollection(document: document), document.meta, document.jsonapi)
                    fulfill(response)
                case .failure(let error):
                    reject(error)
                }
            }
            self.addOperation(operation)
        }
	}
	
	/**
	Fetch multiple resources with the given IDs and type.
	
	:param: IDs  IDs of resources to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
	open func find<T: Resource>(_ IDs: [String], ofType type: T.Type) -> Promise<(resources: ResourceCollection, meta: Metadata?, jsonapi: JSONAPIData?)> {
		let query = Query(resourceType: type, resourceIDs: IDs)
		return find(query)
	}
	
	/**
	Fetch one resource using the given query.
	
	:param: query The query describing which resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	open func findOne<T: Resource>(_ query: Query<T>) -> Promise<(resource: T, meta: Metadata?, jsonapi: JSONAPIData?)> {
        
        return Promise { fulfill, reject in
            
            let operation = FetchOperation(query: query, spine: self)
            operation.completionBlock = {
                switch operation.result! {
                case .success(let document) where document.data?.count == 0:
                    reject(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.ResourceNotFound, userInfo: nil))
                case .success(let document):
                    let firstResource = document.data!.first as! T
                    let response = (resource: firstResource, meta: document.meta, jsonapi: document.jsonapi)
                    fulfill(response)
                case .failure(let error):
                    reject(error)
                }
            }
            self.addOperation(operation)
        }
	}
	
	/**
	Fetch one resource with the given ID and type.
	
	:param: ID   ID of resource to fetch.
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to the fetched resource.
	*/
	open func findOne<T: Resource>(_ ID: String, ofType type: T.Type) -> Promise<(resource: T, meta: Metadata?, jsonapi: JSONAPIData?)> {
		let query = Query(resourceType: type, resourceIDs: [ID])
		return findOne(query)
	}
	
	/**
	Fetch all resources with the given type.
	This does not explicitly impose any limit, but the server may choose to limit the response.
	
	:param: type The type of resource to fetch.
	
	:returns: A future that resolves to a ResourceCollection that contains the fetched resources.
	*/
    open func findAll<T: Resource>(_ type: T.Type, filters: [NSComparisonPredicate]?=nil, include: [String]?=nil, pagination: Pagination?=nil) -> Promise<(resources: ResourceCollection, meta: Metadata?, jsonapi: JSONAPIData?)> {
		var query = Query(resourceType: type)
        query.filters = filters ?? [NSComparisonPredicate]()
        query.includes = include ?? [String]()
        query.paginate(pagination)
		return find(query)
	}
	
	
	// MARK: Paginating
	
	/**
	Loads the next page of the given resource collection. The newly loaded resources are appended to the passed collection.
	When the next page is not available, the returned future will fail with a `NextPageNotAvailable` error code.
	
	:param: collection The collection for which to load the next page.
	
	:returns: A future that resolves to the ResourceCollection including the newly loaded resources.
	*/
	open func loadNextPageOfCollection(_ collection: ResourceCollection) -> Promise<ResourceCollection> {
        
        return Promise { fulfill, reject in
            
            if let nextURL = collection.nextURL {
                let query = Query(URL: nextURL)
                let operation = FetchOperation(query: query, spine: self)
                
                operation.completionBlock = {
                    switch operation.result! {
                    case .success(let document):
                        let nextCollection = ResourceCollection(document: document)
                        collection.resources += nextCollection.resources
                        collection.resourcesURL = nextCollection.resourcesURL
                        collection.nextURL = nextCollection.nextURL
                        collection.previousURL = nextCollection.previousURL
                        
                        fulfill(collection)
                    case .failure(let error):
                        reject(error)
                    }
                }
                
                self.addOperation(operation)
                
            } else {
                reject(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.NextPageNotAvailable, userInfo: nil))
            }
        }
    }
	
	/**
	Loads the previous page of the given resource collection. The newly loaded resources are prepended to the passed collection.
	When the previous page is not available, the returned future will fail with a `PreviousPageNotAvailable` error code.
	
	:param: collection The collection for which to load the previous page.
	
	:returns: A future that resolves to the ResourceCollection including the newly loaded resources.
	*/
	open func loadPreviousPageOfCollection(_ collection: ResourceCollection) -> Promise<ResourceCollection> {
        
        return Promise { fulfill, reject in
            
            if let previousURL = collection.previousURL {
                let query = Query(URL: previousURL)
                let operation = FetchOperation(query: query, spine: self)
                
                operation.completionBlock = {
                    switch operation.result! {
                    case .success(let document):
                        let previousCollection = ResourceCollection(document: document)
                        collection.resources = previousCollection.resources + collection.resources
                        collection.resourcesURL = previousCollection.resourcesURL
                        collection.nextURL = previousCollection.nextURL
                        collection.previousURL = previousCollection.previousURL
                        
                        fulfill(collection)
                    case .failure(let error):
                        reject(error)
                    }
                }
                
                self.addOperation(operation)
                
            } else {
                reject(NSError(domain: SpineClientErrorDomain, code: SpineErrorCodes.NextPageNotAvailable, userInfo: nil))
            }
        }
    }
	
	
	// MARK: Persisting
	
	/**
	Saves the given resource.
	
	:param: resource The resource to save.
	
	:returns: A future that resolves to the saved resource.
	*/
    public func save<T: Resource>(resource: T) -> Promise<T> {
        return Promise { fulfill, reject in
            let operation = SaveOperation(resource: resource, spine: self)
            
            operation.completionBlock = {
                if let error = operation.result?.error {
                    reject(error)
                } else {
                    fulfill(resource)
                }
            }
            self.addOperation(operation)
        }
    }
	
	/**
	Deletes the given resource.
	
	:param: resource The resource to delete.
	
	:returns: A future
	*/
	open func delete(_ resource: Resource) -> Promise<Void> {
        return Promise { fulfill, reject in
            let operation = DeleteOperation(resource: resource, spine: self)
            
            operation.completionBlock = {
                if let error = operation.result?.error {
                    reject(error)
                } else {
                    fulfill()
                }
            }
            self.addOperation(operation)
        }
    }
	
	
	// MARK: Ensuring
	
	/**
	Ensures that the given resource is loaded. If it's `isLoaded` property is false,
	it loads the given resource from the API, otherwise it returns the resource as is.
	
	:param: resource The resource to ensure.
	
	:returns: return value description
	*/
	open func ensure<T: Resource>(_ resource: T) -> Promise<T> {
		let query = Query(resource: resource)
		return loadResourceByExecutingQuery(resource, query: query)
	}
	
	/**
	Ensures that the given resource is loaded. If it's `isLoaded` property is false,
	it loads the given resource from the API, otherwise it returns the resource as is.
	
	:param: resource The resource to ensure.
	
	:param: resource      The resource to ensure.
	:param: queryCallback <#queryCallback description#>
	
	:returns: <#return value description#>
	*/
	open func ensure<T: Resource>(_ resource: T, queryCallback: (Query<T>) -> Query<T>) -> Promise<T> {
		let query = queryCallback(Query(resource: resource))
		return loadResourceByExecutingQuery(resource, query: query)
	}

	func loadResourceByExecutingQuery<T: Resource>(_ resource: T, query: Query<T>) -> Promise<T> {
        return Promise { fulfill, reject in
            if let loaded = resource.isLoaded, loaded.boolValue {
                fulfill(resource)
                return
            }
            
            let operation = FetchOperation(query: query, spine: self)
            operation.mappingTargets = [resource]
            operation.completionBlock = {
                if let error = operation.result?.error {
                    reject(error)
                } else {
                    fulfill(resource)
                }
            }
            
            self.addOperation(operation)
        }
	}
}


/**
Extension regarding (registering of) resource types.
*/
public extension Spine {
	/**
	Registers a factory function `factory` for resource type `type`.
	
	:param: type    The resource type to register the factory function for.
	:param: factory The factory method that returns an instance of a resource.
	*/
	func registerResource(_ type: String, factory: @escaping () -> Resource) {
		serializer.resourceFactory.registerResource(type, factory: factory)
	}
}


/**
Extension regarding (registering of) transformers.
*/
public extension Spine {
	/**
	Registers transformer `transformer`.
	
	:param: type The Transformer to register.
	*/
	func registerTransformer<T: Transformer>(_ transformer: T) {
		serializer.transformers.registerTransformer(transformer)
	}
}


// MARK: - Utilities

/// Return the first resource of `domain`, that is of the resource type `type` and has id `id`.
func findResource(_ keyValueCache: [String : Resource], type: ResourceType, id: String) -> Resource? {
    return keyValueCache[String(type) + ":$" + id]
}

func cacheResource(_ keyValueCache: inout [String : Resource], resource: Resource) {
    if let id = resource.id {
        keyValueCache[String(resource.resourceType()) + ":$" + id] = resource
    }
}


// MARK: - Failable

/**
Represents the result of a failable operation.

- Success: The operation succeeded with the given result.
- Failure: The operation failed with the given error.
*/
enum Failable<T> {
	case success(T)
	case failure(NSError)
	
	init(_ value: T) {
		self = .success(value)
	}
	
	init(_ error: NSError) {
		self = .failure(error)
	}
	
	var error: NSError? {
		switch self {
		case .failure(let error):
			return error
		default:
			return nil
		}
	}
}
