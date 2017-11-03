//
//  Operation.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation

func statusCodeIsSuccess(_ statusCode: Int?) -> Bool {
	return statusCode != nil && 200 ... 299 ~= statusCode!
}

func errorFromStatusCode(_ statusCode: Int, additionalErrors: [NSError]? = nil) -> NSError {
	let userInfo: [AnyHashable: Any]?
	
	if let additionalErrors = additionalErrors {
		userInfo = [SNAPIErrorsKey: additionalErrors]
	} else {
		userInfo = nil
	}
	
    return NSError(domain: SpineServerErrorDomain, code: statusCode, userInfo: userInfo as? [String : Any])
}

private func convertResourcesToLinkage(_ resources: [Resource]) -> [[String: String]] {
	if resources.isEmpty {
		return []
	} else {
		return resources.map { resource in
			assert(resource.id != nil, "Attempt to convert resource without id to linkage. Only resources with ids can be converted to linkage.")
			return [resource.resourceType(): resource.id!]
		}
	}
}

// MARK: - Base operation

/**
The ConcurrentOperation class is an abstract class for all Spine operations.
You must not create instances of this class directly, but instead create
an instance of one of its concrete subclasses.

Subclassing
===========
To support generic subclasses, Operation adds an `execute` method.
Override this method to provide the implementation for a concurrent subclass.

Concurrent state
================
ConcurrentOperation is concurrent by default. To update the state of the operation,
update the `state` instance variable. This will fire off the needed KVO notifications.

Operating against a Spine
=========================
The `Spine` instance variable references the Spine against which to operate.
*/
class ConcurrentOperation: Operation {
	enum State: String {
		case Ready = "isReady"
		case Executing = "isExecuting"
		case Finished = "isFinished"
	}
	
	/// The current state of the operation
	var state: State = .Ready {
		willSet {
			willChangeValue(forKey: newValue.rawValue)
			willChangeValue(forKey: state.rawValue)
		}
		didSet {
			didChangeValue(forKey: oldValue.rawValue)
			didChangeValue(forKey: state.rawValue)
		}
	}
	override var isReady: Bool {
		return super.isReady && state == .Ready
	}
	override var isExecuting: Bool {
		return state == .Executing
	}
	override var isFinished: Bool {
		return state == .Finished
	}
	override var isAsynchronous: Bool {
		return true
	}
	
	/// The Spine instance to operate against.
	var spine: Spine!
	
	/// Convenience variables that proxy to their spine counterpart
	var router: Router {
		return spine.router
	}
	var networkClient: NetworkClient {
		return spine.networkClient
	}
	var serializer: JSONSerializer {
		return spine.serializer
	}
	
	override init() {}
	
	final override func start() {
		if self.isCancelled {
			state = .Finished
		} else {
			state = .Executing
			main()
		}
	}
	
	final override func main() {
		execute()
	}
	
	func execute() {}
}


// MARK: - Main operations

/**
A FetchOperation fetches a JSONAPI document from a Spine, using a given Query.
*/
class FetchOperation<T: Resource>: ConcurrentOperation {
	/// The query describing which resources to fetch.
	let query: Query<T>
	
	/// Existing resources onto which to map the fetched resources.
	var mappingTargets = [Resource]()
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<JSONAPIDocument>?
	
	init(query: Query<T>, spine: Spine) {
		self.query = query
		super.init()
		self.spine = spine
	}
	
	override func execute() {
		let URL = spine.router.URLForQuery(query)
		
		Spine.logInfo(.spine, "Fetching document using URL: \(URL)")
        networkClient.request(method: "GET", url: URL) { statusCode, responseData, networkError in
			defer { self.state = .Finished }
			
			guard networkError == nil else {
				self.result = Failable.failure(networkError!)
				return
			}
			
			if let data = responseData, data.count > 0 {
				do {
					let document = try self.serializer.deserializeData(data, mappingTargets: self.mappingTargets)
					if statusCodeIsSuccess(statusCode) {
						self.result = Failable(document)
					} else {
						self.result = Failable.failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
					}
				} catch let error as NSError {
					self.result = Failable.failure(error)
				}
				
			} else {
				self.result = Failable.failure(errorFromStatusCode(statusCode!))
			}
		}
	}
}

