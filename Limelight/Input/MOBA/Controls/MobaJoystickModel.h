//
//  MobaJoystickModel.h
//  Moonlight
//


#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaJoystickState) {
    MobaJoystickStateNeutral,
    MobaJoystickStateUp,
    MobaJoystickStateUpRight,
    MobaJoystickStateRight,
    MobaJoystickStateDownRight,
    MobaJoystickStateDown,
    MobaJoystickStateDownLeft,
    MobaJoystickStateLeft,
    MobaJoystickStateUpLeft,
};

FOUNDATION_EXPORT const CGFloat MobaJoystickDefaultDeadZoneRatio;
FOUNDATION_EXPORT const CGFloat MobaJoystickDefaultDirectionHysteresisDegrees;

/// A valid dead zone is in 0...1 and hysteresis is in 0...22.5 degrees.
/// The upper limits are exclusive so every expanded sector remains narrower
/// than the two adjacent base sectors combined.
FOUNDATION_EXPORT BOOL MobaJoystickConfigurationIsValid(CGFloat wheelRadius,
                                                         CGFloat deadZoneRatio,
                                                         CGFloat directionHysteresisDegrees);

/// Maps a UIKit-coordinate displacement to one of eight directions or Neutral.
/// Positive X points right, positive Y points down, and zero degrees points right.
/// Dead-zone evaluation takes precedence over directional hysteresis.
FOUNDATION_EXPORT BOOL MobaJoystickStateForDisplacement(CGVector displacement,
                                                        CGFloat wheelRadius,
                                                        CGFloat deadZoneRatio,
                                                        CGFloat directionHysteresisDegrees,
                                                        MobaJoystickState previousState,
                                                        MobaJoystickState * _Nullable state);

NS_ASSUME_NONNULL_END
