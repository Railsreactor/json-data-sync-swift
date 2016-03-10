//
//  SNExceptionWrapper.h
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/1/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//


#import <Foundation/Foundation.h>

@interface SNExceptionWrapper : NSObject

+ (BOOL)tryBlock:(void(^)())tryBlock
           error:(NSError **)error;

@end