//
//  MobaSkillTuningSaveTransaction.m
//  Moonlight
//

#import "MobaSkillTuningSaveTransaction.h"

NSErrorDomain const MobaSkillTuningSaveTransactionErrorDomain = @"MobaSkillTuningSaveTransactionErrorDomain";

@interface MobaSkillTuningSaveResult ()
- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                          runtime:(MobaChampionRuntime *)runtime
              skillControlPackage:(MobaSkillControlPackage *)package
                      runtimeData:(NSData *)runtimeData
                     championData:(NSData *)championData;
@end

@implementation MobaSkillTuningSaveResult
- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot runtime:(MobaChampionRuntime *)runtime
              skillControlPackage:(MobaSkillControlPackage *)package runtimeData:(NSData *)runtimeData
                     championData:(NSData *)championData {
    self = [super init];
    if (self) {
        _snapshot = snapshot;
        _runtime = runtime;
        _skillControlPackage = package;
        _runtimeData = [runtimeData copy];
        _championData = [championData copy];
    }
    return self;
}
@end

@implementation MobaSkillTuningSaveTransaction {
    MobaProfileStore *_store;
    MobaProfileRepository *_repository;
    id<MobaChampionRuntimeBuilding> _runtimeBuilder;
    id<MobaSkillControlPackageBuilding> _controlPackageBuilder;
    id<MobaSkillTuningSaveLifecycle> _lifecycle;
    id<MobaSkillTuningSaveInstalling> _installer;
}

- (instancetype)initWithStore:(MobaProfileStore *)store repository:(MobaProfileRepository *)repository
                  runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
           controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                      lifecycle:(id<MobaSkillTuningSaveLifecycle>)lifecycle
                       installer:(id<MobaSkillTuningSaveInstalling>)installer {
    if (store == nil || repository == nil || runtimeBuilder == nil || controlPackageBuilder == nil ||
        lifecycle == nil || installer == nil) return nil;
    self = [super init];
    if (self) {
        _store = store;
        _repository = repository;
        _runtimeBuilder = runtimeBuilder;
        _controlPackageBuilder = controlPackageBuilder;
        _lifecycle = lifecycle;
        _installer = installer;
    }
    return self;
}

- (NSError *)errorWithCode:(MobaSkillTuningSaveTransactionErrorCode)code
                description:(NSString *)description underlying:(NSError *)underlying {
    NSMutableDictionary *info = [@{NSLocalizedDescriptionKey: description} mutableCopy];
    if (underlying != nil) info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:MobaSkillTuningSaveTransactionErrorDomain code:code userInfo:info];
}

- (void)restoreRuntimeData:(NSData *)runtimeData championData:(NSData *)championData
      championRelativePath:(NSString *)championRelativePath
                 candidate:(MobaProfileRepositoryCandidate *)candidate
       repositoryCommitted:(BOOL)repositoryCommitted originalError:(NSError *)originalError
                     error:(NSError **)error {
    NSError *repositoryError = nil;
    NSError *championError = nil;
    NSError *runtimeError = nil;
    BOOL repositoryRestored = !repositoryCommitted ||
        [_repository rollbackSkillTuningCandidate:candidate error:&repositoryError];
    BOOL championRestored = [_store writeData:championData toRelativePath:championRelativePath
                               replaceExisting:YES error:&championError];
    BOOL runtimeRestored = [_store writeData:runtimeData toRelativePath:MobaRuntimeProfileRelativePath
                              replaceExisting:YES error:&runtimeError];
    if (repositoryRestored && championRestored && runtimeRestored) {
        if (error != NULL) *error = originalError;
        return;
    }
    NSError *cause = repositoryError ?: championError ?: runtimeError ?: originalError;
    if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorRollbackFailed
        description:@"Skill tuning save failed and the previous two-file state could not be fully restored."
        underlying:cause];
}

