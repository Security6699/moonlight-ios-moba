//
//  MobaModeToolbarView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "../Core/MobaOverlayLifecycle.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaModeToolbarView;

@protocol MobaModeToolbarViewDelegate <NSObject>

- (BOOL)mobaModeToolbarView:(MobaModeToolbarView *)toolbar
                requestMode:(MobaOverlayMode)mode;
@optional
- (void)mobaModeToolbarViewDidRequestProfileTransfer:(MobaModeToolbarView *)toolbar;

@end

@interface MobaModeToolbarView : UIView

@property (nonatomic, weak, nullable) id<MobaModeToolbarViewDelegate> delegate;
@property (nonatomic, readonly) MobaOverlayMode selectedMode;
@property (nonatomic, getter=isBattleModeAvailable) BOOL battleModeAvailable;

- (void)setSelectedMode:(MobaOverlayMode)mode;
- (BOOL)requestMode:(MobaOverlayMode)mode;

@end

NS_ASSUME_NONNULL_END
