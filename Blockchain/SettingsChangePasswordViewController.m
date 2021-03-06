//
//  SettingsChangePasswordViewController.m
//  Blockchain
//
//  Created by Kevin Wu on 11/26/15.
//  Copyright © 2015 Qkos Services Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import "BCFadeView.h"
#import "SettingsChangePasswordViewController.h"

@interface SettingsChangePasswordViewController () <UITextFieldDelegate>
@property (nonatomic) IBOutlet UILabel *passwordFeedbackLabel;
@property (nonatomic) IBOutlet UIProgressView *passwordStrengthMeter;
@property (nonatomic) IBOutlet BCTextField *mainPasswordTextField;
@property (nonatomic) IBOutlet BCTextField *newerPasswordTextField;
@property (nonatomic) IBOutlet BCTextField *confirmNewPasswordTextField;

@property (nonatomic) float passwordStrength;
@end


@implementation SettingsChangePasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *createButton = [UIButton buttonWithType:UIButtonTypeCustom];
    createButton.frame = CGRectMake(0, 0, app.window.frame.size.width, 46);
    createButton.backgroundColor = COLOR_BLOCKCHAIN_BLUE;
    [createButton setTitle:BC_STRING_CONTINUE forState:UIControlStateNormal];
    [createButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    createButton.titleLabel.font = [UIFont systemFontOfSize:17.0];
    [createButton addTarget:self action:@selector(confirmChangePassword) forControlEvents:UIControlEventTouchUpInside];
    
    self.mainPasswordTextField.inputAccessoryView = createButton;
    self.newerPasswordTextField.inputAccessoryView = createButton;
    self.confirmNewPasswordTextField.inputAccessoryView = createButton;
    
    self.mainPasswordTextField.delegate = self;
    self.newerPasswordTextField.delegate = self;
    self.confirmNewPasswordTextField.delegate = self;
    
    self.mainPasswordTextField.returnKeyType = UIReturnKeyNext;
    self.newerPasswordTextField.returnKeyType = UIReturnKeyNext;
    self.confirmNewPasswordTextField.returnKeyType = UIReturnKeyDone;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    SettingsNavigationController *navigationController = (SettingsNavigationController *)self.navigationController;
    navigationController.headerLabel.text = BC_STRING_SETTINGS_SECURITY_CHANGE_PASSWORD;
    [self clearTextFields];
    self.passwordStrength = 0;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.mainPasswordTextField becomeFirstResponder];
}

- (void)clearTextFields
{
    self.mainPasswordTextField.text = @"";
    self.newerPasswordTextField.text = @"";
    self.confirmNewPasswordTextField.text = @"";
}

#pragma mark - TextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.mainPasswordTextField) {
        [self.newerPasswordTextField becomeFirstResponder];
    } else if (textField == self.newerPasswordTextField) {
        [self.confirmNewPasswordTextField becomeFirstResponder];
    } else if (textField == self.confirmNewPasswordTextField) {
        [self confirmChangePassword];
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.newerPasswordTextField) {
        [self performSelector:@selector(checkPasswordStrength) withObject:nil afterDelay:0.01];
    }
    
    return YES;
}

- (void)confirmChangePassword
{
    if ([self isReadyToSubmitForm]) {
        [self addObserversForChangingPassword];
        
        [self.mainPasswordTextField resignFirstResponder];
        [self.newerPasswordTextField resignFirstResponder];
        [self.confirmNewPasswordTextField resignFirstResponder];
        
        SettingsNavigationController *navigationController = (SettingsNavigationController *)self.navigationController;
        [navigationController.busyView fadeIn];
        [app.wallet changePassword:self.newerPasswordTextField.text];
    }
}

- (void)changePasswordSuccess
{
    [self removeObserversForChangingPassword];
    
    UIAlertController *alertForChangePasswordSuccess = [UIAlertController alertControllerWithTitle:BC_STRING_SUCCESS message:BC_STRING_SETTINGS_SECURITY_PASSWORD_CHANGED preferredStyle:UIAlertControllerStyleAlert];
    [alertForChangePasswordSuccess addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        app.settingsNavigationController = nil;
        [app closeSideMenu];
        [app showPasswordModal];
        app.changedPassword = YES;
        [app.window.rootViewController presentViewController:alertForChangePasswordSuccess animated:YES completion:nil];
    }];

    [self clearTextFields];
}

