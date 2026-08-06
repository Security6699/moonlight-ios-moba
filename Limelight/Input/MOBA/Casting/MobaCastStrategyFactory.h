//
//  MobaCastStrategyFactory.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "MobaCastStrategy.h"
#import "MobaDirectionalCastStrategy.h"
#import "MobaInstantCastStrategy.h"
#import "MobaPointCastStrategy.h"
#import "../Core/MobaCursorCoalescer.h"
#import "../Profiles/MobaProfileModels.h"

@class MobaInputDispatcher;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaCastStrategyFactoryErrorDomain;
FOUNDATION_EXPORT NSString *const MobaCastStrategyFactoryChampionIDKey;
FOUNDATION_EXPORT NSString *const MobaCastStrategyFactorySkillSlotKey;
FOUNDATION_EXPORT NSString *const MobaCastStrategyFactoryFieldPathKey;
FOUNDATION_EXPORT NSString *const MobaCastStrategyFactoryOperationKey;

typedef NS_ERROR_ENUM(MobaCastStrategyFactoryErrorDomain, MobaCastStrategyFactoryErrorCode) {
    MobaCastStrategyFactoryErrorMissingCanonicalSkill = 1,
    MobaCastStrategyFactoryErrorMissingLayoutControl,
    MobaCastStrategyFactoryErrorMissingAimedWheelRadius,
    MobaCastStrategyFactoryErrorUnresolvedInputAction,
    MobaCastStrategyFactoryErrorUnsupportedRuntimeCombination,
    MobaCastStrategyFactoryErrorInvalidCancelOrdering,
    MobaCastStrategyFactoryErrorConfigurationRejected,
    MobaCastStrategyFactoryErrorDisplayLinkCreationFailed,
    MobaCastStrategyFactoryErrorInvalidDependency,
};

typedef NSString *MobaCanonicalSkillSlot NS_TYPED_ENUM;
FOUNDATION_EXPORT MobaCanonicalSkillSlot const MobaCanonicalSkillSlotQ;
FOUNDATION_EXPORT MobaCanonicalSkillSlot const MobaCanonicalSkillSlotW;
FOUNDATION_EXPORT MobaCanonicalSkillSlot const MobaCanonicalSkillSlotE;
FOUNDATION_EXPORT MobaCanonicalSkillSlot const MobaCanonicalSkillSlotR;
FOUNDATION_EXPORT NSArray<MobaCanonicalSkillSlot> *MobaCanonicalSkillSlots(void);

FOUNDATION_EXPORT const NSUInteger MobaDefaultKeyboardCancelTapDurationMs;

@protocol MobaDisplayLinkDriverProviding <NSObject>
- (nullable id<MobaDisplayLinkDriving>)newDisplayLinkDriver;
@end

@interface MobaCADisplayLinkDriverProvider : NSObject <MobaDisplayLinkDriverProviding>
@end

@interface MobaSkillRuntimeDescriptor : NSObject

@property (nonatomic, copy, readonly) MobaCanonicalSkillSlot skillSlot;
@property (nonatomic, copy, readonly) NSString *displayLabel;
@property (nonatomic, copy, readonly) NSString *layoutControlName;
@property (nonatomic, copy, readonly) NSString *inputAction;
@property (nonatomic, readonly) uint16_t hostKeyCode;
@property (nonatomic, readonly) MobaProfileSkillCastType castType;
@property (nonatomic, readonly) BOOL allowCancel;
@property (nonatomic, strong, readonly) MobaChampionSkillProfile *skillProfile;
@property (nonatomic, strong, readonly) MobaLayoutControlProfile *layoutControlProfile;
@property (nonatomic, strong, readonly) id<MobaCastStrategy> strategy;
@property (nonatomic, strong, readonly, nullable) MobaCursorCoalescer *cursorCoalescer;
@property (nonatomic, strong, readonly, nullable) MobaInstantCastConfiguration *instantConfiguration;
@property (nonatomic, strong, readonly, nullable) MobaDirectionalCastConfiguration *directionalConfiguration;
@property (nonatomic, strong, readonly, nullable) MobaPointCastConfiguration *pointConfiguration;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MobaChampionRuntime : NSObject

@property (nonatomic, copy, readonly) NSString *championID;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly, nullable) NSString *displayNameZhCN;
@property (nonatomic, copy, readonly, nullable) NSString *calibrationStatus;
@property (nonatomic, copy, readonly) NSDictionary<MobaCanonicalSkillSlot, MobaSkillRuntimeDescriptor *> *skillDescriptors;
@property (nonatomic, copy, readonly) NSArray<id<MobaLocalInteractionResetParticipant>> *localInteractionResetParticipants;

- (nullable MobaSkillRuntimeDescriptor *)descriptorForSkillSlot:(MobaCanonicalSkillSlot)skillSlot;
- (instancetype)init NS_UNAVAILABLE;

@end

@protocol MobaChampionRuntimeBuilding <NSObject>
- (nullable MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot
                                                 error:(NSError **)error;
@end

// Main-thread assembly boundary. It maps already validated typed models into
// immutable runtime descriptors and never reads JSON or profile storage.
@interface MobaCastStrategyFactory : NSObject <MobaChampionRuntimeBuilding>

- (nullable instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                              driverProvider:(id<MobaDisplayLinkDriverProviding>)driverProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot
                                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
