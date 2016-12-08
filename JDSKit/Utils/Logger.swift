//
//  Logger.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/12/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import CocoaLumberjack

open class Logger {
    
    open static func initialize(_ logLevel: DDLogLevel = DDLogLevel.all) {
        let level = logLevel
        
        DDLog.add(DDTTYLogger.sharedInstance(), with: level) // TTY = Xcode console
        DDLog.add(DDASLLogger.sharedInstance(), with: level) // ASL = Apple System Logs
        
        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = TimeInterval(60*60*24)  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
        
        DDLogInfo("Logger initialized...")
    }
    
}
