//
//  BCConfirmPaymentView.h
//  Blockchain
//
//  Created by Kevin Wu on 10/2/15.
//  Copyright © 2015 Qkos Services Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BCConfirmPaymentView : UIView

@property (strong, nonatomic) IBOutlet UILabel *fromLabel;
@property (strong, nonatomic) IBOutlet UILabel *toLabel;

@property (strong, nonatomic) IBOutlet UILabel *fiatAmountLabel;
@property (strong, nonatomic) IBOutlet UILabel *btcAmountLabel;

@property (strong, nonatomic) IBOutlet UILabel *fiatFeeLabel;
@property (strong, nonatomic) IBOutlet UILabel *btcFeeLabel;
@property (strong, nonatomic) IBOutlet UIButton *customizeFeeButton;

@property (strong, nonatomic) IBOutlet UILabel *fiatTotalLabel;
@property (strong, nonatomic) IBOutlet UILabel *btcTotalLabel;

@property (strong, nonatomic) IBOutlet UIImageView *arrowImageView;
@property (strong, nonatomic) IBOutlet UIButton *reallyDoPaymentButton;
@end
