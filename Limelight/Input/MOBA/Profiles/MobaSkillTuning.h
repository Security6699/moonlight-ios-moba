//
//  MobaSkillTuning.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileRepository.h"
#import "../Casting/MobaCastStrategyFactory.h"
#import "../Controls/MobaSkillControlPackage.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaSkillTuningErrorDomain;

typedef NS_ERROR_ENUM(MobaSkillTuningErrorDomain, MobaSkillTuningErrorCode) {
    MobaSkillTuningErrorInvalidBaseline = 1,
    MobaSkillTuningErrorInvalidField,
    MobaSkillTuningErrorSerializationFailed,
    MobaSkillTuningErrorCandidateRejected,
};

typedef NS_ENUM(NSInteger, MobaSkillTuningField) {
    MobaSkillTuningFieldDefaultAngleDegrees,
    MobaSkillTuningFieldDefaultDistanceRatio,
    MobaSkillTuningFieldDirectionalLeftPx,
    MobaSkillTuningFieldDirectionalRightPx,
    MobaSkillTuningFieldDirectionalUpPx,
    MobaSkillTuningFieldDirectionalDownPx,
    MobaSkillTuningFieldPointMinLeftPx,
    MobaSkillTuningFieldPointMinRightPx,
    MobaSkillTuningFieldPointMinUpPx,
    MobaSkillTuningFieldPointMinDownPx,
    MobaSkillTuningFieldPointMaxLeftPx,
    MobaSkillTuningFieldPointMaxRightPx,
    MobaSkillTuningFieldPointMaxUpPx,
    MobaSkillTuningFieldPointMaxDownPx,
    MobaSkillTuningFieldTouchDeadzoneRatio,
    MobaSkillTuningFieldTouchFullRangeRatio,
    MobaSkillTuningFieldTouchCurveExponent,
};

// Immutable typed projection for one skill. Optional values remain absent for
// cast types where the schema does not define them.
@interface MobaSkillTuningSkillValue : NSObject
@property (nonatomic, copy, readonly) MobaCanonicalSkillSlot skillSlot;
@property (nonatomic, readonly) MobaProfileSkillCastType castType;
@property (nonatomic, readonly) BOOL allowCancel;
@property (nonatomic, strong, readonly, nullable) NSNumber *defaultAngleDegrees;
@property (nonatomic, strong, readonly, nullable) NSNumber *defaultDistanceRatio;
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, NSNumber *> *numericValues;
- (instancetype)init NS_UNAVAILABLE;
@end

// Foundation-only mutable editor state. Raw JSON containers remain private and
// serialized copies are the only persistence boundary.
@interface MobaSkillTuningDraft : NSObject
@property (nonatomic, readonly) double heroAnchorX;
@property (nonatomic, readonly) double heroAnchorY;
@property (nonatomic, readonly) NSUInteger mouseUpdateRateHz;
@property (nonatomic, readonly, getter=isDirty) BOOL dirty;

- (nullable instancetype)initWithRuntimeData:(NSData *)runtimeData
                                championData:(NSData *)championData
                                     decoder:(MobaProfileDecoder *)decoder
                                       error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaSkillTuningSkillValue *)skillValueForSlot:(MobaCanonicalSkillSlot)slot;
- (BOOL)setHeroAnchorX:(double)x y:(double)y error:(NSError **)error;
- (BOOL)setMouseUpdateRateHz:(NSUInteger)rate error:(NSError **)error;
- (BOOL)setValue:(id)value
        forField:(MobaSkillTuningField)field
       skillSlot:(MobaCanonicalSkillSlot)slot
           error:(NSError **)error;
- (BOOL)setAllowCancel:(BOOL)allowCancel
             skillSlot:(MobaCanonicalSkillSlot)slot
                 error:(NSError **)error;

- (nullable NSData *)runtimeDataWithError:(NSError **)error;
- (nullable NSData *)championDataWithError:(NSError **)error;
- (BOOL)replaceWithRuntimeData:(NSData *)runtimeData
                  championData:(NSData *)championData
                       decoder:(MobaProfileDecoder *)decoder
                         error:(NSError **)error;
- (BOOL)applyManagedDefaultsFromRuntimeData:(NSData *)runtimeData
                               championData:(NSData *)championData
                                    decoder:(MobaProfileDecoder *)decoder
                                      error:(NSError **)error;
- (void)revert;
- (BOOL)acceptCurrentValuesAsBaselineWithError:(NSError **)error;
@end

// Rebuilds a complete Runtime + Champion candidate and all four skill controls
// after each edit. Invalid edits never replace the last valid candidate.
@interface MobaSkillTuningController : NSObject
@property (nonatomic, strong, readonly) MobaSkillTuningDraft *draft;
@property (nonatomic, copy) MobaCanonicalSkillSlot selectedSkillSlot;
@property (nonatomic, strong, readonly, nullable) MobaProfileRepositoryCandidate *lastValidCandidate;
@property (nonatomic, strong, readonly, nullable) MobaChampionRuntime *lastValidRuntime;
@property (nonatomic, strong, readonly, nullable) MobaSkillControlPackage *lastValidControlPackage;
@property (nonatomic, strong, readonly, nullable) NSError *validationError;

- (nullable instancetype)initWithRuntimeData:(NSData *)runtimeData
                                championData:(NSData *)championData
                                     decoder:(MobaProfileDecoder *)decoder
                                  repository:(MobaProfileRepository *)repository
                              runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                       controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                                       error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)refreshCandidateWithError:(NSError **)error;
- (BOOL)restoreDefaultsFromRuntimeData:(NSData *)runtimeData
                          championData:(NSData *)championData
                                 error:(NSError **)error;
- (BOOL)revertWithError:(NSError **)error;
- (BOOL)acceptSavedRuntimeData:(NSData *)runtimeData
                  championData:(NSData *)championData
                         error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
