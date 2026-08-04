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
@property (nonatomic, readonly, getter=isBattleModeAvailable) BOOL battleModeAvailable;

// Future MOBA battle input must only be emitted while this value is YES.
@property (nonatomic, readonly, getter=isBattleInputAllowed) BOOL battleInputAllowed;

- (instancetype)initWithStreamView:(StreamView *)streamView;
- (BOOL)transitionToMode:(MobaOverlayMode)mode;
- (void)start;
- (void)stop;

@end
