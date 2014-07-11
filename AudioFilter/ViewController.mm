#import "NVDSP.h"
#import "ViewController.h"
#import "NVPeakingEQFilter.h"

@implementation ViewController {
    BOOL skipFilter; //to skip filter process
    BOOL playNovocaine; //whether to try novocaine sample or AVFoundation sample
    BOOL writeUsingAssetWriter;//in AVFoundation Sample write using AVAssetWriter or Novocaine's AudioFileWriter
    BOOL writeNovocaineDuringPlay;//in Novocaine Sample write during play call back or use AudioFileWriter's record
    BOOL useNovocaineDataWriteFunction;//whether to use AudioFileWriter's write data or try writing AudioBufferList
    
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
    
    skipFilter = NO;
    playNovocaine = YES;
    writeUsingAssetWriter = YES;
    writeNovocaineDuringPlay = YES;
    useNovocaineDataWriteFunction = YES;
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
    if(playNovocaine) {
        [self playUsingNovocaine];
    }
    else {
        [self playUsingAVFoundation];
    }
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

- (void) applyFilter: (float *)data numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels {
    if(skipFilter) {
        return;
    }
    
    for (int i = 0; i < 10; i++) {
        [PEQ[i] filterData:data numFrames:numFrames numChannels:numChannels];
    }
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
    NSError *error = nil;
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
    
    //output file setup
    NSString *pathComponet = [NSString stringWithFormat:@"soundTrack%d.m4a",trackIndex];
    NSURL *outputUrl = [self getDocumentPathUrlFromStringPathComponent:pathComponet];
    [self removeFileAtUrl:outputUrl];
    
    //set this flag to NO if you want to write to file using AudioFileWriter
    if(writeUsingAssetWriter) {
        [self writeFileUsingAssetWriter:reader readerOutput:readerOutput sampleRate:sampleRate bitDepth:bitDepth numFrames:numFrames numChannels:channels outputFileUrl:outputUrl];
    }
    else {
        [self writeFileUsingAudioFileWriter:reader readerOutput:readerOutput sampleRate:sampleRate numFrames:numFrames numChannels:channels outputFileUrl:outputUrl];
    }
}

- (void) writeFileUsingAudioFileWriter: (AVAssetReader *)reader readerOutput: (AVAssetReaderOutput *)readerOutput sampleRate: (Float64)sampleRate numFrames: (UInt32)numFrames numChannels: (UInt32)channels outputFileUrl: (NSURL *)outputUrl {
    //setUp AudioFileWriter
    self.fileWriter = [[AudioFileWriter alloc]
                       initWithAudioFileURL:outputUrl
                       samplingRate:sampleRate
                       numChannels:channels];
    
    //reading and filtering sample buffer
    while ([reader status] == AVAssetReaderStatusReading) {
        CMSampleBufferRef buffer = [readerOutput copyNextSampleBuffer];
        if (buffer != NULL) {
            CMBlockBufferRef blockBuffer;
            AudioBufferList audioBufferList;
            
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer, NULL, &audioBufferList, sizeof(AudioBufferList), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
            
            CMItemCount totalAudioBuffers = audioBufferList.mNumberBuffers;
            for (CMItemCount i = 0; i < totalAudioBuffers; i++) {
                AudioBuffer *pBuffer = &audioBufferList.mBuffers[i];
                float *pData = (float *)pBuffer->mData;
                //TODO: check error here that causes random crash
                [self applyFilter:pData numFrames:numFrames numChannels:channels];
                
                if(useNovocaineDataWriteFunction) {
                    [self.fileWriter writeNewAudio:pData numFrames:numFrames numChannels:channels];
                }
            }
            
            if(!useNovocaineDataWriteFunction) {
                [self.fileWriter writeNewAudio:audioBufferList numFrames:numFrames];
            }
            
            CMSampleBufferInvalidate(buffer);
            CFRelease(buffer);
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.fileWriter stop];
    });
}

- (void) writeFileUsingAssetWriter: (AVAssetReader *)reader readerOutput: (AVAssetReaderOutput *)readerOutput sampleRate: (Float64)sampleRate bitDepth: (UInt32)bitDepth numFrames: (UInt32)numFrames numChannels: (UInt32)channels outputFileUrl: (NSURL *)outputUrl {
    //settingUp asset writer
    NSError *error = nil;
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
                    //TODO: check error here that causes random crash
                    [self applyFilter:pData numFrames:numFrames numChannels:channels];
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
        if (!wself.fileReader.playing) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.fileWriter pause];
                [wself.fileWriter stop];
                [wself.fileReader stop];
            });
        }
        else {
            [wself.fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
            [wself applyFilter:data numFrames:numFrames numChannels:numChannels];
            [wself.fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
        }
    }];
    
    [wself.fileWriter record];
}

- (void) writeFileInPlayCallback {
    __weak ViewController *wself = self;
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        if (!wself.fileReader.playing) {
            wself.audioManager.outputBlock = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.fileWriter stop];
                [wself.fileReader stop];
                [wself.audioManager pause];
            });
        }
        else {
            [wself.fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
            [wself applyFilter:data numFrames:numFrames numChannels:numChannels];
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
    
    if(writeNovocaineDuringPlay) {
        [self writeFileInPlayCallback];
    }
    else {
        [self writeFileViaRecording];
    }
}

@end