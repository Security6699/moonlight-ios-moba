//
//  MobaAimGeometry.m
//  Moonlight
//


#import "MobaAimGeometry.h"

#import <math.h>

static BOOL MobaAimScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

CGVector MobaAimDefaultUpDirection(void) {
    return CGVectorMake(0.0, -1.0);
}

BOOL MobaAimTargetForDirection(CGPoint anchor,
                               CGVector direction,
                               MobaAimRadii radii,
                               CGFloat distanceRatio,
                               CGPoint *target) {
    if (target == NULL ||
        !MobaAimScalarIsFinite(anchor.x) ||
        !MobaAimScalarIsFinite(anchor.y) ||
        !MobaAimScalarIsFinite(direction.dx) ||
        !MobaAimScalarIsFinite(direction.dy) ||
        !MobaAimScalarIsFinite(radii.leftPx) ||
        !MobaAimScalarIsFinite(radii.rightPx) ||
        !MobaAimScalarIsFinite(radii.upPx) ||
        !MobaAimScalarIsFinite(radii.downPx) ||
        !MobaAimScalarIsFinite(distanceRatio)) {
        return NO;
    }

    CGFloat directionLength = hypot(direction.dx, direction.dy);
    if (!MobaAimScalarIsFinite(directionLength) || directionLength <= 0.0) {
        return NO;
    }

    CGFloat unitX = direction.dx / directionLength;
    CGFloat unitY = direction.dy / directionLength;
    CGFloat denominator = 0.0;

    if (unitX != 0.0) {
        CGFloat radiusX = unitX >= 0.0 ? radii.rightPx : radii.leftPx;
        if (radiusX <= 0.0) {
            return NO;
        }
        CGFloat scaledX = unitX / radiusX;
        denominator += scaledX * scaledX;
    }

    if (unitY != 0.0) {
        CGFloat radiusY = unitY >= 0.0 ? radii.downPx : radii.upPx;
        if (radiusY <= 0.0) {
            return NO;
        }
        CGFloat scaledY = unitY / radiusY;
        denominator += scaledY * scaledY;
    }

    if (!MobaAimScalarIsFinite(denominator) || denominator <= 0.0) {
        return NO;
    }

    CGFloat maxDistance = 1.0 / sqrt(denominator);
    if (!MobaAimScalarIsFinite(maxDistance)) {
        return NO;
    }

    CGFloat clampedRatio = fmin(fmax(distanceRatio, 0.0), 1.0);
    CGPoint result = CGPointMake(anchor.x + unitX * maxDistance * clampedRatio,
                                 anchor.y + unitY * maxDistance * clampedRatio);
    if (!MobaAimScalarIsFinite(result.x) || !MobaAimScalarIsFinite(result.y)) {
        return NO;
    }

    *target = result;
    return YES;
}
