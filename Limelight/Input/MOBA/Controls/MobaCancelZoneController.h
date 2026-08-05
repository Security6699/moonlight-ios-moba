//
//  MobaCancelZoneController.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "../Casting/MobaCastStateMachine.h"
#import "../Geometry/MobaCancelZoneGeometry.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MobaCancelZonePresenting <NSObject>

- (void)setCancelZoneCastingVisible:(BOOL)visible;
- (void)setCancelZoneArmed:(BOOL)armed;
- (void)resetCancelZonePresentation;

@end

// Pure semantic owner for one shared cancel-zone presentation. It consumes
// caller-space points and accepted Session results but never calls Session,
// Strategy, Dispatcher, or a remote input API.
@interface MobaCancelZoneController : NSObject

@property (nonatomic, weak, nullable) id<MobaCancelZonePresenting> presentation;
@property (nonatomic, readonly) MobaCancelZoneGeometry geometry;
@property (nonatomic, readonly, getter=isCastingActive) BOOL castingActive;
@property (nonatomic, readonly, getter=isArmed) BOOL armed;
@property (nonatomic, strong, readonly, nullable) id activeCastToken;

- (nullable instancetype)initWithGeometry:(MobaCancelZoneGeometry)geometry
                              presentation:(nullable id<MobaCancelZonePresenting>)presentation NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)updateGeometry:(MobaCancelZoneGeometry)geometry;
- (BOOL)beginCastingWithToken:(id)token;
- (BOOL)evaluatePoint:(CGPoint)point
              forToken:(id)token
      insideCancelZone:(BOOL *)insideCancelZone;
- (BOOL)applyAcceptedTransitionResult:(MobaCastTransitionResult)result
                              forToken:(id)token;
- (BOOL)endCastingWithToken:(id)token;
- (void)silentReset;

@end

NS_ASSUME_NONNULL_END
