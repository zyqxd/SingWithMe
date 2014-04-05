//
//  ViewController.h
//  SingWithMe
//
//  Created by David Zhang on 2014-04-05.
//  Copyright (c) 2014 EzGame. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <MPMediaPickerControllerDelegate>

@property (strong, nonatomic)       AVAudioPlayer *audioPlayer;
@property (weak, nonatomic)     IBOutlet UIButton *playButton;
@property (weak, nonatomic)      IBOutlet UILabel *playLabel;

- (IBAction)playButtonTouch:(id)sender;
@end
