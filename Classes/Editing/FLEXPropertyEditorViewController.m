//
//  FLEXPropertyEditorViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 5/20/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import "FLEXPropertyEditorViewController.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXFieldEditorView.h"
#import "FLEXArgumentInputView.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXArgumentInputSwitchView.h"

FLEX_DidEditProperty _didEditProperty;

@interface FLEXPropertyEditorViewController () <FLEXArgumentInputViewDelegate>

@property (nonatomic, assign) objc_property_t property;

@end

@implementation FLEXPropertyEditorViewController

+ (FLEX_DidEditProperty)didEditProperty {
    return _didEditProperty;
}

+ (void)setDidEditProperty:(FLEX_DidEditProperty)didEditProperty {
    _didEditProperty = didEditProperty;
}

- (id)initWithTarget:(id)target property:(objc_property_t)property
{
    self = [super initWithTarget:target];
    if (self) {
        self.property = property;
        self.title = @"Property";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.fieldEditorView.fieldDescription = [FLEXRuntimeUtility fullDescriptionForProperty:self.property];
    id currentValue = [FLEXRuntimeUtility valueForProperty:self.property onObject:self.target];
    self.setterButton.enabled = [[self class] canEditProperty:self.property currentValue:currentValue];
    
    const char *typeEncoding = [[FLEXRuntimeUtility typeEncodingForProperty:self.property] UTF8String];
    FLEXArgumentInputView *inputView = [FLEXArgumentInputViewFactory argumentInputViewForTypeEncoding:typeEncoding];
    inputView.backgroundColor = self.view.backgroundColor;
    inputView.inputValue = [FLEXRuntimeUtility valueForProperty:self.property onObject:self.target];
    if ([[NSString stringWithUTF8String:typeEncoding] containsString:@"UIColor"]) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressInputView:)];
        [inputView addGestureRecognizer:lp];
    }
    inputView.delegate = self;
    self.fieldEditorView.argumentInputViews = @[inputView];
    
    // Don't show a "set" button for switches - just call the setter immediately after the switch toggles.
    if ([inputView isKindOfClass:[FLEXArgumentInputSwitchView class]]) {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)longPressInputView:(UILongPressGestureRecognizer *)gesture {
    FLEXArgumentInputView *inputView = gesture.view;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑颜色" message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof(alert) walert = alert;
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            
    }];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *field = walert.textFields.firstObject;
        NSString *colorStr = field.text;
        if ([colorStr length] > 0) {
            inputView.inputValue = [self UIColorFromString:colorStr];
        }
        
        [walert dismissViewControllerAnimated:NO completion:nil];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [walert dismissViewControllerAnimated:NO completion:nil];
    }];
    [alert addAction:ok];
    [alert addAction:cancel];
    [self presentViewController:alert animated:NO completion:nil];
}

- (UIColor *)UIColorFromString:(NSString *)colorString {
    NSString *tempString = colorString;
    if ([tempString hasPrefix:@"0x"]) {//检查开头是0x
        tempString = [tempString substringFromIndex:2];
    } else if ([tempString hasPrefix:@"#"]) {//检查开头是#
        tempString = [tempString substringFromIndex:1];
    }
    if (tempString.length == 6) {
        return [self colorWithHTMLPattern:tempString alpha:1.0];
    }
    else if (tempString.length == 8) {
        NSRange range = NSMakeRange(6, 2);
        NSString *aString = [tempString substringWithRange:range];
        unsigned int alpha;
        [[NSScanner scannerWithString:aString] scanHexInt:&alpha];
        CGFloat a = (CGFloat)(MAX(0, MIN(255, alpha))) / 255.0;
        return [self colorWithHTMLPattern:[tempString substringToIndex:6] alpha:a];
    }
    else {
        return [UIColor blackColor];
    }
}

- (instancetype)colorWithHTMLPattern:(NSString*)hexColorString alpha:(CGFloat)alpha {
    if ([hexColorString length] < 6) {//长度不合法
        return [UIColor blackColor];
    }
    NSString *tempString = [hexColorString lowercaseString];
    if ([tempString hasPrefix:@"0x"]) {//检查开头是0x
        tempString = [tempString substringFromIndex:2];
    } else if ([tempString hasPrefix:@"#"]) {//检查开头是#
        tempString = [tempString substringFromIndex:1];
    }
    if ([tempString length] != 6) {
        return [UIColor blackColor];
    }
    //分解三种颜色的值
    NSRange range;
    range.location = 0;
    range.length   = 2;
    NSString    *rString = [tempString substringWithRange:range];
    range.location = 2;
    NSString    *gString = [tempString substringWithRange:range];
    range.location = 4;
    NSString    *bString = [tempString substringWithRange:range];
    //取三种颜色值
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];

    CGFloat validAlpha = MAX(0, MIN(1, alpha));

    return [UIColor colorWithRed:((float)r / 255.0f)
                           green:((float)g / 255.0f)
                            blue:((float)b / 255.0f)
                           alpha:validAlpha];
}

- (void)actionButtonPressed:(id)sender
{
    [super actionButtonPressed:sender];
    
    id userInputObject = self.firstInputView.inputValue;
    NSArray *arguments = userInputObject ? @[userInputObject] : nil;
    SEL setterSelector = [FLEXRuntimeUtility setterSelectorForProperty:self.property];
    id oldValue;
    NSString *selectorString = NSStringFromSelector(setterSelector);
    if ([selectorString isEqualToString:@"setTextColor:"]) {
        oldValue = [self.target textColor];
    }
    else if ([selectorString isEqualToString:@"setBackgroundColor:"]) {
        oldValue = [self.target backgroundColor];
    }
    NSError *error = nil;
    [FLEXRuntimeUtility performSelector:setterSelector onObject:self.target withArguments:arguments error:&error];
    if (_didEditProperty) {
        _didEditProperty(self.target, NSStringFromSelector(setterSelector), oldValue, arguments);
    }
    if (error) {
        NSString *title = @"Property Setter Failed";
        NSString *message = [error localizedDescription];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        self.firstInputView.inputValue = [FLEXRuntimeUtility valueForProperty:self.property onObject:self.target];
    } else {
        // If the setter was called without error, pop the view controller to indicate that and make the user's life easier.
        // Don't do this for simulated taps on the action button (i.e. from switch/BOOL editors). The experience is weird there.
        if (sender) {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

- (void)getterButtonPressed:(id)sender
{
    [super getterButtonPressed:sender];
    id returnedObject = [FLEXRuntimeUtility valueForProperty:self.property onObject:self.target];
    [self exploreObjectOrPopViewController:returnedObject];
}

- (void)argumentInputViewValueDidChange:(FLEXArgumentInputView *)argumentInputView
{
    if ([argumentInputView isKindOfClass:[FLEXArgumentInputSwitchView class]]) {
        [self actionButtonPressed:nil];
    }
}

+ (BOOL)canEditProperty:(objc_property_t)property currentValue:(id)value
{
    const char *typeEncoding = [[FLEXRuntimeUtility typeEncodingForProperty:property] UTF8String];
    BOOL canEditType = [FLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:value];
    BOOL isReadonly = [FLEXRuntimeUtility isReadonlyProperty:property];
    return canEditType && !isReadonly;
}

@end
