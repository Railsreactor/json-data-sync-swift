//
//  UpdateInfoGateway.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/2/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit

public class UpdateInfoGateway: NSObject {
    
    weak var contextProvider : ManagedObjectContextProvider!

    init(_ provider: ManagedObjectContextProvider) {
        super.init()
        contextProvider = provider
    }
    
    public func allObjects() throws -> [CDUpdateInfo] {
        return try contextProvider?.fetchEntities(nil, ofType: CDUpdateInfo.self, sortDescriptors: nil) as! [CDUpdateInfo]
    }
    
    public func objectsCount() throws -> Int {
        return contextProvider?.countEntities(CDUpdateInfo.self) ?? 0
    }
    
    public func updateInfoForKey(entityKey: String, filterID: String?=nil, createIfNeed: Bool=false) throws -> CDUpdateInfo? {
        
        var predicateString = "entityType == %@"
        var params = [entityKey]
        
        if let filterID = filterID {
            predicateString += " && filterID == %@"
            params.append(filterID)
        }
        
        let predicate = NSPredicate(format: predicateString, argumentArray: params)
        
        var updateInfo = try contextProvider?.fetchEntity(predicate, ofType: CDUpdateInfo.self) as? CDUpdateInfo
        if updateInfo == nil && createIfNeed {
            updateInfo = contextProvider?.createEntity(CDUpdateInfo.self, temp: false) as? CDUpdateInfo
            updateInfo?.entityType = entityKey
            updateInfo?.filterID = filterID
            updateInfo?.updateDate = NSDate(timeIntervalSince1970: 0)
        }
        
        return updateInfo
    }
}
