//
//  MobaLayoutSaveTransaction.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaLayoutEditor.h"
#import "MobaProfileRepository.h"
#import "MobaProfileStore.h"
#import "../Casting/MobaCastStrategyFactory.h"
#import "../Controls/MobaSkillControlPackage.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaLayoutSaveTransactionErrorDomain;

typedef NS_ERROR_ENUM(MobaLayoutSaveTransactionErrorDomain, MobaLayoutSaveTransactionErrorCode) {
    MobaLayoutSaveTransactionErrorSerializationFailed = 1,
    MobaLayoutSaveTransactionErrorCandidateRejected,
    MobaLayoutSaveTransactionErrorRuntimeRejected,
    MobaLayoutSaveTransactionErrorPackageRejected,
    MobaLayoutSaveTransactionErrorPersistenceFailed,
    MobaLayoutSaveTransactionErrorRepositoryCommitFailed,
    MobaLayoutSaveTransactionErrorRuntimeInstallFailed,
    MobaLayoutSaveTransactionErrorRollbackFailed,
};

@protocol MobaLayoutSaveLifecycle <NSObject>
- (void)profileWillReload;
- (void)profileDidReload;
@end

@protocol MobaLayoutSaveInstalling <NSObject>

// Implementations must reject before mutation or complete installation in one
// main-thread step. A NO result is treated as having preserved the old runtime,
// package, participants, controls, and selected champion.
- (BOOL)installLayoutSaveSnapshot:(MobaProfileSnapshot *)snapshot
                           runtime:(MobaChampionRuntime *)runtime
               skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                             error:(NSError **)error;

@end

@interface MobaLayoutSaveResult : NSObject
@property (nonatomic, strong, readonly) MobaProfileSnapshot *snapshot;
@property (nonatomic, strong, readonly) MobaChampionRuntime *runtime;
@property (nonatomic, strong, readonly) MobaSkillControlPackage *skillControlPackage;
@property (nonatomic, copy, readonly) NSData *runtimeData;
@property (nonatomic, copy, readonly) NSData *layoutData;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaLayoutSaveTransaction : NSObject

- (nullable instancetype)initWithStore:(MobaProfileStore *)store
                             repository:(MobaProfileRepository *)repository
                          runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                   controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                              lifecycle:(id<MobaLayoutSaveLifecycle>)lifecycle
                               installer:(id<MobaLayoutSaveInstalling>)installer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaLayoutSaveResult *)saveDraft:(MobaLayoutEditorDraft *)draft
                                        error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
