//
//  MobaJoystickModel.m
//  Moonlight
//


#import "MobaJoystickModel.h"

#import <math.h>

const CGFloat MobaJoystickDefaultDeadZoneRatio = 0.16;
const CGFloat MobaJoystickDefaultDirectionHysteresisDegrees = 8.0;

static const CGFloat MobaJoystickSectorWidthDegrees = 45.0;
static const CGFloat MobaJoystickSectorHalfWidthDegrees = 22.5;

static BOOL MobaJoystickScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

static BOOL MobaJoystickStateIsValid(MobaJoystickState state) {
    return state >= MobaJoystickStateNeutral && state <= MobaJoystickStateUpLeft;
}

BOOL MobaJoystickConfigurationIsValid(CGFloat wheelRadius,
                                      CGFloat deadZoneRatio,
                                      CGFloat directionHysteresisDegrees) {
    return MobaJoystickScalarIsFinite(wheelRadius) &&
        MobaJoystickScalarIsFinite(deadZoneRatio) &&
        MobaJoystickScalarIsFinite(directionHysteresisDegrees) &&
        wheelRadius > 0.0 &&
        deadZoneRatio >= 0.0 &&
        deadZoneRatio < 1.0 &&
        directionHysteresisDegrees >= 0.0 &&
        directionHysteresisDegrees < MobaJoystickSectorHalfWidthDegrees;
}

static CGFloat MobaJoystickNormalizedAngleDegrees(CGVector displacement) {
    CGFloat angle = atan2(displacement.dy, displacement.dx) * 180.0 / M_PI;
    if (angle < 0.0) {
        angle += 360.0;
    }
    return angle;
}

static MobaJoystickState MobaJoystickBaseStateForAngle(CGFloat angleDegrees) {
    NSInteger sector = (NSInteger)floor((angleDegrees + MobaJoystickSectorHalfWidthDegrees) /
                                        MobaJoystickSectorWidthDegrees) % 8;
    switch (sector) {
        case 0:
            return MobaJoystickStateRight;
        case 1:
            return MobaJoystickStateDownRight;
        case 2:
            return MobaJoystickStateDown;
        case 3:
            return MobaJoystickStateDownLeft;
        case 4:
            return MobaJoystickStateLeft;
        case 5:
            return MobaJoystickStateUpLeft;
        case 6:
            return MobaJoystickStateUp;
        case 7:
            return MobaJoystickStateUpRight;
    }
    return MobaJoystickStateNeutral;
}

static CGFloat MobaJoystickCenterAngleForState(MobaJoystickState state) {
    switch (state) {
        case MobaJoystickStateRight:
            return 0.0;
        case MobaJoystickStateDownRight:
            return 45.0;
        case MobaJoystickStateDown:
            return 90.0;
        case MobaJoystickStateDownLeft:
            return 135.0;
        case MobaJoystickStateLeft:
            return 180.0;
        case MobaJoystickStateUpLeft:
            return 225.0;
        case MobaJoystickStateUp:
            return 270.0;
        case MobaJoystickStateUpRight:
            return 315.0;
        case MobaJoystickStateNeutral:
            return 0.0;
    }
    return 0.0;
}

static CGFloat MobaJoystickSmallestSignedAngleDifference(CGFloat angleDegrees,
                                                         CGFloat centerDegrees) {
    CGFloat difference = fmod(angleDegrees - centerDegrees + 540.0, 360.0) - 180.0;
    return difference;
}

BOOL MobaJoystickStateForDisplacement(CGVector displacement,
                                      CGFloat wheelRadius,
                                      CGFloat deadZoneRatio,
                                      CGFloat directionHysteresisDegrees,
                                      MobaJoystickState previousState,
                                      MobaJoystickState *state) {
    if (state == NULL ||
        !MobaJoystickConfigurationIsValid(wheelRadius,
                                          deadZoneRatio,
                                          directionHysteresisDegrees) ||
        !MobaJoystickStateIsValid(previousState) ||
        !MobaJoystickScalarIsFinite(displacement.dx) ||
        !MobaJoystickScalarIsFinite(displacement.dy)) {
        return NO;
    }

    CGFloat distance = hypot(displacement.dx, displacement.dy);
    CGFloat deadZoneDistance = wheelRadius * deadZoneRatio;
    if (!MobaJoystickScalarIsFinite(distance) ||
        !MobaJoystickScalarIsFinite(deadZoneDistance)) {
        return NO;
    }

    if (distance <= deadZoneDistance) {
        *state = MobaJoystickStateNeutral;
        return YES;
    }

    CGFloat angleDegrees = MobaJoystickNormalizedAngleDegrees(displacement);
    if (previousState != MobaJoystickStateNeutral) {
        CGFloat centerDegrees = MobaJoystickCenterAngleForState(previousState);
        CGFloat difference = MobaJoystickSmallestSignedAngleDifference(angleDegrees,
                                                                        centerDegrees);
        CGFloat holdHalfWidth = MobaJoystickSectorHalfWidthDegrees +
            directionHysteresisDegrees;
        if (fabs(difference) <= holdHalfWidth) {
            *state = previousState;
            return YES;
        }
    }

    *state = MobaJoystickBaseStateForAngle(angleDegrees);
    return YES;
}
