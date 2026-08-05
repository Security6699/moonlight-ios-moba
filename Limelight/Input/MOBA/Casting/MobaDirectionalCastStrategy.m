//
//  MobaDirectionalCastStrategy.m
//  Moonlight
//

#import "MobaDirectionalCastStrategy.h"

#import <math.h>

#import "../Core/MobaCursorCoalescer.h"
#import "../Core/MobaInputDispatcher.h"

static BOOL MobaDirectionalConfigurationScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

@implementation MobaDirectionalCastConfiguration

+ (instancetype)defaultConfigurationWithSkillKeyCode:(uint16_t)skillKeyCode
                                           heroAnchor:(CGPoint)heroAnchor
                                                radii:(MobaAimRadii)radii
                                         cancelAction:(MobaCastCancelAction *)cancelAction {
    return [[self alloc] initWithSkillKeyCode:skillKeyCode
                                  heroAnchor:heroAnchor
                                       radii:radii
                            defaultDirection:MobaAimDefaultUpDirection()
                        defaultDistanceRatio:1.0
                                cancelAction:cancelAction];
}

- (instancetype)initWithSkillKeyCode:(uint16_t)skillKeyCode
                           heroAnchor:(CGPoint)heroAnchor
                                radii:(MobaAimRadii)radii
                     defaultDirection:(CGVector)defaultDirection
                 defaultDistanceRatio:(CGFloat)defaultDistanceRatio
                         cancelAction:(MobaCastCancelAction *)cancelAction {
    CGFloat directionLength = hypot(defaultDirection.dx, defaultDirection.dy);
    if (cancelAction == nil ||
        !MobaDirectionalConfigurationScalarIsFinite(heroAnchor.x) ||
        !MobaDirectionalConfigurationScalarIsFinite(heroAnchor.y) ||
        !MobaDirectionalConfigurationScalarIsFinite(radii.leftPx) || radii.leftPx <= 0.0 ||
        !MobaDirectionalConfigurationScalarIsFinite(radii.rightPx) || radii.rightPx <= 0.0 ||
        !MobaDirectionalConfigurationScalarIsFinite(radii.upPx) || radii.upPx <= 0.0 ||
        !MobaDirectionalConfigurationScalarIsFinite(radii.downPx) || radii.downPx <= 0.0 ||
        !MobaDirectionalConfigurationScalarIsFinite(defaultDirection.dx) ||
        !MobaDirectionalConfigurationScalarIsFinite(defaultDirection.dy) ||
        !MobaDirectionalConfigurationScalarIsFinite(directionLength) || directionLength <= 0.0 ||
        !MobaDirectionalConfigurationScalarIsFinite(defaultDistanceRatio)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _skillKeyCode = skillKeyCode;
        _heroAnchor = heroAnchor;
        _aimRadii = radii;
        _defaultDirection = defaultDirection;
        _defaultDistanceRatio = defaultDistanceRatio;
        _cancelAction = cancelAction;
    }
    return self;
}

@end

@implementation MobaDirectionalCastStrategy {
    MobaInputDispatcher *_dispatcher;
    MobaDirectionalCastConfiguration *_configuration;
    id<MobaCursorCoalescing> _cursorCoalescer;
    BOOL _awaitingTerminalOutcome;
    BOOL _hasLatestTarget;
    CGPoint _latestTarget;
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaDirectionalCastConfiguration *)configuration {
    return [self initWithDispatcher:dispatcher
                      configuration:configuration
                    cursorCoalescer:nil];
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaDirectionalCastConfiguration *)configuration
                    cursorCoalescer:(id<MobaCursorCoalescing>)cursorCoalescer {
    NSParameterAssert(dispatcher != nil);
    NSParameterAssert(configuration != nil);

    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _configuration = configuration;
        _cursorCoalescer = cursorCoalescer;
    }
    return self;
}

- (BOOL)hasLatestTarget {
    return _hasLatestTarget;
}

- (CGPoint)latestTarget {
    return _latestTarget;
}

- (BOOL)beginWithTransitionResult:(MobaCastTransitionResult)result {
    if (_awaitingTerminalOutcome || !MobaCastTransitionIsAcceptedBegin(result)) {
        return NO;
    }

    CGPoint defaultTarget = CGPointZero;
    if (!MobaAimTargetForDirection(_configuration.heroAnchor,
                                   _configuration.defaultDirection,
                                   _configuration.aimRadii,
                                   _configuration.defaultDistanceRatio,
                                   &defaultTarget)) {
        return NO;
    }
    if (_cursorCoalescer != nil && ![_cursorCoalescer start]) {
        return NO;
    }

    _awaitingTerminalOutcome = YES;
    _hasLatestTarget = YES;
    _latestTarget = defaultTarget;
    [_dispatcher moveCursorToCanvasPoint:defaultTarget];
    [_dispatcher setKeyCode:_configuration.skillKeyCode down:YES];
    return YES;
}

- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result
                     dragDirection:(CGVector)dragDirection {
    if (!_awaitingTerminalOutcome || !MobaCastTransitionIsAcceptedUpdate(result)) {
        return NO;
    }

    CGPoint target = CGPointZero;
    if (!MobaAimTargetForDirection(_configuration.heroAnchor,
                                   dragDirection,
                                   _configuration.aimRadii,
                                   1.0,
                                   &target)) {
        return NO;
    }

    _hasLatestTarget = YES;
    _latestTarget = target;
    return _cursorCoalescer == nil || [_cursorCoalescer submitLatestPoint:target];
}

- (BOOL)commitWithTransitionResult:(MobaCastTransitionResult)result {
    if (!_awaitingTerminalOutcome || !_hasLatestTarget ||
        !MobaCastTransitionIsAcceptedTerminal(result, MobaCastTerminalOutcomeCommitted)) {
        return NO;
    }

    CGPoint finalTarget = _latestTarget;
    [_cursorCoalescer stopAndDiscardPending];
    [self clearLocalCastState];
    [_dispatcher commitFinalCursorPoint:finalTarget
                       releasingKeyCode:_configuration.skillKeyCode];
    return YES;
}

- (BOOL)cancelWithTransitionResult:(MobaCastTransitionResult)result {
    if (!_awaitingTerminalOutcome ||
        !MobaCastTransitionIsAcceptedTerminal(result, MobaCastTerminalOutcomeCancelled)) {
        return NO;
    }

    [_cursorCoalescer stopAndDiscardPending];
    [self clearLocalCastState];
    MobaCastDispatchCancelAction(_dispatcher,
                                 _configuration.cancelAction,
                                 _configuration.skillKeyCode);
    return YES;
}

- (void)clearLocalCastState {
    _awaitingTerminalOutcome = NO;
    _hasLatestTarget = NO;
    _latestTarget = CGPointZero;
}

- (void)silentReset {
    [_cursorCoalescer stopAndDiscardPending];
    [self clearLocalCastState];
}

@end
