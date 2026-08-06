//
//  MobaSkillTuningOverlayView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "../Profiles/MobaSkillTuning.h"

@class MobaAimPreviewView;
@class MobaSkillTuningOverlayView;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaSkillTuningCastMode) {
    MobaSkillTuningCastModePreviewOnly,
    MobaSkillTuningCastModeLiveCast,
};

@protocol MobaSkillTuningOverlayViewDelegate <NSObject>
- (void)skillTuningOverlay:(MobaSkillTuningOverlayView *)overlay
            didSelectSkill:(MobaCanonicalSkillSlot)skillSlot;
- (void)skillTuningOverlay:(MobaSkillTuningOverlayView *)overlay
     didRequestCastMode:(MobaSkillTuningCastMode)castMode;
- (void)skillTuningOverlayDidChangeDraft:(MobaSkillTuningOverlayView *)overlay;
- (void)skillTuningOverlayDidRequestSave:(MobaSkillTuningOverlayView *)overlay;
- (void)skillTuningOverlayDidRequestRevert:(MobaSkillTuningOverlayView *)overlay;
- (void)skillTuningOverlayDidRequestRestoreDefaults:(MobaSkillTuningOverlayView *)overlay;
@end

// UIKit inspector and local preview gesture surface. It never imports or calls
// Dispatcher, Session, Strategy, Adapter or Moonlight input APIs.
@interface MobaSkillTuningOverlayView : UIView
@property (nonatomic, weak, nullable) id<MobaSkillTuningOverlayViewDelegate> delegate;
@property (nonatomic, strong, readonly) MobaSkillTuningController *tuningController;
@property (nonatomic, strong, readonly) MobaAimPreviewView *aimPreviewView;
@property (nonatomic, readonly) MobaSkillTuningCastMode castMode;
@property (nonatomic, readonly) CGVector previewDisplacement;
@property (nonatomic, strong, readonly) UIScrollView *inspectorScrollView;
@property (nonatomic, copy, readonly) NSArray<NSString *> *visibleFieldLabels;
@property (nonatomic, readonly, getter=isEditingEnabled) BOOL editingEnabled;
@property (nonatomic, strong, readonly) UISegmentedControl *castModeControl;

- (instancetype)initWithTuningController:(MobaSkillTuningController *)tuningController
                             championName:(NSString *)championName NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setVideoRect:(CGRect)videoRect;
- (void)setCastMode:(MobaSkillTuningCastMode)castMode;
- (void)setEditingEnabled:(BOOL)enabled;
- (void)refreshFromDraft;
- (void)showStatusMessage:(nullable NSString *)message error:(BOOL)isError;

// Deterministic preview-only seam using already converted StreamView points.
- (BOOL)beginPreviewWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)updatePreviewWithToken:(id)token streamViewPoint:(CGPoint)point;
- (BOOL)endPreviewWithToken:(id)token;
- (BOOL)endPreviewWithToken:(id)token streamViewPoint:(CGPoint)point;
- (void)cancelPreview;
@end

NS_ASSUME_NONNULL_END
