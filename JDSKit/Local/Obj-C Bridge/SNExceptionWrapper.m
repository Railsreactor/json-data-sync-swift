//
//  SNExceptionWrapper.m
//  JDSKit
//
//  Created by Igor Reshetnikov on 12/1/15.
//  Copyright © 2015 RailsReactor. All rights reserved.
//

#import "JDSKit.h"

@implementation SNExceptionWrapper

+ (BOOL)tryBlock:(void(^)(void))tryBlock
           error:(NSError **)error
{
    @try {
        tryBlock ? tryBlock() : nil;
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.railsreactor.SNExceptionWrapper"
                                         code:0
                                     userInfo:@{NSLocalizedDescriptionKey: exception.name}];
        }
        return NO;
    }
    return YES;
}

@end
