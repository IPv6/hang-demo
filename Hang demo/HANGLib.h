//
//  HANGLib.h
//  Hang demo
//
//  Created by lim on 6/30/13.
//  Copyright (c) 2013 TBK apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

#define FFT_ARR_BITS 11 // Bits for adressing array
#define FFT_ARR_SIZE (1 << FFT_ARR_BITS) // 2^FFT_ARR_BITS
#define FFT_ARR_SIZE_2 (FFT_ARR_SIZE / 2)
#define FFT_ARR_SIZE_2_1 (FFT_ARR_SIZE / 2 + 1)
#define FFT_2_ARR_SIZE (FFT_ARR_SIZE * 2)
#define DEFAULT_SAMPLE_RATE 44100
#define DEFAULT_OSAMP 4


@interface HANGLib : NSObject {
    FFTSetup fftSetup;
    DSPComplex *tempComplex;
    DSPSplitComplex tempSplitComplex;
    
    float *gInFIFO;
    float *gOutFIFO;
    float *gFFTworksp;
    float *gLastPhase;
    float *gSumPhase;
    float *gOutputAccum;
    float *gAnaFreq;
    float *gAnaMagn;
    float *gSynFreq;
    float *gSynMagn;
    int fftFrameSize, fftFrameSize2, fftFrameSizeLog2;
    int osamp, stepSize, inFifoLatency, gRover;
    float freqPerBin, sampleRate, expct;
    
    float magn, phase, tmp, window, real, imag;
    int i, k, qpd, index;
    
    float *windowArray;
}

-(void) fftTest;

-(void) pitchShiftInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length andPitch:(float)pitchShift;
-(void) autotuneInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length andFrequencyCorrection:(float (^)(float inFrequency))frequencyCorrection;

@end
