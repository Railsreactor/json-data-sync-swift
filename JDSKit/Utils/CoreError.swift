//
//  CoreError.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 10/25/15.
//  Copyright © 2015 IT. All rights reserved.
//

import UIKit

typealias RetryHandler = () -> Void


public let SNLocalizedTitleKey: String  = "kSNLocalizedTitle"
public let SNAPIErrorSourceKey: String  = "kSNAAPISource"
public let SNAPIErrorsKey: String       = "kSNAPIErrors"


public enum CoreError: ErrorType {
    
    case RuntimeError(description: String, cause: NSError?)
    case ConnectionProblem(description: String, cause: NSError?)
    
    case WrongCredentials
    case ServiceError(description: String, cause: NSError?)
    case ValidationError(apiErrors: [NSError])
    case EntityMisstype(input: String, target: String)
    
    public var errorInfo: (code: Int, message: String?, cause: NSError?, actionTitle: String?) {
        
        var code: Int, message: String?, cause: NSError?, actionTitle: String?
        
        switch self {
        case .RuntimeError(let aDescription, let aCause):
            code = 0
            cause = aCause
            message = aDescription
            
        case .ConnectionProblem(let aDescription, let aCause):
            code = 1
            cause = aCause
            message = aDescription
            
        case .ServiceError(let aDescription, let aCause):
            code = 2
            cause = aCause
            message = aDescription
            
        case .ValidationError(let apiErrors):
            code = 3
            if apiErrors.count > 0 {
                message = localizedDescriptionFromAPIErrors()
            }
            
        case .WrongCredentials:
            code = 4
            message = "Wrong username or password."
            actionTitle = "Logout"
            
        case .EntityMisstype(let input, let target):
            code = 8
            message = "Failed to save entity of type \(input). Expected: \(target)"
            actionTitle = "OK"
        }
        
        return (code: code, message: message, cause: cause, actionTitle: actionTitle)
    }
    
    public func extractAPIErrors() -> [NSError] {
        switch self {
        case .ValidationError(let apiErrors):
            return apiErrors
        default:
            break
        }
        return [NSError]()
    }
    
    public func localizedDescriptionFromAPIErrors() -> String {
        var description = ""
        for apiError in extractAPIErrors() {
            if let source = apiError.userInfo[SNAPIErrorSourceKey] as? [String: String] {
                if let pointer = source["pointer"] {
                    let titleChars = pointer.characters.split { $0 == "/" }.last
                    
                    if titleChars != nil && !titleChars!.elementsEqual("base".characters) {
                        description += String(titleChars!).capitalizedString + " "
                    }
                }
                description += apiError.localizedDescription + "\n"
            }
        }
        return description
    }
}
