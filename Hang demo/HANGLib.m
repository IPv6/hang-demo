//
//  HANGLib.m
//  Hang demo
//
//  Created by lim on 6/30/13.
//  Copyright (c) 2013 TBK apps. All rights reserved.
//

#import "HANGLib.h"

@interface HANGLib() {
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
    float *tmpPolar, *tmpRect;
    
    float magn, phase, tmp, window, real, imag;
    int i, k, qpd, index;
    
    float *windowArray;
}

@end

@implementation HANGLib

-(id) init
{
    self = [super init];
    if (self) {
        [self setupvDSP];
        [self setupPitchShiftBuffers];
        [self setupWindowArray];
    }
    return self;
}

-(void) dealloc
{
    [self destroyPitchShiftBuffers];
    [self destroyvDSP];
    [self destroyWindowArray];
}

-(void) setupvDSP
{
    fftSetup = vDSP_create_fftsetup(FFT_ARR_BITS, kFFTRadix2);
    tempComplex = calloc(sizeof(DSPComplex), FFT_ARR_SIZE_2);
    tempSplitComplex.realp = calloc(sizeof(float), FFT_ARR_SIZE_2);
    tempSplitComplex.imagp = calloc(sizeof(float), FFT_ARR_SIZE_2);
}

-(void) setupWindowArray
{
    windowArray = malloc(sizeof(float) * fftFrameSize);
    vDSP_hann_window(windowArray, fftFrameSize, vDSP_HANN_DENORM);
}

-(void) destroyWindowArray
{
    free(windowArray);
}

-(void) destroyvDSP
{
    vDSP_destroy_fftsetup(fftSetup);
    free(tempComplex);
    free(tempSplitComplex.realp);
    free(tempSplitComplex.imagp);
}

