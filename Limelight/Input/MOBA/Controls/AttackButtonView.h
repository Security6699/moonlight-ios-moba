//
//  AttackButtonView.h
//  Moonlight
//


#import <UIKit/UIKit.h>

#import "../Core/MobaOverlayLifecycle.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaAttackController;

FOUNDATION_EXPORT const CGSize AttackButtonDefaultVisualSize;
FOUNDATION_EXPORT const CGFloat AttackButtonDefaultHitAreaScale;
FOUNDATION_EXPORT const CGFloat AttackButtonDefaultNormalOpacity;
FOUNDATION_EXPORT const CGFloat AttackButtonDefaultPressedOpacity;
FOUNDATION_EXPORT const CGFloat AttackButtonDefaultDisabledOpacity;

@interface AttackButtonView : UIView <MobaLocalInteractionResetParticipant>

@property (nonatomic, readonly) CGSize visualSize;
@property (nonatomic, readonly) CGFloat hitAreaScale;
@property (nonatomic) CGFloat normalOpacity;
@property (nonatomic) CGFloat pressedOpacity;
@property (nonatomic) CGFloat disabledOpacity;
@property (nonatomic, getter=isInteractionEnabled) BOOL interactionEnabled;
@property (nonatomic, readonly, getter=isPressed) BOOL pressed;

- (nullable instancetype)initWithAttackController:(MobaAttackController *)attackController;
- (nullable instancetype)initWithAttackController:(MobaAttackController *)attackController
                                        visualSize:(CGSize)visualSize
                                       hitAreaScale:(CGFloat)hitAreaScale NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
