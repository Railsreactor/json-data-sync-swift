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

public class AttachmentService: GenericService<Attachment> {

    public override class func sharedService() -> AttachmentService {
        return super.sharedService() as! AttachmentService
    }
    
    public required init() {
        super.init()
    }
    
    public func cachedEntityProvider(parent: ManagedEntity, sortBy: [String]?=nil, groupBy: String?=nil) -> NSFetchedResultsController {
        let name = parent.entityName
        let predicate = NSPredicate(format: "parentId == %@ && parentType == %@ && isLoaded == %@ && pendingDelete != %@", parent.id!, name, true, true )
        return self.entityGatway()!.fetchedResultsProvider(predicate, sortBy: sortBy ?? ["-createDate"], groupBy: groupBy)
    }
    
    public func latestAttachment(parent: ManagedEntity) -> Attachment? {
        var result: Attachment? = nil
        let name = parent.entityName
        let predicate = NSPredicate(format: "parentId == %@ && parentType == %@ && isLoaded == %@ && pendingDelete != %@", parent.id!, name, true, true )
        
        do {
            result = try self.entityGatway()!.fetchEntities(predicate, sortDescriptors: ["-createDate"].sortDescriptors()).first
        } catch {
            DDLogError("Failed to fetch image: \(error)")
        }
        return result
    }
}
