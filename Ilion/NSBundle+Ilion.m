//
//  NSBundle+Ilion.m
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 19..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Ilion/Ilion-Private-Swift.h>
#import <objc/runtime.h>

@interface NSBundle (Ilion)
@end

@implementation NSBundle (Ilion)

+ (void)load {
    SEL originalSelector = @selector(localizedStringForKey:value:table:);
    SEL overrideSelector = @selector(specialLocalizedStringForKey:value:table:);
    Method origMethod = class_getInstanceMethod(self, originalSelector);
    Method overrideMethod = class_getInstanceMethod(self, overrideSelector);

    if (class_addMethod(self,
                        originalSelector,
                        method_getImplementation(overrideMethod),
                        method_getTypeEncoding(overrideMethod))) {
        class_replaceMethod(self,
                            overrideSelector,
                            method_getImplementation(origMethod),
                            method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, overrideMethod);
    }
}

- (NSString*)specialLocalizedStringForKey:(NSString*)key value:(NSString*)value table:(NSString*)tableName {
    return [[StringsManager defaultManager] localizedStringForKey:key comment:value ?: @""];
}

@end
