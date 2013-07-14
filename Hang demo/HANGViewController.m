//
//  HANGViewController.m
//  Hang demo
//
//  Created by lim on 6/30/13.
//  Copyright (c) 2013 TBK apps. All rights reserved.
//

#import "HANGViewController.h"
#import "HANGLib.h"
#import "RecordToMemory.h"
#import "WavCreator.h"
#import "NSString+Filename.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

#define RECORDED_FILENAME @"recordedSound.wav"

@interface HANGViewController ()

@property (nonatomic, strong) RecordToMemory *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) HANGLib *hangLib;

@end

@implementation HANGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordButtonPressed:(id)sender
{
    [self.recorder startRecord];
}

- (IBAction)stopButtonPressed:(id)sender
{
    [self.recorder stopRecord];
    NSData *wavData = [WavCreator createWavFromData:self.recorder.recordedData];
    [wavData writeToFile:[RECORDED_FILENAME fullFilenameInDocumentDirectory] atomically:YES];
}

- (IBAction)playButtonPressed:(id)sender
{
    NSData *wavAudioData = nil;
    if (self.recorder.recordedData.length) {
        wavAudioData = [WavCreator createWavFromData:self.recorder.recordedData];
    } else {
        wavAudioData = [NSData dataWithContentsOfFile:[RECORDED_FILENAME fullFilenameInDocumentDirectory]];
    }

    [self playWavAudioData:wavAudioData];
}

- (IBAction)pitchShiftUpButtonPressed:(id)sender
{
    NSData *outputData = [self morphAudioData:[self audioData] withBlock:^(SInt16 *input, SInt16 *output, int length) {
        [self.hangLib pitchShiftInAudiodata:input toOutAudiodata:output withLength:length andPitch:4.0/3.0];
    }];
    NSData *wavAudioData = [WavCreator createWavFromData:outputData];
    [self playWavAudioData:wavAudioData];
}

- (IBAction)pitchShiftDownButtonPressed:(id)sender
{
    NSData *outputData = [self morphAudioData:[self audioData] withBlock:^(SInt16 *input, SInt16 *output, int length) {
        [self.hangLib pitchShiftInAudiodata:input toOutAudiodata:output withLength:length andPitch:3.0/4.0];
    }];
    NSData *wavAudioData = [WavCreator createWavFromData:outputData];
    [self playWavAudioData:wavAudioData];
}

- (IBAction)autotunePressed:(id)sender
{
    NSData *outputData = [self morphAudioData:[self audioData] withBlock:^(SInt16 *input, SInt16 *output, int length) {
        [self.hangLib autotuneInAudiodata:input toOutAudiodata:output withLength:length];
    }];
    NSData *wavAudioData = [WavCreator createWavFromData:outputData];
    [self playWavAudioData:wavAudioData];
}

-(NSData *)morphAudioData:(NSData *)inputData withBlock:(void (^)(SInt16 *input, SInt16 *output, int length))morphBlock
{
    int length = inputData.length/sizeof(SInt16);
    SInt16 *input = (SInt16 *)[inputData bytes];
    NSMutableData *outputData = [NSMutableData data];
    [outputData setLength:[inputData length]];
    SInt16 *output = (SInt16 *)[outputData mutableBytes];
    morphBlock(input, output, length);
    return outputData;
}

- (void)playWavAudioData:(NSData *)wavAudioData
{
    NSError *error = nil;
    self.player = [[AVAudioPlayer alloc] initWithData:wavAudioData error:&error];
    if (error) {
        DLog(@"%@", error);
    } else {
        [self.player prepareToPlay];
        [self.player play];
    }
}

- (NSData *)audioData
{
    NSData *result = nil;
    if (self.recorder.recordedData.length) {
        result = [NSData dataWithData:self.recorder.recordedData];
    } else {
        result = [WavCreator createDataFromWav:[NSData dataWithContentsOfFile:[RECORDED_FILENAME fullFilenameInDocumentDirectory]]];
    }
    return result;
}

#pragma mark Lazy loadings

- (RecordToMemory *)recorder
{
    if (!_recorder) {
        _recorder = [[RecordToMemory alloc] init];
    }
    return _recorder;
}

- (HANGLib *)hangLib
{
    if (!_hangLib) {
        _hangLib = [[HANGLib alloc] init];
    }
    return _hangLib;
}

@end
