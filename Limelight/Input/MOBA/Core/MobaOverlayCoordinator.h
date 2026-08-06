//
//  MobaOverlayCoordinator.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "../Casting/MobaCastStateMachine.h"
#import "MobaOverlayLifecycle.h"

@class StreamView;
@class MobaChampionRuntime;
@class MobaChampionSelectionController;
@class MobaSkillButtonView;
@class UIViewController;

@interface MobaOverlayCoordinator : NSObject

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic) MobaOverlayMode mode;
@property (nonatomic, readonly, getter=isBattleModeAvailable) BOOL battleModeAvailable;
@property (nonatomic, readonly, getter=isInputSuspended) BOOL inputSuspended;
@property (nonatomic, strong, readonly, nullable) MobaChampionRuntime *activeChampionRuntime;
@property (nonatomic, strong, readonly) MobaChampionSelectionController *championSelectionController;
@property (nonatomic, copy, readonly, nonnull) NSDictionary<NSString *, MobaSkillButtonView *> *skillButtonViews;

// Future MOBA battle input must only be emitted while this value is YES.
@property (nonatomic, readonly, getter=isBattleInputAllowed) BOOL battleInputAllowed;

- (instancetype)initWithStreamView:(StreamView *)streamView;
- (instancetype)initWithStreamView:(StreamView *)streamView
         presentationViewController:(nullable UIViewController *)presentationViewController;
- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant;
- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant;
- (BOOL)transitionToMode:(MobaOverlayMode)mode;
- (void)start;
- (void)stop;

// Fixed cancel-zone boundary for a future SkillButtonView. Points are already
// converted into StreamView coordinates. Geometry never mutates Session state,
// while accepted Session results remain the authority for armed presentation.
- (BOOL)beginCancelZonePresentationForCastToken:(id)token;
- (BOOL)evaluateCancelZoneAtStreamViewPoint:(CGPoint)point
                                forCastToken:(id)token
                           insideCancelZone:(BOOL *)insideCancelZone;
- (BOOL)applyCancelZoneTransitionResult:(MobaCastTransitionResult)result
                            forCastToken:(id)token;
- (BOOL)endCancelZonePresentationForCastToken:(id)token;
- (void)resetCancelZonePresentation;

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
