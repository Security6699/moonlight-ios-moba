//
//  MobaInputSink.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

@protocol MobaInputSink <NSObject>

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down;
- (void)moveCursorToCanvasPoint:(CGPoint)point;
- (void)sendMouseButton:(int)button down:(BOOL)down;

// Called after the dispatcher emits releases for all state it tracks.
- (void)releaseAllInputs;

@end
