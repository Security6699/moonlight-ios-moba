//
//  MobaDisplayLinkDriving.h
//  Moonlight
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MobaCursorUpdateRate) {
    MobaCursorUpdateRate30Hz = 30,
    MobaCursorUpdateRate60Hz = 60,
    MobaCursorUpdateRate120Hz = 120,
};

FOUNDATION_EXPORT const MobaCursorUpdateRate MobaCursorUpdateRateDefault;
FOUNDATION_EXPORT BOOL MobaCursorUpdateRateIsValid(MobaCursorUpdateRate updateRate);

typedef void (^MobaDisplayLinkTickHandler)(void);

// Display-link timing boundary used by the non-UIKit cursor coalescer.
// Callers invoke every method on the main thread.
@protocol MobaDisplayLinkDriving <NSObject>

@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate
                tickHandler:(MobaDisplayLinkTickHandler)tickHandler;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
