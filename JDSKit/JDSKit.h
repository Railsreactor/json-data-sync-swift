//
//  JDSKit.h
//  JDSKit
//
//  Created by Igor Reshetnikov on 3/9/16.
//  Copyright © 2016 RailsReactor. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for JDSKit.
FOUNDATION_EXPORT double JDSKitVersionNumber;

//! Project version string for JDSKit.
FOUNDATION_EXPORT const unsigned char JDSKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <JDSKit/PublicHeader.h>


#import <Foundation/Foundation.h>


// ********************* Hack to fix compilation error's regarding to not found ManagedEntity protocol :( ... ********************* //

@protocol ManagedEntity;

// ********************* Hack to fix pod bugs with public headers :( ... ********************** //

@interface SNExceptionWrapper : NSObject

+ (BOOL)tryBlock:(void(^)(void))tryBlock
           error:(NSError **)error;

@end
