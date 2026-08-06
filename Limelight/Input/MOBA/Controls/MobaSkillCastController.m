//
//  MobaSkillCastController.m
//  Moonlight
//

#import "MobaSkillCastController.h"

#import "../Casting/MobaCastSession.h"
#import "../Casting/MobaCastStrategyFactory.h"
#import "../Casting/MobaDirectionalCastStrategy.h"
#import "../Casting/MobaInstantCastStrategy.h"
#import "../Casting/MobaPointCastStrategy.h"

#import <math.h>

const CGFloat MobaDirectionalMeaningfulDragDeadzoneRatio = 0.10;

@implementation MobaSkillCastController {
    __weak id<MobaBattleInputGate> _inputGate;
    __weak id<MobaSkillCancelZoneRouting> _cancelZoneRouter;
    MobaSkillRuntimeDescriptor *_descriptor;
    MobaCastSession *_session;
    BOOL _interactionEnabled;
    BOOL _pressed;
    BOOL _casting;
    BOOL _cancelZoneActive;
    id _activeTouchToken;
    CGPoint _initialStreamViewPoint;
    CGPoint _latestStreamViewPoint;
}

- (instancetype)initWithDescriptor:(MobaSkillRuntimeDescriptor *)descriptor
                          inputGate:(id<MobaBattleInputGate>)inputGate
                   cancelZoneRouter:(id<MobaSkillCancelZoneRouting>)cancelZoneRouter {
    if (descriptor == nil || inputGate == nil || cancelZoneRouter == nil) {
        return nil;
    }

    self = [super init];
    if (self) {
        _descriptor = descriptor;
        _inputGate = inputGate;
        _cancelZoneRouter = cancelZoneRouter;
        _session = [[MobaCastSession alloc] init];
        _interactionEnabled = YES;
    }
    return self;
}

- (MobaSkillRuntimeDescriptor *)descriptor { return _descriptor; }
- (MobaCastSession *)session { return _session; }
- (BOOL)isInteractionEnabled { return _interactionEnabled; }
- (BOOL)isPressed { return _pressed; }
- (BOOL)isCasting { return _casting; }
- (id)activeTouchToken { return _activeTouchToken; }
- (CGPoint)initialStreamViewPoint { return _initialStreamViewPoint; }
- (CGPoint)latestStreamViewPoint { return _latestStreamViewPoint; }

- (void)setInteractionEnabled:(BOOL)interactionEnabled {
    _interactionEnabled = interactionEnabled;
}

- (BOOL)isOwnerToken:(id)token {
    return token != nil && token == _activeTouchToken;
}

- (BOOL)pointIsFinite:(CGPoint)point {
    return isfinite(point.x) && isfinite(point.y);
}

- (BOOL)usesCancelZone {
    return _descriptor.castType != MobaProfileSkillCastTypeInstant && _descriptor.allowCancel;
}

- (void)clearLocalOwnership {
    _activeTouchToken = nil;
    _pressed = NO;
    _casting = NO;
    _cancelZoneActive = NO;
    _initialStreamViewPoint = CGPointZero;
    _latestStreamViewPoint = CGPointZero;
}

- (void)rollbackWithoutInputForToken:(id)token {
    [_descriptor.strategy silentReset];
    [_session silentReset];
    if (_cancelZoneActive) {
        [_cancelZoneRouter endCancelZonePresentationForCastToken:token];
    }
    [self clearLocalOwnership];
}

- (void)requestLifecycleCancellation {
    id<MobaSkillCastControllerDelegate> delegate = self.delegate;
    if (delegate != nil) {
        [delegate skillCastControllerDidRequestTouchCancellation:self];
    }
    // Lifecycle normally resets this participant synchronously. This fallback
    // guarantees no half-active local Session if a test or future host does not.
    if (_activeTouchToken != nil || _session.state != MobaCastStateIdle) {
        [self silentReset];
    }
}

- (BOOL)beginInteractionWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (!_interactionEnabled || !_inputGate.isBattleInputAllowed || token == nil ||
        _activeTouchToken != nil || ![self pointIsFinite:point]) {
        return NO;
    }

    MobaCastTransitionResult begin = [_session beginInteractionWithToken:token];
    if (!begin.accepted) {
        return NO;
    }

    _activeTouchToken = token;
    _initialStreamViewPoint = point;
    _latestStreamViewPoint = point;
    _casting = YES;

    if ([self usesCancelZone]) {
        if (![_cancelZoneRouter beginCancelZonePresentationForCastToken:token]) {
            [self rollbackWithoutInputForToken:token];
            [self requestLifecycleCancellation];
            return NO;
        }
        _cancelZoneActive = YES;
    }

    if (![_descriptor.strategy beginWithTransitionResult:begin]) {
        [self rollbackWithoutInputForToken:token];
        [self requestLifecycleCancellation];
        return NO;
    }

    _pressed = YES;
    return YES;
}

