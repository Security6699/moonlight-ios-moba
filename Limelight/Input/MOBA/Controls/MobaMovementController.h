//
//  MobaMovementController.h
//  Moonlight
//


#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#include <stdint.h>

#import "MobaJoystickModel.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaInputDispatcher;
@class MobaMovementController;

typedef struct {
    uint16_t upKeyCode;
    uint16_t leftKeyCode;
    uint16_t downKeyCode;
    uint16_t rightKeyCode;
} MobaMovementKeyMapping;

NS_INLINE MobaMovementKeyMapping MobaMovementKeyMappingMake(uint16_t upKeyCode,
                                                            uint16_t leftKeyCode,
                                                            uint16_t downKeyCode,
                                                            uint16_t rightKeyCode) {
    MobaMovementKeyMapping mapping;
    mapping.upKeyCode = upKeyCode;
    mapping.leftKeyCode = leftKeyCode;
    mapping.downKeyCode = downKeyCode;
    mapping.rightKeyCode = rightKeyCode;
    return mapping;
}

FOUNDATION_EXPORT MobaMovementKeyMapping MobaDefaultMovementKeyMapping(void);

@protocol MobaMovementControllerDelegate <NSObject>

- (void)movementControllerDidRequestTouchCancellation:(MobaMovementController *)controller;

@end

/// Semantic movement controller with no UITouch dependency.
/// Key transitions are submitted through MobaInputDispatcher in W, A, S, D order.
@interface MobaMovementController : NSObject

@property (nonatomic, weak, nullable) id<MobaMovementControllerDelegate> delegate;
@property (nonatomic, readonly) MobaJoystickState state;
@property (nonatomic, readonly) MobaMovementKeyMapping keyMapping;
@property (nonatomic, readonly) CGFloat wheelRadius;
@property (nonatomic, readonly) CGFloat deadZoneRatio;
@property (nonatomic, readonly) CGFloat directionHysteresisDegrees;
@property (nonatomic, readonly, getter=isInteractionEnabled) BOOL interactionEnabled;
@property (nonatomic, strong, readonly, nullable) id activeTouchToken;

- (nullable instancetype)initWithInputDispatcher:(MobaInputDispatcher *)inputDispatcher
                                       keyMapping:(MobaMovementKeyMapping)keyMapping
                                      wheelRadius:(CGFloat)wheelRadius
                                    deadZoneRatio:(CGFloat)deadZoneRatio
                       directionHysteresisDegrees:(CGFloat)directionHysteresisDegrees NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)setInteractionEnabled:(BOOL)interactionEnabled;

// Profile-commit boundary only. The controller must already be disabled,
// neutral, and without an owned touch.
- (BOOL)updateWheelRadiusForCommittedProfile:(CGFloat)wheelRadius;

// Profile-import commit boundary only. The controller must already be
// disabled, neutral, and without an owned touch.
- (BOOL)updateKeyMappingForCommittedProfile:(MobaMovementKeyMapping)keyMapping;

/// Returns NO for disabled interaction or invalid model input.
- (BOOL)updateDisplacement:(CGVector)displacement;

/// Sends the active movement key difference to Neutral exactly once.
- (void)releaseMovement;

/// Clears local joystick and touch ownership without sending remote input.
- (void)silentReset;

/// Token seam used by MoveJoystickView and deterministic tests.
- (BOOL)beginInteractionWithToken:(id)token displacement:(CGVector)displacement;
- (BOOL)updateInteractionWithToken:(id)token displacement:(CGVector)displacement;
- (BOOL)endInteractionWithToken:(id)token;
- (BOOL)cancelInteractionWithToken:(id)token;

@end

NS_ASSUME_NONNULL_END
