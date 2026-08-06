//
//  MobaSkillDragSemantics.m
//  Moonlight
//

#import "MobaSkillDragSemantics.h"

#import "../Casting/MobaCastStrategyFactory.h"

#import <math.h>

const CGFloat MobaDirectionalMeaningfulDragDeadzoneRatio = 0.10;

BOOL MobaSkillMeaningfulDragForDescriptor(MobaSkillRuntimeDescriptor *descriptor,
                                           CGVector dragDisplacement) {
    if (descriptor == nil || descriptor.castType == MobaProfileSkillCastTypeInstant ||
        !isfinite(dragDisplacement.dx) || !isfinite(dragDisplacement.dy)) {
        return NO;
    }

    NSNumber *wheelRadiusValue = descriptor.layoutControlProfile.wheelRadiusPt;
    if (wheelRadiusValue == nil || !isfinite(wheelRadiusValue.doubleValue) ||
        wheelRadiusValue.doubleValue <= 0.0) {
        return NO;
    }

    MobaTouchResponseProfile *response = descriptor.skillProfile.touchResponse;
    CGFloat deadzoneRatio = response == nil
        ? MobaDirectionalMeaningfulDragDeadzoneRatio
        : (CGFloat)response.deadzoneRatio;
    if (!isfinite(deadzoneRatio) || deadzoneRatio < 0.0) {
        return NO;
    }

    CGFloat threshold = (CGFloat)wheelRadiusValue.doubleValue * deadzoneRatio;
    return hypot(dragDisplacement.dx, dragDisplacement.dy) > threshold;
}
