//
//  AppDelegate.m
//  StarJeweledBot
//
//  Created by Dustin Dettmer on 2/25/13.
//  Copyright (c) 2013 Dustin Dettmer. All rights reserved.
//

#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreAudio/CoreAudio.h>

@implementation AppDelegate

static float xstart = 0;
static float ystart = 0;

- (CGRect)findGameBoard:(CGSize)imgSize
{
    NSRect rect = { { 0, 0 }, imgSize };
    
    rect.origin.x = xstart;
    rect.origin.y = 0;
    
    rect.size.width = imgSize.width - rect.origin.x;
    rect.size.height = imgSize.height - ystart;
    
    return rect;
}

static NSImage *partOfImage(NSImage *input, NSRect targetRect) {
    if (input) {
        NSImage *output = [[NSImage alloc] initWithSize: targetRect.size];
        [output lockFocus];
        [input
         drawAtPoint: NSZeroPoint
         fromRect: targetRect
         operation: NSCompositeCopy
         fraction:  1.0f];
        [output unlockFocus];
        return output;
    } else {
        return nil;
    }
}

- (NSDictionary*)loadWindows {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    NSArray*  windows = (NSArray*)CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    
    NSMutableArray *sort = [@[] mutableCopy];
    
    for(NSDictionary *info in windows) {
        if([[info objectForKey:(NSString*)kCGWindowIsOnscreen] intValue]) {
            if([[info objectForKey:(NSString*)kCGWindowLayer] intValue] == 0) {
                
                NSString *title = [[info objectForKey:(NSString*)kCGWindowName] copy];
                NSNumber *windowIdNum = [[info objectForKey:(NSString*)kCGWindowNumber] copy];
                NSNumber *ownerName = [[info objectForKey:(NSString*)kCGWindowOwnerName] copy];
                NSDictionary *windowBounds = [[info objectForKey:(NSString*)kCGWindowBounds] copy];
                
                if(title && title.length && windowIdNum && windowIdNum.stringValue.length) {
                    
                    [sort addObject:windowIdNum.stringValue];
                    
                    NSMutableDictionary *object = [@{@"title":title} mutableCopy];
                    
                    if(ownerName)
                        [object setObject:ownerName forKey:@"ownerName"];
                    
                    if(windowBounds)
                        [object setObject:windowBounds forKey:@"windowBounds"];
                    
                    [object setObject:windowIdNum.stringValue forKey:@"windowId"];
                    
                    [dict setObject:object forKey:windowIdNum.stringValue];
                }
            }
        }
    }
    
    return @{@"sort":sort, @"windows":dict};
}

- (uint32_t)getWid {
    
    NSDictionary *dict = [self loadWindows];
    
    for(id key in [dict objectForKey:@"sort"]) {
        
        NSDictionary *info = [[dict objectForKey:@"windows"] objectForKey:key];
        
        if([[info objectForKey:@"ownerName"] isEqual:@"StarCraft II"])
            return (uint32_t)[[info objectForKey:@"windowId"] longLongValue];
        
        return 0;
    }
    
    return 0;
}

- (NSImage*)getScreenshot:(uint32_t)wid {
    
    if(!wid)
        return nil;
    
    CGImageRef image = CGWindowListCreateImage(CGRectNull,
                                               kCGWindowListOptionIncludingWindow |
                                               kCGWindowListExcludeDesktopElements,
                                               wid,
                                               kCGWindowImageBoundsIgnoreFraming |
                                               kCGWindowImageShouldBeOpaque |
                                               kCGWindowImageBestResolution);
    
    CGSize size = { CGImageGetWidth(image), CGImageGetHeight(image) };
    
    return [[NSImage alloc] initWithCGImage:image size:size];
}

typedef enum PieceType {
    Invalid = -1,
    Purple,
    Black,
    Orange,
    Green,
    Blue,
    Red
} PieceType;

