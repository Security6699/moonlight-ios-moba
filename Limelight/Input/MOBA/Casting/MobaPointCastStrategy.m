//
//  MobaPointCastStrategy.m
//  Moonlight
//

#import "MobaPointCastStrategy.h"

#import <math.h>

#import "../Core/MobaInputDispatcher.h"
#import "../Geometry/MobaPointCastGeometry.h"
#import "../Geometry/MobaPointResponse.h"

static BOOL MobaPointCastConfigurationScalarIsFinite(CGFloat value) {
    return isfinite(value);
}

static BOOL MobaPointCastTargetModeIsValid(MobaPointCastTargetMode targetMode) {
    return targetMode == MobaPointCastTargetModeGround ||
        targetMode == MobaPointCastTargetModeUnit;
}

static BOOL MobaPointCastConfigurationRadiiAreValid(MobaAimRadii minimumRadii,
                                                    MobaAimRadii maximumRadii) {
    return MobaPointCastConfigurationScalarIsFinite(minimumRadii.leftPx) && minimumRadii.leftPx >= 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(minimumRadii.rightPx) && minimumRadii.rightPx >= 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(minimumRadii.upPx) && minimumRadii.upPx >= 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(minimumRadii.downPx) && minimumRadii.downPx >= 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(maximumRadii.leftPx) && maximumRadii.leftPx > 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(maximumRadii.rightPx) && maximumRadii.rightPx > 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(maximumRadii.upPx) && maximumRadii.upPx > 0.0 &&
        MobaPointCastConfigurationScalarIsFinite(maximumRadii.downPx) && maximumRadii.downPx > 0.0 &&
        minimumRadii.leftPx <= maximumRadii.leftPx &&
        minimumRadii.rightPx <= maximumRadii.rightPx &&
        minimumRadii.upPx <= maximumRadii.upPx &&
        minimumRadii.downPx <= maximumRadii.downPx;
}

@implementation MobaPointCastConfiguration

+ (instancetype)defaultConfigurationWithTargetMode:(MobaPointCastTargetMode)targetMode
                                       skillKeyCode:(uint16_t)skillKeyCode
                                         heroAnchor:(CGPoint)heroAnchor
                                        wheelRadius:(CGFloat)wheelRadius
                                      deadzoneRatio:(CGFloat)deadzoneRatio
                                     fullRangeRatio:(CGFloat)fullRangeRatio
                                      curveExponent:(CGFloat)curveExponent
                                       minimumRadii:(MobaAimRadii)minimumRadii
                                       maximumRadii:(MobaAimRadii)maximumRadii
                                        cancelAction:(MobaCastCancelAction *)cancelAction {
    return [[self alloc] initWithTargetMode:targetMode
                              skillKeyCode:skillKeyCode
                                heroAnchor:heroAnchor
                          defaultDirection:MobaAimDefaultUpDirection()
                      defaultDistanceRatio:1.0
                               wheelRadius:wheelRadius
                             deadzoneRatio:deadzoneRatio
                            fullRangeRatio:fullRangeRatio
                             curveExponent:curveExponent
                              minimumRadii:minimumRadii
                              maximumRadii:maximumRadii
                               cancelAction:cancelAction];
}

- (instancetype)initWithTargetMode:(MobaPointCastTargetMode)targetMode
                       skillKeyCode:(uint16_t)skillKeyCode
                         heroAnchor:(CGPoint)heroAnchor
                   defaultDirection:(CGVector)defaultDirection
               defaultDistanceRatio:(CGFloat)defaultDistanceRatio
                        wheelRadius:(CGFloat)wheelRadius
                      deadzoneRatio:(CGFloat)deadzoneRatio
                     fullRangeRatio:(CGFloat)fullRangeRatio
                      curveExponent:(CGFloat)curveExponent
                       minimumRadii:(MobaAimRadii)minimumRadii
                       maximumRadii:(MobaAimRadii)maximumRadii
                        cancelAction:(MobaCastCancelAction *)cancelAction {
    CGFloat directionLength = hypot(defaultDirection.dx, defaultDirection.dy);
    if (!MobaPointCastTargetModeIsValid(targetMode) ||
        cancelAction == nil ||
        !MobaPointCastConfigurationScalarIsFinite(heroAnchor.x) ||
        !MobaPointCastConfigurationScalarIsFinite(heroAnchor.y) ||
        !MobaPointCastConfigurationScalarIsFinite(defaultDirection.dx) ||
        !MobaPointCastConfigurationScalarIsFinite(defaultDirection.dy) ||
        !MobaPointCastConfigurationScalarIsFinite(directionLength) || directionLength <= 0.0 ||
        !MobaPointCastConfigurationScalarIsFinite(defaultDistanceRatio) ||
        !MobaPointCastConfigurationScalarIsFinite(wheelRadius) || wheelRadius <= 0.0 ||
        !MobaPointCastConfigurationScalarIsFinite(deadzoneRatio) || deadzoneRatio < 0.0 ||
        !MobaPointCastConfigurationScalarIsFinite(fullRangeRatio) || fullRangeRatio <= deadzoneRatio ||
        !MobaPointCastConfigurationScalarIsFinite(curveExponent) || curveExponent <= 0.0 ||
        !MobaPointCastConfigurationRadiiAreValid(minimumRadii, maximumRadii)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _targetMode = targetMode;
        _skillKeyCode = skillKeyCode;
        _heroAnchor = heroAnchor;
        _defaultDirection = defaultDirection;
        _defaultDistanceRatio = defaultDistanceRatio;
        _wheelRadius = wheelRadius;
        _deadzoneRatio = deadzoneRatio;
        _fullRangeRatio = fullRangeRatio;
        _curveExponent = curveExponent;
        _minimumRadii = minimumRadii;
        _maximumRadii = maximumRadii;
        _cancelAction = cancelAction;
    }
    return self;
}