- (CGFloat)meaningfulDragDeadzoneRatio {
    MobaTouchResponseProfile *response = _descriptor.skillProfile.touchResponse;
    if (response != nil) {
        return response.deadzoneRatio;
    }
    return MobaDirectionalMeaningfulDragDeadzoneRatio;
}

- (BOOL)meaningfulDragForDisplacement:(CGVector)displacement {
    NSNumber *wheelRadiusValue = _descriptor.layoutControlProfile.wheelRadiusPt;
    if (_descriptor.castType == MobaProfileSkillCastTypeInstant || wheelRadiusValue == nil) {
        return NO;
    }
    CGFloat threshold = (CGFloat)wheelRadiusValue.doubleValue * [self meaningfulDragDeadzoneRatio];
    return hypot(displacement.dx, displacement.dy) > threshold;
}

- (BOOL)consumeStrategyUpdate:(MobaCastTransitionResult)result
                 displacement:(CGVector)displacement {
    switch (_descriptor.castType) {
        case MobaProfileSkillCastTypeInstant:
            return [(MobaInstantCastStrategy *)_descriptor.strategy updateWithTransitionResult:result];
        case MobaProfileSkillCastTypeDirectional:
            return [(MobaDirectionalCastStrategy *)_descriptor.strategy
                updateWithTransitionResult:result
                             dragDirection:displacement];
        case MobaProfileSkillCastTypePoint:
            return [(MobaPointCastStrategy *)_descriptor.strategy
                updateWithTransitionResult:result
                          dragDisplacement:displacement];
    }
    return NO;
}

- (BOOL)updateInteractionWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (!_interactionEnabled || !_inputGate.isBattleInputAllowed ||
        ![self isOwnerToken:token] || ![self pointIsFinite:point]) {
        return NO;
    }

    CGVector displacement = CGVectorMake(point.x - _initialStreamViewPoint.x,
                                         point.y - _initialStreamViewPoint.y);
    BOOL insideCancelZone = NO;
    if (_cancelZoneActive &&
        ![_cancelZoneRouter evaluateCancelZoneAtStreamViewPoint:point
                                                   forCastToken:token
                                              insideCancelZone:&insideCancelZone]) {
        [self requestLifecycleCancellation];
        return NO;
    }

    MobaCastTransitionResult result = [_session updateInteractionWithToken:token
                                                            meaningfulDrag:[self meaningfulDragForDisplacement:displacement]
                                                           insideCancelZone:insideCancelZone];
    if (!result.accepted) {
        return NO;
    }

    if (![self consumeStrategyUpdate:result displacement:displacement]) {
        [self requestLifecycleCancellation];
        return NO;
    }

    if (_cancelZoneActive &&
        ![_cancelZoneRouter applyCancelZoneTransitionResult:result forCastToken:token]) {
        [self requestLifecycleCancellation];
        return NO;
    }

    _latestStreamViewPoint = point;
    return YES;
}

- (BOOL)endInteractionWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (!_interactionEnabled || !_inputGate.isBattleInputAllowed ||
        ![self isOwnerToken:token] || ![self pointIsFinite:point]) {
        return NO;
    }

    MobaCastTransitionResult terminal = [_session releaseInteractionWithToken:token];
    if (!terminal.accepted || !terminal.producedTerminalOutcome) {
        [self requestLifecycleCancellation];
        return NO;
    }

    BOOL consumed = terminal.terminalOutcome == MobaCastTerminalOutcomeCancelled
        ? [_descriptor.strategy cancelWithTransitionResult:terminal]
        : [_descriptor.strategy commitWithTransitionResult:terminal];
    if (!consumed) {
        [self requestLifecycleCancellation];
        return NO;
    }

    if (_cancelZoneActive && ![_cancelZoneRouter endCancelZonePresentationForCastToken:token]) {
        [self requestLifecycleCancellation];
        return NO;
    }

    [_descriptor.strategy silentReset];
    [_session silentReset];
    [self clearLocalOwnership];
    return YES;
}

- (BOOL)cancelInteractionWithToken:(id)token {
    if (!_interactionEnabled || ![self isOwnerToken:token]) {
        return NO;
    }

    [self requestLifecycleCancellation];
    return YES;
}

- (void)silentReset {
    id token = _activeTouchToken;
    if (_cancelZoneActive && token != nil) {
        [_cancelZoneRouter endCancelZonePresentationForCastToken:token];
    }
    [_descriptor.strategy silentReset];
    [_session silentReset];
    [self clearLocalOwnership];
}

@end
