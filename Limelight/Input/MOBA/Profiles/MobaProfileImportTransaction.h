//
//  MobaProfileImportTransaction.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileTransferService.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaProfileImportTransactionErrorDomain;
FOUNDATION_EXPORT NSString *const MobaProfileImportOriginalErrorKey;
FOUNDATION_EXPORT NSString *const MobaProfileImportRollbackErrorKey;

typedef NS_ERROR_ENUM(MobaProfileImportTransactionErrorDomain, MobaProfileImportTransactionErrorCode) {
    MobaProfileImportTransactionErrorStalePlan = 1,
    MobaProfileImportTransactionErrorActiveBytesChanged,
    MobaProfileImportTransactionErrorBackupFailed,
    MobaProfileImportTransactionErrorPersistenceFailed,
    MobaProfileImportTransactionErrorRepositoryCommitFailed,
    MobaProfileImportTransactionErrorRuntimeInstallFailed,
    MobaProfileImportTransactionErrorRollbackFailed,
};

@protocol MobaProfileImportLifecycle <NSObject>
- (void)profileWillReload;
- (void)profileDidReload;
@end

@protocol MobaProfileImportInstalling <NSObject>
// A failure must preserve the old runtime, selected Champion, Views and
// participant registrations. Successful installation is one main-thread swap.
- (BOOL)installImportedProfileSnapshot:(MobaProfileSnapshot *)snapshot
                                runtime:(MobaChampionRuntime *)runtime
                    skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                 championRelativePath:(NSString *)championRelativePath
                                  error:(NSError **)error;
@end

@protocol MobaProfileBackupDirectoryNameProviding <NSObject>
- (NSString *)nextBackupDirectoryName;
@end

@interface MobaProfileImportResult : NSObject
@property (nonatomic, strong, readonly) MobaProfileSnapshot *snapshot;
@property (nonatomic, copy, readonly) NSString *backupRelativePath;
@property (nonatomic, copy, readonly) NSString *activeChampionRelativePath;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MobaProfileImportTransaction : NSObject

- (nullable instancetype)initWithStore:(MobaProfileStore *)store
                             repository:(MobaProfileRepository *)repository
                              lifecycle:(id<MobaProfileImportLifecycle>)lifecycle
                               installer:(id<MobaProfileImportInstalling>)installer;
- (nullable instancetype)initWithStore:(MobaProfileStore *)store
                             repository:(MobaProfileRepository *)repository
                              lifecycle:(id<MobaProfileImportLifecycle>)lifecycle
                               installer:(id<MobaProfileImportInstalling>)installer
                 backupDirectoryProvider:(id<MobaProfileBackupDirectoryNameProviding>)backupDirectoryProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaProfileImportResult *)applyImportPlan:(MobaProfileImportPlan *)plan
                                                error:(NSError **)error;

@end
NS_ASSUME_NONNULL_END
