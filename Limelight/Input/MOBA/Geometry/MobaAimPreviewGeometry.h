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

// Builds a closed-loop-ready Directional range boundary in fixed game-canvas
// coordinates. Every sample reuses production Directional aim geometry.
FOUNDATION_EXPORT NSArray<NSValue *> *MobaDirectionalAimPreviewBoundaryPoints(
    CGPoint anchor,
    MobaAimRadii radii,
    NSUInteger sampleCount);

// Builds a Point range boundary through production Point geometry. A ratio of
// zero represents the minimum boundary and one represents the maximum.
FOUNDATION_EXPORT NSArray<NSValue *> *MobaPointAimPreviewBoundaryPoints(
    CGPoint anchor,
    MobaAimRadii minimumRadii,
    MobaAimRadii maximumRadii,
    CGFloat distanceRatio,
    NSUInteger sampleCount);

// Result-facing seams keep cast-type selection and production geometry in this
// pure layer. UIKit receives only clamped game-space points to draw.
FOUNDATION_EXPORT NSArray<NSValue *> *MobaAimPreviewMinimumBoundaryPoints(
    MobaAimPreviewResult result,
    NSUInteger sampleCount);
FOUNDATION_EXPORT NSArray<NSValue *> *MobaAimPreviewMaximumBoundaryPoints(
    MobaAimPreviewResult result,
    NSUInteger sampleCount);

// Reuses the production directional and point geometry. The result target is
// clamped through MobaGameCanvas after geometry calculation.
FOUNDATION_EXPORT BOOL MobaAimPreviewResultForDescriptor(MobaSkillRuntimeDescriptor *descriptor,
                                                          CGVector dragDisplacement,
                                                          MobaAimPreviewResult * _Nullable result);

NS_ASSUME_NONNULL_END
