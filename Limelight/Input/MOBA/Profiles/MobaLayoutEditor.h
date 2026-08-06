//
//  MobaLayoutEditor.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "MobaProfileDecoder.h"
#import "MobaProfileModels.h"
#import "../Controls/MobaControlLayoutPresentation.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MobaLayoutEditorControlMove;
FOUNDATION_EXPORT NSString *const MobaLayoutEditorControlAttack;
FOUNDATION_EXPORT NSString *const MobaLayoutEditorControlCancelZone;

typedef NS_ENUM(NSInteger, MobaLayoutEditorControlField) {
    MobaLayoutEditorControlFieldCenterX,
    MobaLayoutEditorControlFieldCenterY,
    MobaLayoutEditorControlFieldVisualWidth,
    MobaLayoutEditorControlFieldVisualHeight,
    MobaLayoutEditorControlFieldHitAreaScale,
    MobaLayoutEditorControlFieldWheelRadius,
    MobaLayoutEditorControlFieldNormalOpacity,
    MobaLayoutEditorControlFieldPressedOpacity,
    MobaLayoutEditorControlFieldDisabledOpacity,
};

typedef NS_ENUM(NSInteger, MobaLayoutEditorCancelZoneField) {
    MobaLayoutEditorCancelZoneFieldCenterX,
    MobaLayoutEditorCancelZoneFieldCenterY,
    MobaLayoutEditorCancelZoneFieldDiameter,
    MobaLayoutEditorCancelZoneFieldActivationInset,
    MobaLayoutEditorCancelZoneFieldOpacity,
};

@interface MobaLayoutEditorControlDraft : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *controlName;
@property (nonatomic, readonly) double centerX;
@property (nonatomic, readonly) double centerY;
@property (nonatomic, readonly) double visualWidthPt;
@property (nonatomic, readonly) double visualHeightPt;
@property (nonatomic, readonly) double hitAreaScale;
@property (nonatomic, strong, readonly, nullable) NSNumber *wheelRadiusPt;
@property (nonatomic, readonly, getter=isWheelRadiusEditable) BOOL wheelRadiusEditable;
@property (nonatomic, readonly) double opacity;
@property (nonatomic, readonly) double pressedOpacity;
@property (nonatomic, readonly) double disabledOpacity;
@property (nonatomic, readonly) NSInteger zIndex;
@property (nonatomic, readonly, getter=isInteractionEnabled) BOOL interactionEnabled;
@property (nonatomic, strong, readonly) MobaControlLayoutPresentation *presentation;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MobaLayoutEditorCancelZoneDraft : NSObject <NSCopying>

@property (nonatomic, readonly) double centerX;
@property (nonatomic, readonly) double centerY;
@property (nonatomic, readonly) double diameterPt;
@property (nonatomic, readonly) double activationInsetPt;
@property (nonatomic, readonly) double opacity;
@property (nonatomic, readonly) BOOL visibleOnlyWhileCasting;
@property (nonatomic, strong, readonly) MobaCancelZoneLayoutPresentation *presentation;

- (instancetype)init NS_UNAVAILABLE;

@end

// Mutable editor state with typed public reads. Raw mutable JSON is retained
// privately so candidate serialization can patch managed paths without losing
// unknown schema-v1 fields.
@interface MobaLayoutEditorDraft : NSObject <NSCopying>

@property (nonatomic, readonly) double globalOpacityMultiplier;
@property (nonatomic, copy, readonly) NSArray<NSString *> *controlNames;
@property (nonatomic, strong, readonly) MobaLayoutEditorCancelZoneDraft *cancelZone;

- (nullable instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                              runtimeData:(NSData *)runtimeData
                               layoutData:(NSData *)layoutData
                                    error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaLayoutEditorControlDraft *)controlNamed:(NSString *)controlName;
- (nullable NSData *)candidateRuntimeDataWithError:(NSError **)error;
- (nullable NSData *)candidateLayoutDataWithError:(NSError **)error;

@end

@class MobaLayoutEditorController;

@protocol MobaLayoutEditorControllerDelegate <NSObject>
- (void)layoutEditorControllerDidChangeDraft:(MobaLayoutEditorController *)controller;
@end

// UIKit-free main-thread editing boundary. It owns no view, touch, input
// dispatcher, cast session, or strategy.
@interface MobaLayoutEditorController : NSObject

@property (nonatomic, weak, nullable) id<MobaLayoutEditorControllerDelegate> delegate;
@property (nonatomic, strong, readonly) MobaLayoutEditorDraft *draft;
@property (nonatomic, copy, readonly, nullable) NSString *selectedControlName;
@property (nonatomic, readonly, getter=isDirty) BOOL dirty;
@property (nonatomic) MobaControlOpacityPreviewState opacityPreviewState;

- (nullable instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                              runtimeData:(NSData *)runtimeData
                               layoutData:(NSData *)layoutData
                                  decoder:(MobaProfileDecoder *)decoder
                                    error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)selectControlNamed:(nullable NSString *)controlName;
- (nullable NSString *)selectTopmostControlAtPoint:(CGPoint)point
                                      safeAreaFrame:(CGRect)safeAreaFrame;
- (BOOL)moveSelectedControlToPoint:(CGPoint)point safeAreaFrame:(CGRect)safeAreaFrame;
- (BOOL)setSelectedControlValue:(double)value forField:(MobaLayoutEditorControlField)field;
- (BOOL)setSelectedControlInteractionEnabled:(BOOL)enabled;
- (BOOL)adjustSelectedControlZIndexBy:(NSInteger)delta;
- (BOOL)setCancelZoneValue:(double)value forField:(MobaLayoutEditorCancelZoneField)field;
- (void)setCancelZoneVisibleOnlyWhileCasting:(BOOL)visibleOnlyWhileCasting;
- (BOOL)setGlobalOpacityMultiplierValue:(double)value;

- (void)revert;
- (BOOL)restoreDefaultsFromRuntimeData:(NSData *)runtimeData
                            layoutData:(NSData *)layoutData
                                 error:(NSError **)error;
- (BOOL)acceptSavedSnapshot:(MobaProfileSnapshot *)snapshot
                runtimeData:(NSData *)runtimeData
                 layoutData:(NSData *)layoutData
                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
