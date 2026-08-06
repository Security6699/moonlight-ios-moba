//
//  MobaSkillButtonView.m
//  Moonlight
//

#import "MobaSkillButtonView.h"

#import "MobaSkillCastController.h"
#import "../Casting/MobaCastStrategyFactory.h"

@implementation MobaSkillButtonView {
    MobaSkillCastController *_controller;
    __weak UIView *_streamCoordinateView;
    UIView *_buttonView;
    UILabel *_label;
    MobaOverlayMode _mode;
    BOOL _mobaLocalInteractionEnabled;
    BOOL _pressed;
    id _activeTouchToken;
}

- (instancetype)initWithController:(MobaSkillCastController *)controller
                streamCoordinateView:(UIView *)streamCoordinateView {
    MobaLayoutControlProfile *layout = controller.descriptor.layoutControlProfile;
    if (controller == nil || streamCoordinateView == nil || layout == nil) {
        return nil;
    }

    self = [super initWithFrame:CGRectZero];
    if (self) {
        _controller = controller;
        _streamCoordinateView = streamCoordinateView;
        _mode = MobaOverlayModeBattle;
        _mobaLocalInteractionEnabled = controller.isInteractionEnabled;

        self.backgroundColor = UIColor.clearColor;
        self.multipleTouchEnabled = YES;
        self.layer.zPosition = layout.zIndex;

        _buttonView = [[UIView alloc] initWithFrame:CGRectZero];
        _buttonView.userInteractionEnabled = NO;
        _buttonView.backgroundColor = [UIColor colorWithRed:0.10 green:0.28 blue:0.55 alpha:1.0];
        _buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.75].CGColor;
        _buttonView.layer.borderWidth = 2.0;
        [self addSubview:_buttonView];

        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.userInteractionEnabled = NO;
        _label.text = controller.descriptor.displayLabel;
        _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = UIColor.whiteColor;
        _label.font = [UIFont boldSystemFontOfSize:24.0];
        [_buttonView addSubview:_label];

        [self updateInteractionAndAppearance];
    }
    return self;
}

- (MobaSkillRuntimeDescriptor *)descriptor { return _controller.descriptor; }
- (MobaOverlayMode)mode { return _mode; }
- (BOOL)isPressed { return _pressed; }
- (id)activeTouchToken { return _activeTouchToken; }

- (CGSize)visualSize {
    MobaLayoutControlProfile *layout = self.descriptor.layoutControlProfile;
    return CGSizeMake(layout.visualWidthPt, layout.visualHeightPt);
}

- (CGFloat)hitAreaScale { return self.descriptor.layoutControlProfile.hitAreaScale; }
- (CGFloat)normalOpacity { return self.descriptor.layoutControlProfile.opacity; }
- (CGFloat)pressedOpacity { return self.descriptor.layoutControlProfile.pressedOpacity; }
- (CGFloat)disabledOpacity { return self.descriptor.layoutControlProfile.disabledOpacity; }

- (CGSize)intrinsicContentSize {
    CGSize visualSize = self.visualSize;
    return CGSizeMake(visualSize.width * self.hitAreaScale,
                      visualSize.height * self.hitAreaScale);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize visualSize = self.visualSize;
    _buttonView.bounds = (CGRect){ CGPointZero, visualSize };
    _buttonView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _buttonView.layer.cornerRadius = MIN(visualSize.width, visualSize.height) * 0.5;
    _label.frame = _buttonView.bounds;
}

- (void)setMode:(MobaOverlayMode)mode {
    _mode = mode;
    [self updateInteractionAndAppearance];
}

- (void)updateInteractionAndAppearance {
    BOOL visible = _mode != MobaOverlayModeUI;
    BOOL enabled = visible &&
        _mode == MobaOverlayModeBattle &&
        _mobaLocalInteractionEnabled &&
        self.descriptor.layoutControlProfile.isInteractionEnabled;
    self.hidden = !visible;
    self.userInteractionEnabled = enabled;
    [_controller setInteractionEnabled:enabled];
    self.alpha = enabled ? (_pressed ? self.pressedOpacity : self.normalOpacity)
                         : self.disabledOpacity;
}

- (void)setPressedState:(BOOL)pressed {
    _pressed = pressed;
    [self updateInteractionAndAppearance];
}

- (BOOL)beginInteractionWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (_activeTouchToken != nil ||
        ![_controller beginInteractionWithToken:token streamViewPoint:point]) {
        return NO;
    }
    _activeTouchToken = token;
    [self setPressedState:YES];
    return YES;
}

- (BOOL)updateInteractionWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (token == nil || token != _activeTouchToken) {
        return NO;
    }
    return [_controller updateInteractionWithToken:token streamViewPoint:point];
}

- (BOOL)endInteractionWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (token == nil || token != _activeTouchToken ||
        ![_controller endInteractionWithToken:token streamViewPoint:point]) {
        return NO;
    }
    _activeTouchToken = nil;
    [self setPressedState:NO];
    return YES;
}

- (BOOL)cancelInteractionWithToken:(id)token {
    if (token == nil || token != _activeTouchToken) {
        return NO;
    }
    return [_controller cancelInteractionWithToken:token];
}

- (CGPoint)streamViewPointForTouch:(UITouch *)touch {
    return [touch locationInView:_streamCoordinateView];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([self beginInteractionWithToken:touch streamViewPoint:[self streamViewPointForTouch:touch]]) {
            break;
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        [self updateInteractionWithToken:touch streamViewPoint:[self streamViewPointForTouch:touch]];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([self endInteractionWithToken:touch streamViewPoint:[self streamViewPointForTouch:touch]]) {
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
    [_controller silentReset];
    _activeTouchToken = nil;
    [self setPressedState:NO];
}

@end
