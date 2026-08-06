//
//  MobaProfileRepository.m
//  Moonlight
//

#import "MobaProfileRepository.h"

#import "MobaProfileError.h"

NSString *const MobaRuntimeProfileRelativePath = @"runtime.json";
NSString *const MobaInputProfileRelativePath = @"input.json";
NSString *const MobaActiveLayoutProfileRelativePath = @"active-layout.json";

@interface MobaProfileRepositoryCandidate ()
@property (nonatomic, strong, readwrite) MobaProfileSnapshot *snapshot;
@property (nonatomic, strong) MobaProfileSnapshot *baseSnapshot;
- (instancetype)initWithBaseSnapshot:(MobaProfileSnapshot *)baseSnapshot
                             snapshot:(MobaProfileSnapshot *)snapshot;
@end

@implementation MobaProfileRepositoryCandidate
- (instancetype)initWithBaseSnapshot:(MobaProfileSnapshot *)baseSnapshot
                             snapshot:(MobaProfileSnapshot *)snapshot {
    self = [super init];
    if (self) {
        _baseSnapshot = baseSnapshot;
        _snapshot = snapshot;
    }
    return self;
}
@end

@implementation MobaProfileRepository {
    MobaProfileStore *_store;
    MobaProfileDecoder *_decoder;
    MobaProfileSnapshot *_activeSnapshot;
}

- (instancetype)initWithStore:(MobaProfileStore *)store {
    return [self initWithStore:store decoder:[[MobaProfileDecoder alloc] init]];
}

- (instancetype)initWithStore:(MobaProfileStore *)store
                       decoder:(MobaProfileDecoder *)decoder {
    self = [super init];
    if (self) {
        _store = store;
        _decoder = decoder;
    }
    return self;
}

- (MobaProfileSnapshot *)activeSnapshot {
    @synchronized (self) {
        return _activeSnapshot;
    }
}

- (NSData *)readRelativePath:(NSString *)relativePath
                 profileKind:(MobaProfileKind)profileKind
                    operation:(NSString *)operation
                        error:(NSError **)error {
    NSError *storageError = nil;
    NSData *data = [_store readDataAtRelativePath:relativePath error:&storageError];
    if (data == nil && error != NULL) {
        *error = MobaProfileMakeError(MobaProfileErrorStorageReadFailed,
                                      profileKind,
                                      @"$",
                                      operation,
                                      @"Unable to read profile bytes from the profile store.",
                                      storageError);
    }
    return data;
}

- (BOOL)validateChampion:(MobaChampionProfile *)champion
             inputProfile:(MobaInputProfile *)input
                     error:(NSError **)error {
    for (NSString *skillName in champion.skills) {
        MobaChampionSkillProfile *skill = champion.skills[skillName];
        if ([input keyCodeForAction:skill.inputAction] == nil) {
            if (error != NULL) {
                NSString *path = [NSString stringWithFormat:@"$.skills.%@.inputAction", skillName];
                *error = MobaProfileMakeError(MobaProfileErrorCrossProfileReferenceInvalid,
                                              MobaProfileKindChampion,
                                              path,
                                              @"cross-profile-validation",
                                              @"The champion skill references an unknown input action.",
                                              nil);
            }
            return NO;
        }
    }
    return YES;
}

- (NSError *)candidateStateError:(NSString *)description operation:(NSString *)operation {
    return MobaProfileMakeError(MobaProfileErrorCrossProfileReferenceInvalid,
                                MobaProfileKindLayout,
                                @"$",
                                operation,
                                description,
                                nil);
}

- (MobaProfileRepositoryCandidate *)prepareLayoutCandidateWithRuntimeData:(NSData *)runtimeData
                                                                layoutData:(NSData *)layoutData
                                                                     error:(NSError **)error {
    if (error != NULL) *error = nil;
    MobaProfileSnapshot *base = self.activeSnapshot;
    if (base == nil) {
        if (error != NULL) {
            *error = [self candidateStateError:@"An active profile snapshot is required before layout editing."
                                      operation:@"prepare-layout-candidate"];
        }
        return nil;
    }
    MobaRuntimeProfile *runtime = [_decoder decodeRuntimeProfileData:runtimeData error:error];
    if (runtime == nil) return nil;
    MobaLayoutProfile *layout = [_decoder decodeLayoutProfileData:layoutData error:error];
    if (layout == nil || ![self validateChampion:base.championProfile inputProfile:base.inputProfile error:error]) {
        return nil;
    }
    MobaProfileSnapshot *snapshot = [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtime
                                                                           inputProfile:base.inputProfile
                                                                          layoutProfile:layout
                                                                        championProfile:base.championProfile];
    MobaProfileRepositoryCandidate *candidate = [[MobaProfileRepositoryCandidate alloc]
        initWithBaseSnapshot:base snapshot:snapshot];
    return candidate;
}

- (BOOL)commitLayoutCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    if (error != NULL) *error = nil;
    @synchronized (self) {
        if (candidate == nil || candidate.baseSnapshot == nil || candidate.snapshot == nil ||
            _activeSnapshot != candidate.baseSnapshot) {
            if (error != NULL) {
                *error = [self candidateStateError:@"The active snapshot changed after the layout candidate was prepared."
                                          operation:@"commit-layout-candidate"];
            }
            return NO;
        }
        _activeSnapshot = candidate.snapshot;
    }
    return YES;
}

- (BOOL)rollbackLayoutCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    if (error != NULL) *error = nil;
    @synchronized (self) {
        if (candidate == nil || _activeSnapshot != candidate.snapshot) {
            if (error != NULL) {
                *error = [self candidateStateError:@"The committed layout candidate is no longer active and cannot be rolled back."
                                          operation:@"rollback-layout-candidate"];
            }
            return NO;
        }
        _activeSnapshot = candidate.baseSnapshot;
    }
    return YES;
}

