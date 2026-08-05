//
//  MobaCancelZoneGeometry.m
//  Moonlight
//

#import "MobaCancelZoneGeometry.h"

#import <math.h>

static BOOL MobaCancelZoneScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

BOOL MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometry geometry) {
    if (!MobaCancelZoneScalarIsFinite(geometry.center.x) ||
        !MobaCancelZoneScalarIsFinite(geometry.center.y) ||
        !MobaCancelZoneScalarIsFinite(geometry.visualDiameter) ||
        !MobaCancelZoneScalarIsFinite(geometry.activationInset) ||
        geometry.visualDiameter <= 0.0 ||
        geometry.activationInset < 0.0) {
        return NO;
    }

    CGFloat visualRadius = geometry.visualDiameter * 0.5;
    return geometry.activationInset < visualRadius;
}

BOOL MobaCancelZoneContainsPoint(MobaCancelZoneGeometry geometry,
                                 CGPoint point,
                                 BOOL *inside) {
    if (inside == NULL ||
        !MobaCancelZoneGeometryIsValid(geometry) ||
        !MobaCancelZoneScalarIsFinite(point.x) ||
        !MobaCancelZoneScalarIsFinite(point.y)) {
        return NO;
    }

    CGFloat visualRadius = geometry.visualDiameter * 0.5;
    CGFloat activationRadius = fmax(0.0, visualRadius - geometry.activationInset);
    CGFloat distance = hypot(point.x - geometry.center.x,
                             point.y - geometry.center.y);
    if (!MobaCancelZoneScalarIsFinite(distance)) {
        return NO;
    }

    *inside = distance <= activationRadius;
    return YES;
}
