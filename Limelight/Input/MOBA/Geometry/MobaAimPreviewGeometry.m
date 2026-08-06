//
//  MobaAimPreviewGeometry.m
//  Moonlight
//

#import "MobaAimPreviewGeometry.h"

#import "MobaGameCanvas.h"
#import "MobaPointCastGeometry.h"
#import "MobaPointResponse.h"
#import "MobaSkillDragSemantics.h"
#import "../Casting/MobaCastStrategyFactory.h"

#import <math.h>

BOOL MobaAimPreviewMapGamePointToVideoRect(CGPoint gamePoint, CGRect videoRect, CGPoint *viewPoint) {
    if (viewPoint == NULL || !isfinite(gamePoint.x) || !isfinite(gamePoint.y) ||
        !isfinite(videoRect.origin.x) || !isfinite(videoRect.origin.y) ||
        !isfinite(videoRect.size.width) || !isfinite(videoRect.size.height) ||
        videoRect.size.width <= 0 || videoRect.size.height <= 0) return NO;
    MobaGameCanvasPosition position;
    if (!MobaGameCanvasPositionFromPoint(gamePoint, &position)) return NO;
    CGFloat normalizedX = (CGFloat)position.x / (CGFloat)MobaGameCanvasMaxX;
    CGFloat normalizedY = (CGFloat)position.y / (CGFloat)MobaGameCanvasMaxY;
    *viewPoint = CGPointMake(CGRectGetMinX(videoRect) + normalizedX * CGRectGetWidth(videoRect),
                             CGRectGetMinY(videoRect) + normalizedY * CGRectGetHeight(videoRect));
    return YES;
}

static CGPoint MobaAimPreviewClampedPoint(CGPoint point) {
    MobaGameCanvasPosition position;
    if (!MobaGameCanvasPositionFromPoint(point, &position)) return CGPointZero;
    return CGPointMake(position.x, position.y);
}

static NSValue *MobaAimPreviewPointValue(CGPoint point) {
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

static CGVector MobaAimPreviewDirectionAtIndex(NSUInteger index, NSUInteger sampleCount) {
    CGFloat angle = 2.0 * (CGFloat)M_PI * (CGFloat)index / (CGFloat)sampleCount;
    CGFloat x = cos(angle);
    CGFloat y = sin(angle);
    if (fabs(x) < 1e-12) x = 0.0;
    if (fabs(y) < 1e-12) y = 0.0;
    return CGVectorMake(x, y);
}

NSArray<NSValue *> *MobaDirectionalAimPreviewBoundaryPoints(CGPoint anchor,
                                                             MobaAimRadii radii,
                                                             NSUInteger sampleCount) {
    if (!isfinite(anchor.x) || !isfinite(anchor.y) || sampleCount == 0 ||
        !isfinite(radii.leftPx) || !isfinite(radii.rightPx) ||
        !isfinite(radii.upPx) || !isfinite(radii.downPx) ||
        radii.leftPx < 0.0 || radii.rightPx < 0.0 ||
        radii.upPx < 0.0 || radii.downPx < 0.0) {
        return @[];
    }

    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:sampleCount];
    for (NSUInteger index = 0; index < sampleCount; index++) {
        CGVector direction = MobaAimPreviewDirectionAtIndex(index, sampleCount);
        CGPoint point = CGPointZero;
        if (!MobaAimTargetForDirection(anchor, direction, radii, 1.0, &point)) {
            return @[];
        }
        [points addObject:MobaAimPreviewPointValue(MobaAimPreviewClampedPoint(point))];
    }
    return points;
}

NSArray<NSValue *> *MobaPointAimPreviewBoundaryPoints(CGPoint anchor,
                                                       MobaAimRadii minimumRadii,
                                                       MobaAimRadii maximumRadii,
                                                       CGFloat distanceRatio,
                                                       NSUInteger sampleCount) {
    if (sampleCount == 0 || !isfinite(distanceRatio)) return @[];

    BOOL allMinimumRadiiAreZero = minimumRadii.leftPx == 0.0 &&
        minimumRadii.rightPx == 0.0 && minimumRadii.upPx == 0.0 &&
        minimumRadii.downPx == 0.0;
    if (allMinimumRadiiAreZero && distanceRatio <= 0.0) {
        CGPoint anchorPoint = CGPointZero;
        if (!MobaPointCastTargetForDirection(anchor, CGVectorMake(1.0, 0.0),
                                              minimumRadii, maximumRadii,
                                              distanceRatio, &anchorPoint)) return @[];
        return @[MobaAimPreviewPointValue(MobaAimPreviewClampedPoint(anchorPoint))];
    }

    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:sampleCount];
    for (NSUInteger index = 0; index < sampleCount; index++) {
        CGVector direction = MobaAimPreviewDirectionAtIndex(index, sampleCount);
        CGPoint point = CGPointZero;
        if (!MobaPointCastTargetForDirection(anchor, direction, minimumRadii,
                                              maximumRadii, distanceRatio, &point)) {
            return @[];
        }
        [points addObject:MobaAimPreviewPointValue(MobaAimPreviewClampedPoint(point))];
    }
    return points;
}

