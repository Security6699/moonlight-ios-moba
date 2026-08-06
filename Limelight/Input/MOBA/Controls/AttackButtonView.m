//
//  AttackButtonView.m
//  Moonlight
//


#import "AttackButtonView.h"

#import "MobaAttackController.h"

#import <math.h>

const CGSize AttackButtonDefaultVisualSize = { 110.0, 110.0 };
const CGFloat AttackButtonDefaultHitAreaScale = 1.18;
const CGFloat AttackButtonDefaultNormalOpacity = 0.78;
const CGFloat AttackButtonDefaultPressedOpacity = 0.92;
const CGFloat AttackButtonDefaultDisabledOpacity = 0.30;

@implementation AttackButtonView {
    MobaAttackController *_attackController;
    UIView *_buttonView;
    UILabel *_label;
    CGSize _visualSize;
    CGFloat _hitAreaScale;
    CGFloat _normalOpacity;
    CGFloat _pressedOpacity;
    CGFloat _disabledOpacity;
    BOOL _interactionEnabled;
    BOOL _mobaLocalInteractionEnabled;
    BOOL _pressed;
    CGFloat _globalOpacityMultiplier;
    MobaControlOpacityPreviewState _opacityPreviewState;
}

- (instancetype)initWithAttackController:(MobaAttackController *)attackController {
    return [self initWithAttackController:attackController
                              visualSize:AttackButtonDefaultVisualSize
                             hitAreaScale:AttackButtonDefaultHitAreaScale];
}

- (instancetype)initWithAttackController:(MobaAttackController *)attackController
                               visualSize:(CGSize)visualSize
                              hitAreaScale:(CGFloat)hitAreaScale {
    if (attackController == nil ||
        !isfinite(visualSize.width) ||
        !isfinite(visualSize.height) ||
        !isfinite(hitAreaScale) ||
        visualSize.width <= 0.0 ||
        visualSize.height <= 0.0 ||
        hitAreaScale <= 0.0) {
        return nil;
    }

    self = [super initWithFrame:CGRectZero];
    if (self) {
        _attackController = attackController;
        _visualSize = visualSize;
        _hitAreaScale = hitAreaScale;
        _normalOpacity = AttackButtonDefaultNormalOpacity;
        _pressedOpacity = AttackButtonDefaultPressedOpacity;
        _disabledOpacity = AttackButtonDefaultDisabledOpacity;
        _interactionEnabled = YES;
        _mobaLocalInteractionEnabled = attackController.isInteractionEnabled;
        _globalOpacityMultiplier = 1.0;
        _opacityPreviewState = MobaControlOpacityPreviewStateAutomatic;

        self.backgroundColor = UIColor.clearColor;
        self.multipleTouchEnabled = YES;

        _buttonView = [[UIView alloc] initWithFrame:CGRectZero];
        _buttonView.userInteractionEnabled = NO;
        _buttonView.backgroundColor = [UIColor colorWithRed:0.56 green:0.12 blue:0.10 alpha:1.0];
        _buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.70].CGColor;
        _buttonView.layer.borderWidth = 2.0;
        [self addSubview:_buttonView];

        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.userInteractionEnabled = NO;
        _label.text = @"ATK";
        _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = UIColor.whiteColor;
        _label.font = [UIFont boldSystemFontOfSize:22.0];
        [_buttonView addSubview:_label];

        [self updateInteractionAndAppearance];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(_visualSize.width * _hitAreaScale,
                      _visualSize.height * _hitAreaScale);
}

- (CGSize)visualSize {
    return _visualSize;
}

- (CGFloat)hitAreaScale {
    return _hitAreaScale;
}

- (CGFloat)normalOpacity {
    return _normalOpacity;
}

- (CGFloat)pressedOpacity {
    return _pressedOpacity;
}

- (CGFloat)disabledOpacity {
    return _disabledOpacity;
}

- (BOOL)isInteractionEnabled {
    return _interactionEnabled;
}

- (BOOL)isPressed {
    return _pressed;
}

- (CGFloat)effectiveVisualOpacity {
    return _buttonView.alpha;
}

- (CGSize)renderedVisualSize {
    return _buttonView.bounds.size;
}

- (CGFloat)validatedOpacity:(CGFloat)opacity fallback:(CGFloat)fallback {
    if (!isfinite(opacity)) {
        return fallback;
    }
    return fmin(fmax(opacity, 0.0), 1.0);
}

