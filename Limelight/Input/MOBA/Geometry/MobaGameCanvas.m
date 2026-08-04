//
//  MobaGameCanvas.m
//  Moonlight
//

#import "MobaGameCanvas.h"
#import <math.h>

const int16_t MobaGameCanvasWidth = 2560;
const int16_t MobaGameCanvasHeight = 1440;
const int16_t MobaGameCanvasMaxX = 2559;
const int16_t MobaGameCanvasMaxY = 1439;

BOOL MobaGameCanvasPositionFromPoint(CGPoint point, MobaGameCanvasPosition *position) {
    if (position == NULL || !isfinite(point.x) || !isfinite(point.y)) {
        return NO;
    }

    CGFloat clampedX = MIN(MAX(point.x, 0.0), (CGFloat)MobaGameCanvasMaxX);
    CGFloat clampedY = MIN(MAX(point.y, 0.0), (CGFloat)MobaGameCanvasMaxY);
    position->x = (int16_t)trunc(clampedX);
    position->y = (int16_t)trunc(clampedY);
    return YES;
}
