//
//  MobaCastSession.m
//  Moonlight
//

#import "MobaCastSession.h"

@implementation MobaCastSession {
    MobaCastStateMachine *_stateMachine;
    id _activeInteractionToken;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _stateMachine = [[MobaCastStateMachine alloc] init];
    }
    return self;
}

- (MobaCastState)state {
    return _stateMachine.state;
}

- (id)activeInteractionToken {
    return _activeInteractionToken;
}

- (MobaCastTransitionResult)rejectedResult {
    return MobaCastRejectedTransitionResult(_stateMachine.state);
}

- (BOOL)isOwnerToken:(id)token {
    return token != nil && token == _activeInteractionToken;
}

- (MobaCastTransitionResult)beginInteractionWithToken:(id)token {
    if (token == nil || _activeInteractionToken != nil) {
        return [self rejectedResult];
    }

    MobaCastTransitionResult result = [_stateMachine begin];
    if (result.accepted) {
        _activeInteractionToken = token;
    }
    return result;
}

- (MobaCastTransitionResult)updateInteractionWithToken:(id)token
                                        meaningfulDrag:(BOOL)meaningfulDrag
                                       insideCancelZone:(BOOL)insideCancelZone {
    if (![self isOwnerToken:token]) {
        return [self rejectedResult];
    }
    return [_stateMachine updateWithMeaningfulDrag:meaningfulDrag
                                  insideCancelZone:insideCancelZone];
}

- (MobaCastTransitionResult)releaseInteractionWithToken:(id)token {
    if (![self isOwnerToken:token]) {
        return [self rejectedResult];
    }

    MobaCastTransitionResult result = [_stateMachine releaseNormally];
    if (result.producedTerminalOutcome) {
        _activeInteractionToken = nil;
    }
    return result;
}

- (MobaCastTransitionResult)cancelInteractionWithToken:(id)token {
    if (![self isOwnerToken:token]) {
        return [self rejectedResult];
    }

    MobaCastTransitionResult result = [_stateMachine cancelForTouchCancellation];
    if (result.producedTerminalOutcome) {
        _activeInteractionToken = nil;
    }
    return result;
}

- (MobaCastTransitionResult)interrupt {
    MobaCastTransitionResult result = [_stateMachine interrupt];
    if (result.producedTerminalOutcome) {
        _activeInteractionToken = nil;
    }
    return result;
}

- (MobaCastTransitionResult)silentReset {
    _activeInteractionToken = nil;
    return [_stateMachine reset];
}

@end
