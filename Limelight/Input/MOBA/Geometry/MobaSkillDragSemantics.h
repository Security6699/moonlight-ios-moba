//
//  MobaSkillDragSemantics.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class MobaSkillRuntimeDescriptor;

NS_ASSUME_NONNULL_BEGIN

// Directional profiles created before touch response was required use this
// named orchestration fallback. It matches the bundled directional profiles.
FOUNDATION_EXPORT const CGFloat MobaDirectionalMeaningfulDragDeadzoneRatio;

// Shared production and preview boundary. The threshold comparison is strict.
FOUNDATION_EXPORT BOOL MobaSkillMeaningfulDragForDescriptor(
    MobaSkillRuntimeDescriptor *descriptor,
    CGVector dragDisplacement);

NS_ASSUME_NONNULL_END