- (MobaProfileRepositoryCandidate *)prepareSkillTuningCandidateWithRuntimeData:(NSData *)runtimeData
                                                                  championData:(NSData *)championData
                                                                         error:(NSError **)error {
    if (error != NULL) *error = nil;
    MobaProfileSnapshot *base = self.activeSnapshot;
    if (base == nil) {
        if (error != NULL) *error = [self candidateStateError:
            @"An active profile snapshot is required before skill tuning."
            operation:@"prepare-skill-tuning-candidate"];
        return nil;
    }
    MobaRuntimeProfile *runtime = [_decoder decodeRuntimeProfileData:runtimeData error:error];
    MobaChampionProfile *champion = [_decoder decodeChampionProfileData:championData error:error];
    if (runtime == nil || champion == nil ||
        ![champion.championID isEqualToString:base.championProfile.championID] ||
        ![self validateChampion:champion inputProfile:base.inputProfile error:error]) {
        if (champion != nil && ![champion.championID isEqualToString:base.championProfile.championID] && error != NULL) {
            *error = [self candidateStateError:@"Skill tuning cannot replace a different champion."
                                      operation:@"prepare-skill-tuning-candidate"];
        }
        return nil;
    }
    MobaProfileSnapshot *snapshot = [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtime
                                                                           inputProfile:base.inputProfile
                                                                          layoutProfile:base.layoutProfile
                                                                        championProfile:champion];
    return [[MobaProfileRepositoryCandidate alloc] initWithBaseSnapshot:base snapshot:snapshot];
}

- (BOOL)commitSkillTuningCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    return [self commitLayoutCandidate:candidate error:error];
}

- (BOOL)rollbackSkillTuningCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    return [self rollbackLayoutCandidate:candidate error:error];
}

- (BOOL)reloadWithChampionRelativePath:(NSString *)championRelativePath error:(NSError **)error {
    return [self reloadWithChampionRelativePath:championRelativePath
                              candidateValidator:nil
                                           error:error];
}

- (BOOL)reloadWithChampionRelativePath:(NSString *)championRelativePath
                    candidateValidator:(MobaProfileCandidateValidator)candidateValidator
                                 error:(NSError **)error {
    return [self loadRuntimeRelativePath:MobaRuntimeProfileRelativePath
                       inputRelativePath:MobaInputProfileRelativePath
                      layoutRelativePath:MobaActiveLayoutProfileRelativePath
                    championRelativePath:championRelativePath
                      candidateValidator:candidateValidator
                                   error:error];
}

- (BOOL)loadRuntimeRelativePath:(NSString *)runtimeRelativePath
              inputRelativePath:(NSString *)inputRelativePath
             layoutRelativePath:(NSString *)layoutRelativePath
           championRelativePath:(NSString *)championRelativePath
                          error:(NSError **)error {
    return [self loadRuntimeRelativePath:runtimeRelativePath
                       inputRelativePath:inputRelativePath
                      layoutRelativePath:layoutRelativePath
                    championRelativePath:championRelativePath
                      candidateValidator:nil
                                   error:error];
}

- (BOOL)loadRuntimeRelativePath:(NSString *)runtimeRelativePath
              inputRelativePath:(NSString *)inputRelativePath
             layoutRelativePath:(NSString *)layoutRelativePath
           championRelativePath:(NSString *)championRelativePath
             candidateValidator:(MobaProfileCandidateValidator)candidateValidator
                          error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }

    // Every value remains local until all four profiles and their references
    // have succeeded. No failure path writes the active snapshot.
    NSData *runtimeData = [self readRelativePath:runtimeRelativePath
                                     profileKind:MobaProfileKindRuntime
                                        operation:@"read-runtime"
                                            error:error];
    if (runtimeData == nil) {
        return NO;
    }
    NSData *inputData = [self readRelativePath:inputRelativePath
                                   profileKind:MobaProfileKindInput
                                      operation:@"read-input"
                                          error:error];
    if (inputData == nil) {
        return NO;
    }
    NSData *layoutData = [self readRelativePath:layoutRelativePath
                                    profileKind:MobaProfileKindLayout
                                       operation:@"read-layout"
                                           error:error];
    if (layoutData == nil) {
        return NO;
    }
    NSData *championData = [self readRelativePath:championRelativePath
                                      profileKind:MobaProfileKindChampion
                                         operation:@"read-champion"
                                             error:error];
    if (championData == nil) {
        return NO;
    }

    MobaRuntimeProfile *runtime = [_decoder decodeRuntimeProfileData:runtimeData error:error];
    if (runtime == nil) {
        return NO;
    }
    MobaInputProfile *input = [_decoder decodeInputProfileData:inputData error:error];
    if (input == nil) {
        return NO;
    }
    MobaLayoutProfile *layout = [_decoder decodeLayoutProfileData:layoutData error:error];
    if (layout == nil) {
        return NO;
    }
    MobaChampionProfile *champion = [_decoder decodeChampionProfileData:championData error:error];
    if (champion == nil || ![self validateChampion:champion inputProfile:input error:error]) {
        return NO;
    }

    MobaProfileSnapshot *candidate = [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtime
                                                                            inputProfile:input
                                                                           layoutProfile:layout
                                                                         championProfile:champion];
    if (candidateValidator != nil && !candidateValidator(candidate, error)) {
        return NO;
    }
    @synchronized (self) {
        _activeSnapshot = candidate;
    }
    return YES;
}

@end
