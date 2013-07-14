//
//  NSString+Filename.m
//
//  Created by Ivan Klimchuk on 8/2/12.
//  Copyright (c) 2012 Ivan Klimchuk Inc. All rights reserved.
//

#import "NSString+Filename.h"

@implementation NSString (Filename)

- (NSString *)fullFilenameInDocumentDirectory
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *result = [documentPath stringByAppendingPathComponent:self];
    return result;
}

@end
