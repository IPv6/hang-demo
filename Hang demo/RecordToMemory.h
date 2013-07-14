//
//  RecordToMemory.h
//
//  Created by Ivan Klimchuk on 8/2/12.
//  Copyright (c) 2012 Ivan Klimchuk Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RecordToMemory : NSObject

@property (nonatomic, assign) BOOL recording;
@property (nonatomic, strong) NSMutableData *recordedData;

- (void)startRecord;
- (void)stopRecord;

@end