- (void)changePasswordError
{
    SettingsNavigationController *navigationController = (SettingsNavigationController *)self.navigationController;
    [navigationController.busyView fadeOut];
    [self removeObserversForChangingPassword];
}

- (void)addObserversForChangingPassword
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePasswordSuccess) name:NOTIFICATION_KEY_CHANGE_PASSWORD_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePasswordError) name:NOTIFICATION_KEY_CHANGE_PASSWORD_ERROR object:nil];
}

- (void)removeObserversForChangingPassword
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_PASSWORD_SUCCESS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_KEY_CHANGE_PASSWORD_ERROR object:nil];
}

#pragma mark - Form Submission Checks

- (void)checkPasswordStrength
{
    self.passwordFeedbackLabel.hidden = NO;
    self.passwordStrengthMeter.hidden = NO;
    
    NSString *password = self.newerPasswordTextField.text;
    
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
        self.passwordFeedbackLabel.text = description;
        self.passwordFeedbackLabel.textColor = color;
        self.passwordStrengthMeter.progress = passwordStrength/100;
        self.passwordStrengthMeter.progressTintColor = color;
        self.newerPasswordTextField.layer.borderColor = color.CGColor;
    }];
}

- (BOOL)isReadyToSubmitForm
{
    if (![app.wallet isCorrectPassword:self.mainPasswordTextField.text]) {
        [self alertUserOfError:BC_STRING_INCORRECT_PASSWORD];
        return NO;
    }
    
    if ([self.newerPasswordTextField.text length] == 0) {
        [self.newerPasswordTextField becomeFirstResponder];
        [self alertUserOfError:BC_STRING_NO_PASSWORD_ENTERED];
        return NO;
    }
    
    NSString *email = [app.wallet.accountInfo objectForKey:DICTIONARY_KEY_ACCOUNT_SETTINGS_EMAIL];
    if (email && [self.newerPasswordTextField.text isEqualToString:email]) {
        [self.newerPasswordTextField becomeFirstResponder];
        [self alertUserOfError:BC_STRING_PASSWORD_MUST_BE_DIFFERENT_FROM_YOUR_EMAIL];
        return NO;
    }
    
    if (self.passwordStrength < 25) {
        [self.newerPasswordTextField becomeFirstResponder];
        [self alertUserOfError:BC_STRING_PASSWORD_NOT_STRONG_ENOUGH];
        return NO;
    }
    
    if ([self.newerPasswordTextField.text length] > 255) {
        [self.newerPasswordTextField becomeFirstResponder];
        [self alertUserOfError:BC_STRING_PASSWORD_MUST_BE_LESS_THAN_OR_EQUAL_TO_255_CHARACTERS];
        return NO;
    }
    
    if (![self.newerPasswordTextField.text isEqualToString:[self.confirmNewPasswordTextField text]]) {
        if (![self.newerPasswordTextField isFirstResponder]) {
            [self.confirmNewPasswordTextField becomeFirstResponder];
        }
        [self alertUserOfError:BC_STRING_PASSWORDS_DO_NOT_MATCH];
        return NO;
    }
    
    if ([app.wallet isCorrectPassword:self.newerPasswordTextField.text]) {
        [self alertUserOfError:BC_STRING_NEW_PASSWORD_MUST_BE_DIFFERENT];
        return NO;
    }
    
    if ([app.wallet.accountInfo[DICTIONARY_KEY_ACCOUNT_SETTINGS_PASSWORD_HINT] isEqualToString:self.newerPasswordTextField.text]) {
        [self alertUserOfError:BC_STRING_NEW_PASSWORD_MUST_BE_DIFFERENT_FROM_HINT];
        return NO;
    }
    
    if (![app checkInternetConnection]) {
        return NO;
    }
    
    return YES;
}

- (void)alertUserOfError:(NSString *)errorMessage
{
    UIAlertController *alertForError = [UIAlertController alertControllerWithTitle:BC_STRING_ERROR message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    [alertForError addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertForError animated:YES completion:nil];
}

@end
