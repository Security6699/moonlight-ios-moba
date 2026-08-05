//
//  MobaCastStateMachine.h
//  Moonlight
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaCastState) {
    MobaCastStateIdle,
    MobaCastStateAimingDefault,
    MobaCastStateAimingDragged,
    MobaCastStateCancelArmed,
    MobaCastStateCommitted,
    MobaCastStateCancelled,
};

typedef NS_ENUM(NSInteger, MobaCastTerminalOutcome) {
    MobaCastTerminalOutcomeNone,
    MobaCastTerminalOutcomeCommitted,
    MobaCastTerminalOutcomeCancelled,
};

typedef struct {
    BOOL accepted;
    MobaCastState previousState;
    MobaCastState currentState;
    BOOL producedTerminalOutcome;
    MobaCastTerminalOutcome terminalOutcome;
} MobaCastTransitionResult;

FOUNDATION_EXPORT MobaCastTransitionResult MobaCastRejectedTransitionResult(MobaCastState state);

// Pure semantic cast-state transitions. Geometry and remote input are owned by
// callers and future cast strategies.
@interface MobaCastStateMachine : NSObject

@property (nonatomic, readonly) MobaCastState state;

- (MobaCastTransitionResult)begin;
- (MobaCastTransitionResult)dragBecameMeaningful;
- (MobaCastTransitionResult)dragReturnedBelowMeaningfulThreshold;
- (MobaCastTransitionResult)enterCancelZone;
- (MobaCastTransitionResult)exitCancelZone;
- (MobaCastTransitionResult)updateWithMeaningfulDrag:(BOOL)meaningfulDrag
                                    insideCancelZone:(BOOL)insideCancelZone;
- (MobaCastTransitionResult)releaseNormally;
- (MobaCastTransitionResult)cancelForTouchCancellation;
- (MobaCastTransitionResult)interrupt;

// Explicit local cleanup. This never emits input and may reset active or
// terminal state. Repeated reset while Idle is accepted and has no outcome.
- (MobaCastTransitionResult)reset;

@end

NS_ASSUME_NONNULL_END
