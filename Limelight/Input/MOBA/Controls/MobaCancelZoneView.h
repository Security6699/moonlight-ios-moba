//
//  MobaCancelZoneView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "MobaControlLayoutPresentation.h"
#import "MobaCancelZoneController.h"
#import "../Core/MobaOverlayLifecycle.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT const CGFloat MobaCancelZoneDefaultVisualDiameter;
FOUNDATION_EXPORT const CGFloat MobaCancelZoneDefaultNormalOpacity;
FOUNDATION_EXPORT const CGFloat MobaCancelZoneDefaultArmedOpacity;
FOUNDATION_EXPORT const CGFloat MobaCancelZoneDefaultDisabledOpacity;

typedef NS_ENUM(NSInteger, MobaCancelZoneVisualState) {
    MobaCancelZoneVisualStateNormal,
    MobaCancelZoneVisualStateArmed,
    MobaCancelZoneVisualStateDisabled,
};

// A shared, non-interactive presentation. Skill touch ownership always remains
// with the future SkillButtonView.
@interface MobaCancelZoneView : UIView <MobaCancelZonePresenting,
                                       MobaLayoutEditableCancelZonePresenting,
                                       MobaLocalInteractionResetParticipant>

@property (nonatomic, weak, nullable) MobaCancelZoneController *controller;
@property (nonatomic, readonly) CGFloat visualDiameter;
@property (nonatomic) CGFloat normalOpacity;
@property (nonatomic) CGFloat armedOpacity;
@property (nonatomic) CGFloat disabledOpacity;
@property (nonatomic, readonly, getter=isCastingVisible) BOOL castingVisible;
@property (nonatomic, readonly, getter=isArmed) BOOL armed;
@property (nonatomic, readonly) MobaCancelZoneVisualState visualState;
@property (nonatomic, readonly) CGFloat effectiveVisualOpacity;

- (nullable instancetype)initWithVisualDiameter:(CGFloat)visualDiameter NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
