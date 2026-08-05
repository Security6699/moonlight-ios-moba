//
//  MobaProfileModels.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

@interface MobaProfileSize : NSObject
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaProfilePoint : NSObject
@property (nonatomic, readonly) double x;
@property (nonatomic, readonly) double y;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaCameraProfile : NSObject
@property (nonatomic, copy, readonly) NSString *mode;
@property (nonatomic, strong, readonly) MobaProfilePoint *heroAnchor;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaRuntimeProfile : NSObject
@property (nonatomic, readonly) NSUInteger schemaVersion;
@property (nonatomic, strong, readonly) MobaProfileSize *canvas;
@property (nonatomic, strong, readonly) MobaProfileSize *requiredStreamResolution;
@property (nonatomic, copy, readonly) NSString *videoMode;
@property (nonatomic, strong, readonly) MobaCameraProfile *camera;
@property (nonatomic, readonly) NSUInteger mouseUpdateRateHz;
@property (nonatomic, readonly) double globalOpacityMultiplier;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaMovementProfile : NSObject
@property (nonatomic, readonly) uint16_t upKeyCode;
@property (nonatomic, readonly) uint16_t leftKeyCode;
@property (nonatomic, readonly) uint16_t downKeyCode;
@property (nonatomic, readonly) uint16_t rightKeyCode;
- (instancetype)init NS_UNAVAILABLE;
@end

typedef NS_ENUM(NSInteger, MobaProfileCancelType) {
    MobaProfileCancelTypeKeyboard,
    MobaProfileCancelTypeRightMouse,
    MobaProfileCancelTypeReleaseOnly,
};

@interface MobaCancelCastActionProfile : NSObject
@property (nonatomic, readonly) MobaProfileCancelType type;
@property (nonatomic, readonly) BOOL hasKeyCode;
@property (nonatomic, readonly) uint16_t keyCode;
@property (nonatomic, readonly) BOOL cancelBeforeSkillKeyUp;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaInputProfile : NSObject
@property (nonatomic, readonly) NSUInteger schemaVersion;
@property (nonatomic, copy, readonly) NSString *profileID;
@property (nonatomic, strong, readonly) MobaMovementProfile *movement;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSNumber *> *actions;
@property (nonatomic, readonly) NSUInteger attackTapDurationMs;
@property (nonatomic, strong, readonly) MobaCancelCastActionProfile *cancelCastAction;
- (nullable NSNumber *)keyCodeForAction:(NSString *)actionName;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaLayoutControlProfile : NSObject
@property (nonatomic, readonly) double centerX;
@property (nonatomic, readonly) double centerY;
@property (nonatomic, readonly) double visualWidthPt;
@property (nonatomic, readonly) double visualHeightPt;
@property (nonatomic, readonly) double hitAreaScale;
@property (nonatomic, strong, readonly, nullable) NSNumber *wheelRadiusPt;
@property (nonatomic, readonly) double opacity;
@property (nonatomic, readonly) double pressedOpacity;
@property (nonatomic, readonly) double disabledOpacity;
@property (nonatomic, readonly) NSInteger zIndex;
@property (nonatomic, readonly, getter=isInteractionEnabled) BOOL interactionEnabled;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaCancelZoneProfile : NSObject
@property (nonatomic, readonly) double centerX;
@property (nonatomic, readonly) double centerY;
@property (nonatomic, readonly) double diameterPt;
@property (nonatomic, readonly) double activationInsetPt;
@property (nonatomic, readonly) double opacity;
@property (nonatomic, readonly) BOOL visibleOnlyWhileCasting;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaLayoutProfile : NSObject
@property (nonatomic, readonly) NSUInteger schemaVersion;
@property (nonatomic, copy, readonly) NSString *layoutID;
@property (nonatomic, copy, readonly) NSString *deviceClass;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, MobaLayoutControlProfile *> *controls;
@property (nonatomic, strong, readonly) MobaCancelZoneProfile *cancelZone;
- (instancetype)init NS_UNAVAILABLE;
@end