NSArray<NSValue *> *MobaAimPreviewMinimumBoundaryPoints(MobaAimPreviewResult result,
                                                         NSUInteger sampleCount) {
    if (!result.pointCast) return @[];
    return MobaPointAimPreviewBoundaryPoints(result.anchor, result.minimumRadii,
                                             result.maximumRadii, 0.0, sampleCount);
}

NSArray<NSValue *> *MobaAimPreviewMaximumBoundaryPoints(MobaAimPreviewResult result,
                                                         NSUInteger sampleCount) {
    if (result.pointCast) {
        return MobaPointAimPreviewBoundaryPoints(result.anchor, result.minimumRadii,
                                                 result.maximumRadii, 1.0, sampleCount);
    }
    return MobaDirectionalAimPreviewBoundaryPoints(result.anchor, result.maximumRadii,
                                                    sampleCount);
}

BOOL MobaAimPreviewResultForDescriptor(MobaSkillRuntimeDescriptor *descriptor,
                                        CGVector dragDisplacement,
                                        MobaAimPreviewResult *result) {
    if (descriptor == nil || result == NULL || !isfinite(dragDisplacement.dx) ||
        !isfinite(dragDisplacement.dy) || descriptor.castType == MobaProfileSkillCastTypeInstant) return NO;
    CGFloat length = hypot(dragDisplacement.dx, dragDisplacement.dy);
    BOOL meaningfulDrag = MobaSkillMeaningfulDragForDescriptor(descriptor, dragDisplacement);
    if (descriptor.castType == MobaProfileSkillCastTypeDirectional) {
        MobaDirectionalCastConfiguration *configuration = descriptor.directionalConfiguration;
        if (configuration == nil) return NO;
        CGVector direction = meaningfulDrag ? dragDisplacement : configuration.defaultDirection;
        CGFloat ratio = meaningfulDrag ? 1.0 : configuration.defaultDistanceRatio;
        CGPoint defaultTarget;
        CGPoint target;
        if (!MobaAimTargetForDirection(configuration.heroAnchor, configuration.defaultDirection,
                                       configuration.aimRadii, configuration.defaultDistanceRatio,
                                       &defaultTarget) ||
            !MobaAimTargetForDirection(configuration.heroAnchor, direction,
                                       configuration.aimRadii, ratio, &target)) return NO;
        *result = (MobaAimPreviewResult){
            configuration.heroAnchor, MobaAimPreviewClampedPoint(defaultTarget),
            MobaAimPreviewClampedPoint(target), direction,
            MobaAimRadiiMake(0, 0, 0, 0), configuration.aimRadii, ratio, NO,
        };
        return YES;
    }
    MobaPointCastConfiguration *configuration = descriptor.pointConfiguration;
    if (configuration == nil) return NO;
    CGVector direction = meaningfulDrag ? dragDisplacement : configuration.defaultDirection;
    CGFloat ratio = configuration.defaultDistanceRatio;
    if (meaningfulDrag && !MobaPointResponseDistanceRatio(length, configuration.wheelRadius,
            configuration.deadzoneRatio, configuration.fullRangeRatio,
            configuration.curveExponent, &ratio)) return NO;
    CGPoint defaultTarget;
    CGPoint target;
    if (!MobaPointCastTargetForDirection(configuration.heroAnchor, configuration.defaultDirection,
                                         configuration.minimumRadii, configuration.maximumRadii,
                                         configuration.defaultDistanceRatio, &defaultTarget) ||
        !MobaPointCastTargetForDirection(configuration.heroAnchor, direction,
                                         configuration.minimumRadii, configuration.maximumRadii,
                                         ratio, &target)) return NO;
    *result = (MobaAimPreviewResult){
        configuration.heroAnchor, MobaAimPreviewClampedPoint(defaultTarget),
        MobaAimPreviewClampedPoint(target), direction,
        configuration.minimumRadii, configuration.maximumRadii, ratio, YES,
    };
    return YES;
}