- (PieceType*)getPieces:(NSImage*)img
{
    static PieceType pieces[64];
    
//    NSImage *img = [NSImage imageNamed:@"1.png"];
    
    NSRect result = [self findGameBoard:img.size];
    
    img = partOfImage(img, result);
    
    NSBitmapImageRep* raw_img = [NSBitmapImageRep imageRepWithData:[img TIFFRepresentation]];
    
    float cellWidth = img.size.width * 0.118f;
    float cellHeight = img.size.height * 0.074f;
    
    static struct {float r, g, b; } cols[] =
    {
        {0.802, 0.674, 0.574}, // purple
        {0.423, 0.083, 0.554}, // black
        {0.122, 0.950, 0.780}, // orange
        {0.265, 0.621, 0.640}, // green
        {0.545, 0.620, 0.803}, // blue
        {0.031, 0.912, 0.641}, // red
    };
    
    static int colors[] =
    {
        Purple,
        Black,
        Orange,
        Green,
        Blue,
        Red
    };
    
    NSColor *nscolor[] =
    {
        [NSColor purpleColor],
        [NSColor blackColor],
        [NSColor orangeColor],
        [NSColor greenColor],
        [NSColor blueColor],
        [NSColor redColor]
    };
    
    for(int y = 0; y < 8; y++) {
        for(int x = 0; x < 8; x++) {
            
            int xpos = x * cellWidth + cellWidth / 2;
            int ypos = y * cellHeight + cellHeight / 2;
            
            float r = 0;
            float g = 0;
            float b = 0;
            
            const int amnt = 20     ;
            
            int count = 0;
            
            for(int diff1 = -amnt; diff1 < amnt; diff1++) {
                for(int diff2 = -amnt; diff2 < amnt; diff2++) {
                    
                    NSColor *col = [raw_img colorAtX:xpos + diff1 y:ypos + diff2];
                    
                    r += col.hueComponent;
                    g += col.saturationComponent;
                    b += col.brightnessComponent;
                    
                    count++;
                }
            }
            
            r /= count;
            g /= count;
            b /= count;
            
//            NSLog(@"%dx%d %.3f, %.3f, %.3f", x, y, r, g, b);
            
            float smallestDiff = 0;
            int smallestIndex = 0;
            
#define FUZZY_MATCH(a, b, tolerance) \
            (a > b - tolerance && a < b + tolerance)
            
            for(int i = 0; i < sizeof(colors) / sizeof(colors[0]); i++) {
                
                float diff = 0;
                
                diff += fabs(cols[i].r - r);
                diff += fabs(cols[i].g - g);
//                diff += fabs(cols[i].b - b);
                
                if(i == 0 || diff < smallestDiff) {
                    
                    smallestDiff = diff;
                    smallestIndex = i;
                }
            }
            
//            if(smallestIndex == colors[Blue]) {
//                
//                // check for orange
//                
//                smallestIndex = Orange;
//            }
//            
            if(smallestIndex == colors[Green]) {
                
                // check for green
                smallestIndex = Green;
                
                float hue = 0;
                int count = 0;
                
                int diff1 = 0;
                int diff2 = -amnt;
                
                for(diff1 = -amnt; diff1 < amnt; diff1++) {
                    
                    hue += [[raw_img colorAtX:xpos + diff1 y:ypos + diff2] redComponent];
                    count++;
                }
                
                diff2 = amnt;
                
                for(diff1 = -amnt; diff1 < amnt; diff1++) {
                    
                    hue += [[raw_img colorAtX:xpos + diff1 y:ypos + diff2] redComponent];
                    count++;
                }
                
                diff2 = -amnt;
                
                for(diff1 = -amnt; diff1 < amnt; diff1++) {
                    
                    hue += [[raw_img colorAtX:xpos + diff2 y:ypos + diff1] redComponent];
                    count++;
                }
                
                diff2 = amnt;
                
                for(diff1 = -amnt; diff1 < amnt; diff1++) {
                    
                    hue += [[raw_img colorAtX:xpos + diff2 y:ypos + diff1] redComponent];
                    count++;
                }
                
//                if(hue > 60)
//                    smallestIndex = Orange;
            }
            
//            NSParameterAssert(smallestIndex < sizeof(colors) / sizeof(colors[0]));
            
            for(int diff1 = -3; diff1 < 3; diff1++)
                for(int diff2 = -3; diff2 < 3; diff2++) {
                    NSColor * c = [NSColor colorWithCalibratedHue:cols[smallestIndex].r saturation:cols[smallestIndex].g brightness:cols[smallestIndex].b alpha:1.0];
                    [raw_img setColor:c atX:xpos + diff1 y:ypos + diff2];
                }
            pieces[y * 8 + x] = colors[smallestIndex];
        }
    }
    
    self.imageWell.image = [[NSImage alloc] initWithData:[raw_img TIFFRepresentation]];
    
    return pieces;
}

typedef struct Move {
    int x1, y1;
    enum { left, up, right, down } direction;
} Move;

