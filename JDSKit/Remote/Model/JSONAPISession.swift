//
//  JSONAPISession.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/13/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import Foundation

open class JSONAPISession {
    open var sessionToken : String?
    open var refreshToken : String?
    
    open var userName: String?
    open var password: String?
    
    public init(sessionToken: String, refreshToken: String?) {
        self.sessionToken = sessionToken
        self.refreshToken = refreshToken
    }
    
    public init(userName: String, password: String) {
        self.userName = userName
        self.password = password
    }
    
    open func isPending() -> Bool {
        return self.sessionToken == nil
    }
}
