//
//  MoonlightMobaInputSender.m
//  Moonlight
//

#import "MoonlightMobaInputSender.h"
#include <Limelight.h>

@implementation MoonlightMobaInputSender

- (int)sendKeyboardEventWithKeyCode:(int16_t)keyCode
                             action:(int8_t)action
                          modifiers:(int8_t)modifiers {
    return LiSendKeyboardEvent(keyCode, action, modifiers);
}

- (int)sendMousePositionX:(int16_t)x
                        y:(int16_t)y
           referenceWidth:(int16_t)referenceWidth
          referenceHeight:(int16_t)referenceHeight {
    return LiSendMousePositionEvent(x, y, referenceWidth, referenceHeight);
}

- (int)sendMouseButton:(int)button action:(int8_t)action {
    return LiSendMouseButtonEvent(action, button);
}

@end