#define ADD_MOVE(x, y, dir) {\
Move tmp = {x, y, dir };\
[moves addObject:[NSData dataWithBytes:&tmp length:sizeof(tmp)]];\
}

- (NSArray*)findMoves:(PieceType*)pieces
{
    NSMutableArray *moves = [@[] mutableCopy];
    
    // left to right
    
    for(int y = 0; y < 8; y++) {
        
        PieceType last = 0;
        
        for(int x = 0; x < 7; x++) {
            
            PieceType itr = pieces[y * 8 + x];
            
            if(x != 0 && itr == last) {
                
                x++;
                
                if(y && pieces[(y - 1) * 8 + x] == itr)
                    ADD_MOVE(x, y, up);
                
                if(y < 7 && pieces[(y + 1) * 8 + x] == itr)
                    ADD_MOVE(x, y, down);
                
                if(x < 7 && pieces[y * 8 + x + 1] == itr)
                    ADD_MOVE(x, y, right);
                
                x--;
            }
            
            last = itr;
        }
    }
    
    // right to left
    
    for(int y = 0; y < 8; y++) {
        
        PieceType last;
        
        for(int x = 7; x > 0; x--) {
            
            PieceType itr = pieces[y * 8 + x];
            
            if(x != 7 && itr == last) {
                
                x--;
                
                if(y && pieces[(y - 1) * 8 + x] == itr)
                    ADD_MOVE(x, y, up);
                
                if(y < 7 && pieces[(y + 1) * 8 + x] == itr)
                    ADD_MOVE(x, y, down);
                
                if(x && pieces[y * 8 + x - 1] == itr)
                    ADD_MOVE(x, y, left);
                
                x++;
            }
            
            last = itr;
        }
    }
    
    // top to bottom
    
    for(int x = 0; x < 8; x++) {
        
        PieceType last = 0;
        
        for(int y = 0; y < 7; y++) {
            
            PieceType itr = pieces[y * 8 + x];
            
            if(y != 0 && itr == last) {
                
                y++;
                
                if(x && pieces[y * 8 + x - 1] == itr)
                    ADD_MOVE(x, y, left);
                
                if(y < 7 && pieces[(y + 1) * 8 + x] == itr)
                    ADD_MOVE(x, y, down);
                
                if(x < 7 && pieces[y * 8 + x + 1] == itr)
                    ADD_MOVE(x, y, right);
                
                y--;
            }
            
            last = itr;
        }
    }
    
    // bottom to top
    
    for(int x = 0; x < 8; x++) {
        
        PieceType last = 0;
        
        for(int y = 7; y > 0; y--) {
            
            PieceType itr = pieces[y * 8 + x];
            
            if(y != 7 && itr == last) {
                
                y--;
                
                if(x && pieces[y * 8 + x - 1] == itr)
                    ADD_MOVE(x, y, left);
                
                if(y && pieces[(y - 1) * 8 + x] == itr)
                    ADD_MOVE(x, y, down);
                
                if(x < 7 && pieces[y * 8 + x + 1] == itr)
                    ADD_MOVE(x, y, right);
                
                y++;
            }
            
            last = itr;
        }
    }
    
    return moves;
}

- (int)pointsForBoard:(PieceType*)board
{
    int score = 0;
    
    for(int x = 0; x < 8; x++) {
        
        int last1 = -1;
        int last2 = -1;
        
        for(int y = 0; y < 8; y++) {
            
            PieceType itr = board[y * 8 + x];
            
            if(last1 == last2 && last2 == itr && itr != -1) {
                
                score++;
            }
            
            last2 = last1;
            last1 = itr;
        }
    }
    
    for(int y = 0; y < 8; y++) {
        
        int last1 = -1;
        int last2 = -1;
        
        for(int x = 0; x < 8; x++) {
            
            PieceType itr = board[y * 8 + x];
            
            if(last1 == last2 && last2 == itr && itr != -1) {
                
                score++;
            }
            
            last2 = last1;
            last1 = itr;
        }
    }
    
    return score;
}

- (void)swapBoardPieces:(PieceType*)board x1:(int)x1 y1:(int)y1 x2:(int)x2 y2:(int)y2
{
    PieceType tmp = board[y1 * 8 + x1];
    
    board[y1 * 8 + x1] = board[y2 * 8 + x2];
    
    board[y2 * 8 + x2] = tmp;
}

