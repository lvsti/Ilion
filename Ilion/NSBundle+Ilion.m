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
static BOOL didRegisterMainBundle = NO;

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
    
    // avoid parsing foreign bundle resources
    if ([bundle.bundlePath hasPrefix:[NSBundle mainBundle].bundlePath] && !didRegisterMainBundle) {
        didRegisterMainBundle = YES;
        [[StringsManager defaultManager] loadStringsFilesInBundle:bundle];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"IlionDidRegisterBundle"
                                                            object:bundle];
    }
    
    return bundle;
}

- (NSString*)ilion_localizedStringForKey:(NSString*)key value:(NSString*)value table:(NSString*)tableName {
    // the original implementation has hidden side effects so we must always perform the call,
    // even if we discard/override the result afterwards 
    NSString* locString = [self ilion_localizedStringForKey:key value:value table:tableName];

    // avoid intercepting foreign bundle queries
    if (![self.bundlePath hasPrefix:[NSBundle mainBundle].bundlePath]) {
        return locString;
    }
    
    return [[StringsManager defaultManager] localizedStringForKey:key
                                                            value:value
                                                            table:tableName
                                                           bundle:self];
}

@end
