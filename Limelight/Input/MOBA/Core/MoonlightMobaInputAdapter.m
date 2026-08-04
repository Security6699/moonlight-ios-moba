//
//  MoonlightMobaInputAdapter.m
//  Moonlight
//

#import "MoonlightMobaInputAdapter.h"
#import "../Geometry/MobaGameCanvas.h"
#include <Limelight.h>

@implementation MoonlightMobaInputAdapter {
    id<MoonlightMobaInputSending> _sender;
}

- (instancetype)initWithSender:(id<MoonlightMobaInputSending>)sender {
    self = [super init];
    if (self) {
        NSParameterAssert(sender != nil);
        _sender = sender;
    }
    return self;
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    int16_t moonlightKeyCode = (int16_t)(0x8000u | keyCode);
    [_sender sendKeyboardEventWithKeyCode:moonlightKeyCode
                                   action:down ? KEY_ACTION_DOWN : KEY_ACTION_UP
                                modifiers:0];
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    MobaGameCanvasPosition position;
    if (!MobaGameCanvasPositionFromPoint(point, &position)) {
        return;
    }

    [_sender sendMousePositionX:position.x
                              y:position.y
                 referenceWidth:MobaGameCanvasWidth
                referenceHeight:MobaGameCanvasHeight];
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    [_sender sendMouseButton:button
                      action:down ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE];
}

@end
