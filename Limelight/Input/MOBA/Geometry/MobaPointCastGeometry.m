//
//  MobaPointCastGeometry.m
//  Moonlight
//

#import "MobaPointCastGeometry.h"

#import <math.h>

static BOOL MobaPointCastScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

static BOOL MobaPointCastRadiiAreValid(MobaAimRadii minimumRadii,
                                       MobaAimRadii maximumRadii) {
    return MobaPointCastScalarIsFinite(minimumRadii.leftPx) && minimumRadii.leftPx >= 0.0 &&
        MobaPointCastScalarIsFinite(minimumRadii.rightPx) && minimumRadii.rightPx >= 0.0 &&
        MobaPointCastScalarIsFinite(minimumRadii.upPx) && minimumRadii.upPx >= 0.0 &&
        MobaPointCastScalarIsFinite(minimumRadii.downPx) && minimumRadii.downPx >= 0.0 &&
        MobaPointCastScalarIsFinite(maximumRadii.leftPx) && maximumRadii.leftPx > 0.0 &&
        MobaPointCastScalarIsFinite(maximumRadii.rightPx) && maximumRadii.rightPx > 0.0 &&
        MobaPointCastScalarIsFinite(maximumRadii.upPx) && maximumRadii.upPx > 0.0 &&
        MobaPointCastScalarIsFinite(maximumRadii.downPx) && maximumRadii.downPx > 0.0 &&
        minimumRadii.leftPx <= maximumRadii.leftPx &&
        minimumRadii.rightPx <= maximumRadii.rightPx &&
        minimumRadii.upPx <= maximumRadii.upPx &&
        minimumRadii.downPx <= maximumRadii.downPx;
}

static BOOL MobaPointCastRayDistance(CGFloat unitX,
                                     CGFloat unitY,
                                     MobaAimRadii radii,
                                     BOOL zeroRadiusMeansZeroDistance,
                                     CGFloat *distance) {
    CGFloat denominator = 0.0;
    if (unitX != 0.0) {
        CGFloat radiusX = unitX >= 0.0 ? radii.rightPx : radii.leftPx;
        if (radiusX == 0.0 && zeroRadiusMeansZeroDistance) {
            *distance = 0.0;
            return YES;
        }
        if (radiusX <= 0.0) {
            return NO;
        }
        CGFloat scaledX = unitX / radiusX;
        denominator += scaledX * scaledX;
    }
    if (unitY != 0.0) {
        CGFloat radiusY = unitY >= 0.0 ? radii.downPx : radii.upPx;
        if (radiusY == 0.0 && zeroRadiusMeansZeroDistance) {
            *distance = 0.0;
            return YES;
        }
        if (radiusY <= 0.0) {
            return NO;
        }
        CGFloat scaledY = unitY / radiusY;
        denominator += scaledY * scaledY;
    }

    if (!MobaPointCastScalarIsFinite(denominator) || denominator <= 0.0) {
        return NO;
    }
    CGFloat result = 1.0 / sqrt(denominator);
    if (!MobaPointCastScalarIsFinite(result)) {
        return NO;
    }
    *distance = result;
    return YES;
}

BOOL MobaPointCastTargetForDirection(CGPoint anchor,
                                     CGVector direction,
                                     MobaAimRadii minimumRadii,
                                     MobaAimRadii maximumRadii,
                                     CGFloat distanceRatio,
                                     CGPoint *target) {
    if (target == NULL ||
        !MobaPointCastScalarIsFinite(anchor.x) ||
        !MobaPointCastScalarIsFinite(anchor.y) ||
        !MobaPointCastScalarIsFinite(direction.dx) ||
        !MobaPointCastScalarIsFinite(direction.dy) ||
        !MobaPointCastScalarIsFinite(distanceRatio) ||
        !MobaPointCastRadiiAreValid(minimumRadii, maximumRadii)) {
        return NO;
    }

    CGFloat directionLength = hypot(direction.dx, direction.dy);
    if (!MobaPointCastScalarIsFinite(directionLength) || directionLength <= 0.0) {
        return NO;
    }
    CGFloat unitX = direction.dx / directionLength;
    CGFloat unitY = direction.dy / directionLength;
    CGFloat minimumDistance = 0.0;
    CGFloat maximumDistance = 0.0;
    if (!MobaPointCastRayDistance(unitX, unitY, minimumRadii, YES, &minimumDistance) ||
        !MobaPointCastRayDistance(unitX, unitY, maximumRadii, NO, &maximumDistance)) {
        return NO;
    }

    CGFloat clampedRatio = fmin(fmax(distanceRatio, 0.0), 1.0);
    CGFloat distance = minimumDistance + (maximumDistance - minimumDistance) * clampedRatio;
    CGPoint result = CGPointMake(anchor.x + unitX * distance,
                                 anchor.y + unitY * distance);
    if (!MobaPointCastScalarIsFinite(distance) ||
        !MobaPointCastScalarIsFinite(result.x) ||
        !MobaPointCastScalarIsFinite(result.y)) {
        return NO;
    }

    *target = result;
    return YES;
}
