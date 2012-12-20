//
//  hotkeys.m
//  Pcsxr
//
//  Created by Nicolas Pepin-Perreault on 12-12-12.
//
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import "hotkeys.h"
#import "EmuThread.h"
#include "plugins.h"
#include "ExtendedKeys.h"
#import "PcsxrController.h"

#define HK_MAX_STATE 10
static id monitor;
static int currentState = 0;
static NSMutableDictionary *hotkeys;
enum {
    HK_FAST_FORWARD,
    HK_SAVE_STATE,
    HK_LOAD_STATE,
    HK_NEXT_STATE,
    HK_PREV_STATE
};

void nextState() {
    currentState++;
    if(currentState == HK_MAX_STATE) {
        currentState = 0;
    }
}

void prevState() {
    currentState--;
    if(currentState < 0) {
        currentState = HK_MAX_STATE-1;
    }
}

bool handleHotkey(NSString* keyCode) {
    if([EmuThread active]) { // Don't catch hotkeys if there is no emulation
        NSNumber *ident = [hotkeys objectForKey:keyCode];

        if(ident != nil) {
            switch([ident intValue]) {
                case HK_FAST_FORWARD:
                    // We ignore FastForward requests if the emulation is paused
                    if(![EmuThread isPaused]) {
                        GPU_keypressed(GPU_FAST_FORWARD);
                    }
                    break;
                case HK_SAVE_STATE:
                    [PcsxrController saveState:currentState];
                    break;
                case HK_LOAD_STATE:
                    [PcsxrController loadState:currentState];
                    break;
                case HK_NEXT_STATE:
                    nextState();
                    GPU_displayText((char*)[[NSString stringWithFormat:@"State Slot: %d", currentState] UTF8String]);
                    break;
                case HK_PREV_STATE:
                    prevState();
                    GPU_displayText((char*)[[NSString stringWithFormat:@"State Slot: %d", currentState] UTF8String]);
                    break;
                default:
                    NSLog(@"Invalid hotkey identifier.");
            }
        
            return true;
        }
    }
    
    return false;
}

void setupHotkey(int hk, NSString *label, NSDictionary *binding) {
    [hotkeys setObject:[NSNumber numberWithInt:hk] forKey:[binding objectForKey:@"keyCode"]];
}

void setupHotkeys() {
    NSDictionary *bindings = [[NSUserDefaults standardUserDefaults] objectForKey:@"HotkeyBindings"];
    hotkeys = [[NSMutableDictionary alloc] initWithCapacity:[bindings count]];
    
    setupHotkey(HK_FAST_FORWARD, @"FastForward", [bindings objectForKey:@"FastForward"]);
    setupHotkey(HK_SAVE_STATE, @"SaveState", [bindings objectForKey:@"SaveState"]);
    setupHotkey(HK_LOAD_STATE, @"LoadState", [bindings objectForKey:@"LoadState"]);
    setupHotkey(HK_NEXT_STATE, @"NextState", [bindings objectForKey:@"NextState"]);
    setupHotkey(HK_PREV_STATE, @"PrevState", [bindings objectForKey:@"PrevState"]);
    
    currentState = 0;
}

void attachHotkeys() {
    NSEvent* (^handler)(NSEvent*) = ^(NSEvent *event) {
        if(handleHotkey([NSString stringWithFormat:@"%d", [event keyCode]])) {
            return (NSEvent*)nil; // handled
        }
        
        // Not handled
        return event;
    };
    setupHotkeys();
    monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyUpMask handler:handler];
}

void detachHotkeys() {
    if(hotkeys)[hotkeys release];
    [NSEvent removeMonitor:monitor];
}