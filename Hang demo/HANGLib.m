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

    // main processing loop
    for (i = 0; i < length; i++)
    {
        // As long as we have not yet collected enough data just read in
        gInFIFO[gRover] = inDataFloat[i];
        outDataFloat[i] = gOutFIFO[gRover - inFifoLatency];
        gRover++;
        
        // now we have enough data for processing
        if (gRover >= fftFrameSize)
        {
            gRover = inFifoLatency;
            
            // do windowing
            vDSP_vmul(gInFIFO, 1, windowArray, 1, gFFTworksp, 1, fftFrameSize);
            
            // ***************** ANALYSIS *******************
            // do transform

            vDSP_ctoz((DSPComplex*)gFFTworksp, 2, &tempSplitComplex, 1, fftFrameSize2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, fftFrameSizeLog2, kFFTDirection_Forward);

            // compute magnitude and phase
            vDSP_zvabs(&tempSplitComplex, 1, gAnaMagn, 1, fftFrameSize2);
            vDSP_zvphas(&tempSplitComplex, 1, gAnaFreq, 1, fftFrameSize2);

            // this is the analysis step
            for (k = 0; k <= fftFrameSize2; k++)
            {
                phase = gAnaFreq[k];
                
                // compute phase difference
                tmp = phase - gLastPhase[k];
                gLastPhase[k] = (float)phase;
                
                // subtract expected phase difference
                tmp -= (float)k * expct;
                
                // map delta phase into +/- Pi interval
                qpd = (int)(tmp / M_PI);
                if (qpd >= 0) qpd += qpd & 1;
                else qpd -= qpd & 1;
                tmp -= M_PI * (float)qpd;
                
                // get deviation from bin frequency from the +/- Pi interval
                tmp = osamp * tmp / (2.0 * M_PI);
                
                // compute the k-th partials' true frequency
                tmp = (float)k * freqPerBin + tmp * freqPerBin;
                
                // store magnitude and true frequency in analysis arrays
                gAnaMagn[k] = gAnaMagn[k]*2;
                gAnaFreq[k] = (float)tmp;
                
            }
            
            // ***************** PROCESSING *******************
            // this does the actual pitch shifting
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
            
            // ***************** SYNTHESIS *******************
            // this is the synthesis step
            for (k = 0; k <= fftFrameSize2; k++)
            {
                // get magnitude and true frequency from synthesis arrays
                magn = gSynMagn[k];
                tmp = gSynFreq[k];
                
                // subtract bin mid frequency
                tmp -= (float)k * freqPerBin;
                
                // get bin deviation from freq deviation
                tmp /= freqPerBin;
                
                // take osamp into account
                tmp = 2.0 * M_PI * tmp / osamp;
                
                // add the overlap phase advance back in
                tmp += (float)k * expct;
                
                // accumulate delta phase to get bin phase
                gSumPhase[k] += (float)tmp;
                phase = gSumPhase[k];
                
                gFFTworksp[2 * k] = magn;
                gFFTworksp[2 * k + 1] = phase;
            }
            
            // get real and imag parts
            vDSP_rect(gFFTworksp, 2, gFFTworksp, 2, fftFrameSize/2);
            
            // do inverse transform
            vDSP_ctoz((DSPComplex*)gFFTworksp, 2, &tempSplitComplex, 1, fftFrameSize2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, fftFrameSizeLog2, kFFTDirection_Inverse);
            vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp, 2, fftFrameSize2);
            
            // do windowing and add to output accumulator
            for (k = 0; k < fftFrameSize; k++)
            {
                gOutputAccum[k] += (float)(2.0 * windowArray[k] * gFFTworksp[k] / (fftFrameSize2 * osamp));
            }
            for (k = 0; k < stepSize; k++) gOutFIFO[k] = gOutputAccum[k];
            
            // shift accumulator
            memmove(gOutputAccum, gOutputAccum + stepSize, fftFrameSize * sizeof(float));
            
            // move input FIFO
            for (k = 0; k < inFifoLatency; k++) gInFIFO[k] = gInFIFO[k + stepSize];
        }
    }

//---------------------------------------------------------------------------------------
    vDSP_vfix16(outDataFloat, 1, outData, 1, length);
    
    free(outDataFloat);
    free(inDataFloat);
}

