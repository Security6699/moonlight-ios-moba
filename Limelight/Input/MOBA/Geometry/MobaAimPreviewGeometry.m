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

NSArray<NSValue *> *MobaAimPreviewBoundaryPoints(CGPoint anchor,
                                                  MobaAimRadii radii,
                                                  NSUInteger sampleCount) {
    if (!isfinite(anchor.x) || !isfinite(anchor.y) || sampleCount == 0 ||
        !isfinite(radii.leftPx) || !isfinite(radii.rightPx) ||
        !isfinite(radii.upPx) || !isfinite(radii.downPx) ||
        radii.leftPx < 0.0 || radii.rightPx < 0.0 ||
        radii.upPx < 0.0 || radii.downPx < 0.0) {
        return @[];
    }

    CGPoint clampedAnchor = MobaAimPreviewClampedPoint(anchor);
    if (radii.leftPx == 0.0 && radii.rightPx == 0.0 &&
        radii.upPx == 0.0 && radii.downPx == 0.0) {
        return @[MobaAimPreviewPointValue(clampedAnchor)];
    }

    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:sampleCount];
    for (NSUInteger index = 0; index < sampleCount; index++) {
        CGFloat angle = 2.0 * (CGFloat)M_PI * (CGFloat)index / (CGFloat)sampleCount;
        CGVector direction = CGVectorMake(cos(angle), sin(angle));
        CGPoint point = CGPointZero;
        if (!MobaAimTargetForDirection(anchor, direction, radii, 1.0, &point)) {
            return @[];
        }
        [points addObject:MobaAimPreviewPointValue(MobaAimPreviewClampedPoint(point))];
    }
    return points;
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
