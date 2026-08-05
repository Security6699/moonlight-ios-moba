//
//  MobaInstantCastStrategy.m
//  Moonlight
//

#import "MobaInstantCastStrategy.h"

#import "../Core/MobaInputDispatcher.h"

@implementation MobaInstantCastConfiguration

- (instancetype)initWithSkillKeyCode:(uint16_t)skillKeyCode
                        tapDurationMs:(NSUInteger)tapDurationMs {
    self = [super init];
    if (self) {
        _skillKeyCode = skillKeyCode;
        _tapDurationMs = tapDurationMs;
    }
    return self;
}

@end

@implementation MobaInstantCastStrategy {
    MobaInputDispatcher *_dispatcher;
    MobaInstantCastConfiguration *_configuration;
    BOOL _awaitingTerminalOutcome;
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaInstantCastConfiguration *)configuration {
    NSParameterAssert(dispatcher != nil);
    NSParameterAssert(configuration != nil);

    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _configuration = configuration;
    }
    return self;
}

- (BOOL)beginWithTransitionResult:(MobaCastTransitionResult)result {
    if (_awaitingTerminalOutcome || !MobaCastTransitionIsAcceptedBegin(result)) {
        return NO;
    }

    _awaitingTerminalOutcome = YES;
    return YES;
}

- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result {
    return _awaitingTerminalOutcome && MobaCastTransitionIsAcceptedUpdate(result);
}

- (BOOL)commitWithTransitionResult:(MobaCastTransitionResult)result {
    if (!_awaitingTerminalOutcome ||
        !MobaCastTransitionIsAcceptedTerminal(result, MobaCastTerminalOutcomeCommitted)) {
        return NO;
    }

    _awaitingTerminalOutcome = NO;
    [_dispatcher tapKeyCode:_configuration.skillKeyCode
                 durationMs:_configuration.tapDurationMs];
    return YES;
}

- (BOOL)cancelWithTransitionResult:(MobaCastTransitionResult)result {
    if (!_awaitingTerminalOutcome ||
        !MobaCastTransitionIsAcceptedTerminal(result, MobaCastTerminalOutcomeCancelled)) {
        return NO;
    }

    _awaitingTerminalOutcome = NO;
    return YES;
}

- (void)silentReset {
    _awaitingTerminalOutcome = NO;
}

@end