-(void) autotuneInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length andFrequencyCorrection:(float (^)(float inFrequency))frequencyCorrection;
{
    float *inDataFloat = malloc(sizeof(float)*length);
    float *outDataFloat = malloc(sizeof(float)*length);
    
    vDSP_vflt16((short *)inData, 1, inDataFloat, 1, length);
    
    if (gRover == 0) gRover = inFifoLatency;
    
    // main processing loop
    for (i = 0; i < length; i++)
    {
        // As long as we have not yet collected enough data just read in
        gInFIFO[gRover] = inDataFloat[i];
        outDataFloat[i] = gOutFIFO[gRover - inFifoLatency];
        gRover++;
        
        // now we have enough data for processing
        if (gRover >= fftFrameSize)
        {
            gRover = inFifoLatency;
            
            // do windowing
            vDSP_vmul(gInFIFO, 1, windowArray, 1, gFFTworksp, 1, fftFrameSize);
            
            // ***************** ANALYSIS *******************
            // do transform
            
            vDSP_ctoz((DSPComplex*)gFFTworksp, 2, &tempSplitComplex, 1, fftFrameSize2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, fftFrameSizeLog2, kFFTDirection_Forward);
            
            // compute magnitude and phase
            vDSP_zvabs(&tempSplitComplex, 1, gAnaMagn, 1, fftFrameSize2);
            vDSP_zvphas(&tempSplitComplex, 1, gAnaFreq, 1, fftFrameSize2);
            
            // this is the analysis step
            int maxFreqIndex = 1;
            float maxFreqAmp = 0;
            float pitchShift = 1.0;

            for (k = 0; k <= fftFrameSize2; k++)
            {
                // get frequency with max amplitude
                if (maxFreqAmp<gAnaMagn[k]) {
                    maxFreqIndex = k;
                    maxFreqAmp = gAnaMagn[k];
                }
                
                phase = gAnaFreq[k];
                
                // compute phase difference
                tmp = phase - gLastPhase[k];
                gLastPhase[k] = (float)phase;
                
                // subtract expected phase difference
                tmp -= (float)k * expct;
                
                // map delta phase into +/- Pi interval
                qpd = (int)(tmp / M_PI);
                if (qpd >= 0) qpd += qpd & 1;
                else qpd -= qpd & 1;
                tmp -= M_PI * (float)qpd;
                
                // get deviation from bin frequency from the +/- Pi interval
                tmp = osamp * tmp / (2.0 * M_PI);
                
                // compute the k-th partials' true frequency
                tmp = (float)k * freqPerBin + tmp * freqPerBin;
                
                // store magnitude and true frequency in analysis arrays
                gAnaMagn[k] = gAnaMagn[k]*2;
                gAnaFreq[k] = (float)tmp;
                
            }
            
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
                pitchShift = frequencyCorrection(freq);
            }
            
            
            // ***************** PROCESSING *******************
            // this does the actual pitch shifting
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
            
            // ***************** SYNTHESIS *******************
            // this is the synthesis step
            for (k = 0; k <= fftFrameSize2; k++)
            {
                // get magnitude and true frequency from synthesis arrays
                magn = gSynMagn[k];
                tmp = gSynFreq[k];
                
                // subtract bin mid frequency
                tmp -= (float)k * freqPerBin;
                
                // get bin deviation from freq deviation
                tmp /= freqPerBin;
                
                // take osamp into account
                tmp = 2.0 * M_PI * tmp / osamp;
                
                // add the overlap phase advance back in
                tmp += (float)k * expct;
                
                // accumulate delta phase to get bin phase
                gSumPhase[k] += (float)tmp;
                phase = gSumPhase[k];
                
                gFFTworksp[2 * k] = magn;
                gFFTworksp[2 * k + 1] = phase;
            }
            
            // get real and imag parts
            vDSP_rect(gFFTworksp, 2, gFFTworksp, 2, fftFrameSize/2);
            
            // do inverse transform
            vDSP_ctoz((DSPComplex*)gFFTworksp, 2, &tempSplitComplex, 1, fftFrameSize2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, fftFrameSizeLog2, kFFTDirection_Inverse);
            vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp, 2, fftFrameSize2);
            
            // do windowing and add to output accumulator
            for (k = 0; k < fftFrameSize; k++)
            {
                gOutputAccum[k] += (float)(2.0 * windowArray[k] * gFFTworksp[k] / (fftFrameSize2 * osamp));
            }
            for (k = 0; k < stepSize; k++) gOutFIFO[k] = gOutputAccum[k];
            
            // shift accumulator
            memmove(gOutputAccum, gOutputAccum + stepSize, fftFrameSize * sizeof(float));
            
            // move input FIFO
            for (k = 0; k < inFifoLatency; k++) gInFIFO[k] = gInFIFO[k + stepSize];
        }
    }
    
    //---------------------------------------------------------------------------------------
    vDSP_vfix16(outDataFloat, 1, outData, 1, length);
    
    free(outDataFloat);
    free(inDataFloat);
}

@end
