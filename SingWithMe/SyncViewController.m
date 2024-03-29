//
//  SyncViewController.m
//  SingWithMe
//
//  Created by David Zhang on 2014-05-19.
//  Copyright (c) 2014 EzGame. All rights reserved.
//

#import "SyncViewController.h"

@interface SyncViewController ()

@end

@implementation SyncViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    /* Create audio feed plot */
    self.audioPlot.color = [UIColor blueColor];
    self.audioPlot.plotType = EZPlotTypeRolling;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = NO;
    
    /* Create lyrical stack */
    // TODO: Think about making this syllables instead of whole words (easier to listen and tap to)
    [self updateLyricsTextView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) loadSongFromURL:(NSURL *)aURL
{
    [[EZOutput sharedOutput] stopPlayback];
    
    self.songFile = [EZAudioFile audioFileWithURL:aURL andDelegate:self];
    
    [[EZOutput sharedOutput] setAudioStreamBasicDescription:self.songFile.clientFormat];
}

- (IBAction)start:(id)sender
{
    [self loadSongFromURL:self.songURL];
    
    [EZOutput sharedOutput].outputDataSource = self;
    [[EZOutput sharedOutput] startPlayback];
    
    self.pauseButton.hidden = NO;
    self.startButton.hidden = YES;
}

- (IBAction)pause:(id)sender
{
    if( ![[EZOutput sharedOutput] isPlaying] ){
        [EZOutput sharedOutput].outputDataSource = self;
        [[EZOutput sharedOutput] startPlayback];
    } else {
        [EZOutput sharedOutput].outputDataSource = nil;
        [[EZOutput sharedOutput] stopPlayback];
    }
}

- (IBAction)tapGesture:(id)sender
{
    if ( [[EZOutput sharedOutput] isPlaying] ) {
        NSRange spaceRange = [self.lyrics rangeOfString:@" "];
        NSRange newlineRange = [self.lyrics rangeOfString:@"\n"];
        NSRange replaceRange = (spaceRange.location < newlineRange.location) ? spaceRange : newlineRange;
        if (replaceRange.location != NSNotFound){
            replaceRange.length = replaceRange.location + 1;
            replaceRange.location = 0;
            self.lyrics = [self.lyrics stringByReplacingCharactersInRange:replaceRange withString:@""];
        }
        [self updateLyricsTextView];
    }
}

- (void) updateLyricsTextView
{
    self.lyricsTextView.text = self.lyrics;
}

#pragma mark - EZAudioFileDelegate
- (void) audioFile:(EZAudioFile *)audioFile readAudio:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels
{
    /* GCD block to send buffer data into plot */
    dispatch_async(dispatch_get_main_queue(), ^{
        if( [EZOutput sharedOutput].isPlaying ){
            [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
        }
    });
}

- (void) audioFile:(EZAudioFile *)audioFile
   updatedPosition:(SInt64)framePosition
{
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        if( !self.framePositionSlider.touchInside ){
    //            self.framePositionSlider.value = (float)framePosition;
    //        }
    //    });
}

#pragma mark - EZOutputDataSource
- (void) output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames
{
    if( self.songFile ) {
        UInt32 bufferSize;
        BOOL eof;
        [self.songFile readFrames:frames
                  audioBufferList:audioBufferList
                       bufferSize:&bufferSize
                              eof:&eof];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
