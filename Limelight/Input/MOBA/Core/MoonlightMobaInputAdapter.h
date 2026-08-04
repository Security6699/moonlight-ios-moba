//
//  MoonlightMobaInputAdapter.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#include <stdint.h>

#import "MobaInputSink.h"

@protocol MoonlightMobaInputSending <NSObject>

- (int)sendKeyboardEventWithKeyCode:(int16_t)keyCode
                             action:(int8_t)action
                          modifiers:(int8_t)modifiers;
- (int)sendMousePositionX:(int16_t)x
                        y:(int16_t)y
           referenceWidth:(int16_t)referenceWidth
          referenceHeight:(int16_t)referenceHeight;
- (int)sendMouseButton:(int)button action:(int8_t)action;

@end
// Stateless semantic adapter. MobaInputDispatcher remains the only input state owner.
@interface MoonlightMobaInputAdapter : NSObject <MobaInputSink>

- (instancetype)initWithSender:(id<MoonlightMobaInputSending>)sender NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end
