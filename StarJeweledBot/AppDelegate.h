//
//  AppDelegate.h
//  StarJeweledBot
//
//  Created by Dustin Dettmer on 2/25/13.
//  Copyright (c) 2013 Dustin Dettmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageCell *imageCell;
@property (weak) IBOutlet NSImageView *imageWell;
@property (weak) IBOutlet NSTextField *label;

@end
