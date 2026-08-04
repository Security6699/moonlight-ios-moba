//
//  MobaOverlayCoordinator.h
//  Moonlight
//

#import <Foundation/Foundation.h>

@class StreamView;

typedef NS_ENUM(NSInteger, MobaOverlayMode) {
    MobaOverlayModeBattle,
    MobaOverlayModeUI,
    MobaOverlayModeLayoutEdit,
    MobaOverlayModeSkillTuning,
};

@interface MobaOverlayCoordinator : NSObject

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic) MobaOverlayMode mode;

- (instancetype)initWithStreamView:(StreamView *)streamView;
- (void)start;
- (void)stop;

@end
