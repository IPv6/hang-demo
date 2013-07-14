//
//  HANGViewController.m
//  Hang demo
//
//  Created by lim on 6/30/13.
//  Copyright (c) 2013 TBK apps. All rights reserved.
//

#import "HANGViewController.h"
#import "RecordToMemory.h"
#import "WavCreator.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface HANGViewController ()

@property (nonatomic, strong) RecordToMemory *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;

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
}

- (IBAction)playButtonPressed:(id)sender
{
    if (self.recorder.recordedData.length) {
        NSData *audioData = [WavCreator createWavFromData:self.recorder.recordedData];
        NSError *error = nil;
        self.player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
        if (error) {
            DLog(@"%@", error);
        } else {
            [self.player prepareToPlay];
            [self.player play];
        }
    }
}

- (IBAction)pitchShiftUpButtonPressed:(id)sender
{
    
}

- (IBAction)pitchShiftDownButtonPressed:(id)sender
{
    
}

- (IBAction)autotunePressed:(id)sender
{
    
}

#pragma mark Lazy loadings

- (RecordToMemory *)recorder
{
    if (!_recorder) {
        _recorder = [[RecordToMemory alloc] init];
    }
    return _recorder;
}

@end
