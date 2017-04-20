//
//  NSBundle+Ilion.m
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 19..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Ilion/Ilion-Private-Swift.h>
#import <objc/runtime.h>

static void Swizzle(Class cls, SEL originalSelector, SEL overrideSelector) {
    Method origMethod = class_getInstanceMethod(cls, originalSelector);
    Method overrideMethod = class_getInstanceMethod(cls, overrideSelector);

    if (class_addMethod(cls,
                        originalSelector,
                        method_getImplementation(overrideMethod),
                        method_getTypeEncoding(overrideMethod))) {
        class_replaceMethod(cls,
                            overrideSelector,
                            method_getImplementation(origMethod),
                            method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, overrideMethod);
    }
}


@interface NSBundle (Ilion)
@end

static id observerToken = nil;

@implementation NSBundle (Ilion)

+ (void)load {
    Swizzle(self, @selector(localizedStringForKey:value:table:), @selector(ilion_localizedStringForKey:value:table:));

    // delay init swizzling until after the application has been launched to avoid triggers from system bundles
    void (^handler)(NSNotification*) = ^(NSNotification* _) {
        Swizzle(self, @selector(initWithPath:), @selector(ilion_initWithPath:));
        [[NSNotificationCenter defaultCenter] removeObserver:observerToken];
        observerToken = nil;
    };
    observerToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification
                                                                      object:nil
                                                                       queue:nil
                                                                  usingBlock:handler];
}

- (instancetype)ilion_initWithPath:(NSString*)path {
    NSBundle* bundle = [self ilion_initWithPath:path];
    [[StringsManager defaultManager] loadStringsFilesInBundle:bundle];
    return bundle;
}

- (NSString*)ilion_localizedStringForKey:(NSString*)key value:(NSString*)value table:(NSString*)tableName {
    return [[StringsManager defaultManager] localizedStringForKey:key value:value table:tableName];
}

@end
