//
//  MobaCastSession.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaCastStateMachine.h"

NS_ASSUME_NONNULL_BEGIN

// Owns one semantic interaction token for one future skill instance. Token
// ownership uses object identity and never transfers during an active session.
@interface MobaCastSession : NSObject

@property (nonatomic, readonly) MobaCastState state;
@property (nonatomic, strong, readonly, nullable) id activeInteractionToken;

- (MobaCastTransitionResult)beginInteractionWithToken:(id)token;
- (MobaCastTransitionResult)updateInteractionWithToken:(id)token
                                        meaningfulDrag:(BOOL)meaningfulDrag
                                       insideCancelZone:(BOOL)insideCancelZone;
- (MobaCastTransitionResult)releaseInteractionWithToken:(id)token;
- (MobaCastTransitionResult)cancelInteractionWithToken:(id)token;

// Lifecycle interruption does not require a token. It cancels any active
// session and clears ownership without sending input.
- (MobaCastTransitionResult)interrupt;

// Silent local cleanup clears ownership and returns state to Idle. It does not
// call a strategy, Dispatcher, Sink, Adapter, or input API.
- (MobaCastTransitionResult)silentReset;

@end

NS_ASSUME_NONNULL_END