-(void) setupPitchShiftBuffers
{
    gInFIFO = calloc(sizeof(float), FFT_ARR_SIZE);
    gOutFIFO = calloc(sizeof(float), FFT_ARR_SIZE);
    gFFTworksp = calloc(sizeof(float), FFT_ARR_SIZE);
    gLastPhase = calloc(sizeof(float), FFT_ARR_SIZE_2_1);
    gSumPhase = calloc(sizeof(float), FFT_ARR_SIZE_2_1);
    gOutputAccum = calloc(sizeof(float), FFT_2_ARR_SIZE);
    gAnaFreq = calloc(sizeof(float), FFT_ARR_SIZE);
    gAnaMagn = calloc(sizeof(float), FFT_ARR_SIZE);
    gSynFreq = calloc(sizeof(float), FFT_ARR_SIZE);
    gSynMagn = calloc(sizeof(float), FFT_ARR_SIZE);
    tmpPolar = calloc(sizeof(float), 4);
    tmpRect = calloc(sizeof(float), 4);
    fftFrameSize = FFT_ARR_SIZE;
    fftFrameSize2 = fftFrameSize / 2;
    fftFrameSizeLog2 = FFT_ARR_BITS;
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
    free(tmpRect);      tmpRect = nil;
    free(tmpPolar);     tmpPolar = nil;
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

-(void) generalTransformInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length andFrequencyCorrection:(PitchShiftsStruct (^)(float inFrequency, float position))frequencyCorrection
{
    float *inDataFloat = malloc(sizeof(float)*length);
    float *outDataFloat = malloc(sizeof(float)*length);
    
    vDSP_vflt16((short *)inData, 1, inDataFloat, 1, length);
    
    if (gRover == 0) gRover = inFifoLatency;
    
    for (i = 0; i < length; i++)
    {
        gInFIFO[gRover] = inDataFloat[i];
        outDataFloat[i] = gOutFIFO[gRover - inFifoLatency];
        gRover++;
        
        if (gRover >= fftFrameSize)
        {
            gRover = inFifoLatency;
            vDSP_vmul(gInFIFO, 1, windowArray, 1, gFFTworksp, 1, fftFrameSize);
            vDSP_ctoz((DSPComplex*)gFFTworksp, 2, &tempSplitComplex, 1, fftFrameSize2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, fftFrameSizeLog2, kFFTDirection_Forward);
            vDSP_zvabs(&tempSplitComplex, 1, gAnaMagn, 1, fftFrameSize2);
            vDSP_zvphas(&tempSplitComplex, 1, gAnaFreq, 1, fftFrameSize2);
            int maxFreqIndex = 1;
            float maxFreqAmp = 0;
            float pitchShift = 1.0;
            for (k = 0; k <= fftFrameSize2; k++)
            {
                if (maxFreqAmp<gAnaMagn[k]) {
                    maxFreqIndex = k;
                    maxFreqAmp = gAnaMagn[k];
                }
                phase = gAnaFreq[k];
                tmp = phase - gLastPhase[k] - (float)k * expct;
                gLastPhase[k] = (float)phase;
                qpd = (int)(tmp / M_PI);
                if (qpd >= 0) qpd += qpd & 1;
                else qpd -= qpd & 1;
                tmp = (float)k * freqPerBin + (osamp * (tmp - M_PI * (float)qpd) / (2.0 * M_PI)) * freqPerBin;
                gAnaMagn[k] = gAnaMagn[k]*2;
                gAnaFreq[k] = (float)tmp;
            }
            
            PitchShiftsStruct pitchShifts;
            if ((maxFreqIndex>0)&&(maxFreqIndex<fftFrameSize2)) {
                float magnp = gAnaMagn[maxFreqIndex-1];
                float magnn = gAnaMagn[maxFreqIndex+1];
                float freq = maxFreqIndex;
                if (magnp > magnn) {
                    freq = maxFreqIndex - 1 + (maxFreqAmp / (maxFreqAmp + magnp));
                } else {
                    freq = maxFreqIndex + (magnn / (maxFreqAmp + magnn));
                }
                freq = freq*sampleRate/fftFrameSize;
                pitchShifts = frequencyCorrection(freq, ((float)i) / length);
            }
            
            for (int voice = 0; voice < pitchShifts.voices; voice++) {
                pitchShift = pitchShifts.pitchShifts[voice];
                for (int zero = 0; zero < fftFrameSize; zero++)
                {
                    gSynMagn[zero] = 0;
                    gSynFreq[zero] = 0;
                }
                for (k = 0; k <= fftFrameSize2; k++)
                {
                    index = (int)(k * pitchShift);
                    if (index <= fftFrameSize2)
                    {
                        gSynMagn[index] += gAnaMagn[k];
                        gSynFreq[index] = gAnaFreq[k] * pitchShift;
                    }
                }
                for (k = 0; k <= fftFrameSize2; k++)
                {
                    magn = gSynMagn[k];
                    tmp = 2.0 * M_PI * ((gSynFreq[k] - (float)k * freqPerBin) / freqPerBin) / osamp + (float)k * expct;
                    gSumPhase[k] += (float)tmp;
                    phase = gSumPhase[k];
                    
                    if (voice>0) {
                        tmpPolar[0] = gFFTworksp[2 * k];
                        tmpPolar[1] = gFFTworksp[2 * k+1];
                        tmpPolar[2] = magn;
                        tmpPolar[3] = phase;
                        vDSP_rect(tmpPolar, 2, tmpRect, 2, 2);
                        tmpRect[0] += tmpRect[2];
                        tmpRect[1] += tmpRect[3];
                        vDSP_polar(tmpRect, 2, tmpPolar, 2, 1);
                        gFFTworksp[2 * k] = tmpPolar[0];
                        gFFTworksp[2 * k + 1] = tmpPolar[1];
                    } else {
                        gFFTworksp[2 * k] = magn;
                        gFFTworksp[2 * k + 1] = phase;
                    }
                }
            }
            vDSP_rect(gFFTworksp, 2, gFFTworksp, 2, fftFrameSize/2);
            vDSP_ctoz((DSPComplex*)gFFTworksp, 2, &tempSplitComplex, 1, fftFrameSize2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, fftFrameSizeLog2, kFFTDirection_Inverse);
            vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp, 2, fftFrameSize2);
            for (k = 0; k < fftFrameSize; k++)
            {
                gOutputAccum[k] += (float)(2.0 * windowArray[k] * gFFTworksp[k] / (fftFrameSize2 * osamp));
            }
            for (k = 0; k < stepSize; k++) gOutFIFO[k] = gOutputAccum[k];
            memmove(gOutputAccum, gOutputAccum + stepSize, fftFrameSize * sizeof(float));
            for (k = 0; k < inFifoLatency; k++) gInFIFO[k] = gInFIFO[k + stepSize];
        }
    }
    
    float maxV = 0;
    float minV = 0;
    vDSP_maxv(outDataFloat, 1, &maxV, length);
    vDSP_minv(outDataFloat, 1, &minV, length);
    float maxA = MAX(ABS(maxV), ABS(minV));
    float mulCoef = (1.0 / maxA) * 32767;
    vDSP_vsmul(outDataFloat, 1, &mulCoef, outDataFloat, 1, length);
    vDSP_vfix16(outDataFloat, 1, outData, 1, length);
    free(outDataFloat);
    free(inDataFloat);
}


@end
