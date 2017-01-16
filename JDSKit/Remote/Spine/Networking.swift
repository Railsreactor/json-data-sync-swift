//
//  Networking.swift
//  Spine
//
//  Created by Ward van Teijlingen on 05-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//
import Foundation

public typealias NetworkClientCallback = (_ statusCode: Int?, _ data: Data?, _ error: NSError?) -> Void

/**
 A NetworkClient is the interface between Spine and the server. It does not impose any transport
 and can be used for HTTP, websockets, and any other data transport.
 */
public protocol NetworkClient {
    /**
     Performs a network request to the given URL with the given method.
     
     - parameter method:   The method to use, expressed as a HTTP verb.
     - parameter URL:      The URL to which to make the request.
     - parameter callback: The callback to execute when the request finishes.
     */
    func request(method: String, url: URL, callback: @escaping NetworkClientCallback)
    
    /**
     Performs a network request to the given URL with the given method.
     
     - parameter method:   The method to use, expressed as a HTTP verb.
     - parameter URL:      The URL to which to make the request.
     - parameter payload:  The payload the send as part of the request.
     - parameter callback: The callback to execute when the request finishes.
     */
    func request(method: String, url: URL, payload: Data?, callback: @escaping NetworkClientCallback)
}

extension NetworkClient {
    public func request(method: String, url: URL, callback: @escaping NetworkClientCallback) {
        return request(method: method, url: url, payload: nil, callback: callback)
    }
}

/**
 The HTTPClient implements the NetworkClient protocol to work over an HTTP connection.
 */
public class HTTPClient: NetworkClient {
    /**
     Performs a network request to the given URL with the given method.
     
     - parameter method:   The method to use, expressed as a HTTP verb.
     - parameter URL:      The URL to which to make the request.
     - parameter payload:  The payload the send as part of the request.
     - parameter callback: The callback to execute when the request finishes.
     */
    public func request(method: String, URL: NSURL, payload: NSData?, callback: (Int?, NSData?, NSError?) -> Void) {
        
    }


    var urlSession: URLSession
    var headers: [String: String] = [:]
    
    public init() {
        let configuration = URLSessionConfiguration.default
        //configuration.HTTPAdditionalHeaders = ["Content-Type": "application/vnd.api+json"]
        configuration.httpAdditionalHeaders = [ "Content-Type": "application/json",
                                                "Accept": "application/json"]
        
        configuration.requestCachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData
        configuration.urlCache = nil
        
        
        urlSession = URLSession(configuration: configuration)
    }
    
    /**
     Sets a HTTP header for all upcoming network requests.
     
     - parameter header: The name of header to set the value for.
     - parameter value:  The value to set the header tp.
     */
    public func setHeader(header: String, to value: String) {
        headers[header] = value
    }
    
    /**
     Removes a HTTP header for all upcoming  network requests.
     
     - parameter header: The name of header to remove.
     */
    public func removeHeader(header: String) {
        headers.removeValue(forKey: header)
    }
    
    public func buildRequest(method: String, url: URL, payload: Data?) -> NSURLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let payload = payload {
            request.httpBody = payload
        }
        
        return request as NSURLRequest
    }
    
    public func request(method: String, url: URL, payload: Data?, callback: @escaping NetworkClientCallback) {
        var request = buildRequest(method: method, url: url, payload: payload) as URLRequest
        
        NetworkSpinner.sharedInstance.startActiveConnection()
        
        Spine.logInfo(.networking, "\(method): \(url)")
        
        if Spine.shouldLog(.debug, domain: .networking) {
            
            if let headers = request.allHTTPHeaderFields {
                Spine.logDebug(.networking, "Headers: \(headers) + \(urlSession.configuration.httpAdditionalHeaders)")
            }
            
            if let httpBody = request.httpBody, let stringRepresentation = NSString(data: httpBody, encoding: String.Encoding.utf8.rawValue) {
                Spine.logDebug(.networking, stringRepresentation)
            }
        }

        let task = urlSession.dataTask(with: request, completionHandler: { data, response, networkError in
            let response = (response as? HTTPURLResponse)
            
            NetworkSpinner.sharedInstance.stopActiveConnection()
            
            if networkError == nil && response?.url != request.url {
                Spine.logError(.networking, "Request URL: \(request.url) - Doesn't corresponds to response URL: \(response?.url). Fallback with error 400")
                callback(400, nil, NSError(domain: NSURLErrorDomain, code: 400, userInfo: nil))
                return
            }
            
            if let error = networkError {
                // Network error
                Spine.logError(.networking, "\(request.url) - \(error.localizedDescription)")
                
            } else if let statusCode = response?.statusCode, 200 ... 299 ~= statusCode {
                // Success
                Spine.logInfo(.networking, "\(statusCode): \(request.url)")
                
            } else {
                // API Error
                Spine.logWarning(.networking, "\(response?.statusCode): \(request.url)")
            }
            
            if Spine.shouldLog(.debug, domain: .networking) {
                if let data = data, let stringRepresentation = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    Spine.logDebug(.networking, stringRepresentation)
                }
            }
            
            callback(response?.statusCode, data, networkError as NSError?)
        })
        
        task.resume()
    }
}
