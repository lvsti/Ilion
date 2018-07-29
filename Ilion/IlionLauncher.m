//
//  IlionLauncher.m
//  Ilion
//
//  Created by Tamas Lustyik on 2017. 04. 28..
//  Copyright © 2017. Tamas Lustyik. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Ilion/Ilion-Private-Swift.h>

@interface IlionLauncher : NSObject
@end

static id observerToken = nil;

@implementation IlionLauncher

+ (void)load {
    void (^handler)(NSNotification*) = ^(NSNotification* notif) {
        [[NSNotificationCenter defaultCenter] removeObserver:observerToken];
        observerToken = nil;
        
        NSMenu* mainMenu = ((NSApplication*)notif.object).mainMenu;
        NSMenu* appMenu = mainMenu.itemArray.firstObject.submenu;
        if (!appMenu) {
            return;
        }
        
        NSNumber* suppressMenuFlag = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"IlionSuppressMenu"];
        if ([suppressMenuFlag isKindOfClass:[NSNumber class]] && suppressMenuFlag.boolValue) {
            return;
        }
        
        NSMenuItem* launchMenuItem = [[NSMenuItem alloc] initWithTitle:@"Launch Ilion \xF0\x9F\x8C\x8D"
                                                                action:@selector(launch)
                                                         keyEquivalent:@"l"];
        launchMenuItem.keyEquivalentModifierMask = NSCommandKeyMask | NSAlternateKeyMask;
        launchMenuItem.target = self;
        
        [appMenu insertItem:launchMenuItem atIndex:0];
        [appMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
    };
    
    observerToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification
                                                                      object:nil
                                                                       queue:nil
                                                                  usingBlock:handler];
}

+ (void)launch {
    [[Ilion shared] start];
}

@end

