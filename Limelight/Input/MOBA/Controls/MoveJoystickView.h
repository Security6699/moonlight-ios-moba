//
//  MoveJoystickView.h
//  Moonlight
//


#import <UIKit/UIKit.h>

#import "MobaControlLayoutPresentation.h"
#import "../Core/MobaOverlayLifecycle.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaMovementController;

FOUNDATION_EXPORT const CGSize MoveJoystickDefaultVisualSize;
FOUNDATION_EXPORT const CGFloat MoveJoystickDefaultWheelRadius;
FOUNDATION_EXPORT const CGFloat MoveJoystickDefaultHitAreaScale;
FOUNDATION_EXPORT const CGFloat MoveJoystickDefaultNormalOpacity;
FOUNDATION_EXPORT const CGFloat MoveJoystickDefaultPressedOpacity;
FOUNDATION_EXPORT const CGFloat MoveJoystickDefaultDisabledOpacity;

@interface MoveJoystickView : UIView <MobaLayoutEditableControlPresenting,
                                      MobaLocalInteractionResetParticipant>

@property (nonatomic, readonly) CGSize visualSize;
@property (nonatomic, readonly) CGFloat wheelRadius;
@property (nonatomic, readonly) CGFloat hitAreaScale;
@property (nonatomic) CGFloat normalOpacity;
@property (nonatomic) CGFloat pressedOpacity;
@property (nonatomic) CGFloat disabledOpacity;
@property (nonatomic, getter=isInteractionEnabled) BOOL interactionEnabled;
@property (nonatomic, readonly, getter=isPressed) BOOL pressed;
@property (nonatomic, readonly) CGVector knobDisplacement;

- (nullable instancetype)initWithMovementController:(MobaMovementController *)movementController;
- (nullable instancetype)initWithMovementController:(MobaMovementController *)movementController
                                          visualSize:(CGSize)visualSize
                                         wheelRadius:(CGFloat)wheelRadius
                                        hitAreaScale:(CGFloat)hitAreaScale NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
