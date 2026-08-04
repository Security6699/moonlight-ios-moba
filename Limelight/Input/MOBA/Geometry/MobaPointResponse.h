//
//  MobaPointResponse.h
//  Moonlight
//


#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Maps drag distance to a normalized point-cast distance ratio.
/// The output is always in 0...1 when the function succeeds.
FOUNDATION_EXPORT BOOL MobaPointResponseDistanceRatio(CGFloat dragDistance,
                                                       CGFloat wheelRadius,
                                                       CGFloat deadzoneRatio,
                                                       CGFloat fullRangeRatio,
                                                       CGFloat curveExponent,
                                                       CGFloat * _Nullable distanceRatio);

NS_ASSUME_NONNULL_END
