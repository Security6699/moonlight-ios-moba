//
//  MobaInputDispatcher.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dispatch/dispatch.h>
#include <stdint.h>

#import "MobaInputSink.h"

@protocol MobaInputScheduling <NSObject>

- (void)scheduleAfterMilliseconds:(NSUInteger)delayMs block:(dispatch_block_t)block;

@end

@interface MobaInputDispatcher : NSObject

// Input methods may be called from any thread. State and sink callbacks are confined
// to one private serial queue, and methods return without waiting for that queue.

- (instancetype)initWithSink:(id<MobaInputSink>)sink;
- (instancetype)initWithSink:(id<MobaInputSink>)sink
                    scheduler:(id<MobaInputScheduling>)scheduler NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down;
- (void)tapKeyCode:(uint16_t)keyCode durationMs:(NSUInteger)durationMs;
- (void)moveCursorToCanvasPoint:(CGPoint)point;
- (void)setMouseButton:(int)button down:(BOOL)down;

- (void)commitFinalCursorPoint:(CGPoint)point releasingKeyCode:(uint16_t)keyCode;
- (void)cancelWithKeyCode:(uint16_t)cancelKeyCode
               durationMs:(NSUInteger)durationMs
    releasingSkillKeyCode:(uint16_t)skillKeyCode;
- (void)cancelWithMouseButton:(int)button releasingSkillKeyCode:(uint16_t)skillKeyCode;

- (void)releaseAllInputs;

// The completion runs on the input queue after all previously submitted work.
- (void)notifyWhenIdle:(dispatch_block_t)completion;

@end
