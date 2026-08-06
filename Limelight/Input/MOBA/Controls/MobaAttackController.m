//
//  MobaAttackController.m
//  Moonlight
//


#import "MobaAttackController.h"

#import "../Core/MobaInputDispatcher.h"

const uint16_t MobaDefaultAttackKeyCode = 67;
const NSUInteger MobaDefaultAttackTapDurationMs = 30;

@implementation MobaAttackController {
    MobaInputDispatcher *_inputDispatcher;
    uint16_t _attackKeyCode;
    NSUInteger _tapDurationMs;
    BOOL _interactionEnabled;
    BOOL _pressed;
    id _activeTouchToken;
}

- (instancetype)initWithInputDispatcher:(MobaInputDispatcher *)inputDispatcher {
    return [self initWithInputDispatcher:inputDispatcher
                           attackKeyCode:MobaDefaultAttackKeyCode
                           tapDurationMs:MobaDefaultAttackTapDurationMs];
}

- (instancetype)initWithInputDispatcher:(MobaInputDispatcher *)inputDispatcher
                           attackKeyCode:(uint16_t)attackKeyCode
                           tapDurationMs:(NSUInteger)tapDurationMs {
    if (inputDispatcher == nil) {
        return nil;
    }

    self = [super init];
    if (self) {
        _inputDispatcher = inputDispatcher;
        _attackKeyCode = attackKeyCode;
        _tapDurationMs = tapDurationMs;
        _interactionEnabled = YES;
    }
    return self;
}

- (uint16_t)attackKeyCode {
    return _attackKeyCode;
}

- (NSUInteger)tapDurationMs {
    return _tapDurationMs;
}

- (BOOL)isInteractionEnabled {
    return _interactionEnabled;
}

- (BOOL)isPressed {
    return _pressed;
}

- (id)activeTouchToken {
    return _activeTouchToken;
}

- (void)setInteractionEnabled:(BOOL)interactionEnabled {
    _interactionEnabled = interactionEnabled;
}

- (BOOL)updateAttackKeyCodeForCommittedProfile:(uint16_t)attackKeyCode
                                  tapDurationMs:(NSUInteger)tapDurationMs {
    if (_interactionEnabled || _pressed || _activeTouchToken != nil) return NO;
    _attackKeyCode = attackKeyCode;
    _tapDurationMs = tapDurationMs;
    return YES;
}

- (BOOL)beginInteractionWithToken:(id)token {
    if (!_interactionEnabled || token == nil || _activeTouchToken != nil) {
        return NO;
    }

    _activeTouchToken = token;
    _pressed = YES;
    [_inputDispatcher tapKeyCode:_attackKeyCode durationMs:_tapDurationMs];
    return YES;
}

- (BOOL)updateInteractionWithToken:(id)token {
    return _interactionEnabled && token != nil && token == _activeTouchToken;
}

- (BOOL)endInteractionWithToken:(id)token {
    if (!_interactionEnabled || token == nil || token != _activeTouchToken) {
        return NO;
    }

    _activeTouchToken = nil;
    _pressed = NO;
    return YES;
}

- (BOOL)cancelInteractionWithToken:(id)token {
    if (!_interactionEnabled || token == nil || token != _activeTouchToken) {
        return NO;
    }

    id<MobaAttackControllerDelegate> delegate = self.delegate;
    if (delegate == nil) {
        return NO;
    }

    [delegate attackControllerDidRequestTouchCancellation:self];
    return YES;
}

- (void)silentReset {
    _activeTouchToken = nil;
    _pressed = NO;
}

@end
