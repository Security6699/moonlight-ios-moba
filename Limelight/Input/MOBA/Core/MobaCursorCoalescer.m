//
//  MobaCursorCoalescer.m
//  Moonlight
//

#import "MobaCursorCoalescer.h"

#import <math.h>

#import "MobaInputDispatcher.h"

@implementation MobaCursorCoalescer {
    MobaInputDispatcher *_dispatcher;
    id<MobaDisplayLinkDriving> _driver;
    MobaCursorUpdateRate _updateRate;
    CGPoint _latestPoint;
    NSUInteger _generation;
    BOOL _running;
    BOOL _hasPendingPoint;
    BOOL _localInteractionEnabled;
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                              driver:(id<MobaDisplayLinkDriving>)driver {
    return [self initWithDispatcher:dispatcher
                              driver:driver
                          updateRate:MobaCursorUpdateRateDefault];
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                              driver:(id<MobaDisplayLinkDriving>)driver
                          updateRate:(MobaCursorUpdateRate)updateRate {
    if (dispatcher == nil || driver == nil || !MobaCursorUpdateRateIsValid(updateRate)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _driver = driver;
        _updateRate = updateRate;
        _localInteractionEnabled = YES;
    }
    return self;
}

- (MobaCursorUpdateRate)updateRate {
    return _updateRate;
}

- (BOOL)isRunning {
    return _running;
}

- (BOOL)hasPendingPoint {
    return _hasPendingPoint;
}

- (BOOL)start {
    NSAssert([NSThread isMainThread], @"MobaCursorCoalescer must start on the main thread");
    if (!_localInteractionEnabled) {
        return NO;
    }
    if (_running) {
        return YES;
    }

    _generation += 1;
    NSUInteger generation = _generation;
    __weak MobaCursorCoalescer *weakSelf = self;
    BOOL started = [_driver startWithUpdateRate:_updateRate tickHandler:^{
        MobaCursorCoalescer *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf handleTickForGeneration:generation];
        }
    }];
    if (!started) {
        return NO;
    }

    _running = YES;
    _hasPendingPoint = NO;
    _latestPoint = CGPointZero;
    return YES;
}

- (BOOL)submitLatestPoint:(CGPoint)point {
    NSAssert([NSThread isMainThread], @"MobaCursorCoalescer submissions must be on the main thread");
    if (!_localInteractionEnabled || !_running || !isfinite(point.x) || !isfinite(point.y)) {
        return NO;
    }

    _latestPoint = point;
    _hasPendingPoint = YES;
    return YES;
}

- (void)handleTickForGeneration:(NSUInteger)generation {
    NSAssert([NSThread isMainThread], @"MobaCursorCoalescer ticks must be on the main thread");
    if (!_running || generation != _generation || !_hasPendingPoint) {
        return;
    }

    CGPoint point = _latestPoint;
    _hasPendingPoint = NO;
    [_dispatcher moveCursorToCanvasPoint:point];
}

- (void)stopAndDiscardPending {
    NSAssert([NSThread isMainThread], @"MobaCursorCoalescer must stop on the main thread");
    BOOL wasActive = _running || _driver.isRunning;
    _running = NO;
    _hasPendingPoint = NO;
    _latestPoint = CGPointZero;
    if (!wasActive) {
        return;
    }

    _generation += 1;
    [_driver stop];
}

- (void)setMobaLocalInteractionEnabled:(BOOL)enabled {
    NSAssert([NSThread isMainThread], @"MobaCursorCoalescer lifecycle changes must be on the main thread");
    if (!enabled) {
        _localInteractionEnabled = NO;
        [self stopAndDiscardPending];
        return;
    }

    _localInteractionEnabled = YES;
}

- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason {
    (void)reason;
    [self stopAndDiscardPending];
}

@end
