//
//  MobaProfileRepository.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileDecoder.h"
#import "MobaProfileModels.h"
#import "MobaProfileStore.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MobaRuntimeProfileRelativePath;
FOUNDATION_EXPORT NSString *const MobaInputProfileRelativePath;
FOUNDATION_EXPORT NSString *const MobaActiveLayoutProfileRelativePath;

typedef BOOL (^MobaProfileCandidateValidator)(MobaProfileSnapshot *candidate,
                                               NSError **error);

@interface MobaProfileRepositoryCandidate : NSObject
@property (nonatomic, strong, readonly) MobaProfileSnapshot *snapshot;
- (instancetype)init NS_UNAVAILABLE;
@end

// Owns only candidate loading and transactional active-snapshot replacement.
// It never writes profiles and never mutates Coordinator or input state.
@interface MobaProfileRepository : NSObject

@property (atomic, strong, readonly, nullable) MobaProfileSnapshot *activeSnapshot;

- (instancetype)initWithStore:(MobaProfileStore *)store;
- (instancetype)initWithStore:(MobaProfileStore *)store
                       decoder:(MobaProfileDecoder *)decoder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)reloadWithChampionRelativePath:(NSString *)championRelativePath
                                  error:(NSError **)error;

- (BOOL)reloadWithChampionRelativePath:(NSString *)championRelativePath
                    candidateValidator:(nullable MobaProfileCandidateValidator)candidateValidator
                                 error:(NSError **)error;

- (BOOL)loadRuntimeRelativePath:(NSString *)runtimeRelativePath
              inputRelativePath:(NSString *)inputRelativePath
             layoutRelativePath:(NSString *)layoutRelativePath
           championRelativePath:(NSString *)championRelativePath
                          error:(NSError **)error;

- (BOOL)loadRuntimeRelativePath:(NSString *)runtimeRelativePath
              inputRelativePath:(NSString *)inputRelativePath
             layoutRelativePath:(NSString *)layoutRelativePath
           championRelativePath:(NSString *)championRelativePath
             candidateValidator:(nullable MobaProfileCandidateValidator)candidateValidator
                          error:(NSError **)error;

// Narrow layout-save seam. A candidate always reuses the current immutable
// input and champion profiles and can only replace the exact snapshot it was
// prepared from. Rollback can only restore that same snapshot.
- (nullable MobaProfileRepositoryCandidate *)prepareLayoutCandidateWithRuntimeData:(NSData *)runtimeData
                                                                         layoutData:(NSData *)layoutData
                                                                              error:(NSError **)error;
- (BOOL)commitLayoutCandidate:(MobaProfileRepositoryCandidate *)candidate
                         error:(NSError **)error;
- (BOOL)rollbackLayoutCandidate:(MobaProfileRepositoryCandidate *)candidate
                           error:(NSError **)error;

// Narrow skill-tuning seam. Runtime and the current champion are replaced
// together while input and layout reuse their exact immutable base models.
- (nullable MobaProfileRepositoryCandidate *)prepareSkillTuningCandidateWithRuntimeData:(NSData *)runtimeData
                                                                            championData:(NSData *)championData
                                                                                   error:(NSError **)error;
- (BOOL)commitSkillTuningCandidate:(MobaProfileRepositoryCandidate *)candidate
                              error:(NSError **)error;
- (BOOL)rollbackSkillTuningCandidate:(MobaProfileRepositoryCandidate *)candidate
                                error:(NSError **)error;

// Narrow single-profile import seam. The imported model is combined with the
// other immutable models from the exact active base snapshot. Champion/Input
// references are validated before a candidate is returned.
- (nullable MobaProfileRepositoryCandidate *)prepareImportCandidateWithProfileKind:(MobaProfileKind)profileKind
                                                                                data:(NSData *)data
                                                                               error:(NSError **)error;
- (BOOL)commitImportCandidate:(MobaProfileRepositoryCandidate *)candidate
                         error:(NSError **)error;
- (BOOL)rollbackImportCandidate:(MobaProfileRepositoryCandidate *)candidate
                           error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
