//
//  MobaPointCastGeometry.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "MobaAimGeometry.h"

NS_ASSUME_NONNULL_BEGIN

// Interpolates radially between asymmetric minimum and maximum ellipse
// intersections. distanceRatio is clamped to 0...1. A selected zero minimum
// radius makes the minimum distance zero for that ray. No canvas clamping or
// integer conversion occurs here.
FOUNDATION_EXPORT BOOL MobaPointCastTargetForDirection(CGPoint anchor,
                                                       CGVector direction,
                                                       MobaAimRadii minimumRadii,
                                                       MobaAimRadii maximumRadii,
                                                       CGFloat distanceRatio,
                                                       CGPoint * _Nullable target);

NS_ASSUME_NONNULL_END