/**
A DeleteOperation deletes a resource from a Spine.
*/
class DeleteOperation: ConcurrentOperation {
	/// The resource to delete.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void>?
	
	init(resource: Resource, spine: Spine) {
		self.resource = resource
		super.init()
		self.spine = spine
	}
	
	override func execute() {
		let URL = spine.router.URLForQuery(Query(resource: resource))
		
		Spine.logInfo(.spine, "Deleting resource \(resource) using URL: \(URL)")
		
        networkClient.request(method: "DELETE", url: URL) { statusCode, responseData, networkError in
			defer { self.state = .Finished }
		
			guard networkError == nil else {
				self.result = Failable.failure(networkError!)
				return
			}
			
			if statusCodeIsSuccess(statusCode) {
				self.result = Failable.success(())
			} else if let data = responseData, data.count > 0 {
				do {
					let document = try self.serializer.deserializeData(data, mappingTargets: nil)
					self.result = .failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
				} catch let error as NSError {
					self.result = .failure(error)
				}
			} else {
				self.result = .failure(errorFromStatusCode(statusCode!))
			}
		}
	}
}

/**
A SaveOperation saves a resources in a Spine. It can be used to either update an existing resource,
or to insert new resources.
*/
class SaveOperation: ConcurrentOperation {
	/// The resource to save.
	let resource: Resource
	
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void>?
	
	/// Whether the resource is a new resource, or an existing resource.
	fileprivate let isNewResource: Bool
	
	fileprivate let relationshipOperationQueue = OperationQueue()
	
	init(resource: Resource, spine: Spine) {
		self.resource = resource
		self.isNewResource = (resource.id == nil)
		super.init()
		self.spine = spine
		self.relationshipOperationQueue.maxConcurrentOperationCount = 1
	}
	
	override func execute() {
		let URL: Foundation.URL, method: String, payload: Data

		if isNewResource {
			URL = router.URLForResourceType(resource.resourceType())
			method = "POST"
			payload = serializer.serializeResources([resource], options: SerializationOptions(includeID: false, dirtyFieldsOnly: false, includeToMany: true, includeToOne: true))
		} else {
			URL = router.URLForQuery(Query(resource: resource))
			method = "PATCH"
			payload = serializer.serializeResources([resource])
		}
		
		Spine.logInfo(.spine, "Saving resource \(resource) using URL: \(URL)")
		
		networkClient.request(method: method, url: URL, payload: payload) { statusCode, responseData, networkError in
			defer { self.state = .Finished }
			
			guard networkError == nil else {
				self.result = Failable.failure(networkError!)
				return
			}

			if(!statusCodeIsSuccess(statusCode)) {
				if let data = responseData, data.count > 0 {
					do {
						let document = try self.serializer.deserializeData(data, mappingTargets: nil)
						self.result = .failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
						return
					} catch let error as NSError {
						self.result = .failure(error)
						return
					}
				} else {
					self.result = .failure(errorFromStatusCode(statusCode!))
					return
				}
				
			} else {
				if let data = responseData, data.count > 0 {
					do {
						_ = try self.serializer.deserializeData(data, mappingTargets: [self.resource])
					} catch let error as NSError {
						self.result = .failure(error)
						return
					}
				} else {
					self.result = .failure(errorFromStatusCode(statusCode!))
					return
				}
			}
			self.result = Failable.success(())
            
			// Separately update relationships if this is an existing resource
//			if self.isNewResource {
//				
//			} else {
//				//self.updateRelationships()
//                //self.relationshipOperationQueue.waitUntilAllOperationsAreFinished()
//			}
            
            
		}
	}
	
	func updateRelationships() {
		self.relationshipOperationQueue.addObserver(self, forKeyPath: "operations", options: NSKeyValueObservingOptions(), context: nil)
		
		let completionHandler: (_ result: Failable<Void>) -> Void = { result in
			if let error = result.error {
				self.relationshipOperationQueue.cancelAllOperations()
				self.result = Failable(error)
			}
		}
		
		for field in resource.fields() {
			switch field {
			case let toOne as ToOneRelationship:
				let operation = RelationshipReplaceOperation(resource: resource, relationship: toOne, spine: spine)
				operation.completionBlock = { completionHandler(operation.result!) }
				relationshipOperationQueue.addOperation(operation)
				
			case let toMany as ToManyRelationship:
				let addOperation = RelationshipAddOperation(resource: resource, relationship: toMany, spine: spine)
				addOperation.completionBlock = { completionHandler(addOperation.result!) }
				relationshipOperationQueue.addOperation(addOperation)
				
				let removeOperation = RelationshipRemoveOperation(resource: resource, relationship: toMany, spine: spine)
				removeOperation.completionBlock = { completionHandler(removeOperation.result!) }
				relationshipOperationQueue.addOperation(removeOperation)
			default: ()
			}
		}
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		guard let path = keyPath, let queue = object as? OperationQueue, path == "operations" && queue == relationshipOperationQueue else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
			return
		}
		
