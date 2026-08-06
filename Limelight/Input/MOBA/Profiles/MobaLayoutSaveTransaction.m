//
//  MobaLayoutSaveTransaction.m
//  Moonlight
//

#import "MobaLayoutSaveTransaction.h"

NSErrorDomain const MobaLayoutSaveTransactionErrorDomain = @"MobaLayoutSaveTransactionErrorDomain";

@interface MobaLayoutSaveResult ()
- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                          runtime:(MobaChampionRuntime *)runtime
              skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                      runtimeData:(NSData *)runtimeData
                       layoutData:(NSData *)layoutData;
@end

@implementation MobaLayoutSaveResult
- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                          runtime:(MobaChampionRuntime *)runtime
              skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                      runtimeData:(NSData *)runtimeData
                       layoutData:(NSData *)layoutData {
    self = [super init];
    if (self) {
        _snapshot = snapshot;
        _runtime = runtime;
        _skillControlPackage = skillControlPackage;
        _runtimeData = [runtimeData copy];
        _layoutData = [layoutData copy];
    }
    return self;
}
@end

@implementation MobaLayoutSaveTransaction {
    MobaProfileStore *_store;
    MobaProfileRepository *_repository;
    id<MobaChampionRuntimeBuilding> _runtimeBuilder;
    id<MobaSkillControlPackageBuilding> _controlPackageBuilder;
    id<MobaLayoutSaveLifecycle> _lifecycle;
    id<MobaLayoutSaveInstalling> _installer;
}

- (instancetype)initWithStore:(MobaProfileStore *)store
                     repository:(MobaProfileRepository *)repository
                  runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
           controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                      lifecycle:(id<MobaLayoutSaveLifecycle>)lifecycle
                       installer:(id<MobaLayoutSaveInstalling>)installer {
    if (store == nil || repository == nil || runtimeBuilder == nil ||
        controlPackageBuilder == nil || lifecycle == nil || installer == nil) {
        return nil;
    }
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

- (NSError *)errorWithCode:(MobaLayoutSaveTransactionErrorCode)code
                description:(NSString *)description
                 underlying:(NSError *)underlying {
    NSMutableDictionary *info = [@{NSLocalizedDescriptionKey: description} mutableCopy];
    if (underlying != nil) info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:MobaLayoutSaveTransactionErrorDomain code:code userInfo:info];
}

- (BOOL)restoreRuntimeData:(NSData *)oldRuntimeData
                layoutData:(NSData *)oldLayoutData
                 candidate:(MobaProfileRepositoryCandidate *)candidate
       repositoryCommitted:(BOOL)repositoryCommitted
              originalError:(NSError *)originalError
                      error:(NSError **)error {
    NSError *repositoryError = nil;
    NSError *layoutError = nil;
    NSError *runtimeError = nil;
    BOOL repositoryRestored = !repositoryCommitted ||
        [_repository rollbackLayoutCandidate:candidate error:&repositoryError];
    BOOL layoutRestored = [_store writeData:oldLayoutData
                             toRelativePath:MobaActiveLayoutProfileRelativePath
                            replaceExisting:YES
                                      error:&layoutError];
    BOOL runtimeRestored = [_store writeData:oldRuntimeData
                              toRelativePath:MobaRuntimeProfileRelativePath
                             replaceExisting:YES
                                       error:&runtimeError];
    if (repositoryRestored && layoutRestored && runtimeRestored) {
        if (error != NULL) *error = originalError;
        return YES;
    }
    if (error != NULL) {
        NSError *rollbackCause = repositoryError ?: layoutError ?: runtimeError;
        *error = [self errorWithCode:MobaLayoutSaveTransactionErrorRollbackFailed
                         description:@"Layout save failed and restoring the previous committed state also failed."
                          underlying:rollbackCause ?: originalError];
    }
    return NO;
}