// Returns the points after the simulation finishes.
// This overwrites 'board's pieces with the resulting board, returning the score.
- (int)simulateBoard:(PieceType*)board
{
    int score = [self pointsForBoard:board];
    
    if(!score)
        return 0;
    
    int toRemove[64];
    int remCount = 0;
    
    memset(toRemove, 0, sizeof(toRemove));
    
    for(int x = 0; x < 8; x++) {
        
        int last1 = -1;
        int last2 = -1;
        
        for(int y = 0; y < 8; y++) {
            
            PieceType itr = board[y * 8 + x];
            
            if(last1 == last2 && last2 == itr && itr != -1) {
                
                score++;
                
                toRemove[(y - 2) * 8 + x] = 1;
                toRemove[(y - 1) * 8 + x] = 1;
                toRemove[y * 8 + x] = 1;
                remCount += 3;
            }
            
            last2 = last1;
            last1 = itr;
        }
    }
    
    for(int y = 0; y < 8; y++) {
        
        int last1 = -1;
        int last2 = -1;
        
        for(int x = 0; x < 8; x++) {
            
            PieceType itr = board[y * 8 + x];
            
            if(last1 == last2 && last2 == itr && itr != -1) {
                
                score++;
                
                toRemove[y * 8 + x - 2] = 1;
                toRemove[y * 8 + x - 1] = 1;
                toRemove[y * 8 + x] = 1;
                remCount += 3;
            }
            
            last2 = last1;
            last1 = itr;
        }
    }
    
//    NSMutableString *str = [@"" mutableCopy];
//    
//    for(int x = 0; x < 8; x++) {
//        for(int y = 0; y < 8; y++) {
//            [str appendFormat:@"%d", board[y * 8 + x]];
//        }
//        [str appendString:@"\n"];
//    }
//    
//    printf("\n%s\n", str.UTF8String);
    
    // Remove pieces and slide down.
    for(int x = 0; x < 8; x++) {
        
        int colRemCount = 0;
        
        for(int y = 7; y >= 0; y--) {
            
            if(toRemove[y * 8 + x]) {
                
                board[y * 8 + x] = -1;
                
                colRemCount++;
            }
            else if(colRemCount) {
                
                [self swapBoardPieces:board x1:x y1:y x2:x y2:y + colRemCount];
            }
        }
    }
    
    if(remCount) {
        
        int add = [self simulateBoard:board];
        
        score += add;
    }
    
    return score;
}

- (PieceType*)boardAfterMove:(PieceType*)board move:(Move)move
{
    static PieceType result[64];
    
    memcpy(result, board, sizeof(result));
    
    int x2 = move.x1;
    int y2 = move.y1;
    
    if(move.direction == left)
        x2--;
    
    if(move.direction == right)
        x2++;
    
    if(move.direction == up)
        y2--;
    
    if(move.direction == down)
        y2++;
    
    [self swapBoardPieces:result x1:move.x1 y1:move.y1 x2:x2 y2:y2];
    
    return result;
}

- (NSArray*)findAllMoves:(PieceType*)pieces
{
    NSMutableArray *moves = [@[] mutableCopy];
    
    for(int x = 0; x < 8; x++) {
        for(int y = 0; y < 8; y++) {
            
            if(x) ADD_MOVE(x, y, left);
            if(y) ADD_MOVE(x, y, up);
            if(x < 7) ADD_MOVE(x, y, right);
            if(y < 7) ADD_MOVE(x, y, down);
        }
    }
    
    __block int largestScore = 0;
    
    [moves sortUsingComparator:^NSComparisonResult(NSData *obj1, NSData *obj2) {
        
        Move move1, move2;
        
        memcpy(&move1, obj1.bytes, sizeof(Move));
        memcpy(&move2, obj2.bytes, sizeof(Move));
        
        NSNumber *score1 = [NSNumber numberWithInt:[self simulateBoard:[self boardAfterMove:pieces move:move1]]];
        NSNumber *score2 = [NSNumber numberWithInt:[self simulateBoard:[self boardAfterMove:pieces move:move2]]];
        
        largestScore = MAX(largestScore, score1.intValue);
        largestScore = MAX(largestScore, score2.intValue);
        
        return [score1 compare:score2];
    }];
    
//    NSLog(@"Combos: %d", largestScore);
    
    return moves;
}

