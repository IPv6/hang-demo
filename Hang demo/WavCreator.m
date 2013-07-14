//
//  WavCreator.m
//
//  Created by Ivan Klimchuk on 8/2/12.
//  Copyright (c) 2012 Ivan Klimchuk Inc. All rights reserved.
//

#import "WavCreator.h"

typedef struct {
	UInt32 chunkId;
    UInt32 chunkSize;
    UInt32 format;
    UInt32 subchunk1ID;
    UInt32 subchunk1Size;
    UInt16 audioFormat;
    UInt16 numChannels;
    UInt32 sampleRate;
    UInt32 byteRate;
    UInt16 blockAlign;
    UInt16 bitsPerSample;
    UInt32 subchunk2ID;
    UInt32 subchunk2Size;
} WaveHeaderStruct;

@implementation WavCreator

+ (NSData *)createWavFromData:(NSData *)audioData
{
    NSMutableData *result = [[NSMutableData alloc] initWithCapacity:[audioData length]];
    
    // create wav header
    WaveHeaderStruct wav;
    
    wav.subchunk2Size = [audioData length];
    wav.chunkId = 0x46464952; //52494646; //"RIFF"
    wav.chunkSize = wav.subchunk2Size + 36;
    wav.format = 0x45564157; //57415645; //"WAVE"
    wav.subchunk1ID = 0x20746d66; //666d7420; //"fmt "
    wav.subchunk1Size = 16;
    wav.audioFormat = 1; //PCM without compression
    wav.numChannels = 1; //mono
    wav.sampleRate = 44100;
    wav.bitsPerSample = 16;
    wav.byteRate = (wav.sampleRate * wav.numChannels * wav.bitsPerSample)/8;
    wav.blockAlign = (wav.numChannels * wav.bitsPerSample)/8;
    wav.subchunk2ID = 0x61746164; //64617461; //"data"
    
    [result appendBytes:&wav length:sizeof(wav)];
    [result appendData:audioData];
    
    return result;
}

@end
