//
//  MobaControlLayoutPresentation.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaControlOpacityPreviewState) {
    MobaControlOpacityPreviewStateAutomatic,
    MobaControlOpacityPreviewStateNormal,
    MobaControlOpacityPreviewStatePressed,
    MobaControlOpacityPreviewStateDisabled,
};

// Immutable presentation values shared by gameplay controls and the layout
// editor. This object contains UIKit layout values only, never game-canvas
// aiming values or input state.
@interface MobaControlLayoutPresentation : NSObject <NSCopying>

@property (nonatomic, readonly) double centerX;
@property (nonatomic, readonly) double centerY;
@property (nonatomic, readonly) CGSize visualSize;
@property (nonatomic, readonly) CGFloat hitAreaScale;
@property (nonatomic, strong, readonly, nullable) NSNumber *wheelRadiusPt;
@property (nonatomic, readonly) CGFloat normalOpacity;
@property (nonatomic, readonly) CGFloat pressedOpacity;
@property (nonatomic, readonly) CGFloat disabledOpacity;
@property (nonatomic, readonly) NSInteger zIndex;
@property (nonatomic, readonly, getter=isInteractionEnabled) BOOL interactionEnabled;

- (nullable instancetype)initWithCenterX:(double)centerX
                                 centerY:(double)centerY
                              visualSize:(CGSize)visualSize
                            hitAreaScale:(CGFloat)hitAreaScale
                           wheelRadiusPt:(nullable NSNumber *)wheelRadiusPt
                           normalOpacity:(CGFloat)normalOpacity
                          pressedOpacity:(CGFloat)pressedOpacity
                         disabledOpacity:(CGFloat)disabledOpacity
                                  zIndex:(NSInteger)zIndex
                      interactionEnabled:(BOOL)interactionEnabled NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface MobaCancelZoneLayoutPresentation : NSObject <NSCopying>

@property (nonatomic, readonly) double centerX;
@property (nonatomic, readonly) double centerY;
@property (nonatomic, readonly) CGFloat diameterPt;
@property (nonatomic, readonly) CGFloat activationInsetPt;
@property (nonatomic, readonly) CGFloat opacity;
@property (nonatomic, readonly) BOOL visibleOnlyWhileCasting;

- (nullable instancetype)initWithCenterX:(double)centerX
                                 centerY:(double)centerY
                              diameterPt:(CGFloat)diameterPt
                       activationInsetPt:(CGFloat)activationInsetPt
                                 opacity:(CGFloat)opacity
                 visibleOnlyWhileCasting:(BOOL)visibleOnlyWhileCasting NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT CGFloat MobaEffectiveControlOpacity(CGFloat perStateOpacity,
                                                      CGFloat globalOpacityMultiplier);

@protocol MobaLayoutEditableControlPresenting <NSObject>

- (void)applyControlLayoutPresentation:(MobaControlLayoutPresentation *)presentation
               globalOpacityMultiplier:(CGFloat)globalOpacityMultiplier
                          previewState:(MobaControlOpacityPreviewState)previewState;

@end

@protocol MobaLayoutEditableCancelZonePresenting <NSObject>

- (void)applyCancelZoneLayoutPresentation:(MobaCancelZoneLayoutPresentation *)presentation
                  globalOpacityMultiplier:(CGFloat)globalOpacityMultiplier
                            editorPreview:(BOOL)editorPreview
                             previewState:(MobaControlOpacityPreviewState)previewState;

@end

NS_ASSUME_NONNULL_END
