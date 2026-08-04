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
        _mode = MobaOverlayModeBattle;
    }
    return self;
}

- (BOOL)isRunning {
    return _running;
}

- (void)setMode:(MobaOverlayMode)mode {
    if (_mode == mode) {
        return;
    }

    _mode = mode;
    [self updateTraditionalControls];
}

- (void)start {
    if (_running) {
        return;
    }

    _running = YES;
    [self updateTraditionalControls];
}

- (void)stop {
    if (!_running) {
        return;
    }

    _running = NO;
    [_streamView setMobaControlsActive:NO];
}

- (void)updateTraditionalControls {
    if (!_running) {
        return;
    }

    [_streamView setMobaControlsActive:_mode == MobaOverlayModeBattle];
}

- (void)dealloc {
    [self stop];
}

@end
