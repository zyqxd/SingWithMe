//
//  EZAudioFile.m
//  EZAudio
//
//  Created by Syed Haris Ali on 12/1/13.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "EZAudioFile.h"

#import "EZAudio.h"

#define kEZAudioFileWaveformDefaultResolution (1024)

@interface EZAudioFile (){
    AEFloatConverter            *_floatConverter;
}
@end

@implementation EZAudioFile
@synthesize audioFileDelegate = _audioFileDelegate;
@synthesize waveformResolution = _waveformResolution;

#pragma mark - Initializers
-(EZAudioFile*)initWithURL:(NSURL*)url {
  self = [super init];
  if(self){
    _sourceURL = (__bridge CFURLRef)url;
    [self _configureAudioFile];
  }
  return self;
}

-(EZAudioFile *)initWithURL:(NSURL *)url andDelegate:(id<EZAudioFileDelegate>)delegate {
  self = [self initWithURL:url];
  if(self){
    self.audioFileDelegate = delegate;
  }
  return self;
}

#pragma mark - Class Initializers
+(EZAudioFile*)audioFileWithURL:(NSURL*)url {
  return [[EZAudioFile alloc] initWithURL:url];
}

+(EZAudioFile *)audioFileWithURL:(NSURL *)url andDelegate:(id<EZAudioFileDelegate>)delegate {
  return [[EZAudioFile alloc] initWithURL:url andDelegate:delegate];
}

#pragma mark - Class Methods
+(NSArray *)supportedAudioFileTypes {
  return @[ @"aac",
            @"caf",
            @"aif",
            @"aiff",
            @"aifc",
            @"mp3",
            @"mp4",
            @"m4a",
            @"snd",
            @"au",
            @"sd2",
            @"wav" ];
}

#pragma mark - Private Configuation
-(void)_configureAudioFile {
  
  // Source URL should not be nil
  NSAssert(_sourceURL,@"Source URL was not specified correctly.");
  
  // Try to open the file for reading
  [EZAudio checkResult:ExtAudioFileOpenURL(_sourceURL,&_audioFile)
             operation:"Failed to open audio file for reading"];
  
  // Try pulling the stream description
  UInt32 size = sizeof(_fileFormat);
  [EZAudio checkResult:ExtAudioFileGetProperty(_audioFile,kExtAudioFileProperty_FileDataFormat, &size, &_fileFormat)
             operation:"Failed to get audio stream basic description of input file"];
  
  // Try pulling the total frame size
  size = sizeof(_totalFrames);
  [EZAudio checkResult:ExtAudioFileGetProperty(_audioFile,kExtAudioFileProperty_FileLengthFrames, &size, &_totalFrames)
             operation:"Failed to get total frames of input file"];
  _totalFrames = MAX(1, _totalFrames);
  
  // Total duration
  _totalDuration = _totalFrames / _fileFormat.mSampleRate;
  
  // Set the client format on the stream
  switch (_fileFormat.mChannelsPerFrame) {
    case 1:
      _clientFormat = [EZAudio monoFloatFormatWithSampleRate:_fileFormat.mSampleRate];
      break;
    case 2:
      _clientFormat = [EZAudio stereoFloatInterleavedFormatWithSampleRate:_fileFormat.mSampleRate];
      break;
    default:
      break;
  }
    
  [EZAudio checkResult:ExtAudioFileSetProperty(_audioFile,
                                               kExtAudioFileProperty_ClientDataFormat,
                                               sizeof (AudioStreamBasicDescription),
                                               &_clientFormat)
             operation:"Couldn't set client data format on input ext file"];
  
  // Allocate the float buffers
  _floatConverter = [[AEFloatConverter alloc] initWithSourceFormat:_clientFormat];
  size_t sizeToAllocate = sizeof(float*) * _clientFormat.mChannelsPerFrame;
  sizeToAllocate = MAX(8, sizeToAllocate);
  _floatBuffers   = (float**)malloc( sizeToAllocate );
  UInt32 outputBufferSize = 32 * 1024; // 32 KB
  for ( int i=0; i< _clientFormat.mChannelsPerFrame; i++ ) {
    _floatBuffers[i] = (float*)malloc(outputBufferSize);
  }
  
  // There's no waveform data yet
  _waveformData = NULL;
  
  // Set the default resolution for the waveform data
  _waveformResolution = kEZAudioFileWaveformDefaultResolution;
  
}

#pragma mark - Events
-(void)readFrames:(UInt32)frames
  audioBufferList:(AudioBufferList *)audioBufferList
       bufferSize:(UInt32 *)bufferSize
              eof:(BOOL *)eof {
//  @autoreleasepool {
    // Setup the buffers
//  if( !audioBufferList->mNumberBuffers ){
//#warning MEMORY_LEAK!!! Need a better solution
//  if( audioBufferList->mNumberBuffers != 1 )
//  {
//    UInt32 outputBufferSize = 32 * frames; // 32 KB
//    audioBufferList->mNumberBuffers = 1;
//    audioBufferList->mBuffers[0].mNumberChannels = _clientFormat.mChannelsPerFrame;
//    audioBufferList->mBuffers[0].mDataByteSize = _clientFormat.mChannelsPerFrame*outputBufferSize;
//    audioBufferList->mBuffers[0].mData = (AudioUnitSampleType*)malloc(_clientFormat.mChannelsPerFrame*sizeof(AudioUnitSampleType)*outputBufferSize);
//  }
////  }
  
    [EZAudio checkResult:ExtAudioFileRead(_audioFile,
                                          &frames,
                                          audioBufferList)
               operation:"Failed to read audio data from audio file"];
    *bufferSize = audioBufferList->mBuffers[0].mDataByteSize/sizeof(AudioUnitSampleType);
    *eof = frames == 0;
    _frameIndex += frames;
    if( self.audioFileDelegate ){
      if( [self.audioFileDelegate respondsToSelector:@selector(audioFile:updatedPosition:)] ){
        [self.audioFileDelegate audioFile:self
                          updatedPosition:_frameIndex];
      }
      if( [self.audioFileDelegate respondsToSelector:@selector(audioFile:readAudio:withBufferSize:withNumberOfChannels:)] ){
        AEFloatConverterToFloat(_floatConverter,audioBufferList,_floatBuffers,frames);
        [self.audioFileDelegate audioFile:self
                                readAudio:_floatBuffers
                           withBufferSize:frames
                     withNumberOfChannels:_clientFormat.mChannelsPerFrame];
      }
    }
//  }
}

