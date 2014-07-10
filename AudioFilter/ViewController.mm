#import "NVDSP.h"
#import "ViewController.h"
#import "NVHighpassFilter.h"
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
    
    self.audioManager = [Novocaine audioManager];
    [self setUpEqualizer];
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
- (void) setUpEqualizer {
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
        PEQ[i] = [[NVPeakingEQFilter alloc] initWithSamplingRate:self.audioManager.samplingRate];
        PEQ[i].Q = 2.0f;
        PEQ[i].centerFrequency = centerFrequencies[i];
        PEQ[i].G = initialGain;
    }
}

#pragma mark - button Event
- (IBAction)PlayVideo:(id)sender {
    [self playUsingNovocaine];
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

#pragma mark - Novocaine Methods
- (void) playUsingNovocaine {
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

- (void) onConversionCallback: (BOOL) success convertedFileUrl: (NSURL *) fileUrl {
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