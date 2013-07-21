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
    windowArray = calloc(sizeof(float), fftFrameSize);
    for (k = 0; k < fftFrameSize; k++)
    {
        windowArray[k] = -.5 * cosf(2.0 * M_PI * (float)k / (float)fftFrameSize) + .5;
    }
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
    gFFTworksp = calloc(sizeof(float), FFT_2_ARR_SIZE);
    gFFTworksp2 = calloc(sizeof(float), FFT_ARR_SIZE);
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
    free(gFFTworksp2);   gFFTworksp2 = nil;
    free(gFFTworksp);   gFFTworksp = nil;
    free(gOutFIFO);     gOutFIFO = nil;
    free(gInFIFO);      gInFIFO = nil;
}

-(void) fftTest
{
    int length = FFT_ARR_SIZE;
    
    float *inDataFloat = malloc(sizeof(float)*length);
//    float *outDataFloat = malloc(sizeof(float)*length);

    for (int ii = 0; ii < length; ii++) {
        inDataFloat[ii] = sin(ii*M_PI*2/length*20)*2000 + sin(ii*M_PI*2/length*37)*1500 + sin(ii*M_PI*2/length*51)*1000;
    }
    
//    for (int ii = 0; ii < length; ii++) {
//        printf("%d %2.2f \n", ii, inDataFloat[ii]);
//    }
    
    
    for (k = 0; k < fftFrameSize; k++)
    {
        gFFTworksp[2 * k] = (float)(inDataFloat[k]/* * windowArray[k]*/);
        gFFTworksp[2 * k + 1] = 0.0;
        gFFTworksp2[k] = gFFTworksp[2 * k];
    }
    
    /*
    for (int ii = 0; ii < length; ii++) {
        printf("%d %2.6f %2.6f \n", ii, gFFTworksp[ii*2], gFFTworksp[ii*2+1]);
    }
     */
    
    /* ***************** ANALYSIS ******************* */
    /* do transform */
    shortTimeFourierTransform(gFFTworksp, fftFrameSize, -1);
    
    vDSP_ctoz((DSPComplex*)gFFTworksp2, 2, &tempSplitComplex, 1, FFT_ARR_SIZE_2);
    vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, FFT_ARR_BITS, kFFTDirection_Forward);
    vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp2, 2, FFT_ARR_SIZE_2);
    
    for (int ii = 0; ii < length/2; ii++) {
        printf("%d\t%2.2f\t%2.2f\t-\t%2.2f\t%2.2f\n", ii, gFFTworksp[ii*2], gFFTworksp[ii*2+1], gFFTworksp2[ii*2], gFFTworksp2[ii*2+1]);
    }

    printf("\n");
    
    for (int ii = 0; ii < length; ii++) {
        gFFTworksp2[ii] = gFFTworksp[ii];
    }
    
    vDSP_ctoz((DSPComplex*)gFFTworksp2, 2, &tempSplitComplex, 1, FFT_ARR_SIZE_2);
    vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, FFT_ARR_BITS, kFFTDirection_Inverse);
    vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp2, 2, FFT_ARR_SIZE_2);
    
    
    shortTimeFourierTransform(gFFTworksp, fftFrameSize, 1);
    for (int ii = 0; ii < length; ii++) {
        printf("%d\t%2.2f\t%2.2f\t%2.2f\n", ii, gFFTworksp[ii*2]/length, gFFTworksp2[ii]/length, inDataFloat[ii]);
    }
    

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
//            float *gFFTworksp2 = malloc(sizeof(float)*FFT_ARR_SIZE); //------------
            for (k = 0; k < fftFrameSize; k++)
            {
//                gFFTworksp[2 * k] = (float)(gInFIFO[k] * windowArray[k]);
                gFFTworksp2[k] = (float)(gInFIFO[k] * windowArray[k]);
//                gFFTworksp[2 * k + 1] = 0.0;
            }
            
            
            /* ***************** ANALYSIS ******************* */
            /* do transform */
//            shortTimeFourierTransform(gFFTworksp, fftFrameSize, -1);
            vDSP_ctoz((DSPComplex*)gFFTworksp2, 2, &tempSplitComplex, 1, FFT_ARR_SIZE_2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, FFT_ARR_BITS, kFFTDirection_Forward);
            vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp2, 2, FFT_ARR_SIZE_2);
/*
            for (int ii = 0; ii < FFT_ARR_SIZE; ii++) {
                printf("%d\t%6.2f\t%6.2f\n", ii, gFFTworksp[ii], gFFTworksp2[ii]/2);
            }
*/
            /* this is the analysis step */
            for (k = 0; k <= fftFrameSize2; k++)
            {
                /* de-interlace FFT buffer */
                real = gFFTworksp2[2 * k];
                imag = gFFTworksp2[2 * k + 1];
                
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
            
            for (int ii = 0; ii < FFT_ARR_SIZE; ii++) {
                gFFTworksp2[ii] = gFFTworksp[ii];
            }

            /* do inverse transform */
//            shortTimeFourierTransform(gFFTworksp, fftFrameSize, 1);
            vDSP_ctoz((DSPComplex*)gFFTworksp2, 2, &tempSplitComplex, 1, FFT_ARR_SIZE_2);
            vDSP_fft_zrip(fftSetup, &tempSplitComplex, 1, FFT_ARR_BITS, kFFTDirection_Inverse);
            vDSP_ztoc(&tempSplitComplex, 1, (DSPComplex *)gFFTworksp2, 2, FFT_ARR_SIZE_2);
/*
            for (int ii = 0; ii < FFT_ARR_SIZE; ii++) {
                printf("%d\t%6.2f\t%6.2f\n", ii, gFFTworksp[ii * 2], gFFTworksp2[ii]);
            }

            for (int ii = 0; ii < FFT_ARR_SIZE - 1; ii++) {
                printf("%d\t%6.2f\t%6.2f\n", ii, gFFTworksp[ii * 2] - gFFTworksp[ii * 2 + 2], gFFTworksp2[ii] - gFFTworksp2[ii + 1]);
            }
*/
            
            /* do windowing and add to output accumulator */
            for (k = 0; k < fftFrameSize; k++)
            {
//                gOutputAccum[k] += (float)(2.0 * windowArray[k] * gFFTworksp[2 * k] / (fftFrameSize2 * osamp));
                gOutputAccum[k] += (float)(2.0 * windowArray[k] * gFFTworksp2[k] / (fftFrameSize2 * osamp));
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
    memcpy(outData, inData, sizeof(SInt16) * length);
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
