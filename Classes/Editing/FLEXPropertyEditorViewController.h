//
//  FLEXPropertyEditorViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 5/20/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import "FLEXMutableFieldEditorViewController.h"
#import <objc/runtime.h>

typedef void (^FLEX_DidEditProperty)(NSObject *object, NSString *property, id oldValue, id value);

@interface FLEXPropertyEditorViewController : FLEXMutableFieldEditorViewController

+ (FLEX_DidEditProperty __nullable)didEditProperty;
+ (void)setDidEditProperty:(FLEX_DidEditProperty)didEditProperty;

- (id)initWithTarget:(id)target property:(objc_property_t)property;

+ (BOOL)canEditProperty:(objc_property_t)property currentValue:(id)value;

@end
