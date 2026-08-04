//
//  MobaOverlayCoordinator.m
//  Moonlight
//

#import "MobaOverlayCoordinator.h"
#import "MobaCursorDiagnostics.h"
#import "MobaInputDispatcher.h"
#import "MoonlightMobaInputAdapter.h"
#import "MoonlightMobaInputSender.h"
#import "StreamView.h"

#if DEBUG
#import "../Debug/MobaCursorDiagnosticPanel.h"
#endif

@interface MobaOverlayCoordinator () <MobaBattleInputGate>
@end

@implementation MobaOverlayCoordinator {
    __weak StreamView *_streamView;
    MobaInputDispatcher *_inputDispatcher;
    MobaOverlayLifecycle *_lifecycle;
    MobaCursorDiagnostics *_cursorDiagnostics;
#if DEBUG
    MobaCursorDiagnosticPanel *_cursorDiagnosticPanel;
#endif
}

- (instancetype)initWithStreamView:(StreamView *)streamView {
    self = [super init];
    if (self) {
        _streamView = streamView;
        MoonlightMobaInputSender *sender = [[MoonlightMobaInputSender alloc] init];
        MoonlightMobaInputAdapter *adapter = [[MoonlightMobaInputAdapter alloc] initWithSender:sender];
        _inputDispatcher = [[MobaInputDispatcher alloc] initWithSink:adapter];
        _lifecycle = [[MobaOverlayLifecycle alloc] initWithEnvironment:(id<MobaOverlayLifecycleEnvironment>)streamView
                                                       inputDispatcher:_inputDispatcher];
        _cursorDiagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:_inputDispatcher
                                                                     inputGate:self];
#if DEBUG
        _cursorDiagnosticPanel = [[MobaCursorDiagnosticPanel alloc] initWithDiagnostics:_cursorDiagnostics];
        [_lifecycle registerLocalInteractionResetParticipant:_cursorDiagnosticPanel];
#endif
    }
    return self;
}

- (BOOL)isRunning {
    return _lifecycle.isRunning;
}

- (MobaOverlayMode)mode {
    return _lifecycle.mode;
}

- (void)setMode:(MobaOverlayMode)mode {
    [self transitionToMode:mode];
}

- (BOOL)isBattleModeAvailable {
    return [_streamView isMobaBattleModeSupported];
}

- (BOOL)isBattleInputAllowed {
    return _lifecycle.isBattleInputAllowed;
}

- (BOOL)isInputSuspended {
    return _lifecycle.isInputSuspended;
}

- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    [_lifecycle registerLocalInteractionResetParticipant:participant];
}

- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    [_lifecycle unregisterLocalInteractionResetParticipant:participant];
}

- (BOOL)transitionToMode:(MobaOverlayMode)mode {
    return [_lifecycle transitionToMode:mode];
}

- (void)start {
    if (_lifecycle.isRunning) {
        return;
    }

#if DEBUG
    if (_cursorDiagnosticPanel.superview == nil) {
        [_streamView addSubview:_cursorDiagnosticPanel];
        UILayoutGuide *safeArea = _streamView.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [_cursorDiagnosticPanel.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8.0],
            [_cursorDiagnosticPanel.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        ]];
    }
#endif
    [_lifecycle start];
}

- (void)stop {
    [_lifecycle stop];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (BOOL)interruptAndReleaseInputsForReason:(MobaInputInterruptionReason)reason {
    return [_lifecycle interruptAndReleaseInputsForReason:reason];
}

- (void)touchesCancelled {
    [_lifecycle touchesCancelled];
}

- (void)applicationWillResignActive {
    [_lifecycle applicationWillResignActive];
}

- (void)applicationDidEnterBackground {
    [_lifecycle applicationDidEnterBackground];
}

- (void)applicationDidBecomeActive {
    [_lifecycle applicationDidBecomeActive];
}

- (void)streamDidDisconnect {
    [_lifecycle streamDidDisconnect];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)viewControllerWillDisappear {
    [_lifecycle viewControllerWillDisappear];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)orientationWillChange {
    [_lifecycle orientationWillChange];
}

- (void)orientationDidChange {
    [_lifecycle orientationDidChange];
}

- (void)profileWillReload {
    [_lifecycle profileWillReload];
}

- (void)profileDidReload {
    [_lifecycle profileDidReload];
}

- (void)mobaFeatureWillDisable {
    [_lifecycle mobaFeatureWillDisable];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)dealloc {
    [_lifecycle invalidateForDestruction];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

@end
