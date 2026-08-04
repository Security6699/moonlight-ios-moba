//
//  MobaPointResponse.m
//  Moonlight
//


#import "MobaPointResponse.h"

#import <math.h>

static BOOL MobaPointResponseScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

BOOL MobaPointResponseDistanceRatio(CGFloat dragDistance,
                                    CGFloat wheelRadius,
                                    CGFloat deadzoneRatio,
                                    CGFloat fullRangeRatio,
                                    CGFloat curveExponent,
                                    CGFloat *distanceRatio) {
    if (distanceRatio == NULL ||
        !MobaPointResponseScalarIsFinite(dragDistance) ||
        !MobaPointResponseScalarIsFinite(wheelRadius) ||
        !MobaPointResponseScalarIsFinite(deadzoneRatio) ||
        !MobaPointResponseScalarIsFinite(fullRangeRatio) ||
        !MobaPointResponseScalarIsFinite(curveExponent) ||
        wheelRadius <= 0.0 ||
        deadzoneRatio < 0.0 ||
        fullRangeRatio <= deadzoneRatio ||
        curveExponent <= 0.0) {
        return NO;
    }

    CGFloat raw = dragDistance / wheelRadius;
    if (raw <= deadzoneRatio) {
        *distanceRatio = 0.0;
        return YES;
    }
    if (raw >= fullRangeRatio) {
        *distanceRatio = 1.0;
        return YES;
    }

    CGFloat normalized = (raw - deadzoneRatio) / (fullRangeRatio - deadzoneRatio);
    normalized = fmin(fmax(normalized, 0.0), 1.0);
    CGFloat result = pow(normalized, curveExponent);
    if (!MobaPointResponseScalarIsFinite(result)) {
        return NO;
    }

    *distanceRatio = fmin(fmax(result, 0.0), 1.0);
    return YES;
}
