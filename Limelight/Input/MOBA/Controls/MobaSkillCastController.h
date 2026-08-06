//
//  MobaSkillCastController.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "../Casting/MobaCastStateMachine.h"
#import "../Core/MobaCursorDiagnostics.h"
#import "../Geometry/MobaSkillDragSemantics.h"

@class MobaCastSession;
@class MobaSkillCastController;
@class MobaSkillRuntimeDescriptor;

NS_ASSUME_NONNULL_BEGIN

@protocol MobaSkillCancelZoneRouting <NSObject>
- (BOOL)beginCancelZonePresentationForCastToken:(id)token;
- (BOOL)evaluateCancelZoneAtStreamViewPoint:(CGPoint)point
                                forCastToken:(id)token
                           insideCancelZone:(BOOL *)insideCancelZone;
- (BOOL)applyCancelZoneTransitionResult:(MobaCastTransitionResult)result
                            forCastToken:(id)token;
- (BOOL)endCancelZonePresentationForCastToken:(id)token;
@end

@protocol MobaSkillCastControllerDelegate <NSObject>
- (void)skillCastControllerDidRequestTouchCancellation:(MobaSkillCastController *)controller;
@end

// UIKit-free orchestration for exactly one skill control. Session owns cast
// state, the concrete strategy owns remote cast semantics, and Dispatcher
// remains the only remote pressed-input owner.
@interface MobaSkillCastController : NSObject

@property (nonatomic, weak, nullable) id<MobaSkillCastControllerDelegate> delegate;
@property (nonatomic, strong, readonly) MobaSkillRuntimeDescriptor *descriptor;
@property (nonatomic, strong, readonly) MobaCastSession *session;
@property (nonatomic, readonly, getter=isInteractionEnabled) BOOL interactionEnabled;
@property (nonatomic, readonly, getter=isPressed) BOOL pressed;
@property (nonatomic, readonly, getter=isCasting) BOOL casting;
@property (nonatomic, strong, readonly, nullable) id activeTouchToken;
@property (nonatomic, readonly) CGPoint initialStreamViewPoint;
@property (nonatomic, readonly) CGPoint latestStreamViewPoint;

- (nullable instancetype)initWithDescriptor:(MobaSkillRuntimeDescriptor *)descriptor
                                  inputGate:(id<MobaBattleInputGate>)inputGate
                           cancelZoneRouter:(id<MobaSkillCancelZoneRouting>)cancelZoneRouter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Silent gate used by Lifecycle and mode routing. It never sends input.
- (void)setInteractionEnabled:(BOOL)interactionEnabled;

- (BOOL)beginInteractionWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)updateInteractionWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)endInteractionWithToken:(id)token streamViewPoint:(CGPoint)point;

// UIKit cancellation requests the unified Lifecycle interruption boundary.
- (BOOL)cancelInteractionWithToken:(id)token;

// Clears Session, Strategy, Coalescer and local ownership without input.
- (void)silentReset;

@end

NS_ASSUME_NONNULL_END
