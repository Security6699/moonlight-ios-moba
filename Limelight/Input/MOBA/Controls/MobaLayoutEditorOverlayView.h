//
//  MobaLayoutEditorOverlayView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "../Profiles/MobaLayoutEditor.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaLayoutEditorOverlayView;

@protocol MobaLayoutEditorOverlayViewDelegate <NSObject>
- (void)layoutEditorOverlayDidRequestSave:(MobaLayoutEditorOverlayView *)overlay;
- (void)layoutEditorOverlayDidRequestRestoreDefaults:(MobaLayoutEditorOverlayView *)overlay;
@end

// Full-stream editing canvas installed only while Layout Edit mode is active.
// It changes typed draft values and never references input or casting objects.
@interface MobaLayoutEditorOverlayView : UIView

@property (nonatomic, weak, nullable) id<MobaLayoutEditorOverlayViewDelegate> delegate;
@property (nonatomic, strong, readonly) MobaLayoutEditorController *editorController;
@property (nonatomic, strong, readonly, nullable) id activeDragToken;

- (instancetype)initWithEditorController:(MobaLayoutEditorController *)editorController NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (BOOL)beginEditingWithToken:(id)token point:(CGPoint)point;
- (BOOL)updateEditingWithToken:(id)token point:(CGPoint)point;
- (BOOL)endEditingWithToken:(id)token;
- (BOOL)cancelEditingWithToken:(id)token;
- (void)cancelEditingInteraction;
- (void)refreshFromDraft;
- (void)showStatusMessage:(nullable NSString *)message error:(BOOL)isError;

@end

NS_ASSUME_NONNULL_END
