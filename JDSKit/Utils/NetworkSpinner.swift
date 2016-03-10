//
//  NetworkSpinner.swift
//  JDSKit
//
//  Created by Nikita on 11.02.16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

import UIKit


public class NetworkSpinner: NSObject {
    public static let sharedInstance = NetworkSpinner()
    
    private var activeConnectionsCounter: Int = 0
    
    public func startActiveConnection() {
        activeConnectionsCounter++
        updateNetworkIndicator()
    }
    
    public func stopActiveConnection() {
        if activeConnectionsCounter == 0 { return }
        activeConnectionsCounter--
        
        updateNetworkIndicator()
    }
    
    private func updateNetworkIndicator() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = activeConnectionsCounter > 0
    }
    
}
