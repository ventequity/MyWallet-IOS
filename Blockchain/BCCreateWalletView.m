//
//  BCCreateWalletView
//  Blockchain
//
//  Created by Ben Reeves on 18/03/2012.
//  Copyright (c) 2012 Qkos Services Ltd. All rights reserved.
//

#import "BCCreateWalletView.h"

#import "AppDelegate.h"

@implementation BCCreateWalletView

#pragma mark - Lifecycle

- (void)awakeFromNib
{
    UIButton *createButton = [UIButton buttonWithType:UIButtonTypeCustom];
    createButton.frame = CGRectMake(0, 0, self.window.frame.size.width, 46);
    createButton.backgroundColor = COLOR_BLOCKCHAIN_BLUE;
    [createButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    createButton.titleLabel.font = [UIFont systemFontOfSize:17.0];
    self.createButton = createButton;
    
    emailTextField.inputAccessoryView = createButton;
    passwordTextField.inputAccessoryView = createButton;
    password2TextField.inputAccessoryView = createButton;
    
    passwordTextField.textColor = [UIColor grayColor];
    password2TextField.textColor = [UIColor grayColor];
    
    passwordFeedbackLabel.adjustsFontSizeToFitWidth = YES;
    
    // If loadBlankWallet is called without a delay, app.wallet will still be nil
    [self performSelector:@selector(createBlankWallet) withObject:nil afterDelay:0.1f];
}

- (void)createBlankWallet
{
    [app.wallet loadBlankWallet];
}

// Make sure keyboard comes back if use is returning from TOS
- (void)didMoveToWindow
{
    [emailTextField becomeFirstResponder];
}

- (void)setIsRecoveringWallet:(BOOL)isRecoveringWallet
{
    _isRecoveringWallet = isRecoveringWallet;
    
    if (_isRecoveringWallet) {
        [self.createButton removeTarget:self action:@selector(createAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton addTarget:self action:@selector(showRecoveryPhraseView:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton setTitle:BC_STRING_CONTINUE forState:UIControlStateNormal];
    } else {
        [self.createButton removeTarget:self action:@selector(showRecoveryPhraseView:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton addTarget:self action:@selector(createAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton setTitle:BC_STRING_CREATE_WALLET forState:UIControlStateNormal];
    }
}

#pragma mark - BCModalContentView Lifecyle methods

- (void)prepareForModalPresentation
{
    emailTextField.delegate = self;
    passwordTextField.delegate = self;
    password2TextField.delegate = self;
    
    [self clearSensitiveTextFields];

#ifdef DEBUG
    emailTextField.text = @"test@doesnotexist.tld";
    passwordTextField.text = @"testpassword!";
    password2TextField.text = @"testpassword!";
    [self checkPasswordStrength];
#endif
    
    _recoveryPhraseView.recoveryPassphraseTextField.delegate = self;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Scroll up to fit all entry fields on small screens
        if (!IS_568_SCREEN) {
            CGRect frame = self.frame;
            
            frame.origin.y = -SCROLL_HEIGHT_SMALL_SCREEN;
            
            self.frame = frame;
        }
        
        [emailTextField becomeFirstResponder];
    });
}

- (void)prepareForModalDismissal
{
    emailTextField.delegate = nil;
}

#pragma mark - Actions

- (IBAction)showRecoveryPhraseView:(id)sender
{
    if (![self isReadyToSubmitForm]) {
        return;
    };
    
    [self hideKeyboard];
    
    [app showModalWithContent:self.recoveryPhraseView closeType:ModalCloseTypeBack headerText:BC_STRING_RECOVER_FUNDS onDismiss:^{
        [self.createButton removeTarget:self action:@selector(recoverWalletClicked:) forControlEvents:UIControlEventTouchUpInside];
    } onResume:^{
        [self.recoveryPhraseView.recoveryPassphraseTextField performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.3f];
    }];
    
    [self.createButton removeTarget:self action:@selector(showRecoveryPhraseView:) forControlEvents:UIControlEventTouchUpInside];
    [self.createButton addTarget:self action:@selector(recoverWalletClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    self.recoveryPhraseView.recoveryPassphraseTextField.inputAccessoryView = self.createButton;
}

- (IBAction)recoverWalletClicked:(id)sender
{
    if (self.isRecoveringWallet) {
        NSString *recoveryPhrase = [[NSMutableString alloc] initWithString:self.recoveryPhraseView.recoveryPassphraseTextField.text];
        
        NSString *trimmedRecoveryPhrase = [recoveryPhrase stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]];
        
        [app.wallet loading_start_recover_wallet];
        [self.recoveryPhraseView.recoveryPassphraseTextField resignFirstResponder];
        self.recoveryPhraseView.recoveryPassphraseTextField.hidden = YES;

        [app.wallet recoverWithEmail:emailTextField.text password:passwordTextField.text passphrase:trimmedRecoveryPhrase];
        
        app.wallet.delegate = app;
    }
}


// Get here from New Account and also when manually pairing
- (IBAction)createAccountClicked:(id)sender
{
    if (![self isReadyToSubmitForm]) {
        return;
    };
    
    [self hideKeyboard];
        
    // Get callback when wallet is done loading
    // Continue in walletJSReady callback
    app.wallet.delegate = self;

    [app showBusyViewWithLoadingText:BC_STRING_LOADING_CREATING_WALLET];

    // Load the JS without a wallet
    [app.wallet performSelector:@selector(loadBlankWallet) withObject:nil afterDelay:DELAY_KEYBOARD_DISMISSAL];
}


#pragma mark - Wallet Delegate method

- (void)walletJSReady
{
    // JS is loaded - now create the wallet
    [app.wallet newAccount:self.tmpPassword email:emailTextField.text];
}

- (IBAction)termsOfServiceClicked:(id)sender
{
    [app pushWebViewController:[[app serverURL] stringByAppendingString:TERMS_OF_SERVICE_URL_SUFFIX] title:BC_STRING_TERMS_OF_SERVICE];
    [emailTextField becomeFirstResponder];
}

- (void)didCreateNewAccount:(NSString*)guid sharedKey:(NSString*)sharedKey password:(NSString*)password
{
    emailTextField.text = nil;
    passwordTextField.text = nil;
    password2TextField.text = nil;
    
    // Reset wallet
    [app forgetWallet];
        
    // Load the newly created wallet
    [app.wallet loadWalletWithGuid:guid sharedKey:sharedKey password:password];
        
    app.wallet.delegate = app;
        
    [app standardNotify:[NSString stringWithFormat:BC_STRING_DID_CREATE_NEW_WALLET_DETAIL]
                      title:BC_STRING_DID_CREATE_NEW_WALLET_TITLE
                   delegate:nil];
    
    app.wallet.isNew = YES;
    
    [app.wallet getAllCurrencySymbols];
}

- (void)errorCreatingNewAccount:(NSString*)message
{
    if ([message isEqualToString:@""]) {
        [app standardNotify:BC_STRING_NO_INTERNET_CONNECTION title:BC_STRING_ERROR delegate:nil];
    } else if ([message isEqualToString:ERROR_TIMEOUT_REQUEST]){
        [app standardNotify:BC_STRING_TIMED_OUT];
    } else if ([message isEqualToString:ERROR_FAILED_NETWORK_REQUEST] || [message containsString:ERROR_TIMEOUT_ERROR] || [[message stringByReplacingOccurrencesOfString:@" " withString:@""] containsString:ERROR_STATUS_ZERO]){
        [app performSelector:@selector(standardNotify:) withObject:BC_STRING_REQUEST_FAILED_PLEASE_CHECK_INTERNET_CONNECTION afterDelay:DELAY_KEYBOARD_DISMISSAL];
    } else {
        [app standardNotify:message];
    }
}

#pragma mark - Textfield Delegates


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == emailTextField) {
        [passwordTextField becomeFirstResponder];
    }
    else if (textField == passwordTextField) {
        [password2TextField becomeFirstResponder];
    }
    else if (textField == password2TextField) {
        if (self.isRecoveringWallet) {
            [self.createButton setTitle:BC_STRING_RECOVER_FUNDS forState:UIControlStateNormal];
            [self showRecoveryPhraseView:nil];
        } else {
            [self createAccountClicked:textField];
        }
    }
    else if (textField == self.recoveryPhraseView.recoveryPassphraseTextField) {
        [self recoverWalletClicked:textField];
    }
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == passwordTextField) {
        [self performSelector:@selector(checkPasswordStrength) withObject:nil afterDelay:0.01];
    }
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (passwordTextField.text.length == 0) {
        passwordFeedbackLabel.hidden = YES;
        passwordStrengthMeter.hidden = YES;
    }
}

#pragma mark - Helpers

- (void)didRecoverWallet
{
    [self clearSensitiveTextFields];
    self.recoveryPhraseView.recoveryPassphraseTextField.hidden = NO;
}

- (void)showPassphraseTextField
{
    self.recoveryPhraseView.recoveryPassphraseTextField.hidden = NO;
}

- (void)hideKeyboard
{
    [emailTextField resignFirstResponder];
    [passwordTextField resignFirstResponder];
    [password2TextField resignFirstResponder];
    
    [self.recoveryPhraseView.recoveryPassphraseTextField resignFirstResponder];
}

- (void)clearSensitiveTextFields
{
    passwordTextField.text = nil;
    password2TextField.text = nil;
    passwordStrengthMeter.progress = 0;
    self.passwordStrength = 0;
    
    passwordTextField.layer.borderColor = COLOR_TEXT_FIELD_BORDER_GRAY.CGColor;
    passwordFeedbackLabel.textColor = [UIColor darkGrayColor];
    
    self.recoveryPhraseView.recoveryPassphraseTextField.text = @"";
}

- (void)checkPasswordStrength
{
    passwordFeedbackLabel.hidden = NO;
    passwordStrengthMeter.hidden = NO;
    
    NSString *password = passwordTextField.text;
    
    UIColor *color;
    NSString *description;
    
    float passwordStrength = [app.wallet getStrengthForPassword:password];

    if (passwordStrength < 25) {
        color = COLOR_PASSWORD_STRENGTH_WEAK;
        description = BC_STRING_PASSWORD_STRENGTH_WEAK;
    }
    else if (passwordStrength < 50) {
        color = COLOR_PASSWORD_STRENGTH_REGULAR;
        description = BC_STRING_PASSWORD_STRENGTH_REGULAR;
    }
    else if (passwordStrength < 75) {
        color = COLOR_PASSWORD_STRENGTH_NORMAL;
        description = BC_STRING_PASSWORD_STRENGTH_NORMAL;
    }
    else {
        color = COLOR_PASSWORD_STRENGTH_STRONG;
        description = BC_STRING_PASSWORD_STRENGTH_STRONG;
    }
    
    self.passwordStrength = passwordStrength;
    
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        passwordFeedbackLabel.text = description;
        passwordFeedbackLabel.textColor = color;
        passwordStrengthMeter.progress = passwordStrength/100;
        passwordStrengthMeter.progressTintColor = color;
        passwordTextField.layer.borderColor = color.CGColor;
    }];
}

