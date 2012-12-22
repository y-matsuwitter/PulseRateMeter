//
//  YMViewController.m
//  pulseRateMeter
//
//  Created by matsumoto on 2012/12/21.
//  Copyright (c) 2012年 matsumoto. All rights reserved.
//

#import "YMViewController.h"

@interface YMViewController ()
@property (nonatomic, strong) YMPulseRateMater* pulseRateMeter;
@end

@implementation YMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.pulseRateMeter = [YMPulseRateMater new];
    [self.pulseRateMeter setDelegate:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)pulseRateMeterStartMeasureing:(id)sender
{
    [self.pulseRateLabel setText:@"calcurating..."];
}

- (void)pulseRateMeter:(id)sender completeWithPulseRate:(float)pulseRate
{
    [self.pulseRateLabel setText:[NSString stringWithFormat:@"%.2f", pulseRate]];
    [self.startButton setEnabled:YES];
}

- (IBAction)tapStart:(id)sender {
    [self.startButton setEnabled:NO];
    [self.pulseRateLabel setText:@"start!!"];
    [self.pulseRateMeter start];
}
@end
