//
//  NetworkSpinner.swift
//  JDSKit
//
//  Created by Nikita on 11.02.16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit


open class NetworkSpinner: NSObject {
    open static let sharedInstance = NetworkSpinner()
    
    fileprivate var activeConnectionsCounter: Int = 0
    
    open func startActiveConnection() {
        activeConnectionsCounter += 1
        updateNetworkIndicator()
    }
    
    open func stopActiveConnection() {
        if activeConnectionsCounter == 0 { return }
        activeConnectionsCounter -= 1
        
        updateNetworkIndicator()
    }
    
    fileprivate func updateNetworkIndicator() {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = self.activeConnectionsCounter > 0
        }
    }
    
}