- (BOOL)isReadyToSubmitForm
{
    if ([emailTextField.text length] == 0) {
        [app standardNotify:BC_STRING_PLEASE_PROVIDE_AN_EMAIL_ADDRESS];
        [emailTextField becomeFirstResponder];
        return NO;
    }
    
    if ([emailTextField.text hasPrefix:@"@"] ||
        [emailTextField.text hasSuffix:@"@"] ||
        ![emailTextField.text containsString:@"@"]) {
        [app standardNotify:BC_STRING_INVALID_EMAIL_ADDRESS];
        [emailTextField becomeFirstResponder];
        return NO;
    }
    
    self.tmpPassword = passwordTextField.text;
    
    if (!self.tmpPassword || [self.tmpPassword length] == 0) {
        [app standardNotify:BC_STRING_NO_PASSWORD_ENTERED];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if ([self.tmpPassword isEqualToString:emailTextField.text]) {
        [app standardNotify:BC_STRING_PASSWORD_MUST_BE_DIFFERENT_FROM_YOUR_EMAIL];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if (self.passwordStrength < 25) {
        [app standardNotify:BC_STRING_PASSWORD_NOT_STRONG_ENOUGH];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if ([self.tmpPassword length] > 255) {
        [app standardNotify:BC_STRING_PASSWORD_MUST_BE_LESS_THAN_OR_EQUAL_TO_255_CHARACTERS];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if (![self.tmpPassword isEqualToString:[password2TextField text]]) {
        [app standardNotify:BC_STRING_PASSWORDS_DO_NOT_MATCH];
        [password2TextField becomeFirstResponder];
        return NO;
    }
    
    if (![app checkInternetConnection]) {
        return NO;
    }
    
    return YES;
}

@end
