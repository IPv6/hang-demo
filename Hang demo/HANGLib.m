//
//  HANGLib.m
//  Hang demo
//
//  Created by lim on 6/30/13.
//  Copyright (c) 2013 TBK apps. All rights reserved.
//

#import "HANGLib.h"

@interface HANGLib()

@end

@implementation HANGLib

-(id) init
{
    self = [super init];
    if (self) {
        [self setupvDSP];
        [self setupPitchShiftBuffers];
    }
    return self;
}

-(void) dealloc
{
    [self destroyPitchShiftBuffers];
    [self destroyvDSP];
}

-(void) setupvDSP
{
    fftSetup = vDSP_create_fftsetup(FFT_ARR_BITS, kFFTRadix2);
}

-(void) destroyvDSP
{
    vDSP_destroy_fftsetup(fftSetup);
}

-(void) setupPitchShiftBuffers
{
    gInFIFO = calloc(sizeof(float), FFT_ARR_SIZE);
    gOutFIFO = calloc(sizeof(float), FFT_ARR_SIZE);
    gFFTworksp = calloc(sizeof(float), FFT_2_ARR_SIZE);
    gLastPhase = calloc(sizeof(float), FFT_ARR_SIZE_2_1);
    gSumPhase = calloc(sizeof(float), FFT_ARR_SIZE_2_1);
    gOutputAccum = calloc(sizeof(float), FFT_2_ARR_SIZE);
    gAnaFreq = calloc(sizeof(float), FFT_ARR_SIZE);
    gAnaMagn = calloc(sizeof(float), FFT_ARR_SIZE);
    gSynFreq = calloc(sizeof(float), FFT_ARR_SIZE);
    gSynMagn = calloc(sizeof(float), FFT_ARR_SIZE);
    fftFrameSize = FFT_ARR_SIZE;
    fftFrameSize2 = fftFrameSize / 2;
    osamp = DEFAULT_OSAMP;
    sampleRate = DEFAULT_SAMPLE_RATE;
    stepSize = fftFrameSize / osamp;
    freqPerBin = sampleRate / (float)fftFrameSize;
    expct = 2.0 * M_PI * (float)stepSize / (float)fftFrameSize;
    inFifoLatency = fftFrameSize - stepSize;

    gRover = 0;
}

-(void) destroyPitchShiftBuffers
{
    free(gSynMagn);     gSynMagn = nil;
    free(gSynFreq);     gSynFreq = nil;
    free(gAnaMagn);     gAnaMagn = nil;
    free(gAnaFreq);     gAnaFreq = nil;
    free(gOutputAccum); gOutputAccum = nil;
    free(gSumPhase);    gSumPhase = nil;
    free(gLastPhase);   gLastPhase = nil;
    free(gFFTworksp);   gFFTworksp = nil;
    free(gOutFIFO);     gOutFIFO = nil;
    free(gInFIFO);      gInFIFO = nil;
}

-(void) pitchShiftInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length andPitch:(float)pitchShift
{
    float *inDataFloat = malloc(sizeof(float)*length);
    float *outDataFloat = malloc(sizeof(float)*length);
    
    vDSP_vflt16((short *)inData, 1, inDataFloat, 1, length);
    
    
    
    if (gRover == 0) gRover = inFifoLatency;

    
    memcpy(outDataFloat, inDataFloat, sizeof(float)*length); // Just testing
    
    vDSP_vfix16(outDataFloat, 1, outData, 1, length);
    
    free(outDataFloat);
    free(inDataFloat);
}

-(void) autotuneInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length
{
    
}


@end
