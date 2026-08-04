//
//  MobaVideoGeometry.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

FOUNDATION_EXPORT const CGSize MobaRequiredBattleStreamResolution;

// Returns CGRectZero when bounds or videoSize has a non-positive or non-finite dimension.
FOUNDATION_EXPORT CGRect MobaAspectFitVideoRect(CGRect bounds, CGSize videoSize);

// Battle mode requires an exact match. No alternate resolution or orientation is accepted.
FOUNDATION_EXPORT BOOL MobaStreamResolutionAllowsBattleMode(CGSize streamResolution);
