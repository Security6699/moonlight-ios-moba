//
//  MobaMovementController.m
//  Moonlight
//


#import "MobaMovementController.h"

#import "../Core/MobaInputDispatcher.h"

typedef NS_OPTIONS(NSUInteger, MobaMovementKeyMask) {
    MobaMovementKeyMaskUp = 1 << 0,
    MobaMovementKeyMaskLeft = 1 << 1,
    MobaMovementKeyMaskDown = 1 << 2,
    MobaMovementKeyMaskRight = 1 << 3,
};

MobaMovementKeyMapping MobaDefaultMovementKeyMapping(void) {
    return MobaMovementKeyMappingMake(87, 65, 83, 68);
}

static MobaMovementKeyMask MobaMovementKeyMaskForState(MobaJoystickState state) {
    switch (state) {
        case MobaJoystickStateNeutral:
            return 0;
        case MobaJoystickStateUp:
            return MobaMovementKeyMaskUp;
        case MobaJoystickStateUpRight:
            return MobaMovementKeyMaskUp | MobaMovementKeyMaskRight;
        case MobaJoystickStateRight:
            return MobaMovementKeyMaskRight;
        case MobaJoystickStateDownRight:
            return MobaMovementKeyMaskDown | MobaMovementKeyMaskRight;
        case MobaJoystickStateDown:
            return MobaMovementKeyMaskDown;
        case MobaJoystickStateDownLeft:
            return MobaMovementKeyMaskDown | MobaMovementKeyMaskLeft;
        case MobaJoystickStateLeft:
            return MobaMovementKeyMaskLeft;
        case MobaJoystickStateUpLeft:
            return MobaMovementKeyMaskUp | MobaMovementKeyMaskLeft;
    }
    return 0;
}

@implementation MobaMovementController {
    MobaInputDispatcher *_inputDispatcher;
    MobaMovementKeyMapping _keyMapping;
    CGFloat _wheelRadius;
    CGFloat _deadZoneRatio;
    CGFloat _directionHysteresisDegrees;
    MobaJoystickState _state;
    BOOL _interactionEnabled;
    id _activeTouchToken;
}

- (instancetype)initWithInputDispatcher:(MobaInputDispatcher *)inputDispatcher
                              keyMapping:(MobaMovementKeyMapping)keyMapping
                             wheelRadius:(CGFloat)wheelRadius
                           deadZoneRatio:(CGFloat)deadZoneRatio
              directionHysteresisDegrees:(CGFloat)directionHysteresisDegrees {
    if (inputDispatcher == nil ||
        !MobaJoystickConfigurationIsValid(wheelRadius,
                                          deadZoneRatio,
                                          directionHysteresisDegrees)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _inputDispatcher = inputDispatcher;
        _keyMapping = keyMapping;
        _wheelRadius = wheelRadius;
        _deadZoneRatio = deadZoneRatio;
        _directionHysteresisDegrees = directionHysteresisDegrees;
        _state = MobaJoystickStateNeutral;
        _interactionEnabled = YES;
    }
    return self;
}

- (MobaJoystickState)state {
    return _state;
}

- (MobaMovementKeyMapping)keyMapping {
    return _keyMapping;
}

- (CGFloat)wheelRadius {
    return _wheelRadius;
}

- (CGFloat)deadZoneRatio {
    return _deadZoneRatio;
}

- (CGFloat)directionHysteresisDegrees {
    return _directionHysteresisDegrees;
}

- (BOOL)isInteractionEnabled {
    return _interactionEnabled;
}

- (id)activeTouchToken {
    return _activeTouchToken;
}

- (void)setInteractionEnabled:(BOOL)interactionEnabled {
    _interactionEnabled = interactionEnabled;
}

- (BOOL)updateWheelRadiusForCommittedProfile:(CGFloat)wheelRadius {
    if (_interactionEnabled || _state != MobaJoystickStateNeutral || _activeTouchToken != nil ||
        !MobaJoystickConfigurationIsValid(wheelRadius,
                                          _deadZoneRatio,
                                          _directionHysteresisDegrees)) {
        return NO;
    }
    _wheelRadius = wheelRadius;
    return YES;
}

