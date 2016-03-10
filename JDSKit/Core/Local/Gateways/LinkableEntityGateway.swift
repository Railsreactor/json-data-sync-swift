//
//  LinkableEntitiyGateway.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/10/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation
import CoreData

public class LinkableEntitiyGateway: GenericEntityGateway {
    
    public override func gatewayForEntity(inputEntity: ManagedEntity, fromRelationship: NSRelationshipDescription) -> GenericEntityGateway? {
        if let linkableEntity = inputEntity as? LinkableEntity {
            guard linkableEntity.parentType != nil else {
                return nil
            }
            return contextProvider.entityGatewayByEntityTypeKey(linkableEntity.parentType!)
        } else {
            return super.gatewayForEntity(inputEntity, fromRelationship: fromRelationship)
        }
    }
}
