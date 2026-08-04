//
//  MobaOverlayLifecycle.m
//  Moonlight
//

#import "MobaOverlayLifecycle.h"
#import "MobaInputDispatcher.h"

@implementation MobaOverlayLifecycle {
    __weak id<MobaOverlayLifecycleEnvironment> _environment;
    MobaInputDispatcher *_inputDispatcher;
    NSHashTable<id<MobaLocalInteractionResetParticipant>> *_resetParticipants;
    BOOL _running;
    BOOL _inputSuspended;
    BOOL _applicationActive;
    BOOL _streamConnected;
    BOOL _orientationTransitionInProgress;
    BOOL _profileReloadInProgress;
    MobaOverlayMode _mode;
}

- (instancetype)initWithEnvironment:(id<MobaOverlayLifecycleEnvironment>)environment
                     inputDispatcher:(MobaInputDispatcher *)inputDispatcher {
    self = [super init];
    if (self) {
        NSParameterAssert(environment != nil);
        NSParameterAssert(inputDispatcher != nil);

        _environment = environment;
        _inputDispatcher = inputDispatcher;
        _resetParticipants = [NSHashTable weakObjectsHashTable];
        _mode = [environment isMobaBattleModeSupported] ? MobaOverlayModeBattle : MobaOverlayModeUI;
        _inputSuspended = YES;
        _applicationActive = YES;
    }
    return self;
}

- (BOOL)isRunning {
    return _running;
}

- (BOOL)isInputSuspended {
    return _inputSuspended;
}

- (BOOL)isBattleInputAllowed {
    return _running &&
        _mode == MobaOverlayModeBattle &&
        [_environment isMobaBattleModeSupported] &&
        !_inputSuspended;
}

- (MobaOverlayMode)mode {
    return _mode;
}

- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    if (participant == nil) {
        return;
    }

    [_resetParticipants addObject:participant];
    if ([participant respondsToSelector:@selector(setMobaLocalInteractionEnabled:)]) {
        [participant setMobaLocalInteractionEnabled:[self isBattleInputAllowed]];
    }
}

- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    if (participant != nil) {
        [_resetParticipants removeObject:participant];
    }
}

- (void)setLocalInteractionEnabled:(BOOL)enabled {
    for (id<MobaLocalInteractionResetParticipant> participant in _resetParticipants.allObjects) {
        if ([participant respondsToSelector:@selector(setMobaLocalInteractionEnabled:)]) {
            [participant setMobaLocalInteractionEnabled:enabled];
        }
    }
}

- (void)resumeBattleInputIfAllowed {
    BOOL canResume = _running &&
        _streamConnected &&
        _applicationActive &&
        !_orientationTransitionInProgress &&
        !_profileReloadInProgress &&
        _mode == MobaOverlayModeBattle &&
        [_environment isMobaBattleModeSupported];
    _inputSuspended = !canResume;
    [self setLocalInteractionEnabled:[self isBattleInputAllowed]];
}

- (MobaInputInterruptionReason)interruptionReasonForMode:(MobaOverlayMode)mode {
    switch (mode) {
        case MobaOverlayModeUI:
            return MobaInputInterruptionReasonBattleToUI;
        case MobaOverlayModeLayoutEdit:
            return MobaInputInterruptionReasonBattleToLayoutEdit;
        case MobaOverlayModeSkillTuning:
            return MobaInputInterruptionReasonBattleToSkillTuning;
        case MobaOverlayModeBattle:
            return MobaInputInterruptionReasonTouchCancellation;
    }
    return MobaInputInterruptionReasonTouchCancellation;
}

- (BOOL)transitionToMode:(MobaOverlayMode)mode {
    if (mode == MobaOverlayModeBattle && ![_environment isMobaBattleModeSupported]) {
        return NO;
    }

    if (_mode == mode) {
        return YES;
    }

    if (_mode == MobaOverlayModeBattle) {
        [self interruptAndReleaseInputsForReason:[self interruptionReasonForMode:mode]];
    }

    _mode = mode;
    if (mode == MobaOverlayModeBattle) {
        [self resumeBattleInputIfAllowed];
    }
    else {
        _inputSuspended = YES;
        [self setLocalInteractionEnabled:NO];
    }
    return YES;
}

- (void)start {
    if (_running) {
        return;
    }

    _running = YES;
    _streamConnected = YES;
    _orientationTransitionInProgress = NO;
    _profileReloadInProgress = NO;
    [_environment setTraditionalOnScreenControlsSuppressed:YES];
    [self resumeBattleInputIfAllowed];
}

- (void)stopForReason:(MobaInputInterruptionReason)reason {
    if (_running) {
        [self interruptAndReleaseInputsForReason:reason];
        _running = NO;
        _streamConnected = NO;
        _inputSuspended = YES;
        [self setLocalInteractionEnabled:NO];
    }

    [_environment setTraditionalOnScreenControlsSuppressed:NO];
}

- (void)stop {
    [self stopForReason:MobaInputInterruptionReasonCoordinatorStop];
}

- (void)invalidateForDestruction {
    [self stopForReason:MobaInputInterruptionReasonCoordinatorDestruction];
}

- (BOOL)interruptAndReleaseInputsForReason:(MobaInputInterruptionReason)reason {
    if (_inputSuspended) {
        return NO;
    }

    // This synchronous gate closes before release-all is enqueued so no new
    // diagnostics or future Battle control can submit input during interruption.
    _inputSuspended = YES;
    [self setLocalInteractionEnabled:NO];
    [_inputDispatcher releaseAllInputs];

    for (id<MobaLocalInteractionResetParticipant> participant in _resetParticipants.allObjects) {
        [participant resetMobaLocalInteractionForReason:reason];
    }
    return YES;
}

- (void)touchesCancelled {
    [self interruptAndReleaseInputsForReason:MobaInputInterruptionReasonTouchCancellation];
    [self resumeBattleInputIfAllowed];
}

- (void)applicationWillResignActive {
    _applicationActive = NO;
    [self interruptAndReleaseInputsForReason:MobaInputInterruptionReasonApplicationWillResignActive];
}

- (void)applicationDidEnterBackground {
    _applicationActive = NO;
    [self interruptAndReleaseInputsForReason:MobaInputInterruptionReasonApplicationDidEnterBackground];
}

- (void)applicationDidBecomeActive {
    _applicationActive = YES;
    [self resumeBattleInputIfAllowed];
}

- (void)streamDidDisconnect {
    _streamConnected = NO;
    [self stopForReason:MobaInputInterruptionReasonStreamDisconnectOrTeardown];
}

- (void)viewControllerWillDisappear {
    [self stopForReason:MobaInputInterruptionReasonViewControllerDisappearance];
}

- (void)orientationWillChange {
    _orientationTransitionInProgress = YES;
    [self interruptAndReleaseInputsForReason:MobaInputInterruptionReasonOrientationChange];
}

- (void)orientationDidChange {
    _orientationTransitionInProgress = NO;
    [self resumeBattleInputIfAllowed];
}

- (void)profileWillReload {
    _profileReloadInProgress = YES;
    [self interruptAndReleaseInputsForReason:MobaInputInterruptionReasonProfileReload];
}

- (void)profileDidReload {
    _profileReloadInProgress = NO;
    [self resumeBattleInputIfAllowed];
}

- (void)mobaFeatureWillDisable {
    [self stopForReason:MobaInputInterruptionReasonFeatureDisable];
}

@end