- (MobaLayoutSaveResult *)saveDraft:(MobaLayoutEditorDraft *)draft error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Layout save transactions require the main thread.");
    if (error != NULL) *error = nil;
    NSError *stepError = nil;
    NSData *runtimeData = [draft candidateRuntimeDataWithError:&stepError];
    if (runtimeData == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorSerializationFailed
                                            description:@"Unable to serialize the layout editor runtime draft."
                                             underlying:stepError];
        return nil;
    }
    NSData *layoutData = [draft candidateLayoutDataWithError:&stepError];
    if (layoutData == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorSerializationFailed
                                            description:@"Unable to serialize the layout editor draft."
                                             underlying:stepError];
        return nil;
    }
    MobaProfileRepositoryCandidate *candidate = [_repository
        prepareLayoutCandidateWithRuntimeData:runtimeData layoutData:layoutData error:&stepError];
    if (candidate == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorCandidateRejected
                                            description:@"The candidate runtime or layout profile was rejected."
                                             underlying:stepError];
        return nil;
    }
    MobaChampionRuntime *runtime = [_runtimeBuilder runtimeFromSnapshot:candidate.snapshot error:&stepError];
    if (runtime == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorRuntimeRejected
                                            description:@"The current champion runtime rejected the candidate layout."
                                             underlying:stepError];
        return nil;
    }
    MobaSkillControlPackage *package = [_controlPackageBuilder controlPackageForRuntime:runtime error:&stepError];
    if (!package.isComplete) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorPackageRejected
                                            description:@"The candidate skill control package is incomplete."
                                             underlying:stepError];
        return nil;
    }
    NSData *oldRuntimeData = [_store readDataAtRelativePath:MobaRuntimeProfileRelativePath error:&stepError];
    if (oldRuntimeData == nil) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorPersistenceFailed
                                            description:@"Unable to capture the previous runtime profile bytes before saving."
                                             underlying:stepError];
        return nil;
    }
    NSData *oldLayoutData = [_store readDataAtRelativePath:MobaActiveLayoutProfileRelativePath error:&stepError];
    if (oldLayoutData == nil) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorPersistenceFailed
                                            description:@"Unable to capture the previous profile bytes before saving."
                                             underlying:stepError];
        return nil;
    }

    BOOL repositoryCommitted = NO;
    [_lifecycle profileWillReload];
    @try {
        if (![_store writeData:layoutData
                toRelativePath:MobaActiveLayoutProfileRelativePath
               replaceExisting:YES
                         error:&stepError]) {
            if (error != NULL) *error = [self errorWithCode:MobaLayoutSaveTransactionErrorPersistenceFailed
                                                description:@"Unable to atomically write the active layout profile."
                                                 underlying:stepError];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        if (![_store writeData:runtimeData
                toRelativePath:MobaRuntimeProfileRelativePath
               replaceExisting:YES
                         error:&stepError]) {
            NSError *saveError = [self errorWithCode:MobaLayoutSaveTransactionErrorPersistenceFailed
                                           description:@"Unable to atomically write the runtime profile."
                                            underlying:stepError];
            [self restoreRuntimeData:oldRuntimeData layoutData:oldLayoutData candidate:candidate
                 repositoryCommitted:NO originalError:saveError error:error];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        if (![_repository commitLayoutCandidate:candidate error:&stepError]) {
            NSError *saveError = [self errorWithCode:MobaLayoutSaveTransactionErrorRepositoryCommitFailed
                                           description:@"The prepared profile snapshot could not be committed."
                                            underlying:stepError];
            [self restoreRuntimeData:oldRuntimeData layoutData:oldLayoutData candidate:candidate
                 repositoryCommitted:NO originalError:saveError error:error];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        repositoryCommitted = YES;
        if (![_installer installLayoutSaveSnapshot:candidate.snapshot
                                           runtime:runtime
                               skillControlPackage:package
                                             error:&stepError]) {
            NSError *saveError = [self errorWithCode:MobaLayoutSaveTransactionErrorRuntimeInstallFailed
                                           description:@"The prepared runtime and controls could not be installed."
                                            underlying:stepError];
            [self restoreRuntimeData:oldRuntimeData layoutData:oldLayoutData candidate:candidate
                 repositoryCommitted:repositoryCommitted originalError:saveError error:error];
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            return nil;
        }
        return [[MobaLayoutSaveResult alloc] initWithSnapshot:candidate.snapshot
                                                      runtime:runtime
                                          skillControlPackage:package
                                                  runtimeData:runtimeData
                                                   layoutData:layoutData];
    }
    @catch (NSException *exception) {
        NSError *exceptionError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                       code:NSFileWriteUnknownError
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                       exception.reason ?: @"Layout save raised an exception."}];
        NSError *saveError = [self errorWithCode:MobaLayoutSaveTransactionErrorRuntimeInstallFailed
                                     description:@"Layout save failed unexpectedly before installation completed."
                                      underlying:exceptionError];
        [self restoreRuntimeData:oldRuntimeData layoutData:oldLayoutData candidate:candidate
             repositoryCommitted:repositoryCommitted originalError:saveError error:error];
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        return nil;
    }
    @finally {
        [_lifecycle profileDidReload];
    }
}

@end
