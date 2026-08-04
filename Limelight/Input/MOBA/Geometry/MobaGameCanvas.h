//
//  MobaGameCanvas.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

FOUNDATION_EXPORT const int16_t MobaGameCanvasWidth;
FOUNDATION_EXPORT const int16_t MobaGameCanvasHeight;
FOUNDATION_EXPORT const int16_t MobaGameCanvasMaxX;
FOUNDATION_EXPORT const int16_t MobaGameCanvasMaxY;

typedef struct {
    int16_t x;
    int16_t y;
} MobaGameCanvasPosition;

// Finite coordinates are clamped to the canvas, then fractional parts are
// discarded toward zero. Non-finite coordinates and a NULL output are rejected.
FOUNDATION_EXPORT BOOL MobaGameCanvasPositionFromPoint(CGPoint point,
                                                       MobaGameCanvasPosition *position);
