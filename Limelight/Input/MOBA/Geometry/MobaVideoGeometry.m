//
//  MobaVideoGeometry.m
//  Moonlight
//

#import "MobaVideoGeometry.h"
#import <math.h>

const CGSize MobaRequiredBattleStreamResolution = { 2560.0, 1440.0 };

static BOOL MobaSizeIsValid(CGSize size) {
    return isfinite(size.width) && isfinite(size.height) &&
           size.width > 0.0 && size.height > 0.0;
}

CGRect MobaAspectFitVideoRect(CGRect bounds, CGSize videoSize) {
    if (!MobaSizeIsValid(bounds.size) || !MobaSizeIsValid(videoSize) ||
        !isfinite(CGRectGetMinX(bounds)) || !isfinite(CGRectGetMinY(bounds))) {
        return CGRectZero;
    }

    CGFloat scale = MIN(bounds.size.width / videoSize.width,
                        bounds.size.height / videoSize.height);
    CGSize fittedSize = CGSizeMake(videoSize.width * scale, videoSize.height * scale);

    return CGRectMake(CGRectGetMinX(bounds) + (bounds.size.width - fittedSize.width) / 2.0,
                      CGRectGetMinY(bounds) + (bounds.size.height - fittedSize.height) / 2.0,
                      fittedSize.width,
                      fittedSize.height);
}

BOOL MobaStreamResolutionAllowsBattleMode(CGSize streamResolution) {
    return streamResolution.width == MobaRequiredBattleStreamResolution.width &&
           streamResolution.height == MobaRequiredBattleStreamResolution.height;
}