typedef NS_ENUM(NSInteger, MobaProfileSkillCastType) {
    MobaProfileSkillCastTypeInstant,
    MobaProfileSkillCastTypeDirectional,
    MobaProfileSkillCastTypePoint,
};

typedef NS_ENUM(NSInteger, MobaProfilePointTargetMode) {
    MobaProfilePointTargetModeNone,
    MobaProfilePointTargetModeGround,
    MobaProfilePointTargetModeUnit,
};

typedef NS_ENUM(NSInteger, MobaProfileSkillActivation) {
    MobaProfileSkillActivationNone,
    MobaProfileSkillActivationOnRelease,
};

typedef NS_ENUM(NSInteger, MobaProfileRangeModel) {
    MobaProfileRangeModelNone,
    MobaProfileRangeModelAsymmetricEllipse,
};

@interface MobaDefaultAimProfile : NSObject
@property (nonatomic, readonly) double angleDegrees;
@property (nonatomic, readonly) double distanceRatio;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaDirectionalRangeProfile : NSObject
@property (nonatomic, readonly) MobaProfileRangeModel model;
@property (nonatomic, readonly) double leftPx;
@property (nonatomic, readonly) double rightPx;
@property (nonatomic, readonly) double upPx;
@property (nonatomic, readonly) double downPx;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaPointRangeProfile : NSObject
@property (nonatomic, readonly) MobaProfileRangeModel model;
@property (nonatomic, readonly) double minLeftPx;
@property (nonatomic, readonly) double minRightPx;
@property (nonatomic, readonly) double minUpPx;
@property (nonatomic, readonly) double minDownPx;
@property (nonatomic, readonly) double maxLeftPx;
@property (nonatomic, readonly) double maxRightPx;
@property (nonatomic, readonly) double maxUpPx;
@property (nonatomic, readonly) double maxDownPx;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaTouchResponseProfile : NSObject
@property (nonatomic, readonly) double deadzoneRatio;
@property (nonatomic, strong, readonly, nullable) NSNumber *fullRangeRatio;
@property (nonatomic, strong, readonly, nullable) NSNumber *curveExponent;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaChampionSkillProfile : NSObject
@property (nonatomic, copy, readonly) NSString *inputAction;
@property (nonatomic, readonly) MobaProfileSkillCastType castType;
@property (nonatomic, readonly) MobaProfilePointTargetMode targetMode;
@property (nonatomic, readonly) MobaProfileSkillActivation activation;
@property (nonatomic, readonly) BOOL hasTapDuration;
@property (nonatomic, readonly) NSUInteger tapDurationMs;
@property (nonatomic, strong, readonly, nullable) MobaDefaultAimProfile *defaultAim;
@property (nonatomic, strong, readonly, nullable) MobaDirectionalRangeProfile *directionalRange;
@property (nonatomic, strong, readonly, nullable) MobaPointRangeProfile *pointRange;
@property (nonatomic, strong, readonly, nullable) MobaTouchResponseProfile *touchResponse;
@property (nonatomic, readonly) BOOL allowCancel;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaChampionProfile : NSObject
@property (nonatomic, readonly) NSUInteger schemaVersion;
@property (nonatomic, copy, readonly) NSString *championID;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly, nullable) NSString *displayNameZhCN;
@property (nonatomic, copy, readonly, nullable) NSString *calibrationStatus;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, MobaChampionSkillProfile *> *skills;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaProfileSnapshot : NSObject
@property (nonatomic, strong, readonly) MobaRuntimeProfile *runtimeProfile;
@property (nonatomic, strong, readonly) MobaInputProfile *inputProfile;
@property (nonatomic, strong, readonly) MobaLayoutProfile *layoutProfile;
@property (nonatomic, strong, readonly) MobaChampionProfile *championProfile;
- (instancetype)initWithRuntimeProfile:(MobaRuntimeProfile *)runtimeProfile
                           inputProfile:(MobaInputProfile *)inputProfile
                          layoutProfile:(MobaLayoutProfile *)layoutProfile
                        championProfile:(MobaChampionProfile *)championProfile NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
