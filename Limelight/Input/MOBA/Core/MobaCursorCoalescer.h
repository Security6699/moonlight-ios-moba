//
//  MobaCursorCoalescer.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "MobaDisplayLinkDriving.h"
#import "MobaOverlayLifecycle.h"

@class MobaInputDispatcher;

NS_ASSUME_NONNULL_BEGIN

// Strategy-facing boundary. Cast strategies do not depend on CADisplayLink or
// any UIKit driver type.
@protocol MobaCursorCoalescing <NSObject>

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) BOOL hasPendingPoint;

- (BOOL)start;
- (BOOL)submitLatestPoint:(CGPoint)point;
- (void)stopAndDiscardPending;

@end

// Main-thread latest-value coalescer. Repeated identical submissions are
// treated as new dirty input and may produce one event on the next tick.
@interface MobaCursorCoalescer : NSObject <MobaCursorCoalescing,
                                           MobaLocalInteractionResetParticipant>

@property (nonatomic, readonly) MobaCursorUpdateRate updateRate;

- (nullable instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                                      driver:(id<MobaDisplayLinkDriving>)driver;
- (nullable instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                                      driver:(id<MobaDisplayLinkDriving>)driver
                                  updateRate:(MobaCursorUpdateRate)updateRate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
