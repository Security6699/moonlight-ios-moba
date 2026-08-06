//
//  MobaAttackController.h
//  Moonlight
//


#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

@class MobaAttackController;
@class MobaInputDispatcher;

FOUNDATION_EXPORT const uint16_t MobaDefaultAttackKeyCode;
FOUNDATION_EXPORT const NSUInteger MobaDefaultAttackTapDurationMs;

@protocol MobaAttackControllerDelegate <NSObject>

- (void)attackControllerDidRequestTouchCancellation:(MobaAttackController *)controller;

@end

/// Semantic non-repeating attack controller with no UITouch or UIKit dependency.
/// Tap timing and pressed-key state remain owned by MobaInputDispatcher.
@interface MobaAttackController : NSObject

@property (nonatomic, weak, nullable) id<MobaAttackControllerDelegate> delegate;
@property (nonatomic, readonly) uint16_t attackKeyCode;
@property (nonatomic, readonly) NSUInteger tapDurationMs;
@property (nonatomic, readonly, getter=isInteractionEnabled) BOOL interactionEnabled;
@property (nonatomic, readonly, getter=isPressed) BOOL pressed;
@property (nonatomic, strong, readonly, nullable) id activeTouchToken;

- (nullable instancetype)initWithInputDispatcher:(MobaInputDispatcher *)inputDispatcher;
- (nullable instancetype)initWithInputDispatcher:(MobaInputDispatcher *)inputDispatcher
                                    attackKeyCode:(uint16_t)attackKeyCode
                                    tapDurationMs:(NSUInteger)tapDurationMs NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// This is a silent local gate used by Lifecycle and does not release input.
- (void)setInteractionEnabled:(BOOL)interactionEnabled;

// Profile-import commit boundary only. The controller must already be
// disabled, unpressed, and without an owned touch.
- (BOOL)updateAttackKeyCodeForCommittedProfile:(uint16_t)attackKeyCode
                                  tapDurationMs:(NSUInteger)tapDurationMs;

/// The first accepted token submits exactly one Dispatcher tap on touch-down.
- (BOOL)beginInteractionWithToken:(id)token;

/// Move validates ownership but never submits remote input.
- (BOOL)updateInteractionWithToken:(id)token;

/// Normal end only clears local ownership and pressed state.
- (BOOL)endInteractionWithToken:(id)token;

/// Cancellation requests the existing unified Lifecycle interruption boundary.
- (BOOL)cancelInteractionWithToken:(id)token;

/// Clears local ownership and pressed state without submitting remote input.
- (void)silentReset;

@end

NS_ASSUME_NONNULL_END
