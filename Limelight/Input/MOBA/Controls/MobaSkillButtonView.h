//
//  MobaSkillButtonView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "MobaControlLayoutPresentation.h"
#import "../Core/MobaOverlayLifecycle.h"

@class MobaSkillCastController;
@class MobaSkillRuntimeDescriptor;

NS_ASSUME_NONNULL_BEGIN

// UIKit owns UITouch conversion and visuals only. Remote input and concrete
// strategies are intentionally absent from this interface.
@interface MobaSkillButtonView : UIView <MobaLayoutEditableControlPresenting,
                                         MobaLocalInteractionResetParticipant>

@property (nonatomic, strong, readonly) MobaSkillRuntimeDescriptor *descriptor;
@property (nonatomic, readonly) MobaOverlayMode mode;
@property (nonatomic, readonly, getter=isPressed) BOOL pressed;
@property (nonatomic, strong, readonly, nullable) id activeTouchToken;
@property (nonatomic, readonly) CGSize visualSize;
@property (nonatomic, readonly) CGFloat hitAreaScale;
@property (nonatomic, readonly) CGFloat normalOpacity;
@property (nonatomic, readonly) CGFloat pressedOpacity;
@property (nonatomic, readonly) CGFloat disabledOpacity;
@property (nonatomic, readonly) CGFloat effectiveVisualOpacity;
@property (nonatomic, copy, readonly) NSString *displayLabel;

- (nullable instancetype)initWithController:(MobaSkillCastController *)controller
                          streamCoordinateView:(UIView *)streamCoordinateView NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setMode:(MobaOverlayMode)mode;

// Deterministic semantic seams used without constructing private UITouch data.
// Points supplied here are already in StreamView coordinates.
- (BOOL)beginInteractionWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)updateInteractionWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)endInteractionWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)cancelInteractionWithToken:(id)token;

@end

NS_ASSUME_NONNULL_END
