//
//  ViewController.h
//  VideoPlayRecord
//
//  Created by Abdul Azeem Khan on 5/9/12.
//  Copyright (c) 2012 DataInvent. All rights reserved.
//  Happy Coding

#import "Novocaine.h"
#import <UIKit/UIKit.h>
#import "AudioFileReader.h"
#import "AudioFileWriter.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController

typedef void (^ assetConversionCallback)(BOOL success);

@property (nonatomic, strong) Novocaine *audioManager;
@property (nonatomic, strong) AudioFileReader *fileReader;
@property (nonatomic, strong) AudioFileWriter *fileWriter;

@end
