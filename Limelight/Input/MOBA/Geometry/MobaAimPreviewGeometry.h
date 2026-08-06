//
//  MobaAimPreviewGeometry.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "MobaAimGeometry.h"

@class MobaSkillRuntimeDescriptor;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGPoint anchor;
    CGPoint defaultTarget;
    CGPoint target;
    CGVector direction;
    MobaAimRadii minimumRadii;
    MobaAimRadii maximumRadii;
    CGFloat distanceRatio;
    BOOL pointCast;
} MobaAimPreviewResult;

// Maps the fixed inclusive game canvas endpoints onto the supplied aspect-fit
// video rectangle. Safe-area and control layout coordinates are not inputs.
FOUNDATION_EXPORT BOOL MobaAimPreviewMapGamePointToVideoRect(CGPoint gamePoint,
                                                              CGRect videoRect,
                                                              CGPoint * _Nullable viewPoint);

// Reuses the production directional and point geometry. The result target is
// clamped through MobaGameCanvas after geometry calculation.
FOUNDATION_EXPORT BOOL MobaAimPreviewResultForDescriptor(MobaSkillRuntimeDescriptor *descriptor,
                                                          CGVector dragDisplacement,
                                                          MobaAimPreviewResult * _Nullable result);

NS_ASSUME_NONNULL_END
