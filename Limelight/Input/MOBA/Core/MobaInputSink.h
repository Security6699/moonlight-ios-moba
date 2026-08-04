//
//  MobaInputSink.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

@protocol MobaInputSink <NSObject>

// Implementations send individual stateless actions and do not track pressed input.
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down;
- (void)moveCursorToCanvasPoint:(CGPoint)point;
- (void)sendMouseButton:(int)button down:(BOOL)down;

@end