-(void)seekToFrame:(SInt64)frame {
  [EZAudio checkResult:ExtAudioFileSeek(_audioFile,frame)
             operation:"Failed to seek frame position within audio file"];
  _frameIndex = frame;
  if( self.audioFileDelegate ){
    if( [self.audioFileDelegate respondsToSelector:@selector(audioFile:updatedPosition:)] ){
      [self.audioFileDelegate audioFile:self updatedPosition:_frameIndex];
    }
  }
}

#pragma mark - Getters
-(BOOL)hasLoadedAudioData {
  return _waveformData != NULL;
}

-(void)getWaveformDataWithCompletionBlock:(WaveformDataCompletionBlock)waveformDataCompletionBlock {
  
  SInt64 currentFramePosition = _frameIndex;
  
  if( _waveformData != NULL ){
    waveformDataCompletionBlock( _waveformData, _waveformTotalBuffers );
    return;
  }
  
  _waveformFrameRate    = [self recommendedDrawingFrameRate];
  _waveformTotalBuffers = [self minBuffersWithFrameRate:_waveformFrameRate];
  _waveformData         = (float*)malloc(sizeof(float)*_waveformTotalBuffers);
  
  if( self.totalFrames == 0 ){
    waveformDataCompletionBlock( _waveformData, _waveformTotalBuffers );
    return;
  }
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0ul), ^{
    
    for( int i = 0; i < _waveformTotalBuffers; i++ ){
      
      // Take a snapshot of each buffer through the audio file to form the waveform
      AudioBufferList *bufferList = [EZAudio audioBufferListWithNumberOfFrames:_waveformFrameRate
                                                              numberOfChannels:_clientFormat.mChannelsPerFrame
                                                                   interleaved:YES];
      UInt32 bufferSize;
      BOOL eof;
      
      // Read in the specified number of frames
      [EZAudio checkResult:ExtAudioFileRead(_audioFile,
                                            &_waveformFrameRate,
                                            bufferList)
                 operation:"Failed to read audio data from audio file"];
      bufferSize = bufferList->mBuffers[0].mDataByteSize/sizeof(AudioUnitSampleType);
      bufferSize = MAX(1, bufferSize);
      eof = _waveformFrameRate == 0;
      _frameIndex += _waveformFrameRate;
      
      // Calculate RMS of each buffer
      float rms = [EZAudio RMS:bufferList->mBuffers[0].mData
                        length:bufferSize];
      _waveformData[i] = rms;
      
      // Since we malloc'ed, we should cleanup
      [EZAudio freeBufferList:bufferList];
      
    }
    
    // Seek the audio file back to the beginning
    [EZAudio checkResult:ExtAudioFileSeek(_audioFile,currentFramePosition)
               operation:"Failed to seek frame position within audio file"];
    _frameIndex = currentFramePosition;
    
    // Once we're done send off the waveform data
    dispatch_async(dispatch_get_main_queue(), ^{
      waveformDataCompletionBlock( _waveformData, _waveformTotalBuffers );
    });

  });
  
}

-(AudioStreamBasicDescription)clientFormat {
  return _clientFormat;
}

-(AudioStreamBasicDescription)fileFormat {
  return _fileFormat;
}

-(SInt64)frameIndex {
  return _frameIndex;
}

-(Float32)totalDuration {
  return _totalDuration;
}

-(SInt64)totalFrames {
  return _totalFrames;
}

-(NSURL *)url {
  return (__bridge NSURL*)_sourceURL;
}

#pragma mark - Setters
-(void)setWaveformResolution:(UInt32)waveformResolution {
  if( _waveformResolution != waveformResolution ){
    _waveformResolution = waveformResolution;
    if( _waveformData ){
      free(_waveformData);
      _waveformData = NULL;
    }
  }
}

#pragma mark - Helpers
-(UInt32)minBuffersWithFrameRate:(UInt32)frameRate {
  frameRate = frameRate > 0 ? frameRate : 1;
  UInt32 val = (UInt32) _totalFrames / frameRate + 1;
  return MAX(1, val);
}

-(UInt32)recommendedDrawingFrameRate {
  UInt32 val = 1;
  if(_waveformResolution > 0){
    val = (UInt32) _totalFrames / _waveformResolution;
    if(val > 1)
      --val;
  }
  return MAX(1, val);
}

#pragma mark - Cleanup
-(void)dealloc {
  if( _waveformData ){
    free(_waveformData);
    _waveformData = NULL;
  }
  if( _floatBuffers ){
    free(_floatBuffers);
    _floatBuffers = NULL;
  }
  _frameIndex = 0;
  _waveformFrameRate = 0;
  _waveformTotalBuffers = 0;
  if( _audioFile ){
    [EZAudio checkResult:ExtAudioFileDispose(_audioFile)
               operation:"Failed to dispose of audio file"];
  }
}

#pragma mark - HACK
- (id) getFloatConverter {
    return _floatConverter;
}
@end