- (MobaSkillTuningSaveResult *)saveDraft:(MobaSkillTuningDraft *)draft
                   championRelativePath:(NSString *)championRelativePath error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Skill tuning save transactions require the main thread.");
    if (error != NULL) *error = nil;
    NSError *stepError = nil;
    NSData *runtimeData = [draft runtimeDataWithError:&stepError];
    NSData *championData = [draft championDataWithError:&stepError];
    if (runtimeData == nil || championData == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorSerializationFailed
            description:@"Unable to serialize the skill tuning draft." underlying:stepError];
        return nil;
    }
    MobaProfileRepositoryCandidate *candidate = [_repository
        prepareSkillTuningCandidateWithRuntimeData:runtimeData championData:championData error:&stepError];
    if (candidate == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorCandidateRejected
            description:@"The candidate runtime or champion profile was rejected." underlying:stepError];
        return nil;
    }
    MobaChampionRuntime *runtime = [_runtimeBuilder runtimeFromSnapshot:candidate.snapshot error:&stepError];
    if (runtime == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorRuntimeRejected
            description:@"The candidate champion runtime could not be constructed." underlying:stepError];
        return nil;
    }
    MobaSkillControlPackage *package = [_controlPackageBuilder controlPackageForRuntime:runtime error:&stepError];
    if (!package.isComplete) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorPackageRejected
            description:@"The candidate Q/W/E/R control package is incomplete." underlying:stepError];
        return nil;
    }
    NSData *oldRuntime = [_store readDataAtRelativePath:MobaRuntimeProfileRelativePath error:&stepError];
    NSData *oldChampion = [_store readDataAtRelativePath:championRelativePath error:&stepError];
    if (oldRuntime == nil || oldChampion == nil) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorPersistenceFailed
            description:@"Unable to capture the previous runtime and champion bytes." underlying:stepError];
        return nil;
    }

    BOOL repositoryCommitted = NO;
    [_lifecycle profileWillReload];
    @try {
        if (![_store writeData:runtimeData toRelativePath:MobaRuntimeProfileRelativePath
                replaceExisting:YES error:&stepError]) {
            if (error != NULL) *error = [self errorWithCode:MobaSkillTuningSaveTransactionErrorPersistenceFailed
                description:@"Unable to atomically write runtime.json." underlying:stepError];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        if (![_store writeData:championData toRelativePath:championRelativePath
                replaceExisting:YES error:&stepError]) {
            NSError *saveError = [self errorWithCode:MobaSkillTuningSaveTransactionErrorPersistenceFailed
                description:@"Unable to atomically write the current champion profile." underlying:stepError];
            [self restoreRuntimeData:oldRuntime championData:oldChampion championRelativePath:championRelativePath
                 candidate:candidate repositoryCommitted:NO originalError:saveError error:error];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        if (![_repository commitSkillTuningCandidate:candidate error:&stepError]) {
            NSError *saveError = [self errorWithCode:MobaSkillTuningSaveTransactionErrorRepositoryCommitFailed
                description:@"The exact-base skill tuning candidate could not be committed." underlying:stepError];
            [self restoreRuntimeData:oldRuntime championData:oldChampion championRelativePath:championRelativePath
                 candidate:candidate repositoryCommitted:NO originalError:saveError error:error];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        repositoryCommitted = YES;
        if (![_installer installSkillTuningSnapshot:candidate.snapshot runtime:runtime
                                  skillControlPackage:package error:&stepError]) {
            NSError *saveError = [self errorWithCode:MobaSkillTuningSaveTransactionErrorRuntimeInstallFailed
                description:@"The prepared runtime and controls could not be installed." underlying:stepError];
            [self restoreRuntimeData:oldRuntime championData:oldChampion championRelativePath:championRelativePath
                 candidate:candidate repositoryCommitted:repositoryCommitted originalError:saveError error:error];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        return [[MobaSkillTuningSaveResult alloc] initWithSnapshot:candidate.snapshot runtime:runtime
            skillControlPackage:package runtimeData:runtimeData championData:championData];
    }
    @catch (NSException *exception) {
        NSError *exceptionError = [NSError errorWithDomain:NSCocoaErrorDomain
            code:NSFileWriteUnknownError userInfo:@{NSLocalizedDescriptionKey:
                exception.reason ?: @"Skill tuning save raised an exception."}];
        NSError *saveError = [self errorWithCode:MobaSkillTuningSaveTransactionErrorRuntimeInstallFailed
            description:@"Skill tuning save failed unexpectedly before installation completed."
            underlying:exceptionError];
        [self restoreRuntimeData:oldRuntime championData:oldChampion
            championRelativePath:championRelativePath candidate:candidate
            repositoryCommitted:repositoryCommitted originalError:saveError error:error];
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        return nil;
    }
    @finally {
        [_lifecycle profileDidReload];
    }
}
@end
