//
//  MobaChampionSelectionController.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileRepository.h"
#import "../Casting/MobaCastStrategyFactory.h"
#import "../Controls/MobaSkillControlPackage.h"
#import "../Core/MobaOverlayLifecycle.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaChampionSelectionErrorDomain;
FOUNDATION_EXPORT NSString *const MobaChampionSelectionChampionIDKey;
FOUNDATION_EXPORT NSString *const MobaChampionSelectionOperationKey;

typedef NS_ERROR_ENUM(MobaChampionSelectionErrorDomain, MobaChampionSelectionErrorCode) {
    MobaChampionSelectionErrorUnknownChampion = 1,
    MobaChampionSelectionErrorRuntimeMissing,
    MobaChampionSelectionErrorUnexpectedException,
    MobaChampionSelectionErrorControlPackageBuildFailed,
    MobaChampionSelectionErrorPreparedCommitRejected,
};

@interface MobaChampionCatalogEntry : NSObject

@property (nonatomic, copy, readonly) NSString *championID;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *championRelativePath;

- (instancetype)initWithChampionID:(NSString *)championID
                        displayName:(NSString *)displayName
               championRelativePath:(NSString *)championRelativePath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@protocol MobaChampionSelectionLifecycle <NSObject>
- (void)profileWillReload;
- (void)profileDidReload;
- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant;
- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant;
@end

@class MobaChampionSelectionController;

@protocol MobaChampionSelectionControllerDelegate <NSObject>
- (void)championSelectionController:(MobaChampionSelectionController *)controller
                    didSelectRuntime:(MobaChampionRuntime *)runtime
                 skillControlPackage:(nullable MobaSkillControlPackage *)skillControlPackage;
@end

@interface MobaChampionSelectionController : NSObject

@property (nonatomic, weak, nullable) id<MobaChampionSelectionControllerDelegate> delegate;
@property (class, nonatomic, readonly) NSArray<MobaChampionCatalogEntry *> *defaultCatalogEntries;
@property (nonatomic, copy, readonly) NSArray<MobaChampionCatalogEntry *> *catalogEntries;
@property (atomic, copy, readonly, nullable) NSString *selectedChampionID;
@property (atomic, strong, readonly, nullable) MobaChampionRuntime *activeChampionRuntime;
@property (atomic, strong, readonly, nullable) MobaSkillControlPackage *activeSkillControlPackage;

- (nullable instancetype)initWithRepository:(MobaProfileRepository *)repository
                              runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                                   lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle;
- (nullable instancetype)initWithRepository:(MobaProfileRepository *)repository
                              runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                         controlPackageBuilder:(nullable id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                                   lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle;
- (nullable instancetype)initWithRepository:(MobaProfileRepository *)repository
                              runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                                   lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle
                              catalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries;
- (nullable instancetype)initWithRepository:(MobaProfileRepository *)repository
                              runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                         controlPackageBuilder:(nullable id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                                   lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle
                              catalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaChampionCatalogEntry *)catalogEntryForChampionID:(NSString *)championID;
- (BOOL)selectChampionID:(NSString *)championID error:(NSError **)error;

// Explicit same-champion reload for committed profile changes. Unlike manual
// selection, this never short-circuits when the selected ID is unchanged.
- (BOOL)reloadSelectedChampionWithError:(NSError **)error;

// Transaction-only prepared install seam. Repository state must already be the
// supplied snapshot and the champion ID must remain unchanged.
- (BOOL)commitPreparedProfileSnapshot:(MobaProfileSnapshot *)snapshot
                               runtime:(MobaChampionRuntime *)runtime
                    skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                                 error:(NSError **)error;

// Import-only prepared install seam. Unlike editor/tuning commits, this may
// atomically switch to a newly validated Champion ID and catalog path.
- (BOOL)commitPreparedImportedSnapshot:(MobaProfileSnapshot *)snapshot
                                runtime:(MobaChampionRuntime *)runtime
                     skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                  championRelativePath:(NSString *)championRelativePath
                                  error:(NSError **)error;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
