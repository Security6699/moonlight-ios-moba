//
//  MoveJoystickView.m
//  Moonlight
//


#import "MoveJoystickView.h"

#import "MobaMovementController.h"

#import <math.h>

const CGSize MoveJoystickDefaultVisualSize = { 190.0, 190.0 };
const CGFloat MoveJoystickDefaultWheelRadius = 95.0;
const CGFloat MoveJoystickDefaultHitAreaScale = 1.20;
const CGFloat MoveJoystickDefaultNormalOpacity = 0.66;
const CGFloat MoveJoystickDefaultPressedOpacity = 0.82;
const CGFloat MoveJoystickDefaultDisabledOpacity = 0.30;

@implementation MoveJoystickView {
    MobaMovementController *_movementController;
    UIView *_baseView;
    UIView *_knobView;
    CGSize _visualSize;
    CGFloat _wheelRadius;
    CGFloat _hitAreaScale;
    CGFloat _normalOpacity;
    CGFloat _pressedOpacity;
    CGFloat _disabledOpacity;
    BOOL _interactionEnabled;
    BOOL _mobaLocalInteractionEnabled;
    BOOL _pressed;
    CGVector _knobDisplacement;
}

- (instancetype)initWithMovementController:(MobaMovementController *)movementController {
    return [self initWithMovementController:movementController
                                 visualSize:MoveJoystickDefaultVisualSize
                                wheelRadius:MoveJoystickDefaultWheelRadius
                               hitAreaScale:MoveJoystickDefaultHitAreaScale];
}

- (instancetype)initWithMovementController:(MobaMovementController *)movementController
                                 visualSize:(CGSize)visualSize
                                wheelRadius:(CGFloat)wheelRadius
                               hitAreaScale:(CGFloat)hitAreaScale {
    if (movementController == nil ||
        !isfinite(visualSize.width) ||
        !isfinite(visualSize.height) ||
        !isfinite(wheelRadius) ||
        !isfinite(hitAreaScale) ||
        visualSize.width <= 0.0 ||
        visualSize.height <= 0.0 ||
        wheelRadius <= 0.0 ||
        hitAreaScale <= 0.0 ||
        fabs(movementController.wheelRadius - wheelRadius) > 0.000001) {
        return nil;
    }

    self = [super initWithFrame:CGRectZero];
    if (self) {
        _movementController = movementController;
        _visualSize = visualSize;
        _wheelRadius = wheelRadius;
        _hitAreaScale = hitAreaScale;
        _normalOpacity = MoveJoystickDefaultNormalOpacity;
        _pressedOpacity = MoveJoystickDefaultPressedOpacity;
        _disabledOpacity = MoveJoystickDefaultDisabledOpacity;
        _interactionEnabled = YES;
        _mobaLocalInteractionEnabled = movementController.isInteractionEnabled;

        self.backgroundColor = UIColor.clearColor;
        self.multipleTouchEnabled = YES;

        _baseView = [[UIView alloc] initWithFrame:CGRectZero];
        _baseView.userInteractionEnabled = NO;
        _baseView.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1.0];
        _baseView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
        _baseView.layer.borderWidth = 2.0;
        [self addSubview:_baseView];

        _knobView = [[UIView alloc] initWithFrame:CGRectZero];
        _knobView.userInteractionEnabled = NO;
        _knobView.backgroundColor = [UIColor colorWithWhite:0.82 alpha:1.0];
        _knobView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.75].CGColor;
        _knobView.layer.borderWidth = 2.0;
        [self addSubview:_knobView];

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

- (CGFloat)wheelRadius {
    return _wheelRadius;
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

- (CGVector)knobDisplacement {
    return _knobDisplacement;
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
    _interactionEnabled = interactionEnabled;
    [self updateInteractionAndAppearance];
}

- (void)updateInteractionAndAppearance {
    BOOL enabled = _interactionEnabled && _mobaLocalInteractionEnabled;
    [_movementController setInteractionEnabled:enabled];
    self.userInteractionEnabled = enabled;
    self.alpha = enabled ? (_pressed ? _pressedOpacity : _normalOpacity) : _disabledOpacity;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _baseView.bounds = (CGRect){ CGPointZero, _visualSize };
    _baseView.center = center;
    _baseView.layer.cornerRadius = MIN(_visualSize.width, _visualSize.height) * 0.5;

    CGFloat knobDiameter = MIN(_visualSize.width, _visualSize.height) * 0.34;
    _knobView.bounds = CGRectMake(0.0, 0.0, knobDiameter, knobDiameter);
    _knobView.center = CGPointMake(center.x + _knobDisplacement.dx,
                                   center.y + _knobDisplacement.dy);
    _knobView.layer.cornerRadius = knobDiameter * 0.5;
}

- (CGVector)displacementForTouch:(UITouch *)touch {
    CGPoint location = [touch locationInView:self];
    return CGVectorMake(location.x - CGRectGetMidX(self.bounds),
                        location.y - CGRectGetMidY(self.bounds));
}

- (void)setVisualDisplacement:(CGVector)displacement {
    CGFloat distance = hypot(displacement.dx, displacement.dy);
    if (distance > _wheelRadius && distance > 0.0) {
        CGFloat scale = _wheelRadius / distance;
        displacement.dx *= scale;
        displacement.dy *= scale;
    }
    _knobDisplacement = displacement;
    [self setNeedsLayout];
}

- (void)setPressedState:(BOOL)pressed {
    _pressed = pressed;
    [self updateInteractionAndAppearance];
}

- (void)resetVisualState {
    _knobDisplacement = CGVectorMake(0.0, 0.0);
    _pressed = NO;
    [self updateInteractionAndAppearance];
    [self setNeedsLayout];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        CGVector displacement = [self displacementForTouch:touch];
        if ([_movementController beginInteractionWithToken:touch displacement:displacement]) {
            [self setVisualDisplacement:displacement];
            [self setPressedState:YES];
            break;
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        CGVector displacement = [self displacementForTouch:touch];
        if ([_movementController updateInteractionWithToken:touch displacement:displacement]) {
            [self setVisualDisplacement:displacement];
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([_movementController endInteractionWithToken:touch]) {
            [self resetVisualState];
            break;
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([_movementController cancelInteractionWithToken:touch]) {
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
    [_movementController silentReset];
    [self resetVisualState];
}

@end
