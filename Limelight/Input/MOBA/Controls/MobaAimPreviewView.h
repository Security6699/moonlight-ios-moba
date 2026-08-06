//
//  MobaAimPreviewView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "../Geometry/MobaAimPreviewGeometry.h"

NS_ASSUME_NONNULL_BEGIN

// Draw-only game-space overlay. It has no input, Dispatcher or Strategy API.
@interface MobaAimPreviewView : UIView
@property (nonatomic) CGRect videoRect;
@property (nonatomic) MobaAimPreviewResult previewResult;
@property (nonatomic, readonly) BOOL hasPreviewResult;
- (void)setPreviewResult:(MobaAimPreviewResult)previewResult valid:(BOOL)valid;
@end

NS_ASSUME_NONNULL_END
