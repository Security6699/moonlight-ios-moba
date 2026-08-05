//
//  MobaCancelZoneController.m
//  Moonlight
//

#import "MobaCancelZoneController.h"

static BOOL MobaCancelZoneStateIsActive(MobaCastState state) {
    return state == MobaCastStateAimingDefault ||
        state == MobaCastStateAimingDragged ||
        state == MobaCastStateCancelArmed;
}

@implementation MobaCancelZoneController {
    MobaCancelZoneGeometry _geometry;
    BOOL _castingActive;
    BOOL _armed;
    id _activeCastToken;
}

- (instancetype)initWithGeometry:(MobaCancelZoneGeometry)geometry
                      presentation:(id<MobaCancelZonePresenting>)presentation {
    if (!MobaCancelZoneGeometryIsValid(geometry)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _geometry = geometry;
        _presentation = presentation;
    }
    return self;
}

- (MobaCancelZoneGeometry)geometry {
    return _geometry;
}

- (BOOL)isCastingActive {
    return _castingActive;
}

- (BOOL)isArmed {
    return _armed;
}

- (id)activeCastToken {
    return _activeCastToken;
}

- (BOOL)isOwnerToken:(id)token {
    return token != nil && token == _activeCastToken;
}

- (BOOL)updateGeometry:(MobaCancelZoneGeometry)geometry {
    if (!MobaCancelZoneGeometryIsValid(geometry)) {
        return NO;
    }
    _geometry = geometry;
    return YES;
}

- (BOOL)beginCastingWithToken:(id)token {
    if (token == nil || _activeCastToken != nil) {
        return NO;
    }

    _activeCastToken = token;
    _castingActive = YES;
    _armed = NO;
    [self.presentation setCancelZoneCastingVisible:YES];
    [self.presentation setCancelZoneArmed:NO];
    return YES;
}

- (BOOL)evaluatePoint:(CGPoint)point
              forToken:(id)token
      insideCancelZone:(BOOL *)insideCancelZone {
    if (!_castingActive || ![self isOwnerToken:token]) {
        return NO;
    }
    return MobaCancelZoneContainsPoint(_geometry, point, insideCancelZone);
}

- (BOOL)applyAcceptedTransitionResult:(MobaCastTransitionResult)result
                              forToken:(id)token {
    if (!_castingActive ||
        ![self isOwnerToken:token] ||
        !result.accepted ||
        !MobaCancelZoneStateIsActive(result.previousState) ||
        !MobaCancelZoneStateIsActive(result.currentState) ||
        result.producedTerminalOutcome ||
        result.terminalOutcome != MobaCastTerminalOutcomeNone) {
        return NO;
    }

    BOOL armed;
    switch (result.currentState) {
        case MobaCastStateCancelArmed:
            armed = YES;
            break;
        case MobaCastStateAimingDefault:
        case MobaCastStateAimingDragged:
            armed = NO;
            break;
        case MobaCastStateIdle:
        case MobaCastStateCommitted:
        case MobaCastStateCancelled:
            return NO;
    }

    _armed = armed;
    [self.presentation setCancelZoneArmed:armed];
    return YES;
}

- (BOOL)endCastingWithToken:(id)token {
    if (!_castingActive || ![self isOwnerToken:token]) {
        return NO;
    }

    [self clearLocalState];
    [self.presentation resetCancelZonePresentation];
    return YES;
}

- (void)clearLocalState {
    _activeCastToken = nil;
    _castingActive = NO;
    _armed = NO;
}

- (void)silentReset {
    if (!_castingActive && !_armed && _activeCastToken == nil) {
        return;
    }
    [self clearLocalState];
    [self.presentation resetCancelZonePresentation];
}

@end