@end

@implementation MobaPointCastStrategy {
    MobaInputDispatcher *_dispatcher;
    MobaPointCastConfiguration *_configuration;
    BOOL _awaitingTerminalOutcome;
    BOOL _hasDefaultTarget;
    CGPoint _defaultTarget;
    BOOL _hasLatestTarget;
    CGPoint _latestTarget;
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaPointCastConfiguration *)configuration {
    NSParameterAssert(dispatcher != nil);
    NSParameterAssert(configuration != nil);

    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _configuration = configuration;
    }
    return self;
}

- (MobaPointCastTargetMode)targetMode {
    return _configuration.targetMode;
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
    if (!MobaPointCastTargetForDirection(_configuration.heroAnchor,
                                         _configuration.defaultDirection,
                                         _configuration.minimumRadii,
                                         _configuration.maximumRadii,
                                         _configuration.defaultDistanceRatio,
                                         &defaultTarget)) {
        return NO;
    }

    _awaitingTerminalOutcome = YES;
    _hasDefaultTarget = YES;
    _defaultTarget = defaultTarget;
    _hasLatestTarget = YES;
    _latestTarget = defaultTarget;
    [_dispatcher moveCursorToCanvasPoint:defaultTarget];
    [_dispatcher setKeyCode:_configuration.skillKeyCode down:YES];
    return YES;
}

- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result
                  dragDisplacement:(CGVector)dragDisplacement {
    if (!_awaitingTerminalOutcome ||
        !_hasDefaultTarget ||
        !MobaCastTransitionIsAcceptedUpdate(result)) {
        return NO;
    }

    if (result.currentState == MobaCastStateAimingDefault) {
        [self restoreDefaultTarget];
        return YES;
    }
    if (result.currentState == MobaCastStateCancelArmed) {
        return YES;
    }
    if (result.currentState != MobaCastStateAimingDragged ||
        !MobaPointCastConfigurationScalarIsFinite(dragDisplacement.dx) ||
        !MobaPointCastConfigurationScalarIsFinite(dragDisplacement.dy)) {
        return NO;
    }

    CGFloat dragDistance = hypot(dragDisplacement.dx, dragDisplacement.dy);
    if (!MobaPointCastConfigurationScalarIsFinite(dragDistance) || dragDistance <= 0.0) {
        return NO;
    }
    CGFloat distanceRatio = 0.0;
    if (!MobaPointResponseDistanceRatio(dragDistance,
                                        _configuration.wheelRadius,
                                        _configuration.deadzoneRatio,
                                        _configuration.fullRangeRatio,
                                        _configuration.curveExponent,
                                        &distanceRatio)) {
        return NO;
    }

    // Session meaningful-drag and Point Response dead-zone thresholds may
    // differ. A zero response always restores this cast's default target.
    if (distanceRatio <= 0.0) {
        [self restoreDefaultTarget];
        return YES;
    }

    CGPoint target = CGPointZero;
    if (!MobaPointCastTargetForDirection(_configuration.heroAnchor,
                                         dragDisplacement,
                                         _configuration.minimumRadii,
                                         _configuration.maximumRadii,
                                         distanceRatio,
                                         &target)) {
        return NO;
    }

    _hasLatestTarget = YES;
    _latestTarget = target;
    return YES;
}

- (void)restoreDefaultTarget {
    _hasLatestTarget = YES;
    _latestTarget = _defaultTarget;
}

- (BOOL)commitWithTransitionResult:(MobaCastTransitionResult)result {
    if (!_awaitingTerminalOutcome || !_hasLatestTarget ||
        !MobaCastTransitionIsAcceptedTerminal(result, MobaCastTerminalOutcomeCommitted)) {
        return NO;
    }

    CGPoint finalTarget = _latestTarget;
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

    [self clearLocalCastState];
    MobaCastDispatchCancelAction(_dispatcher,
                                 _configuration.cancelAction,
                                 _configuration.skillKeyCode);
    return YES;
}

- (void)clearLocalCastState {
    _awaitingTerminalOutcome = NO;
    _hasDefaultTarget = NO;
    _defaultTarget = CGPointZero;
    _hasLatestTarget = NO;
    _latestTarget = CGPointZero;
}

- (void)silentReset {
    [self clearLocalCastState];
}

@end
