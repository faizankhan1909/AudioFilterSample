#import "NVDSP.h"
#import "ViewController.h"
#import "NVPeakingEQFilter.h"

@implementation ViewController {
    NVPeakingEQFilter *PEQ[10];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - setup Methods
- (void) setUpEqualizerWithSamplingRate: (float)sampleRate {
    //TODO: clean up PEQ in case more than 1 audioTrack causes re-calling of this method
    //equalizer variables
    float initialGain = 12;
    float centerFrequencies[10];
    
    //define center frequencies of the bands
    centerFrequencies[0] = 32.0f;
    centerFrequencies[1] = 64.0f;
    centerFrequencies[2] = 128.0f;
    centerFrequencies[3] = 256.0f;
    centerFrequencies[4] = 512.0f;
    centerFrequencies[5] = 1000.0f;
    centerFrequencies[6] = 2000.0f;
    centerFrequencies[7] = 4000.0f;
    centerFrequencies[8] = 8000.0f;
    centerFrequencies[9] = 16000.0f;
    
    //audio filter set-up
    for (int i = 0; i < 10; i++) {
        PEQ[i] = [[NVPeakingEQFilter alloc] initWithSamplingRate:sampleRate];
        PEQ[i].Q = 2.0f;
        PEQ[i].centerFrequency = centerFrequencies[i];
        PEQ[i].G = initialGain;
    }
}

#pragma mark - button Event
- (IBAction)PlayVideo:(id)sender {
    [self playUsingAVFoundation];
}

#pragma mark - helper methods
- (BOOL) removeFileAtUrl: (NSURL *)fileUrl {
    BOOL success = NO;
    NSError *error = nil;
    
    NSString *filePathString = [fileUrl path];
    if ([[NSFileManager defaultManager] isDeletableFileAtPath: filePathString]) {
        success = [[NSFileManager defaultManager] removeItemAtPath:filePathString error:&error];
        if (!success) {
            NSLog(@"Error removing file at path: %@", error.localizedDescription);
        }
    }
    
    return success;
}

- (NSURL *) getDocumentPathUrlFromStringPathComponent: (NSString *)pathComponent {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *outputPathString = [documentsDirectory stringByAppendingPathComponent:pathComponent];
    NSURL *outUrl = [NSURL fileURLWithPath:outputPathString];
    
    return outUrl;
}

- (void) exportAssetToM4a: (AVAsset *)avAsset atOutputURL:(NSURL *)outputUrl withCallbackBlock:(assetConversionCallback) callbackBlock  {
    [self removeFileAtUrl:outputUrl];
    
    __block BOOL success = NO;
    AVAssetExportSession *assetsession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetAppleM4A];
    
    assetsession.outputURL = outputUrl;
    assetsession.outputFileType = AVFileTypeAppleM4A;
    
    [assetsession exportAsynchronouslyWithCompletionHandler:^{
        if(assetsession.status == AVAssetExportSessionStatusCompleted) {
            success = YES;
        }
        callbackBlock(success);
    }];
}

#pragma mark - AVFoundationMethods
- (void) playUsingAVFoundation {
    //setting up asset
    NSURL *inputUrl = [[NSBundle mainBundle] URLForResource:@"intro" withExtension:@"mp4"];
    AVAsset *anAsset = [AVAsset assetWithURL:inputUrl];
    
    NSArray *audioTracks = [anAsset tracksWithMediaType:AVMediaTypeAudio];
    
    int totalTracks = [audioTracks count];
    for (int i=0 ; i<totalTracks; i++) {
        AVAssetTrack *audioTrack = [audioTracks objectAtIndex:0];
        [self applyFilterToAudioTrack:audioTrack trackId:i fromAsset:anAsset];
    }
}

