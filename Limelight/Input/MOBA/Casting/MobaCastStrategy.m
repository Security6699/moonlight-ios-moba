//
//  MobaCastStrategy.m
//  Moonlight
//

#import "MobaCastStrategy.h"

#import "../Core/MobaInputDispatcher.h"

// Existing moonlight-common BUTTON_RIGHT value. This is protocol semantics,
// not a profile or champion calibration value.
static const int MobaCastRightMouseButton = 0x03;

@interface MobaCastCancelAction ()

- (instancetype)initWithType:(MobaCastCancelActionType)type
                      keyCode:(uint16_t)keyCode
                   durationMs:(NSUInteger)durationMs
                  mouseButton:(int)mouseButton;

@end

@implementation MobaCastCancelAction

- (instancetype)initWithType:(MobaCastCancelActionType)type
                      keyCode:(uint16_t)keyCode
                   durationMs:(NSUInteger)durationMs
                  mouseButton:(int)mouseButton {
    self = [super init];
    if (self) {
        _type = type;
        _keyCode = keyCode;
        _tapDurationMs = durationMs;
        _mouseButton = mouseButton;
    }
    return self;
}

+ (instancetype)keyboardActionWithKeyCode:(uint16_t)keyCode
                                durationMs:(NSUInteger)durationMs {
    return [[self alloc] initWithType:MobaCastCancelActionTypeKeyboard
                              keyCode:keyCode
                           durationMs:durationMs
                          mouseButton:0];
}

+ (instancetype)rightMouseAction {
    return [[self alloc] initWithType:MobaCastCancelActionTypeRightMouse
                              keyCode:0
                           durationMs:0
                          mouseButton:MobaCastRightMouseButton];
}

+ (instancetype)releaseOnlyAction {
    return [[self alloc] initWithType:MobaCastCancelActionTypeReleaseOnly
                              keyCode:0
                           durationMs:0
                          mouseButton:0];
}

@end

static BOOL MobaCastStateIsActive(MobaCastState state) {
    return state == MobaCastStateAimingDefault ||
        state == MobaCastStateAimingDragged ||
        state == MobaCastStateCancelArmed;
}

BOOL MobaCastTransitionIsAcceptedBegin(MobaCastTransitionResult result) {
    return result.accepted &&
        result.previousState == MobaCastStateIdle &&
        result.currentState == MobaCastStateAimingDefault &&
        !result.producedTerminalOutcome &&
        result.terminalOutcome == MobaCastTerminalOutcomeNone;
}

BOOL MobaCastTransitionIsAcceptedUpdate(MobaCastTransitionResult result) {
    return result.accepted &&
        MobaCastStateIsActive(result.previousState) &&
        MobaCastStateIsActive(result.currentState) &&
        !result.producedTerminalOutcome &&
        result.terminalOutcome == MobaCastTerminalOutcomeNone;
}

BOOL MobaCastTransitionIsAcceptedTerminal(MobaCastTransitionResult result,
                                          MobaCastTerminalOutcome outcome) {
    MobaCastState terminalState = outcome == MobaCastTerminalOutcomeCommitted ?
        MobaCastStateCommitted : MobaCastStateCancelled;
    return outcome != MobaCastTerminalOutcomeNone &&
        result.accepted &&
        MobaCastStateIsActive(result.previousState) &&
        result.currentState == terminalState &&
        result.producedTerminalOutcome &&
        result.terminalOutcome == outcome;
}

void MobaCastDispatchCancelAction(MobaInputDispatcher *dispatcher,
                                  MobaCastCancelAction *cancelAction,
                                  uint16_t skillKeyCode) {
    switch (cancelAction.type) {
        case MobaCastCancelActionTypeKeyboard:
            [dispatcher cancelWithKeyCode:cancelAction.keyCode
                               durationMs:cancelAction.tapDurationMs
                    releasingSkillKeyCode:skillKeyCode];
            break;
        case MobaCastCancelActionTypeRightMouse:
            [dispatcher cancelWithMouseButton:cancelAction.mouseButton
                        releasingSkillKeyCode:skillKeyCode];
            break;
        case MobaCastCancelActionTypeReleaseOnly:
            [dispatcher setKeyCode:skillKeyCode down:NO];
            break;
    }
}
