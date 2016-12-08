//
//  Logging.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-04-15.
//  Copyright (c) 2015 Ward van Teijlingen. All rights reserved.
//

import Foundation
import CocoaLumberjack
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


public enum LogLevel: Int {
	case debug = 0
	case info = 1
	case warning = 2
	case error = 3
	case none = 4
	
	var description: String {
		switch self {
		case .debug:   return "❔ Debug  "
		case .info:    return "❕ Info   "
		case .warning: return "❗️ Warning"
		case .error:   return "❌ Error  "
		case .none:    return "None      "
		}
	}
}

/**
Logging domains

- Spine:       The main Spine component
- Networking:  The networking component, requests, responses etc
- Serializing: The (de)serializing component
*/
public enum LogDomain {
	case spine, networking, serializing
}

/// Configured log levels
internal var logLevels: [LogDomain: LogLevel] = [
	.spine: .none,
	.networking: .none,
	.serializing: .none
]

/**
Extension regarding logging.
*/
extension Spine {
	public class func setLogLevel(_ level: LogLevel, forDomain domain: LogDomain) {
		logLevels[domain] = level
	}
	
	class func shouldLog(_ level: LogLevel, domain: LogDomain) -> Bool {
		return (level.rawValue >= logLevels[domain]?.rawValue)
	}
	
	class func log<T>(_ object: T, level: LogLevel, domain: LogDomain) {
		if shouldLog(level, domain: domain) {
			DDLogDebug("\(level.description) - \(object)")
		}
	}
	
	class func logDebug<T>(_ domain: LogDomain, _ object: T) {
		log(object, level: .debug, domain: domain)
	}
	
	class func logInfo<T>(_ domain: LogDomain, _ object: T) {
		log(object, level: .info, domain: domain)
	}
	
	class func logWarning<T>(_ domain: LogDomain, _ object: T) {
		log(object, level: .warning, domain: domain)
	}
	
	class func logError<T>(_ domain: LogDomain, _ object: T) {
		log(object, level: .error, domain: domain)
	}
}
