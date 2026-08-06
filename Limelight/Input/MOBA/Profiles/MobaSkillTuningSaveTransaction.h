//
//  MobaSkillTuningSaveTransaction.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaSkillTuning.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaSkillTuningSaveTransactionErrorDomain;

typedef NS_ERROR_ENUM(MobaSkillTuningSaveTransactionErrorDomain, MobaSkillTuningSaveTransactionErrorCode) {
    MobaSkillTuningSaveTransactionErrorSerializationFailed = 1,
    MobaSkillTuningSaveTransactionErrorCandidateRejected,
    MobaSkillTuningSaveTransactionErrorRuntimeRejected,
    MobaSkillTuningSaveTransactionErrorPackageRejected,
    MobaSkillTuningSaveTransactionErrorPersistenceFailed,
    MobaSkillTuningSaveTransactionErrorRepositoryCommitFailed,
    MobaSkillTuningSaveTransactionErrorRuntimeInstallFailed,
    MobaSkillTuningSaveTransactionErrorRollbackFailed,
};

@protocol MobaSkillTuningSaveLifecycle <NSObject>
- (void)profileWillReload;
- (void)profileDidReload;
@end

@protocol MobaSkillTuningSaveInstalling <NSObject>
// A failure must leave the previous runtime, views and participants installed.
- (BOOL)installSkillTuningSnapshot:(MobaProfileSnapshot *)snapshot
                           runtime:(MobaChampionRuntime *)runtime
               skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                             error:(NSError **)error;
@end

@interface MobaSkillTuningSaveResult : NSObject
@property (nonatomic, strong, readonly) MobaProfileSnapshot *snapshot;
@property (nonatomic, strong, readonly) MobaChampionRuntime *runtime;
@property (nonatomic, strong, readonly) MobaSkillControlPackage *skillControlPackage;
@property (nonatomic, copy, readonly) NSData *runtimeData;
@property (nonatomic, copy, readonly) NSData *championData;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaSkillTuningSaveTransaction : NSObject
- (nullable instancetype)initWithStore:(MobaProfileStore *)store
                             repository:(MobaProfileRepository *)repository
                          runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                   controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                              lifecycle:(id<MobaSkillTuningSaveLifecycle>)lifecycle
                               installer:(id<MobaSkillTuningSaveInstalling>)installer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaSkillTuningSaveResult *)saveDraft:(MobaSkillTuningDraft *)draft
                           championRelativePath:(NSString *)championRelativePath
                                          error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
