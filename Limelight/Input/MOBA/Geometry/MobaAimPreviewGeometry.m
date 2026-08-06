//
//  MobaAimPreviewGeometry.m
//  Moonlight
//

#import "MobaAimPreviewGeometry.h"

#import "MobaGameCanvas.h"
#import "MobaPointCastGeometry.h"
#import "MobaPointResponse.h"
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

BOOL MobaAimPreviewResultForDescriptor(MobaSkillRuntimeDescriptor *descriptor,
                                        CGVector dragDisplacement,
                                        MobaAimPreviewResult *result) {
    if (descriptor == nil || result == NULL || !isfinite(dragDisplacement.dx) ||
        !isfinite(dragDisplacement.dy) || descriptor.castType == MobaProfileSkillCastTypeInstant) return NO;
    CGFloat length = hypot(dragDisplacement.dx, dragDisplacement.dy);
    if (descriptor.castType == MobaProfileSkillCastTypeDirectional) {
        MobaDirectionalCastConfiguration *configuration = descriptor.directionalConfiguration;
        if (configuration == nil) return NO;
        CGVector direction = length > 0 ? dragDisplacement : configuration.defaultDirection;
        CGPoint defaultTarget;
        CGPoint target;
        if (!MobaAimTargetForDirection(configuration.heroAnchor, configuration.defaultDirection,
                                       configuration.aimRadii, configuration.defaultDistanceRatio,
                                       &defaultTarget) ||
            !MobaAimTargetForDirection(configuration.heroAnchor, direction,
                                       configuration.aimRadii, 1.0, &target)) return NO;
        *result = (MobaAimPreviewResult){
            configuration.heroAnchor, MobaAimPreviewClampedPoint(defaultTarget),
            MobaAimPreviewClampedPoint(target), direction,
            MobaAimRadiiMake(0, 0, 0, 0), configuration.aimRadii, 1.0, NO,
        };
        return YES;
    }
    MobaPointCastConfiguration *configuration = descriptor.pointConfiguration;
    if (configuration == nil) return NO;
    CGVector direction = length > 0 ? dragDisplacement : configuration.defaultDirection;
    CGFloat ratio = configuration.defaultDistanceRatio;
    if (length > 0 && !MobaPointResponseDistanceRatio(length, configuration.wheelRadius,
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
