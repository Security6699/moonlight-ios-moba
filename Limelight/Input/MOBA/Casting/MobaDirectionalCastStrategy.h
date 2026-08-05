//
//  MobaDirectionalCastStrategy.h
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

@interface MobaDirectionalCastConfiguration : NSObject

@property (nonatomic, readonly) uint16_t skillKeyCode;
@property (nonatomic, readonly) CGPoint heroAnchor;
@property (nonatomic, readonly) MobaAimRadii aimRadii;
@property (nonatomic, readonly) CGVector defaultDirection;
@property (nonatomic, readonly) CGFloat defaultDistanceRatio;
@property (nonatomic, strong, readonly) MobaCastCancelAction *cancelAction;

// Uses the product default of 270 degrees and a distance ratio of 1.0.
+ (nullable instancetype)defaultConfigurationWithSkillKeyCode:(uint16_t)skillKeyCode
                                                   heroAnchor:(CGPoint)heroAnchor
                                                      radii:(MobaAimRadii)radii
                                                 cancelAction:(MobaCastCancelAction *)cancelAction;

- (nullable instancetype)initWithSkillKeyCode:(uint16_t)skillKeyCode
                                    heroAnchor:(CGPoint)heroAnchor
                                       radii:(MobaAimRadii)radii
                              defaultDirection:(CGVector)defaultDirection
                          defaultDistanceRatio:(CGFloat)defaultDistanceRatio
                                  cancelAction:(MobaCastCancelAction *)cancelAction NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

// Directional casts send the default cursor and skill down at begin. Updates
// replace latestTarget and optionally submit it to a coalescer. Commit stops
// coalescing before the Dispatcher's atomic final-cursor plus key-up operation.
@interface MobaDirectionalCastStrategy : NSObject <MobaCastStrategy>

@property (nonatomic, readonly) BOOL hasLatestTarget;
@property (nonatomic, readonly) CGPoint latestTarget;

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaDirectionalCastConfiguration *)configuration;
- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaDirectionalCastConfiguration *)configuration
                    cursorCoalescer:(nullable id<MobaCursorCoalescing>)cursorCoalescer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result
                     dragDirection:(CGVector)dragDirection;

@end

NS_ASSUME_NONNULL_END
