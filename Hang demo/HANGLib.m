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

//---------------------------------------------------------------------------------------
//    memcpy(outDataFloat, inDataFloat, sizeof(float)*length); // Just testing
    
    
    /* main processing loop */
    for (i = 0; i < length; i++)
    {
        
        /* As long as we have not yet collected enough data just read in */
        gInFIFO[gRover] = inDataFloat[i];
        outDataFloat[i] = gOutFIFO[gRover - inFifoLatency];
        gRover++;
        
        /* now we have enough data for processing */
        if (gRover >= fftFrameSize)
        {
            gRover = inFifoLatency;
            
            /* do windowing and re,im interleave */
            for (k = 0; k < fftFrameSize; k++)
            {
                window = -.5 * cosf(2.0 * M_PI * (float)k / (float)fftFrameSize) + .5;
                gFFTworksp[2 * k] = (float)(gInFIFO[k] * window);
                gFFTworksp[2 * k + 1] = 0.0;
            }
            
            
            /* ***************** ANALYSIS ******************* */
            /* do transform */
            shortTimeFourierTransform(gFFTworksp, fftFrameSize, -1);
            
            /* this is the analysis step */
            for (k = 0; k <= fftFrameSize2; k++)
            {
                
                /* de-interlace FFT buffer */
                real = gFFTworksp[2 * k];
                imag = gFFTworksp[2 * k + 1];
                
                /* compute magnitude and phase */
                magn = 2.0 * sqrtf(real * real + imag * imag);
                phase = atan2f(imag, real);
                
                /* compute phase difference */
                tmp = phase - gLastPhase[k];
                gLastPhase[k] = (float)phase;
                
                /* subtract expected phase difference */
                tmp -= (float)k * expct;
                
                /* map delta phase into +/- Pi interval */
                qpd = (int)(tmp / M_PI);
                if (qpd >= 0) qpd += qpd & 1;
                else qpd -= qpd & 1;
                tmp -= M_PI * (float)qpd;
                
                /* get deviation from bin frequency from the +/- Pi interval */
                tmp = osamp * tmp / (2.0 * M_PI);
                
                /* compute the k-th partials' true frequency */
                tmp = (float)k * freqPerBin + tmp * freqPerBin;
                
                /* store magnitude and true frequency in analysis arrays */
                gAnaMagn[k] = (float)magn;
                gAnaFreq[k] = (float)tmp;
                
            }
            
            /* ***************** PROCESSING ******************* */
            /* this does the actual pitch shifting */
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
            
            /* ***************** SYNTHESIS ******************* */
            /* this is the synthesis step */
            for (k = 0; k <= fftFrameSize2; k++)
            {
                
                /* get magnitude and true frequency from synthesis arrays */
                magn = gSynMagn[k];
                tmp = gSynFreq[k];
                
                /* subtract bin mid frequency */
                tmp -= (float)k * freqPerBin;
                
                /* get bin deviation from freq deviation */
                tmp /= freqPerBin;
                
                /* take osamp into account */
                tmp = 2.0 * M_PI * tmp / osamp;
                
                /* add the overlap phase advance back in */
                tmp += (float)k * expct;
                
                /* accumulate delta phase to get bin phase */
                gSumPhase[k] += (float)tmp;
                phase = gSumPhase[k];
                
                /* get real and imag part and re-interleave */
                gFFTworksp[2 * k] = (float)(magn * cosf(phase));
                gFFTworksp[2 * k + 1] = (float)(magn * sinf(phase));
            }
            
            /* zero negative frequencies */
            for (k = fftFrameSize + 2; k < 2 * fftFrameSize; k++) gFFTworksp[k] = 0.0;
            
            /* do inverse transform */
            shortTimeFourierTransform(gFFTworksp, fftFrameSize, 1);
            
            /* do windowing and add to output accumulator */
            for (k = 0; k < fftFrameSize; k++)
            {
                window = -.5 * cosf(2.0 * M_PI * (float)k / (float)fftFrameSize) + .5;
                gOutputAccum[k] += (float)(2.0 * window * gFFTworksp[2 * k] / (fftFrameSize2 * osamp));
            }
            for (k = 0; k < stepSize; k++) gOutFIFO[k] = gOutputAccum[k];
            
            /* shift accumulator */
            //memmove(gOutputAccum, gOutputAccum + stepSize, fftFrameSize * sizeof(float));
            for (k = 0; k < fftFrameSize; k++)
            {
                gOutputAccum[k] = gOutputAccum[k + stepSize];
            }
            
            /* move input FIFO */
            for (k = 0; k < inFifoLatency; k++) gInFIFO[k] = gInFIFO[k + stepSize];
        }
    }

    
//---------------------------------------------------------------------------------------
    
    vDSP_vfix16(outDataFloat, 1, outData, 1, length);
    
    free(outDataFloat);
    free(inDataFloat);
}

-(void) autotuneInAudiodata:(SInt16 *)inData toOutAudiodata:(SInt16 *)outData withLength:(int)length
{
    
}




void shortTimeFourierTransform(float *fftBuffer, int fftFrameSize, int sign)
{
    float wr, wi, arg, temp;
    float tr, ti, ur, ui;
    int i, bitm, j, le, le2, k;
    
    for (i = 2; i < 2 * fftFrameSize - 2; i += 2)
    {
        for (bitm = 2, j = 0; bitm < 2 * fftFrameSize; bitm <<= 1)
        {
            if ((i & bitm) != 0) j++;
            j = j << 1;
        }
        if (i < j)
        {
            temp = fftBuffer[i];
            fftBuffer[i] = fftBuffer[j];
            fftBuffer[j] = temp;
            temp = fftBuffer[i + 1];
            fftBuffer[i + 1] = fftBuffer[j + 1];
            fftBuffer[j + 1] = temp;
        }
    }
    int max = (int)(log2f(fftFrameSize) + .5);
    for (k = 0, le = 2; k < max; k++)
    {
        le = le << 1;
        le2 = le >> 1;
        ur = 1.0;
        ui = 0.0;
        arg = M_PI / (le2 >> 1);
        wr = cosf(arg);
        wi = sign * sinf(arg);
        for (j = 0; j < le2; j += 2)
        {
            
            for (i = j; i < 2 * fftFrameSize; i += le)
            {
                tr = fftBuffer[i + le2] * ur - fftBuffer[i + le2 + 1] * ui;
                ti = fftBuffer[i + le2] * ui + fftBuffer[i + le2 + 1] * ur;
                fftBuffer[i + le2] = fftBuffer[i] - tr;
                fftBuffer[i + le2 + 1] = fftBuffer[i + 1] - ti;
                fftBuffer[i] += tr;
                fftBuffer[i + 1] += ti;
                
            }
            tr = ur * wr - ui * wi;
            ui = ur * wi + ui * wr;
            ur = tr;
        }
    }
    //    printf(".");
}


@end
