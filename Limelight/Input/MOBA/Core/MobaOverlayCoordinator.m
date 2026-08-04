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
- (void)updateDiagnosticPanelVisibility;
@end

@implementation MobaOverlayCoordinator {
    __weak StreamView *_streamView;
    MobaInputDispatcher *_inputDispatcher;
    MobaCursorDiagnostics *_cursorDiagnostics;
#if DEBUG
    MobaCursorDiagnosticPanel *_cursorDiagnosticPanel;
#endif
    BOOL _running;
}

- (instancetype)initWithStreamView:(StreamView *)streamView {
    self = [super init];
    if (self) {
        _streamView = streamView;
        _mode = [streamView isMobaBattleModeSupported] ? MobaOverlayModeBattle : MobaOverlayModeUI;

        MoonlightMobaInputSender *sender = [[MoonlightMobaInputSender alloc] init];
        MoonlightMobaInputAdapter *adapter = [[MoonlightMobaInputAdapter alloc] initWithSender:sender];
        _inputDispatcher = [[MobaInputDispatcher alloc] initWithSink:adapter];
        _cursorDiagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:_inputDispatcher
                                                                     inputGate:self];
#if DEBUG
        _cursorDiagnosticPanel = [[MobaCursorDiagnosticPanel alloc] initWithDiagnostics:_cursorDiagnostics];
#endif
    }
    return self;
}

- (BOOL)isRunning {
    return _running;
}

- (void)setMode:(MobaOverlayMode)mode {
    [self transitionToMode:mode];
}

- (BOOL)isBattleModeAvailable {
    return [_streamView isMobaBattleModeSupported];
}

- (BOOL)isBattleInputAllowed {
    return _running && _mode == MobaOverlayModeBattle && [self isBattleModeAvailable];
}

- (BOOL)transitionToMode:(MobaOverlayMode)mode {
    if (mode == MobaOverlayModeBattle && ![self isBattleModeAvailable]) {
        return NO;
    }

    if (_mode == mode) {
        [self updateDiagnosticPanelVisibility];
        return YES;
    }

    _mode = mode;
    [self updateDiagnosticPanelVisibility];
    return YES;
}

- (void)start {
    if (_running) {
        return;
    }

    _running = YES;
    [_streamView setTraditionalOnScreenControlsSuppressed:YES];

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
    [self updateDiagnosticPanelVisibility];
}

- (void)stop {
    if (!_running) {
        return;
    }

    _running = NO;
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
    [_streamView setTraditionalOnScreenControlsSuppressed:NO];
}

- (void)updateDiagnosticPanelVisibility {
#if DEBUG
    _cursorDiagnosticPanel.hidden = ![self isBattleInputAllowed];
#endif
}

- (void)dealloc {
    [self stop];
}

@end
