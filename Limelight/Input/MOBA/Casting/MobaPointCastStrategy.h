//
//  MobaPointCastStrategy.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#include <stdint.h>

#import "MobaCastStrategy.h"
#import "../Geometry/MobaAimGeometry.h"

@class MobaInputDispatcher;
@protocol MobaCursorCoalescing;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaPointCastTargetMode) {
    MobaPointCastTargetModeGround,
    MobaPointCastTargetModeUnit,
};

@interface MobaPointCastConfiguration : NSObject

@property (nonatomic, readonly) MobaPointCastTargetMode targetMode;
@property (nonatomic, readonly) uint16_t skillKeyCode;
@property (nonatomic, readonly) CGPoint heroAnchor;
@property (nonatomic, readonly) CGVector defaultDirection;
@property (nonatomic, readonly) CGFloat defaultDistanceRatio;
@property (nonatomic, readonly) CGFloat wheelRadius;
@property (nonatomic, readonly) CGFloat deadzoneRatio;
@property (nonatomic, readonly) CGFloat fullRangeRatio;
@property (nonatomic, readonly) CGFloat curveExponent;
@property (nonatomic, readonly) MobaAimRadii minimumRadii;
@property (nonatomic, readonly) MobaAimRadii maximumRadii;
@property (nonatomic, strong, readonly) MobaCastCancelAction *cancelAction;

// Uses the product default of 270 degrees and a distance ratio of 1.0.
+ (nullable instancetype)defaultConfigurationWithTargetMode:(MobaPointCastTargetMode)targetMode
                                               skillKeyCode:(uint16_t)skillKeyCode
                                                 heroAnchor:(CGPoint)heroAnchor
                                                wheelRadius:(CGFloat)wheelRadius
                                              deadzoneRatio:(CGFloat)deadzoneRatio
                                              fullRangeRatio:(CGFloat)fullRangeRatio
                                              curveExponent:(CGFloat)curveExponent
                                               minimumRadii:(MobaAimRadii)minimumRadii
                                               maximumRadii:(MobaAimRadii)maximumRadii
                                                cancelAction:(MobaCastCancelAction *)cancelAction;

- (nullable instancetype)initWithTargetMode:(MobaPointCastTargetMode)targetMode
                                skillKeyCode:(uint16_t)skillKeyCode
                                  heroAnchor:(CGPoint)heroAnchor
                            defaultDirection:(CGVector)defaultDirection
                        defaultDistanceRatio:(CGFloat)defaultDistanceRatio
                                 wheelRadius:(CGFloat)wheelRadius
                               deadzoneRatio:(CGFloat)deadzoneRatio
                              fullRangeRatio:(CGFloat)fullRangeRatio
                               curveExponent:(CGFloat)curveExponent
                                minimumRadii:(MobaAimRadii)minimumRadii
                                maximumRadii:(MobaAimRadii)maximumRadii
                                 cancelAction:(MobaCastCancelAction *)cancelAction NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

// Ground and Unit modes intentionally share this direct coordinate strategy.
// Unit mode does not detect, snap to, validate, or provide fallback targets.
@interface MobaPointCastStrategy : NSObject <MobaCastStrategy>

@property (nonatomic, readonly) MobaPointCastTargetMode targetMode;
@property (nonatomic, readonly) BOOL hasLatestTarget;
@property (nonatomic, readonly) CGPoint latestTarget;

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaPointCastConfiguration *)configuration;
- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaPointCastConfiguration *)configuration
                    cursorCoalescer:(nullable id<MobaCursorCoalescing>)cursorCoalescer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// The same displacement supplies both direction and distance. An accepted
// AimingDefault update restores and coalesces the per-cast default target,
// CancelArmed keeps it unsent, and AimingDragged coalesces a valid response.
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result
                  dragDisplacement:(CGVector)dragDisplacement;

@end

NS_ASSUME_NONNULL_END
