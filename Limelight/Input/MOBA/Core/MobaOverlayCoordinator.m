//
//  MobaOverlayCoordinator.m
//  Moonlight
//

#import "MobaOverlayCoordinator.h"
#import "StreamView.h"

@implementation MobaOverlayCoordinator {
    __weak StreamView *_streamView;
    BOOL _running;
}

- (instancetype)initWithStreamView:(StreamView *)streamView {
    self = [super init];
    if (self) {
        _streamView = streamView;
        _mode = [streamView isMobaBattleModeSupported] ? MobaOverlayModeBattle : MobaOverlayModeUI;
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
        return YES;
    }

    _mode = mode;
    return YES;
}

- (void)start {
    if (_running) {
        return;
    }

    _running = YES;
    [_streamView setTraditionalOnScreenControlsSuppressed:YES];
}

- (void)stop {
    if (!_running) {
        return;
    }

    _running = NO;
    [_streamView setTraditionalOnScreenControlsSuppressed:NO];
}

- (void)dealloc {
    [self stop];
}

@end