- (NSDictionary *) getAssetReaderSettings: (Float64)sampleRate bitDepth: (UInt32)bitDepth {
    NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                   [NSNumber numberWithFloat:(float)sampleRate], AVSampleRateKey,
                                   [NSNumber numberWithInt:bitDepth], AVLinearPCMBitDepthKey,
                                   [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                   [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                   [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey, nil];
    
    return audioSettings;
}

- (NSDictionary *) getAssetWriterSettings: (Float64)sampleRate bitDepth: (UInt32)bitDepth numChannels: (UInt32)numChannels {
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                     [NSNumber numberWithInt: kAudioFormatAppleLossless],AVFormatIDKey,
                     [NSNumber numberWithFloat:sampleRate],AVSampleRateKey,
                     [NSData dataWithBytes: &acl length: sizeof( AudioChannelLayout ) ], AVChannelLayoutKey,
                     [NSNumber numberWithInt:numChannels],AVNumberOfChannelsKey,
                     [NSNumber numberWithInt:bitDepth],AVEncoderBitDepthHintKey,
                     nil];
    
    return audioSettings;
}

- (void) applyFilterToAudioTrack: (AVAssetTrack *)audioTrack trackId: (int)trackIndex fromAsset: (AVAsset *)anAsset  {
    NSError *error;
    NSArray *formatDesc = [audioTrack formatDescriptions];
    CMAudioFormatDescriptionRef formatDescriptionRef = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:0];
    
    //format description meta
    const AudioStreamBasicDescription *fileDescription = CMAudioFormatDescriptionGetStreamBasicDescription (formatDescriptionRef);
    
    Float64 sampleRate = fileDescription->mSampleRate;
    UInt32 channels = fileDescription->mChannelsPerFrame;
    UInt32 numFrames = fileDescription->mFramesPerPacket;
    UInt32 bitDepth = fileDescription->mBitsPerChannel == 0 ? 16 : fileDescription->mBitsPerChannel;
    
    //setUp Equalizer
    [self setUpEqualizerWithSamplingRate:sampleRate];
    
    //setting up Avasset reader
    NSDictionary *readerSettings = [self getAssetReaderSettings:sampleRate bitDepth:bitDepth];
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:anAsset error:&error];
    AVAssetReaderTrackOutput *readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:readerSettings];
    
    [reader addOutput:readerOutput];
    [reader startReading];
    
    //settingUp asset writer
    NSString *pathComponet = [NSString stringWithFormat:@"soundTrack%d",trackIndex];
    NSURL *outputUrl = [self getDocumentPathUrlFromStringPathComponent:pathComponet];
    [self removeFileAtUrl:outputUrl];
    
    NSDictionary *audioOutputSettings = [self getAssetWriterSettings:sampleRate bitDepth:bitDepth numChannels:channels];
    AVAssetWriter *assetWriter = [[AVAssetWriter alloc] initWithURL:outputUrl fileType:AVFileTypeAppleM4A error:&error];
    AVAssetWriterInput *assetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    [assetWriter addInput:assetWriterInput];
    
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    //reading and appending sample buffer
    [assetWriterInput requestMediaDataWhenReadyOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) usingBlock:^{
        while ([assetWriterInput isReadyForMoreMediaData]) {
            CMSampleBufferRef buffer = [readerOutput copyNextSampleBuffer];
            if (buffer != NULL) {
                CMBlockBufferRef blockBuffer;
                AudioBufferList audioBufferList;
                
                CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer, NULL, &audioBufferList, sizeof(AudioBufferList), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
                
                CMItemCount totalAudioBuffers = audioBufferList.mNumberBuffers;
                for (CMItemCount i = 0; i < totalAudioBuffers; i++) {
                    AudioBuffer *pBuffer = &audioBufferList.mBuffers[i];
                    float *pData = (float *)pBuffer->mData;
                    // apply the filter
                    for (int i = 0; i < 10; i++) {
                        //TODO: check error here that causes random crash
                        [PEQ[i] filterData:pData numFrames:numFrames numChannels:channels];
                    }
                }
                
                [assetWriterInput appendSampleBuffer:buffer];
                CMSampleBufferInvalidate(buffer);
                CFRelease(buffer);
            }
            else if ([reader status] != AVAssetReaderStatusReading) {
                //close asset writer stream
                dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                    [assetWriterInput markAsFinished];
                    [assetWriter finishWritingWithCompletionHandler:^{
                        NSLog(@"finished writing asset");
                    }];
                });
                break;
            }
        }
    }];
}

#pragma mark - Novocaine Methods
- (void) playUsingNovocaine {
    self.audioManager = [Novocaine audioManager];
    [self setUpEqualizerWithSamplingRate:self.audioManager.samplingRate];
    
    //setting up asset
    NSURL *myMovieURL = [[NSBundle mainBundle] URLForResource:@"intro" withExtension:@"mp4"];
    AVAsset *avMovieAsset = [AVAsset assetWithURL:myMovieURL];
    
    //export asset to m4a
    NSURL *outputUrl = [self getDocumentPathUrlFromStringPathComponent:@"/videoSoundOrg.m4a"];
    [self exportAssetToM4a:avMovieAsset atOutputURL:outputUrl withCallbackBlock:^(BOOL success) {
        [self onConversionCallback:success convertedFileUrl:outputUrl];
    }];
}

- (void) writeFileViaRecording {
    __weak ViewController *wself = self;
    
    [wself.fileWriter setWriterBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        [wself.fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
        if (!wself.fileReader.playing) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.fileWriter pause];
                [wself.fileWriter stop];
                [wself.fileReader stop];
            });
        }
        else {
            for (int i = 0; i < 10; i++) {
                [PEQ[i] filterData:data numFrames:numFrames numChannels:numChannels];
            }
            [wself.fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
        }
    }];
    
    [wself.fileWriter record];
}

- (void) writeFileInPlayCallback {
    __weak ViewController *wself = self;
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        [wself.fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
        if (!wself.fileReader.playing) {
            wself.audioManager.outputBlock = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.fileWriter stop];
                [wself.fileReader stop];
                [wself.audioManager pause];
            });
        }
        else {
            for (int i = 0; i < 10; i++) {
                [PEQ[i] filterData:data numFrames:numFrames numChannels:numChannels];
            }
            [wself.fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
        }
    }];
    
    [self.audioManager play];
}

- (void) onConversionCallback: (BOOL)success convertedFileUrl: (NSURL *)fileUrl {
    if(success) {
        NSURL *outputUrl = [self getDocumentPathUrlFromStringPathComponent:@"/videoSoundAlt.m4a"];
        [self removeFileAtUrl:outputUrl];
        [self applyFilterToAudioFileWithUrl:fileUrl atOutputUrl:outputUrl];
    }
}

- (void) applyFilterToAudioFileWithUrl: (NSURL *)audioFileUrl atOutputUrl: (NSURL *)outputUrl {
    self.fileReader = [[AudioFileReader alloc]
                       initWithAudioFileURL:audioFileUrl
                       samplingRate:_audioManager.samplingRate
                       numChannels:_audioManager.numOutputChannels];
    
    [self.fileReader play];
    
    self.fileWriter = [[AudioFileWriter alloc]
                       initWithAudioFileURL:outputUrl
                       samplingRate:self.audioManager.samplingRate
                       numChannels:self.audioManager.numInputChannels];
    
    //set the following flag to NO if you just want to write file without playing audio
    BOOL shouldPlaySoundDuringWriting = YES;
    if(shouldPlaySoundDuringWriting) {
        [self writeFileInPlayCallback];
    }
    else {
        [self writeFileViaRecording];
    }
}

@end