//
//  MobaOverlayLifecycle.h
//  Moonlight
//

#import <Foundation/Foundation.h>

@class MobaInputDispatcher;

typedef NS_ENUM(NSInteger, MobaOverlayMode) {
    MobaOverlayModeBattle,
    MobaOverlayModeUI,
    MobaOverlayModeLayoutEdit,
    MobaOverlayModeSkillTuning,
};

typedef NS_ENUM(NSInteger, MobaInputInterruptionReason) {
    MobaInputInterruptionReasonTouchCancellation,
    MobaInputInterruptionReasonApplicationWillResignActive,
    MobaInputInterruptionReasonApplicationDidEnterBackground,
    MobaInputInterruptionReasonStreamDisconnectOrTeardown,
    MobaInputInterruptionReasonCoordinatorStop,
    MobaInputInterruptionReasonCoordinatorDestruction,
    MobaInputInterruptionReasonViewControllerDisappearance,
    MobaInputInterruptionReasonBattleToUI,
    MobaInputInterruptionReasonBattleToLayoutEdit,
    MobaInputInterruptionReasonBattleToSkillTuning,
    MobaInputInterruptionReasonOrientationChange,
    MobaInputInterruptionReasonProfileReload,
    MobaInputInterruptionReasonFeatureDisable,
};

@protocol MobaLocalInteractionResetParticipant <NSObject>

// One reset must cancel owned touches, invalidate timers and display links,
// clear cast or session state, and remove any local pressed appearance.
- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason;

@optional
- (void)setMobaLocalInteractionEnabled:(BOOL)enabled;

@end

@protocol MobaOverlayLifecycleEnvironment <NSObject>

@property (nonatomic, readonly, getter=isMobaBattleModeSupported) BOOL mobaBattleModeSupported;
- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed;
- (void)setMobaNativeTouchRoutingEnabled:(BOOL)enabled;

@end

// Pure lifecycle and input-gating state owned by MobaOverlayCoordinator.
// Calls are expected on the coordinator's main-thread lifecycle boundary.
@interface MobaOverlayLifecycle : NSObject

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly, getter=isInputSuspended) BOOL inputSuspended;
@property (nonatomic, readonly, getter=isBattleInputAllowed) BOOL battleInputAllowed;
@property (nonatomic, readonly) MobaOverlayMode mode;

- (instancetype)initWithEnvironment:(id<MobaOverlayLifecycleEnvironment>)environment
                     inputDispatcher:(MobaInputDispatcher *)inputDispatcher NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant;
- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant;

- (BOOL)transitionToMode:(MobaOverlayMode)mode;
- (void)start;
- (void)stop;
- (void)invalidateForDestruction;

// Returns YES only when this call begins a new effective interruption.
- (BOOL)interruptAndReleaseInputsForReason:(MobaInputInterruptionReason)reason;

- (void)touchesCancelled;
- (void)applicationWillResignActive;
- (void)applicationDidEnterBackground;
- (void)applicationDidBecomeActive;
- (void)streamDidDisconnect;
- (void)viewControllerWillDisappear;
- (void)orientationWillChange;
- (void)orientationDidChange;
- (void)profileWillReload;
- (void)profileDidReload;
- (void)mobaFeatureWillDisable;

@end
