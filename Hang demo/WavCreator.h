//
//  WavCreator.h
//
//  Created by Ivan Klimchuk on 8/2/12.
//  Copyright (c) 2012 Ivan Klimchuk Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WavCreator : NSObject

+ (NSData *)createWavFromData:(NSData *)audioData;
+ (NSData *)createDataFromWav:(NSData *)wavAudioData;

@end
