//
//  YMViewController.h
//  pulseRateMeter
//
//  Created by matsumoto on 2012/12/21.
//  Copyright (c) 2012年 matsumoto. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YMPulseRateMater.h"

@interface YMViewController : UIViewController<YMPulseRateMeterDelegate>
@property (strong, nonatomic) IBOutlet UIButton *startButton;
@property (strong, nonatomic) IBOutlet UILabel *pulseRateLabel;
- (IBAction)tapStart:(id)sender;

@end
