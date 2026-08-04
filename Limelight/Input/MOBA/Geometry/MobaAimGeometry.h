//
//  MobaAimGeometry.h
//  Moonlight
//


#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGFloat leftPx;
    CGFloat rightPx;
    CGFloat upPx;
    CGFloat downPx;
} MobaAimRadii;

NS_INLINE MobaAimRadii MobaAimRadiiMake(CGFloat leftPx,
                                        CGFloat rightPx,
                                        CGFloat upPx,
                                        CGFloat downPx) {
    MobaAimRadii radii;
    radii.leftPx = leftPx;
    radii.rightPx = rightPx;
    radii.upPx = upPx;
    radii.downPx = downPx;
    return radii;
}

/// Returns the direction for 270 degrees under the game-canvas convention.
/// Zero degrees points right and positive Y points down.
FOUNDATION_EXPORT CGVector MobaAimDefaultUpDirection(void);

/// Intersects a direction ray with an asymmetric ellipse and scales the result.
/// The direction is normalized internally and distanceRatio is clamped to 0...1.
/// This function does not clamp the result to the game canvas.
FOUNDATION_EXPORT BOOL MobaAimTargetForDirection(CGPoint anchor,
                                                 CGVector direction,
                                                 MobaAimRadii radii,
                                                 CGFloat distanceRatio,
                                                 CGPoint * _Nullable target);

NS_ASSUME_NONNULL_END
