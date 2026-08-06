//
//  MobaProfileImportTransaction.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileTransferService.h"
#import "MobaChampionSelectionController.h"
#import "../Controls/MobaAttackController.h"
#import "../Controls/MobaMovementController.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaProfileImportTransactionErrorDomain;
FOUNDATION_EXPORT NSString *const MobaProfileImportOriginalErrorKey;
FOUNDATION_EXPORT NSString *const MobaProfileImportRollbackErrorKey;
FOUNDATION_EXPORT NSString *const MobaProfileImportInstallerRollbackErrorKey;
FOUNDATION_EXPORT NSString *const MobaProfileImportRepositoryRollbackErrorKey;
FOUNDATION_EXPORT NSString *const MobaProfileImportStorageRollbackErrorKey;

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

// Opaque, immutable capture of the production runtime state before import.
// The installer owns its concrete contents and rollback semantics.
@interface MobaPreparedProfileInstallation : NSObject
@end

@protocol MobaProfileImportInstalling <NSObject>
- (nullable MobaPreparedProfileInstallation *)prepareInstallationForSnapshot:(MobaProfileSnapshot *)snapshot
                                                                      runtime:(MobaChampionRuntime *)runtime
                                                          skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                                                       championRelativePath:(NSString *)championRelativePath
                                                                       error:(NSError **)error;
- (BOOL)commitPreparedInstallation:(MobaPreparedProfileInstallation *)installation
                              error:(NSError **)error;
- (BOOL)rollbackPreparedInstallation:(MobaPreparedProfileInstallation *)installation
                                error:(NSError **)error;
@end

@protocol MobaProfileRuntimeInstallationHost <NSObject>
@property (nonatomic, readonly) BOOL profileImportInputSuspended;
@property (nonatomic, strong, readonly) MobaChampionSelectionController *profileImportChampionSelectionController;
@property (nonatomic, strong, readonly) MobaMovementController *profileImportMovementController;
@property (nonatomic, strong, readonly) MobaAttackController *profileImportAttackController;
@property (nonatomic, strong, readonly) MobaProfileSnapshot *profileImportActiveSnapshot;
@property (nonatomic, copy, readonly) NSString *profileImportActiveChampionRelativePath;
- (BOOL)applyProfileImportMovementMapping:(MobaMovementKeyMapping)mapping error:(NSError **)error;
- (BOOL)applyProfileImportAttackKeyCode:(uint16_t)attackKeyCode
                           tapDurationMs:(NSUInteger)tapDurationMs
                                   error:(NSError **)error;
- (void)setProfileImportActiveChampionRelativePath:(NSString *)relativePath;
- (BOOL)applyProfileImportPresentationForSnapshot:(MobaProfileSnapshot *)snapshot
                                             error:(NSError **)error;
@end

// Production two-phase installer. It owns no remote-input state and mutates
// its host only after complete preflight has captured a reversible token.
@interface MobaProfileRuntimeInstaller : NSObject <MobaProfileImportInstalling>
- (nullable instancetype)initWithHost:(id<MobaProfileRuntimeInstallationHost>)host NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
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
