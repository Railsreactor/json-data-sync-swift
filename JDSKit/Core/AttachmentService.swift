//
//  AttachmentService.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 2/15/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import PromiseKit
import CoreData
import CocoaLumberjack

open class AttachmentService: GenericService<Attachment> {

    open override class func sharedService() -> AttachmentService {
        return super.sharedService() as! AttachmentService
    }
    
    public required init() {
        super.init()
    }
    
    public required init(entityType: ManagedEntity.Type) {
        fatalError("init(entityType:) has not been implemented")
    }
    
    open func cachedEntityProvider(_ parent: ManagedEntity, sortBy: [String]?=nil, groupBy: String?=nil) -> NSFetchedResultsController<NSFetchRequestResult> {
        let name = parent.entityName
        let predicate = NSPredicate(format: "parentId == %@ && parentType == %@ && isLoaded == %@ && pendingDelete != %@", parent.id!, name, true as CVarArg, true as CVarArg )
        return self.entityGateway()!.fetchedResultsProvider(predicate, sortBy: sortBy ?? ["-createDate"], groupBy: groupBy)
    }
    
    open func latestAttachment(_ parent: ManagedEntity) -> Attachment? {
        var result: Attachment? = nil
        let name = parent.entityName
        let predicate = NSPredicate(format: "parentId == %@ && parentType == %@ && isLoaded == %@ && pendingDelete != %@", parent.id!, name, true as CVarArg, true as CVarArg )
        
        do {
            result = try self.entityGateway()!.fetchEntities(predicate, sortDescriptors: ["-createDate"].sortDescriptors()).first
        } catch {
            DDLogError("Failed to fetch image: \(error)")
        }
        return result
    }
}
