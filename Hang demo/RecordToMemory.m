//
//  RecordToMemory.m
//
//  Created by Ivan Klimchuk on 8/2/12.
//  Copyright (c) 2012 Ivan Klimchuk Inc. All rights reserved.
//

#import "RecordToMemory.h"
#import "AudioCapture.h"

@interface RecordToMemory () <AudioCaptureDelegate>

@property (nonatomic, strong) AudioCapture *audioCapture;
@property (nonatomic, assign) NSUInteger recordedBytes;

@end

@implementation RecordToMemory

#pragma mark Init

- (id) init
{
    self = [super init];
    if (self) {
        self.recording = NO;
        self.recordedBytes = 0;
    }
    return self;
}

#pragma mark FingerSnap interface methods
- (void)startRecord
{
    if (!self.recording) {
        self.recording = YES;
        self.recordedData = nil;
        [self.audioCapture startCapture];
    }
}

- (void)stopRecord
{
    if (self.recording) {
        self.recording = NO;
        [self.audioCapture stopCapture];
//        SInt16 *recData = (SInt16 *)[self.recordedData bytes];
//        recData = &(recData[self.recordedBytes/sizeof(SInt16)]);
    }
}

#pragma mark AudioCaptureDelegate

-(void) processSample:(NSData *)sampleData
{
    size_t dataByteLength = [sampleData length];
    [self.recordedData appendData:sampleData];
    self.recordedBytes = self.recordedBytes + dataByteLength;
//    DLog(@"Length = %zd, Recorded = %zd", dataByteLength, [self.recordedData length]);
}

#pragma mark Lazy loading properties

- (AudioCapture *) audioCapture
{
    if (!_audioCapture) {
        _audioCapture = [[AudioCapture alloc] initWithProcessor:self];
    }
    return _audioCapture;
}

- (NSMutableData *) recordedData
{
    if (!_recordedData) {
        _recordedData = [[NSMutableData alloc] initWithCapacity:(44100*2*15)]; //16 bit mono 44100Hz 15 sec
        DLog(@"%zd", [_recordedData length]);
    }
    return _recordedData;
    
}

@end
