//
//  MobaCastStrategy.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#include <stdint.h>

#import "MobaCastStateMachine.h"

@class MobaInputDispatcher;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaCastCancelActionType) {
    MobaCastCancelActionTypeKeyboard,
    MobaCastCancelActionTypeRightMouse,
    MobaCastCancelActionTypeReleaseOnly,
};

// Immutable configuration describing the input that precedes a directional
// skill key-up when an intentional cancel-zone release is consumed.
@interface MobaCastCancelAction : NSObject

@property (nonatomic, readonly) MobaCastCancelActionType type;
@property (nonatomic, readonly) uint16_t keyCode;
@property (nonatomic, readonly) NSUInteger tapDurationMs;
@property (nonatomic, readonly) int mouseButton;

+ (instancetype)keyboardActionWithKeyCode:(uint16_t)keyCode
                                durationMs:(NSUInteger)durationMs;
+ (instancetype)rightMouseAction;
+ (instancetype)releaseOnlyAction;

- (instancetype)init NS_UNAVAILABLE;

@end

// Strategies consume accepted MobaCastSession results. They never mutate the
// session. After a terminal result is consumed, the caller explicitly invokes
// silentReset on the session.
@protocol MobaCastStrategy <NSObject>

- (BOOL)beginWithTransitionResult:(MobaCastTransitionResult)result;
- (BOOL)commitWithTransitionResult:(MobaCastTransitionResult)result;
- (BOOL)cancelWithTransitionResult:(MobaCastTransitionResult)result;
- (void)silentReset;

@end

// Small semantic guards shared by strategies. A rejected or mismatched result
// must never produce Dispatcher input.
FOUNDATION_EXPORT BOOL MobaCastTransitionIsAcceptedBegin(MobaCastTransitionResult result);
FOUNDATION_EXPORT BOOL MobaCastTransitionIsAcceptedUpdate(MobaCastTransitionResult result);
FOUNDATION_EXPORT BOOL MobaCastTransitionIsAcceptedTerminal(MobaCastTransitionResult result,
                                                            MobaCastTerminalOutcome outcome);

// Stateless shared cancellation mapping. The Dispatcher remains the only
// pressed-input owner and preserves cancel-before-skill-key-up ordering.
FOUNDATION_EXPORT void MobaCastDispatchCancelAction(MobaInputDispatcher *dispatcher,
                                                    MobaCastCancelAction *cancelAction,
                                                    uint16_t skillKeyCode);

NS_ASSUME_NONNULL_END