		if queue.operationCount == 0 {
			self.result = Failable.success(())
		}
	}
}


// MARK: - Relationship operations

private class RelationshipOperation: ConcurrentOperation {
	/// The result of the operation. You can safely force unwrap this in the completionBlock.
	var result: Failable<Void>?
	
	func handleNetworkResponse(_ statusCode: Int?, responseData: Data?, networkError: NSError?) {
		defer { self.state = .Finished }
		
		guard networkError == nil else {
			self.result = Failable.failure(networkError!)
			return
		}
		
		if statusCodeIsSuccess(statusCode) {
			self.result = Failable.success(())
		} else if let data = responseData, data.count > 0 {
			do {
				let document = try serializer.deserializeData(data, mappingTargets: nil)
				self.result = .failure(errorFromStatusCode(statusCode!, additionalErrors: document.errors))
			} catch let error as NSError {
				self.result = .failure(error)
			}
		} else {
			self.result = .failure(errorFromStatusCode(statusCode!))
		}
	}
}

private class RelationshipReplaceOperation: RelationshipOperation {
	let resource: Resource
	let relationship: ToOneRelationship

	init(resource: Resource, relationship: ToOneRelationship, spine: Spine) {
		self.resource = resource
		self.relationship = relationship
		super.init()
		self.spine = spine
	}
	
	override func execute() {
        let key = relationship.name
		let relatedResource = resource.valueForField(key!) as! Resource
		let linkage = convertResourcesToLinkage([relatedResource])
		
		if let jsonPayload = try? JSONSerialization.data(withJSONObject: ["data": linkage], options: JSONSerialization.WritingOptions(rawValue: 0)) {
			let URL = router.URLForRelationship(relationship, ofResource: resource)
			networkClient.request(method: "PATCH", url: URL, payload: jsonPayload, callback: handleNetworkResponse)
		}
    }
}

private class RelationshipAddOperation: RelationshipOperation {
	let resource: Resource
	let relationship: ToManyRelationship
	
	init(resource: Resource, relationship: ToManyRelationship, spine: Spine) {
		self.resource = resource
		self.relationship = relationship
		super.init()
		self.spine = spine
	}
	
	override func execute() {
        if let resourceCollection = resource.valueForField(relationship.name) as? LinkedResourceCollection {
            let relatedResources = resourceCollection.addedResources
            
            guard !relatedResources.isEmpty else {
                self.result = Failable(())
                self.state = .Finished
                return
            }
            
            let linkage = convertResourcesToLinkage(relatedResources)
            
            if let jsonPayload = try? JSONSerialization.data(withJSONObject: ["data": linkage], options: JSONSerialization.WritingOptions(rawValue: 0)) {
                let URL = router.URLForRelationship(relationship, ofResource: self.resource)
                networkClient.request(method: "POST", url: URL, payload: jsonPayload, callback: handleNetworkResponse)
            }
        }
	}
}

private class RelationshipRemoveOperation: RelationshipOperation {
	let resource: Resource
	let relationship: ToManyRelationship
	
	init(resource: Resource, relationship: ToManyRelationship, spine: Spine) {
		self.resource = resource
		self.relationship = relationship
		super.init()
		self.spine = spine
	}
	
	override func execute() {
        if let resourceCollection = resource.valueForField(relationship.name) as? LinkedResourceCollection {
            let relatedResources = resourceCollection.addedResources
            
            guard !relatedResources.isEmpty else {
                self.result = Failable(())
                self.state = .Finished
                return
            }
            
            let URL = router.URLForRelationship(relationship, ofResource: self.resource)
            networkClient.request(method: "DELETE", url: URL, callback: handleNetworkResponse)
        }
	}
}