- (void)setNormalOpacity:(CGFloat)normalOpacity {
    _normalOpacity = [self validatedOpacity:normalOpacity fallback:_normalOpacity];
    [self updateInteractionAndAppearance];
}

- (void)setPressedOpacity:(CGFloat)pressedOpacity {
    _pressedOpacity = [self validatedOpacity:pressedOpacity fallback:_pressedOpacity];
    [self updateInteractionAndAppearance];
}

- (void)setDisabledOpacity:(CGFloat)disabledOpacity {
    _disabledOpacity = [self validatedOpacity:disabledOpacity fallback:_disabledOpacity];
    [self updateInteractionAndAppearance];
}

- (void)setInteractionEnabled:(BOOL)interactionEnabled {
    if (_interactionEnabled == interactionEnabled) {
        return;
    }

    if (!interactionEnabled) {
        [_attackController silentReset];
        _pressed = NO;
    }

    _interactionEnabled = interactionEnabled;
    [self updateInteractionAndAppearance];
}

- (void)updateInteractionAndAppearance {
    BOOL enabled = _interactionEnabled && _mobaLocalInteractionEnabled;
    [_attackController setInteractionEnabled:enabled];
    self.userInteractionEnabled = enabled;
    self.alpha = 1.0;
    CGFloat perStateOpacity;
    switch (_opacityPreviewState) {
        case MobaControlOpacityPreviewStateNormal:
            perStateOpacity = _normalOpacity;
            break;
        case MobaControlOpacityPreviewStatePressed:
            perStateOpacity = _pressedOpacity;
            break;
        case MobaControlOpacityPreviewStateDisabled:
            perStateOpacity = _disabledOpacity;
            break;
        case MobaControlOpacityPreviewStateAutomatic:
            perStateOpacity = enabled ? (_pressed ? _pressedOpacity : _normalOpacity) : _disabledOpacity;
            break;
    }
    _buttonView.alpha = MobaEffectiveControlOpacity(perStateOpacity, _globalOpacityMultiplier);
}

- (void)applyControlLayoutPresentation:(MobaControlLayoutPresentation *)presentation
               globalOpacityMultiplier:(CGFloat)globalOpacityMultiplier
                          previewState:(MobaControlOpacityPreviewState)previewState {
    if (presentation == nil) {
        return;
    }
    _visualSize = presentation.visualSize;
    _hitAreaScale = presentation.hitAreaScale;
    _normalOpacity = presentation.normalOpacity;
    _pressedOpacity = presentation.pressedOpacity;
    _disabledOpacity = presentation.disabledOpacity;
    _interactionEnabled = presentation.isInteractionEnabled;
    _globalOpacityMultiplier = [self validatedOpacity:globalOpacityMultiplier fallback:_globalOpacityMultiplier];
    _opacityPreviewState = previewState;
    self.layer.zPosition = presentation.zIndex;
    [self invalidateIntrinsicContentSize];
    [self updateInteractionAndAppearance];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _buttonView.bounds = (CGRect){ CGPointZero, _visualSize };
    _buttonView.center = center;
    _buttonView.layer.cornerRadius = MIN(_visualSize.width, _visualSize.height) * 0.5;
    _label.frame = _buttonView.bounds;
}

- (void)setPressedState:(BOOL)pressed {
    _pressed = pressed;
    [self updateInteractionAndAppearance];
}

- (BOOL)beginInteractionWithToken:(id)token {
    if (![_attackController beginInteractionWithToken:token]) {
        return NO;
    }

    [self setPressedState:YES];
    return YES;
}

- (BOOL)updateInteractionWithToken:(id)token {
    return [_attackController updateInteractionWithToken:token];
}

- (BOOL)endInteractionWithToken:(id)token {
    if (![_attackController endInteractionWithToken:token]) {
        return NO;
    }

    [self setPressedState:NO];
    return YES;
}

- (BOOL)cancelInteractionWithToken:(id)token {
    return [_attackController cancelInteractionWithToken:token];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([self beginInteractionWithToken:touch]) {
            break;
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        [self updateInteractionWithToken:touch];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([self endInteractionWithToken:touch]) {
            break;
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([self cancelInteractionWithToken:touch]) {
            break;
        }
    }
}

- (void)setMobaLocalInteractionEnabled:(BOOL)enabled {
    _mobaLocalInteractionEnabled = enabled;
    [self updateInteractionAndAppearance];
}

- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason {
    (void)reason;
    [_attackController silentReset];
    [self setPressedState:NO];
}

@end
