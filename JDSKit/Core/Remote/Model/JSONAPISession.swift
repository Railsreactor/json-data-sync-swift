//
//  JSONAPISession.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/13/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

public class JSONAPISession {
    public var sessionToken : String?
    public var refreshToken : String?
    
    public var userName: String?
    public var password: String?
    
    public init(sessionToken: String, refreshToken: String?) {
        self.sessionToken = sessionToken
        self.refreshToken = refreshToken
    }
    
    public init(userName: String, password: String) {
        self.userName = userName
        self.password = password
    }
    
    public func isPending() -> Bool {
        return self.sessionToken == nil
    }
}