- (void)executeMove:(Move)move givenScreenSize:(CGSize)size
{
    NSRect result = [self findGameBoard:size];
    
    float cellWidth = result.size.width * 0.118f;
    float cellHeight = result.size.height * 0.074f;
    
    CGPoint point =
    {
        result.origin.x + cellWidth / 2,
        size.height - result.size.height + cellHeight / 2
    };
    
    point.x += move.x1 * cellWidth;
    point.y += move.y1 * cellHeight;
    
    usleep(1000);
    
    CGPostMouseEvent(point, NO, 1, YES);
    
    usleep(1000);
    
    CGPostMouseEvent(point, NO, 1, NO);
    
    if(move.direction == left)
        point.x -= cellWidth;
    if(move.direction == right)
        point.x += cellWidth;
    if(move.direction == up)
        point.y -= cellHeight;
    if(move.direction == down)
        point.y += cellHeight;
    
    usleep(1000);
    
    CGPostMouseEvent(point, NO, 1, YES);
    
    usleep(1000);
    
    CGPostMouseEvent(point, NO, 1, NO);
    
    
    const char *dir = "";
    
    if(move.direction == left)
        dir = "left";
    if(move.direction == right)
        dir = "right";
    if(move.direction == down)
        dir = "down";
    if(move.direction == up)
        dir = "up";
    
    [self.label setStringValue:[NSString stringWithFormat:@"Mouse move %d x %d %s", move.x1, move.y1, dir]];
}
- (float)getVolume {
	float			b_vol;
	OSStatus		err;
	AudioDeviceID		device;
	UInt32			size;
	UInt32			channels[2];
	float			volume[2];
	
	// get device
	size = sizeof device;
	err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &size, &device);
	if(err!=noErr) {
		NSLog(@"audio-volume error get device");
		return 0.0;
	}
	
	// try set master volume (channel 0)
	size = sizeof b_vol;
	err = AudioDeviceGetProperty(device, 0, 0, kAudioDevicePropertyVolumeScalar, &size, &b_vol);	//kAudioDevicePropertyVolumeScalarToDecibels
	if(noErr==err) return b_vol;
	
	// otherwise, try seperate channels
	// get channel numbers
	size = sizeof(channels);
	err = AudioDeviceGetProperty(device, 0, 0,kAudioDevicePropertyPreferredChannelsForStereo, &size,&channels);
	if(err!=noErr) NSLog(@"error getting channel-numbers");
	
	size = sizeof(float);
	err = AudioDeviceGetProperty(device, channels[0], 0, kAudioDevicePropertyVolumeScalar, &size, &volume[0]);
	if(noErr!=err) NSLog(@"error getting volume of channel %d",channels[0]);
	err = AudioDeviceGetProperty(device, channels[1], 0, kAudioDevicePropertyVolumeScalar, &size, &volume[1]);
	if(noErr!=err) NSLog(@"error getting volume of channel %d",channels[1]);
	
	b_vol = (volume[0]+volume[1])/2.00;
	
	return  b_vol;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//    sleep(3);
    
    dispatch_async(dispatch_queue_create(0, 0), ^{
        
        BOOL reset = YES;
        
        while(1) {
            
            @autoreleasepool {
                
                Move lastMove = {0, 0, -1};
                
                float volume = [self getVolume];
                
                if(volume < 0.1) {
                    
                    reset = YES;
                    
                    sleep(1);
                    continue;
                }
                
                if(reset) {
                    
                    CGEventRef ourEvent = CGEventCreate(NULL);
                    CGPoint point = CGEventGetLocation(ourEvent);
                    CFRelease(ourEvent);
                    
                    xstart = point.x;
                    ystart = point.y;
                    
                    reset = NO;
                }
                
                [NSThread sleepForTimeInterval:1 - volume];
//                usleep(100000);
                
                __block NSImage *img = nil;
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    img = [self getScreenshot:[self getWid]];
                });
                
                if(!img) {
                    sleep(1);
                    continue;
                }
                
                Move move;
                
                NSArray *moves = [self findAllMoves:[self getPieces:img]];
                
                if(!moves.count) {
                    sleep(1);
                    continue;
                }
                
                for(int i = 1; i < 10; i++) {
                    
                    if(0 == (rand() % 3))
                        continue;
                    
                    NSData *data = nil;
                    
                    if((int)moves.count - i >= 0)
                        data = [moves objectAtIndex:moves.count - i];
                    
                    if(data)
                        memcpy(&move, data.bytes, data.length);
                    
                    [self executeMove:move givenScreenSize:img.size];
                }
                
                NSLog(@"");
            }
        }
    });
}

@end
