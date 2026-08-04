//
//  MobaInputDispatcher.m
//  Moonlight
//

#import "MobaInputDispatcher.h"

@interface MobaDispatchInputScheduler : NSObject <MobaInputScheduling>
@end

@implementation MobaDispatchInputScheduler

- (void)scheduleAfterMilliseconds:(NSUInteger)delayMs block:(dispatch_block_t)block {
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)delayMs * NSEC_PER_MSEC);
    dispatch_after(deadline, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), block);
}

@end

@implementation MobaInputDispatcher {
    id<MobaInputSink> _sink;
    id<MobaInputScheduling> _scheduler;
    dispatch_queue_t _inputQueue;
    NSMutableSet<NSNumber *> *_pressedKeys;
    NSMutableSet<NSNumber *> *_pressedMouseButtons;
    NSMutableDictionary<NSNumber *, NSObject *> *_pendingTapTokens;
}

- (instancetype)initWithSink:(id<MobaInputSink>)sink {
    return [self initWithSink:sink scheduler:[[MobaDispatchInputScheduler alloc] init]];
}

- (instancetype)initWithSink:(id<MobaInputSink>)sink
                    scheduler:(id<MobaInputScheduling>)scheduler {
    self = [super init];
    if (self) {
        NSParameterAssert(sink != nil);
        NSParameterAssert(scheduler != nil);

        _sink = sink;
        _scheduler = scheduler;
        _inputQueue = dispatch_queue_create("com.moonlight-stream.moba.input", DISPATCH_QUEUE_SERIAL);
        _pressedKeys = [[NSMutableSet alloc] init];
        _pressedMouseButtons = [[NSMutableSet alloc] init];
        _pendingTapTokens = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)pressKeyCodeOnQueue:(uint16_t)keyCode {
    NSNumber *key = @(keyCode);
    if ([_pressedKeys containsObject:key]) {
        return NO;
    }

    [_pressedKeys addObject:key];
    [_sink setKeyCode:keyCode down:YES];
    return YES;
}

- (BOOL)releaseKeyCodeOnQueue:(uint16_t)keyCode {
    NSNumber *key = @(keyCode);
    [_pendingTapTokens removeObjectForKey:key];
    if (![_pressedKeys containsObject:key]) {
        return NO;
    }

    [_pressedKeys removeObject:key];
    [_sink setKeyCode:keyCode down:NO];
    return YES;
}

- (BOOL)pressMouseButtonOnQueue:(int)button {
    NSNumber *mouseButton = @(button);
    if ([_pressedMouseButtons containsObject:mouseButton]) {
        return NO;
    }

    [_pressedMouseButtons addObject:mouseButton];
    [_sink sendMouseButton:button down:YES];
    return YES;
}

- (BOOL)releaseMouseButtonOnQueue:(int)button {
    NSNumber *mouseButton = @(button);
    if (![_pressedMouseButtons containsObject:mouseButton]) {
        return NO;
    }

    [_pressedMouseButtons removeObject:mouseButton];
    [_sink sendMouseButton:button down:NO];
    return YES;
}

- (void)scheduleKeyUpOnQueue:(uint16_t)keyCode durationMs:(NSUInteger)durationMs {
    NSNumber *key = @(keyCode);
    NSObject *token = [[NSObject alloc] init];
    _pendingTapTokens[key] = token;

    __weak MobaInputDispatcher *weakSelf = self;
    [_scheduler scheduleAfterMilliseconds:durationMs block:^{
        MobaInputDispatcher *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        dispatch_async(strongSelf->_inputQueue, ^{
            if (strongSelf->_pendingTapTokens[key] != token) {
                return;
            }

            [strongSelf->_pendingTapTokens removeObjectForKey:key];
            [strongSelf releaseKeyCodeOnQueue:keyCode];
        });
    }];
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    dispatch_async(_inputQueue, ^{
        if (down) {
            [self pressKeyCodeOnQueue:keyCode];
        }
        else {
            [self releaseKeyCodeOnQueue:keyCode];
        }
    });
}

- (void)tapKeyCode:(uint16_t)keyCode durationMs:(NSUInteger)durationMs {
    dispatch_async(_inputQueue, ^{
        if ([self pressKeyCodeOnQueue:keyCode]) {
            [self scheduleKeyUpOnQueue:keyCode durationMs:durationMs];
        }
    });
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    dispatch_async(_inputQueue, ^{
        [self->_sink moveCursorToCanvasPoint:point];
    });
}

- (void)setMouseButton:(int)button down:(BOOL)down {
    dispatch_async(_inputQueue, ^{
        if (down) {
            [self pressMouseButtonOnQueue:button];
        }
        else {
            [self releaseMouseButtonOnQueue:button];
        }
    });
}

- (void)commitFinalCursorPoint:(CGPoint)point releasingKeyCode:(uint16_t)keyCode {
    dispatch_async(_inputQueue, ^{
        [self->_sink moveCursorToCanvasPoint:point];
        [self releaseKeyCodeOnQueue:keyCode];
    });
}

- (void)cancelWithKeyCode:(uint16_t)cancelKeyCode
               durationMs:(NSUInteger)durationMs
    releasingSkillKeyCode:(uint16_t)skillKeyCode {
    dispatch_async(_inputQueue, ^{
        if ([self pressKeyCodeOnQueue:cancelKeyCode]) {
            [self scheduleKeyUpOnQueue:cancelKeyCode durationMs:durationMs];
        }
        [self releaseKeyCodeOnQueue:skillKeyCode];
    });
}

- (void)cancelWithMouseButton:(int)button releasingSkillKeyCode:(uint16_t)skillKeyCode {
    dispatch_async(_inputQueue, ^{
        [self pressMouseButtonOnQueue:button];
        [self releaseMouseButtonOnQueue:button];
        [self releaseKeyCodeOnQueue:skillKeyCode];
    });
}

- (void)releaseAllInputs {
    dispatch_async(_inputQueue, ^{
        [self->_pendingTapTokens removeAllObjects];

        if (self->_pressedKeys.count == 0 && self->_pressedMouseButtons.count == 0) {
            return;
        }

        NSArray<NSNumber *> *keys = [[self->_pressedKeys allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSArray<NSNumber *> *mouseButtons = [[self->_pressedMouseButtons allObjects] sortedArrayUsingSelector:@selector(compare:)];
        [self->_pressedKeys removeAllObjects];
        [self->_pressedMouseButtons removeAllObjects];

        for (NSNumber *key in keys) {
            [self->_sink setKeyCode:key.unsignedShortValue down:NO];
        }
        for (NSNumber *mouseButton in mouseButtons) {
            [self->_sink sendMouseButton:mouseButton.intValue down:NO];
        }
    });
}

- (void)notifyWhenIdle:(dispatch_block_t)completion {
    if (completion == nil) {
        return;
    }

    dispatch_async(_inputQueue, completion);
}

@end
