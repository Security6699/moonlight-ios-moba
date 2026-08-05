//
//  MobaInstantCastStrategy.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#include <stdint.h>

#import "MobaCastStrategy.h"

@class MobaInputDispatcher;

NS_ASSUME_NONNULL_BEGIN

@interface MobaInstantCastConfiguration : NSObject

@property (nonatomic, readonly) uint16_t skillKeyCode;
@property (nonatomic, readonly) NSUInteger tapDurationMs;

- (instancetype)initWithSkillKeyCode:(uint16_t)skillKeyCode
                        tapDurationMs:(NSUInteger)tapDurationMs;

@end

// Instant casts enqueue one configured tap only when a committed terminal
// result is consumed. Begin, update, cancellation, and silent reset send no input.
@interface MobaInstantCastStrategy : NSObject <MobaCastStrategy>

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                      configuration:(MobaInstantCastConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result;

@end

NS_ASSUME_NONNULL_END
