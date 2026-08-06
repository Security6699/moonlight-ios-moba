//
//  MobaControlLayoutPresentation.m
//  Moonlight
//

#import "MobaControlLayoutPresentation.h"

#import <math.h>

static BOOL MobaPresentationFiniteUnit(double value) {
    return isfinite(value) && value >= 0.0 && value <= 1.0;
}

@implementation MobaControlLayoutPresentation

- (instancetype)initWithCenterX:(double)centerX
                         centerY:(double)centerY
                      visualSize:(CGSize)visualSize
                    hitAreaScale:(CGFloat)hitAreaScale
                   wheelRadiusPt:(NSNumber *)wheelRadiusPt
                   normalOpacity:(CGFloat)normalOpacity
                  pressedOpacity:(CGFloat)pressedOpacity
                 disabledOpacity:(CGFloat)disabledOpacity
                          zIndex:(NSInteger)zIndex
              interactionEnabled:(BOOL)interactionEnabled {
    double wheelRadius = wheelRadiusPt.doubleValue;
    if (!MobaPresentationFiniteUnit(centerX) ||
        !MobaPresentationFiniteUnit(centerY) ||
        !isfinite(visualSize.width) || visualSize.width <= 0.0 ||
        !isfinite(visualSize.height) || visualSize.height <= 0.0 ||
        !isfinite(hitAreaScale) || hitAreaScale <= 0.0 ||
        (wheelRadiusPt != nil && (!isfinite(wheelRadius) || wheelRadius <= 0.0)) ||
        !MobaPresentationFiniteUnit(normalOpacity) ||
        !MobaPresentationFiniteUnit(pressedOpacity) ||
        !MobaPresentationFiniteUnit(disabledOpacity)) {
        return nil;
    }
    self = [super init];
    if (self) {
        _centerX = centerX;
        _centerY = centerY;
        _visualSize = visualSize;
        _hitAreaScale = hitAreaScale;
        _wheelRadiusPt = [wheelRadiusPt copy];
        _normalOpacity = normalOpacity;
        _pressedOpacity = pressedOpacity;
        _disabledOpacity = disabledOpacity;
        _zIndex = zIndex;
        _interactionEnabled = interactionEnabled;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@implementation MobaCancelZoneLayoutPresentation

- (instancetype)initWithCenterX:(double)centerX
                         centerY:(double)centerY
                      diameterPt:(CGFloat)diameterPt
               activationInsetPt:(CGFloat)activationInsetPt
                         opacity:(CGFloat)opacity
         visibleOnlyWhileCasting:(BOOL)visibleOnlyWhileCasting {
    if (!MobaPresentationFiniteUnit(centerX) ||
        !MobaPresentationFiniteUnit(centerY) ||
        !isfinite(diameterPt) || diameterPt <= 0.0 ||
        !isfinite(activationInsetPt) || activationInsetPt < 0.0 ||
        activationInsetPt >= diameterPt * 0.5 ||
        !MobaPresentationFiniteUnit(opacity)) {
        return nil;
    }
    self = [super init];
    if (self) {
        _centerX = centerX;
        _centerY = centerY;
        _diameterPt = diameterPt;
        _activationInsetPt = activationInsetPt;
        _opacity = opacity;
        _visibleOnlyWhileCasting = visibleOnlyWhileCasting;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

CGFloat MobaEffectiveControlOpacity(CGFloat perStateOpacity,
                                    CGFloat globalOpacityMultiplier) {
    if (!isfinite(perStateOpacity) || !isfinite(globalOpacityMultiplier)) {
        return 0.0;
    }
    return fmin(fmax(perStateOpacity * globalOpacityMultiplier, 0.0), 1.0);
}
