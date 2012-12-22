//
//  YMPulseRateMater.m
//  pulseRateMeter
//
//  Created by matsumoto on 2012/12/23.
//  Copyright (c) 2012年 matsumoto. All rights reserved.
//

#import "YMPulseRateMater.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#define CALC_FRAME 256
#define INIT_FRAME 300

#define MAX_PULSE 200
#define MIN_PULSE 50

@interface YMPulseRateMater ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    int frameCount;
    float* whitePixelCounts;
}
@property (nonatomic, strong) AVCaptureSession* session;
@property (nonatomic, strong) NSDate* date;
@end

@implementation YMPulseRateMater

- (id)init
{
    self = [super init];
    if (self) {
        frameCount = 0;
        whitePixelCounts = calloc(CALC_FRAME, sizeof(float));
    }
    return self;
}

- (void)start
{
    [self setupConnection];
}

#pragma mark - av foundation
- (void)setupConnection
{
    //デバイス取得
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //入力作成
    AVCaptureDeviceInput* deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];
    
    //ビデオデータ出力作成
    NSDictionary* settings = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    AVCaptureVideoDataOutput* dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dataOutput.videoSettings = settings;
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [device lockForConfiguration:nil];
    device.torchMode = AVCaptureTorchModeOn;
    [device unlockForConfiguration];
    
    //セッション作成
    self.session = [[AVCaptureSession alloc] init];
    [self.session addInput:deviceInput];
    [self.session addOutput:dataOutput];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;//AVCaptureSessionPresetHigh;
    
    AVCaptureConnection *videoConnection = NULL;
    
    [self.session beginConfiguration];
    
    for ( AVCaptureConnection *connection in [dataOutput connections] )
    {
        for ( AVCaptureInputPort *port in [connection inputPorts] )
        {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                
            }
        }
    }
    if([videoConnection isVideoOrientationSupported]) // **Here it is, its always false**
    {
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    [self.session commitConfiguration];
    
    [self.session startRunning];
}

//各フレームにおける処理
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // 画像の表示
    [self calculateWithSampleBufferRef:sampleBuffer];
}

- (void)calculateWithSampleBufferRef:(CMSampleBufferRef)sampleBuffer
{
    // イメージバッファの取得
    CVImageBufferRef    buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // イメージバッファのロック
    CVPixelBufferLockBaseAddress(buffer, 0);
    // イメージバッファ情報の取得
    uint8_t*    base;
    size_t      width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace;
    CGContextRef    cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    // 画像の作成
    CGImageRef  cgImage;
    cgImage = CGBitmapContextCreateImage(cgContext);
    
    [self calcuratePulseRate:cgImage width:width height:height bytesPerRow:bytesPerRow];
    
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);
}

- (void)calcuratePulseRate:(CGImageRef)cgImage width:(size_t)width height:(size_t)height bytesPerRow:(size_t)bytesPerRow
{
    frameCount++;
    if (frameCount == INIT_FRAME) {
        self.date = [NSDate date];
        if ([self.delegate respondsToSelector:@selector(pulseRateMeterStartMeasureing:)]) {
            [self.delegate pulseRateMeterStartMeasureing:self];
        }
    }
    if (frameCount >= INIT_FRAME && frameCount < INIT_FRAME + CALC_FRAME) {
        whitePixelCounts[frameCount - INIT_FRAME] = (float)([self countWhitePixel:cgImage width:width height:height bytesPerRow:bytesPerRow] / 1000000.0f);
    }
    if (frameCount == INIT_FRAME + CALC_FRAME) {
        float pulse = [self getMaxPowerPulseFrom:whitePixelCounts time:[[NSDate date] timeIntervalSinceDate:self.date]];
        [self.session stopRunning];
        [self.delegate pulseRateMeter:self completeWithPulseRate:pulse];
    }
}

- (int)countWhitePixel:(CGImageRef)cgImage width:(size_t)width height:(size_t)height bytesPerRow:(size_t)bytesPerRow
{
    int count = 0;
    UInt8 threshold = 200;
    
    CGDataProviderRef dataProvider = CGImageGetDataProvider(cgImage);
    CFDataRef data = CGDataProviderCopyData(dataProvider);
    UInt8* pixels = (UInt8*)CFDataGetBytePtr(data);
    
    // threshold以上の輝度を持つピクセルを計測
    for (int y = 0 ; y < height; y++){
        for (int x = 0; x < width; x++){
            UInt8* buf = pixels + y * bytesPerRow + x * 4;
            UInt8 r, g, b;
            r = *(buf + 1);
            g = *(buf + 2);
            b = *(buf + 3);
            UInt8 gray = (77 * r + 28 * g + 151 * b)>>8;
            if (gray > threshold) {
                count++;
            }
        }
    }
    CFRelease(data);
    
    return count;
}

#pragma mark - fourier
- (float)getMaxPowerPulseFrom:(float*)wave time:(float)time
{
    unsigned int sizeLog2 = (int)(log(CALC_FRAME)/log(2));
    unsigned int size = 1 << sizeLog2;

    DSPSplitComplex splitComplex;
    splitComplex.realp = calloc(size, sizeof(float));
    splitComplex.imagp = calloc(size, sizeof(float));
    

    FFTSetup fftSetUp = vDSP_create_fftsetup(sizeLog2 + 1, FFT_RADIX2);
    float* window = calloc(size, sizeof(float));
    float* windowedInput = calloc(size, sizeof(float));
    vDSP_hann_window(window, size, 0);
    vDSP_vmul(wave, 1, window, 1, windowedInput, 1, size);
    
    for (int i = 0; i < size; i++) {
        splitComplex.realp[i] = windowedInput[i];
        splitComplex.imagp[i] = 0.0f;
    }
    vDSP_fft_zrip(fftSetUp, &splitComplex, 1, sizeLog2 + 1, FFT_FORWARD);
    
    int start = MIN_PULSE / 60.0f * time;
    int end = MAX_PULSE / 60.0f * time;
    float max = 0;
    float maxDist = 0;
    for (int i = start; i <= end; i++) {
        float real = splitComplex.realp[i];
        float imag = splitComplex.imagp[i];
        float distance = sqrt(real*real + imag*imag);
        if (maxDist < distance) {
            max = i;
            maxDist = distance;
        }
    }
    
    float pulse = max * (60.0f / time);
    
    free(splitComplex.realp);
    free(splitComplex.imagp);
    free(window);
    free(windowedInput);
    vDSP_destroy_fftsetup(fftSetUp);
    
    return pulse;
}

@end
