//
//  MobaCancelZoneView.m
//  Moonlight
//

#import "MobaCancelZoneView.h"

#import <math.h>

const CGFloat MobaCancelZoneDefaultVisualDiameter = 112.0;
const CGFloat MobaCancelZoneDefaultNormalOpacity = 0.58;
const CGFloat MobaCancelZoneDefaultArmedOpacity = 0.86;
const CGFloat MobaCancelZoneDefaultDisabledOpacity = 0.30;

@implementation MobaCancelZoneView {
    UIView *_circleView;
    UILabel *_label;
    CGFloat _visualDiameter;
    CGFloat _normalOpacity;
    CGFloat _armedOpacity;
    CGFloat _disabledOpacity;
    BOOL _castingVisible;
    BOOL _armed;
    BOOL _mobaLocalInteractionEnabled;
    CGFloat _globalOpacityMultiplier;
    BOOL _visibleOnlyWhileCasting;
    BOOL _editorPreview;
    MobaControlOpacityPreviewState _opacityPreviewState;
}

- (instancetype)initWithVisualDiameter:(CGFloat)visualDiameter {
    if (!isfinite(visualDiameter) || visualDiameter <= 0.0) {
        return nil;
    }

    self = [super initWithFrame:CGRectZero];
    if (self) {
        _visualDiameter = visualDiameter;
        _normalOpacity = MobaCancelZoneDefaultNormalOpacity;
        _armedOpacity = MobaCancelZoneDefaultArmedOpacity;
        _disabledOpacity = MobaCancelZoneDefaultDisabledOpacity;
        _mobaLocalInteractionEnabled = YES;
        _globalOpacityMultiplier = 1.0;
        _visibleOnlyWhileCasting = YES;
        _opacityPreviewState = MobaControlOpacityPreviewStateAutomatic;

        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.hidden = YES;

        _circleView = [[UIView alloc] initWithFrame:CGRectZero];
        _circleView.userInteractionEnabled = NO;
        [self addSubview:_circleView];

        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.userInteractionEnabled = NO;
        _label.text = @"CANCEL";
        _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = UIColor.whiteColor;
        _label.font = [UIFont boldSystemFontOfSize:14.0];
        [_circleView addSubview:_label];

        [self updatePresentation];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(_visualDiameter, _visualDiameter);
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {
    (void)userInteractionEnabled;
    [super setUserInteractionEnabled:NO];
}

- (CGFloat)visualDiameter {
    return _visualDiameter;
}

- (CGFloat)normalOpacity {
    return _normalOpacity;
}

- (CGFloat)armedOpacity {
    return _armedOpacity;
}

- (CGFloat)disabledOpacity {
    return _disabledOpacity;
}

- (BOOL)isCastingVisible {
    return _castingVisible;
}

- (BOOL)isArmed {
    return _armed;
}

- (MobaCancelZoneVisualState)visualState {
    if (_editorPreview) {
        switch (_opacityPreviewState) {
            case MobaControlOpacityPreviewStateNormal: return MobaCancelZoneVisualStateNormal;
            case MobaControlOpacityPreviewStatePressed: return MobaCancelZoneVisualStateArmed;
            case MobaControlOpacityPreviewStateDisabled: return MobaCancelZoneVisualStateDisabled;
            case MobaControlOpacityPreviewStateAutomatic: break;
        }
    }
    if (!_mobaLocalInteractionEnabled) {
        return MobaCancelZoneVisualStateDisabled;
    }
    return _armed ? MobaCancelZoneVisualStateArmed : MobaCancelZoneVisualStateNormal;
}

- (CGFloat)validatedOpacity:(CGFloat)opacity fallback:(CGFloat)fallback {
    if (!isfinite(opacity)) {
        return fallback;
    }
    return fmin(fmax(opacity, 0.0), 1.0);
}

- (void)setNormalOpacity:(CGFloat)normalOpacity {
    _normalOpacity = [self validatedOpacity:normalOpacity fallback:_normalOpacity];
    [self updatePresentation];
}

- (void)setArmedOpacity:(CGFloat)armedOpacity {
    _armedOpacity = [self validatedOpacity:armedOpacity fallback:_armedOpacity];
    [self updatePresentation];
}

- (void)setDisabledOpacity:(CGFloat)disabledOpacity {
    _disabledOpacity = [self validatedOpacity:disabledOpacity fallback:_disabledOpacity];
    [self updatePresentation];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _circleView.bounds = CGRectMake(0.0, 0.0, _visualDiameter, _visualDiameter);
    _circleView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _circleView.layer.cornerRadius = _visualDiameter * 0.5;
    _label.frame = _circleView.bounds;
}

- (void)updatePresentation {
    MobaCancelZoneVisualState state = self.visualState;
    switch (state) {
        case MobaCancelZoneVisualStateNormal:
            _circleView.backgroundColor = [UIColor colorWithRed:0.55 green:0.08 blue:0.08 alpha:1.0];
            _circleView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.65].CGColor;
            _circleView.layer.borderWidth = 2.0;
            _circleView.transform = CGAffineTransformIdentity;
            self.alpha = MobaEffectiveControlOpacity(_normalOpacity, _globalOpacityMultiplier);
            break;
        case MobaCancelZoneVisualStateArmed:
            _circleView.backgroundColor = [UIColor colorWithRed:0.82 green:0.06 blue:0.04 alpha:1.0];
            _circleView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
            _circleView.layer.borderWidth = 4.0;
            _circleView.transform = CGAffineTransformMakeScale(1.08, 1.08);
            self.alpha = MobaEffectiveControlOpacity(_armedOpacity, _globalOpacityMultiplier);
            break;
        case MobaCancelZoneVisualStateDisabled:
            _circleView.backgroundColor = [UIColor colorWithWhite:0.28 alpha:1.0];
            _circleView.layer.borderColor = [UIColor colorWithWhite:0.75 alpha:0.55].CGColor;
            _circleView.layer.borderWidth = 2.0;
            _circleView.transform = CGAffineTransformIdentity;
            self.alpha = MobaEffectiveControlOpacity(_disabledOpacity, _globalOpacityMultiplier);
            break;
    }
    BOOL normalVisibility = !_visibleOnlyWhileCasting || _castingVisible;
    self.hidden = !_editorPreview && (!normalVisibility || !_mobaLocalInteractionEnabled);
    self.userInteractionEnabled = NO;
}

- (void)applyCancelZoneLayoutPresentation:(MobaCancelZoneLayoutPresentation *)presentation
                  globalOpacityMultiplier:(CGFloat)globalOpacityMultiplier
                            editorPreview:(BOOL)editorPreview
                             previewState:(MobaControlOpacityPreviewState)previewState {
    if (presentation == nil) {
        return;
    }
    _visualDiameter = presentation.diameterPt;
    _normalOpacity = presentation.opacity;
    _visibleOnlyWhileCasting = presentation.visibleOnlyWhileCasting;
    _globalOpacityMultiplier = MobaEffectiveControlOpacity(1.0, globalOpacityMultiplier);
    _editorPreview = editorPreview;
    _opacityPreviewState = previewState;
    [self invalidateIntrinsicContentSize];
    [self updatePresentation];
    [self setNeedsLayout];
}

- (void)setCancelZoneCastingVisible:(BOOL)visible {
    _castingVisible = visible;
    if (!visible) {
        _armed = NO;
    }
    [self updatePresentation];
}

- (void)setCancelZoneArmed:(BOOL)armed {
    _armed = _castingVisible && armed;
    [self updatePresentation];
}

- (void)resetCancelZonePresentation {
    _castingVisible = NO;
    _armed = NO;
    [self updatePresentation];
}

- (void)setMobaLocalInteractionEnabled:(BOOL)enabled {
    _mobaLocalInteractionEnabled = enabled;
    [self updatePresentation];
}

- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason {
    (void)reason;
    MobaCancelZoneController *controller = self.controller;
    if (controller != nil) {
        [controller silentReset];
    }
    else {
        [self resetCancelZonePresentation];
    }
}

@end