- (NSArray<NSNumber *> *)orderedKeyCodes {
    return @[@(_keyMapping.upKeyCode),
             @(_keyMapping.leftKeyCode),
             @(_keyMapping.downKeyCode),
             @(_keyMapping.rightKeyCode)];
}

- (NSSet<NSNumber *> *)activeKeyCodesForState:(MobaJoystickState)state {
    MobaMovementKeyMask mask = MobaMovementKeyMaskForState(state);
    NSMutableSet<NSNumber *> *keys = [[NSMutableSet alloc] init];
    if ((mask & MobaMovementKeyMaskUp) != 0) {
        [keys addObject:@(_keyMapping.upKeyCode)];
    }
    if ((mask & MobaMovementKeyMaskLeft) != 0) {
        [keys addObject:@(_keyMapping.leftKeyCode)];
    }
    if ((mask & MobaMovementKeyMaskDown) != 0) {
        [keys addObject:@(_keyMapping.downKeyCode)];
    }
    if ((mask & MobaMovementKeyMaskRight) != 0) {
        [keys addObject:@(_keyMapping.rightKeyCode)];
    }
    return keys;
}

- (void)transitionToState:(MobaJoystickState)newState {
    if (_state == newState) {
        return;
    }

    NSSet<NSNumber *> *oldKeys = [self activeKeyCodesForState:_state];
    NSSet<NSNumber *> *newKeys = [self activeKeyCodesForState:newState];
    NSMutableSet<NSNumber *> *visitedKeys = [[NSMutableSet alloc] init];

    for (NSNumber *key in [self orderedKeyCodes]) {
        if ([visitedKeys containsObject:key]) {
            continue;
        }
        [visitedKeys addObject:key];
        if ([oldKeys containsObject:key] && ![newKeys containsObject:key]) {
            [_inputDispatcher setKeyCode:key.unsignedShortValue down:NO];
        }
    }

    [visitedKeys removeAllObjects];
    for (NSNumber *key in [self orderedKeyCodes]) {
        if ([visitedKeys containsObject:key]) {
            continue;
        }
        [visitedKeys addObject:key];
        if ([newKeys containsObject:key] && ![oldKeys containsObject:key]) {
            [_inputDispatcher setKeyCode:key.unsignedShortValue down:YES];
        }
    }

    _state = newState;
}

- (BOOL)stateForDisplacement:(CGVector)displacement result:(MobaJoystickState *)state {
    return MobaJoystickStateForDisplacement(displacement,
                                            _wheelRadius,
                                            _deadZoneRatio,
                                            _directionHysteresisDegrees,
                                            _state,
                                            state);
}

- (BOOL)updateDisplacement:(CGVector)displacement {
    if (!_interactionEnabled) {
        return NO;
    }

    MobaJoystickState newState;
    if (![self stateForDisplacement:displacement result:&newState]) {
        return NO;
    }
    [self transitionToState:newState];
    return YES;
}

- (void)releaseMovement {
    [self transitionToState:MobaJoystickStateNeutral];
}

- (void)silentReset {
    _state = MobaJoystickStateNeutral;
    _activeTouchToken = nil;
}

- (BOOL)beginInteractionWithToken:(id)token displacement:(CGVector)displacement {
    if (!_interactionEnabled || token == nil || _activeTouchToken != nil) {
        return NO;
    }

    MobaJoystickState newState;
    if (![self stateForDisplacement:displacement result:&newState]) {
        return NO;
    }

    _activeTouchToken = token;
    [self transitionToState:newState];
    return YES;
}

- (BOOL)updateInteractionWithToken:(id)token displacement:(CGVector)displacement {
    if (!_interactionEnabled || token == nil || token != _activeTouchToken) {
        return NO;
    }
    return [self updateDisplacement:displacement];
}

- (BOOL)endInteractionWithToken:(id)token {
    if (!_interactionEnabled || token == nil || token != _activeTouchToken) {
        return NO;
    }

    [self releaseMovement];
    _activeTouchToken = nil;
    return YES;
}

- (BOOL)cancelInteractionWithToken:(id)token {
    if (!_interactionEnabled || token == nil || token != _activeTouchToken) {
        return NO;
    }

    id<MobaMovementControllerDelegate> delegate = self.delegate;
    if (delegate == nil) {
        return NO;
    }
    [delegate movementControllerDidRequestTouchCancellation:self];
    return YES;
}

@end
