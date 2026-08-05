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
#import "../Controls/MobaMovementController.h"
#import "../Controls/MoveJoystickView.h"

#if DEBUG
#import "../Debug/MobaCursorDiagnosticPanel.h"
#endif

static const CGFloat MobaDefaultMoveCenterX = 0.14;
static const CGFloat MobaDefaultMoveCenterY = 0.82;

@interface MobaOverlayCoordinator () <MobaBattleInputGate, MobaMovementControllerDelegate>
@end

@implementation MobaOverlayCoordinator {
    __weak StreamView *_streamView;
    MobaInputDispatcher *_inputDispatcher;
    MobaOverlayLifecycle *_lifecycle;
    MobaCursorDiagnostics *_cursorDiagnostics;
    MobaMovementController *_movementController;
    MoveJoystickView *_moveJoystickView;
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
        _movementController = [[MobaMovementController alloc]
            initWithInputDispatcher:_inputDispatcher
                         keyMapping:MobaDefaultMovementKeyMapping()
                        wheelRadius:MoveJoystickDefaultWheelRadius
                      deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
         directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
        _movementController.delegate = self;
        _moveJoystickView = [[MoveJoystickView alloc] initWithMovementController:_movementController];
        [_lifecycle registerLocalInteractionResetParticipant:_moveJoystickView];
        _cursorDiagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:_inputDispatcher
                                                                     inputGate:self];
#if DEBUG
        _cursorDiagnosticPanel = [[MobaCursorDiagnosticPanel alloc] initWithDiagnostics:_cursorDiagnostics];
        [_lifecycle registerLocalInteractionResetParticipant:_cursorDiagnosticPanel];
#endif
    }
    return self;
}

- (void)layoutMoveJoystick {
    [_streamView layoutIfNeeded];
    CGRect safeFrame = _streamView.safeAreaLayoutGuide.layoutFrame;
    CGSize hitAreaSize = _moveJoystickView.intrinsicContentSize;
    _moveJoystickView.bounds = (CGRect){ CGPointZero, hitAreaSize };
    _moveJoystickView.center = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * MobaDefaultMoveCenterX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * MobaDefaultMoveCenterY);
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

    if (_moveJoystickView.superview == nil) {
        [_streamView addSubview:_moveJoystickView];
    }
    [self layoutMoveJoystick];

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
    [_moveJoystickView removeFromSuperview];
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
    [_moveJoystickView removeFromSuperview];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)viewControllerWillDisappear {
    [_lifecycle viewControllerWillDisappear];
    [_moveJoystickView removeFromSuperview];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)orientationWillChange {
    [_lifecycle orientationWillChange];
}

- (void)orientationDidChange {
    [self layoutMoveJoystick];
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
    [_moveJoystickView removeFromSuperview];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)movementControllerDidRequestTouchCancellation:(MobaMovementController *)controller {
    (void)controller;
    [_lifecycle touchesCancelled];
}

- (void)dealloc {
    [_lifecycle invalidateForDestruction];
    [_moveJoystickView removeFromSuperview];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

@end
