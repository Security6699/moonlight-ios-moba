//
//  MobaProfileTransferService.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileRepository.h"
#import "../Casting/MobaCastStrategyFactory.h"
#import "../Controls/MobaSkillControlPackage.h"

NS_ASSUME_NONNULL_BEGIN

@interface MobaProfileExportPayload : NSObject
@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, copy, readonly) NSString *fileName;
@property (nonatomic, copy, readonly) MobaProfileKind profileKind;
- (instancetype)init NS_UNAVAILABLE;
@end

// Immutable preview result. It captures bytes, target, candidate, prepared
// runtime/package, and exact Repository base identity at selection time.
@interface MobaProfileImportPlan : NSObject
@property (nonatomic, copy, readonly) MobaProfileKind profileKind;
@property (nonatomic, copy, readonly) NSData *importData;
@property (nonatomic, readonly) NSUInteger schemaVersion;
@property (nonatomic, copy, readonly) NSString *profileIdentifier;
@property (nonatomic, copy, readonly, nullable) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *targetRelativePath;
@property (nonatomic, copy, readonly) NSString *activeChampionRelativePath;
@property (nonatomic, copy, readonly) NSString *replacedProfileIdentifier;
@property (nonatomic, readonly) BOOL switchesActiveChampion;
@property (nonatomic, readonly) BOOL destinationPreviouslyExisted;
@property (nonatomic, copy, readonly, nullable) NSData *previousDestinationData;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSData *> *activeProfileDataByRelativePath;
@property (nonatomic, copy, readonly) NSArray<NSString *> *summaryLines;
@property (nonatomic, strong, readonly) MobaProfileSnapshot *baseSnapshot;
@property (nonatomic, strong, readonly) MobaProfileRepositoryCandidate *repositoryCandidate;
@property (nonatomic, strong, readonly) MobaChampionRuntime *runtime;
@property (nonatomic, strong, readonly) MobaSkillControlPackage *skillControlPackage;
- (instancetype)init NS_UNAVAILABLE;
@end

// Foundation-only import preview and raw-byte export service. It never writes
// Store data, enters Lifecycle, or mutates Repository/Coordinator state.
@interface MobaProfileTransferService : NSObject

- (nullable instancetype)initWithStore:(MobaProfileStore *)store
                             repository:(MobaProfileRepository *)repository
                          runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                   controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable MobaProfileImportPlan *)prepareImportPlanForData:(NSData *)data
                                  activeChampionRelativePath:(NSString *)activeChampionRelativePath
                                                       error:(NSError **)error;

- (nullable MobaProfileExportPayload *)exportPayloadForProfileKind:(MobaProfileKind)profileKind
                                        activeChampionRelativePath:(NSString *)activeChampionRelativePath
                                                             error:(NSError **)error;

+ (NSString *)safeExportFileComponent:(NSString *)component;

@end

NS_ASSUME_NONNULL_END
