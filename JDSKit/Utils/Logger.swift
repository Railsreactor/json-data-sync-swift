//
//  Logger.swift
//  JDSKit
//
//  Created by Igor Reshetnikov on 11/12/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

import CocoaLumberjack

public enum LoggerLevel: UInt {
    case Off
    case Error
    case Warning
    case Info
    case Debug
    case Verbose
    case All
}

public class Logger {
    
    public static func initialize(logLevel: LoggerLevel = LoggerLevel.All) {
        let level = DDLogLevel(rawValue: logLevel.rawValue)!
        
        DDLog.addLogger(DDTTYLogger.sharedInstance(), withLevel: level) // TTY = Xcode console
        DDLog.addLogger(DDASLLogger.sharedInstance(), withLevel: level) // ASL = Apple System Logs
        
        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = 60*60*24  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(fileLogger)
        
        DDLogInfo("Logger initialized...")
    }
    
}