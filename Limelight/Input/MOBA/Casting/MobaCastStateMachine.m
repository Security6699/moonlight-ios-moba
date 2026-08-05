//
//  MobaCastStateMachine.m
//  Moonlight
//

#import "MobaCastStateMachine.h"

static MobaCastTransitionResult MobaCastTransitionResultMake(BOOL accepted,
                                                             MobaCastState previousState,
                                                             MobaCastState currentState,
                                                             MobaCastTerminalOutcome outcome) {
    MobaCastTransitionResult result;
    result.accepted = accepted;
    result.previousState = previousState;
    result.currentState = currentState;
    result.producedTerminalOutcome = outcome != MobaCastTerminalOutcomeNone;
    result.terminalOutcome = outcome;
    return result;
}

MobaCastTransitionResult MobaCastRejectedTransitionResult(MobaCastState state) {
    return MobaCastTransitionResultMake(NO,
                                        state,
                                        state,
                                        MobaCastTerminalOutcomeNone);
}

@implementation MobaCastStateMachine {
    MobaCastState _state;
    BOOL _meaningfulDrag;
    BOOL _insideCancelZone;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = MobaCastStateIdle;
    }
    return self;
}

- (MobaCastState)state {
    return _state;
}

- (BOOL)isActiveState:(MobaCastState)state {
    return state == MobaCastStateAimingDefault ||
        state == MobaCastStateAimingDragged ||
        state == MobaCastStateCancelArmed;
}

- (MobaCastTransitionResult)transitionToState:(MobaCastState)state
                                      outcome:(MobaCastTerminalOutcome)outcome {
    MobaCastState previousState = _state;
    _state = state;
    return MobaCastTransitionResultMake(YES, previousState, state, outcome);
}

- (MobaCastTransitionResult)begin {
    if (_state != MobaCastStateIdle) {
        return MobaCastRejectedTransitionResult(_state);
    }

    _meaningfulDrag = NO;
    _insideCancelZone = NO;
    return [self transitionToState:MobaCastStateAimingDefault
                           outcome:MobaCastTerminalOutcomeNone];
}

- (MobaCastTransitionResult)dragBecameMeaningful {
    if (![self isActiveState:_state]) {
        return MobaCastRejectedTransitionResult(_state);
    }

    _meaningfulDrag = YES;
    MobaCastState nextState = _insideCancelZone ? MobaCastStateCancelArmed : MobaCastStateAimingDragged;
    return [self transitionToState:nextState outcome:MobaCastTerminalOutcomeNone];
}

- (MobaCastTransitionResult)dragReturnedBelowMeaningfulThreshold {
    if (![self isActiveState:_state]) {
        return MobaCastRejectedTransitionResult(_state);
    }

    _meaningfulDrag = NO;
    MobaCastState nextState = _insideCancelZone ? MobaCastStateCancelArmed : MobaCastStateAimingDefault;
    return [self transitionToState:nextState outcome:MobaCastTerminalOutcomeNone];
}

- (MobaCastTransitionResult)enterCancelZone {
    if (_state != MobaCastStateAimingDefault && _state != MobaCastStateAimingDragged) {
        return MobaCastRejectedTransitionResult(_state);
    }

    _meaningfulDrag = _state == MobaCastStateAimingDragged;
    _insideCancelZone = YES;
    return [self transitionToState:MobaCastStateCancelArmed
                           outcome:MobaCastTerminalOutcomeNone];
}

- (MobaCastTransitionResult)exitCancelZone {
    if (_state != MobaCastStateCancelArmed) {
        return MobaCastRejectedTransitionResult(_state);
    }

    _insideCancelZone = NO;
    MobaCastState nextState = _meaningfulDrag ? MobaCastStateAimingDragged : MobaCastStateAimingDefault;
    return [self transitionToState:nextState outcome:MobaCastTerminalOutcomeNone];
}

- (MobaCastTransitionResult)updateWithMeaningfulDrag:(BOOL)meaningfulDrag
                                    insideCancelZone:(BOOL)insideCancelZone {
    if (![self isActiveState:_state]) {
        return MobaCastRejectedTransitionResult(_state);
    }

    _meaningfulDrag = meaningfulDrag;
    _insideCancelZone = insideCancelZone;
    MobaCastState nextState;
    if (insideCancelZone) {
        nextState = MobaCastStateCancelArmed;
    }
    else {
        nextState = _meaningfulDrag ? MobaCastStateAimingDragged : MobaCastStateAimingDefault;
    }
    return [self transitionToState:nextState outcome:MobaCastTerminalOutcomeNone];
}

- (MobaCastTransitionResult)releaseNormally {
    if (![self isActiveState:_state]) {
        return MobaCastRejectedTransitionResult(_state);
    }

    if (_state == MobaCastStateCancelArmed) {
        return [self transitionToState:MobaCastStateCancelled
                               outcome:MobaCastTerminalOutcomeCancelled];
    }
    return [self transitionToState:MobaCastStateCommitted
                           outcome:MobaCastTerminalOutcomeCommitted];
}

- (MobaCastTransitionResult)cancelActiveCast {
    if (![self isActiveState:_state]) {
        return MobaCastRejectedTransitionResult(_state);
    }
    return [self transitionToState:MobaCastStateCancelled
                           outcome:MobaCastTerminalOutcomeCancelled];
}

- (MobaCastTransitionResult)cancelForTouchCancellation {
    return [self cancelActiveCast];
}

- (MobaCastTransitionResult)interrupt {
    return [self cancelActiveCast];
}

- (MobaCastTransitionResult)reset {
    MobaCastState previousState = _state;
    _state = MobaCastStateIdle;
    _meaningfulDrag = NO;
    _insideCancelZone = NO;
    return MobaCastTransitionResultMake(YES,
                                        previousState,
                                        MobaCastStateIdle,
                                        MobaCastTerminalOutcomeNone);
}

@end
