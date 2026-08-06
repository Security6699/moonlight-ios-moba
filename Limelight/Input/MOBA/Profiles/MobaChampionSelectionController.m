//
//  MobaChampionSelectionController.m
//  Moonlight
//

#import "MobaChampionSelectionController.h"

NSErrorDomain const MobaChampionSelectionErrorDomain = @"MobaChampionSelectionErrorDomain";
NSString *const MobaChampionSelectionChampionIDKey = @"MobaChampionSelectionChampionID";
NSString *const MobaChampionSelectionOperationKey = @"MobaChampionSelectionOperation";

@implementation MobaChampionCatalogEntry
- (instancetype)initWithChampionID:(NSString *)championID
                        displayName:(NSString *)displayName
               championRelativePath:(NSString *)championRelativePath {
    if (championID.length == 0 || displayName.length == 0 || championRelativePath.length == 0) {
        return nil;
    }
    self = [super init];
    if (self) {
        _championID = [championID copy];
        _displayName = [displayName copy];
        _championRelativePath = [championRelativePath copy];
    }
    return self;
}
@end

@interface MobaChampionPreparedImportState : NSObject
@property (nonatomic, weak) MobaChampionSelectionController *owner;
@property (nonatomic, strong) MobaProfileSnapshot *snapshot;
@property (nonatomic, strong) MobaChampionRuntime *runtime;
@property (nonatomic, strong) MobaSkillControlPackage *skillControlPackage;
@property (nonatomic, copy) NSString *championID;
@property (nonatomic, copy) NSArray<MobaChampionCatalogEntry *> *newCatalogEntries;
@property (nonatomic, copy) NSArray<MobaChampionCatalogEntry *> *oldCatalogEntries;
@property (nonatomic, copy, nullable) NSString *oldSelectedChampionID;
@property (nonatomic, strong, nullable) MobaChampionRuntime *oldRuntime;
@property (nonatomic, strong, nullable) MobaSkillControlPackage *oldSkillControlPackage;
@property (nonatomic) BOOL commitStarted;
@property (nonatomic) BOOL rolledBack;
@end

@implementation MobaChampionPreparedImportState
@end

@implementation MobaChampionSelectionController {
    MobaProfileRepository *_repository;
    id<MobaChampionRuntimeBuilding> _runtimeBuilder;
    id<MobaSkillControlPackageBuilding> _controlPackageBuilder;
    id<MobaChampionSelectionLifecycle> _lifecycle;
    NSArray<MobaChampionCatalogEntry *> *_catalogEntries;
    NSString *_selectedChampionID;
    MobaChampionRuntime *_activeChampionRuntime;
    MobaSkillControlPackage *_activeSkillControlPackage;
    BOOL _invalidated;
}

+ (NSArray<MobaChampionCatalogEntry *> *)defaultCatalogEntries {
    static NSArray<MobaChampionCatalogEntry *> *entries;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        entries = @[
            [[MobaChampionCatalogEntry alloc] initWithChampionID:@"caitlyn"
                                                    displayName:@"Caitlyn"
                                           championRelativePath:@"champions/caitlyn.json"],
            [[MobaChampionCatalogEntry alloc] initWithChampionID:@"debug-instant"
                                                    displayName:@"Debug Instant Cast"
                                           championRelativePath:@"champions/debug-instant.json"],
        ];
    });
    return entries;
}

- (instancetype)initWithRepository:(MobaProfileRepository *)repository
                      runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                           lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle {
    return [self initWithRepository:repository
                      runtimeBuilder:runtimeBuilder
              controlPackageBuilder:nil
                           lifecycle:lifecycle
                      catalogEntries:MobaChampionSelectionController.defaultCatalogEntries];
}

- (instancetype)initWithRepository:(MobaProfileRepository *)repository
                      runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
             controlPackageBuilder:(nullable id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                           lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle {
    return [self initWithRepository:repository
                      runtimeBuilder:runtimeBuilder
             controlPackageBuilder:controlPackageBuilder
                           lifecycle:lifecycle
                      catalogEntries:MobaChampionSelectionController.defaultCatalogEntries];
}

- (instancetype)initWithRepository:(MobaProfileRepository *)repository
                      runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
                           lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle
                      catalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries {
    return [self initWithRepository:repository
                      runtimeBuilder:runtimeBuilder
             controlPackageBuilder:nil
                           lifecycle:lifecycle
                      catalogEntries:catalogEntries];
}

- (instancetype)initWithRepository:(MobaProfileRepository *)repository
                      runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
             controlPackageBuilder:(nullable id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                           lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle
                      catalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries {
    if (repository == nil || runtimeBuilder == nil || lifecycle == nil || catalogEntries.count == 0) {
        return nil;
    }
    NSMutableSet<NSString *> *championIDs = [NSMutableSet set];
    for (MobaChampionCatalogEntry *entry in catalogEntries) {
        if (entry.championID.length == 0 || [championIDs containsObject:entry.championID]) {
            return nil;
        }
        [championIDs addObject:entry.championID];
    }
    self = [super init];
    if (self) {
        _repository = repository;
        _runtimeBuilder = runtimeBuilder;
        _controlPackageBuilder = controlPackageBuilder;
        _lifecycle = lifecycle;
        _catalogEntries = [catalogEntries copy];
    }
    return self;
}

- (NSArray<MobaChampionCatalogEntry *> *)catalogEntries {
    return _catalogEntries;
}

- (NSString *)selectedChampionID {
    @synchronized (self) {
        return _selectedChampionID;
    }
}

- (MobaChampionRuntime *)activeChampionRuntime {
    @synchronized (self) {
        return _activeChampionRuntime;
    }
}

- (nullable MobaSkillControlPackage *)activeSkillControlPackage {
    @synchronized (self) {
        return _activeSkillControlPackage;
    }
}

- (MobaChampionCatalogEntry *)catalogEntryForChampionID:(NSString *)championID {
    for (MobaChampionCatalogEntry *entry in _catalogEntries) {
        if ([entry.championID isEqualToString:championID]) {
            return entry;
        }
    }
    return nil;
}

- (NSError *)selectionErrorWithCode:(MobaChampionSelectionErrorCode)code
                         championID:(NSString *)championID
                          operation:(NSString *)operation
                        description:(NSString *)description
                    underlyingError:(NSError *)underlyingError {
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey: [description copy],
        MobaChampionSelectionChampionIDKey: [championID copy],
        MobaChampionSelectionOperationKey: [operation copy],
    } mutableCopy];
    if (underlyingError != nil) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:MobaChampionSelectionErrorDomain code:code userInfo:userInfo];
}

- (void)discardRuntime:(MobaChampionRuntime *)runtime {
    for (id<MobaLocalInteractionResetParticipant> participant in runtime.localInteractionResetParticipants) {
        if ([participant respondsToSelector:@selector(setMobaLocalInteractionEnabled:)]) {
            [participant setMobaLocalInteractionEnabled:NO];
        }
        [participant resetMobaLocalInteractionForReason:MobaInputInterruptionReasonProfileReload];
    }
}

- (void)discardControlPackage:(nullable MobaSkillControlPackage *)controlPackage {
    [controlPackage silentResetForReason:MobaInputInterruptionReasonProfileReload];
}

- (BOOL)selectChampionID:(NSString *)championID error:(NSError **)error {
    return [self selectChampionID:championID forceReload:NO error:error];
}

- (BOOL)reloadSelectedChampionWithError:(NSError **)error {
    NSString *championID = self.selectedChampionID;
    if (championID.length == 0) {
        if (error != NULL) {
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorRuntimeMissing
                                       championID:@"<none>"
                                        operation:@"reload-selected-champion"
                                      description:@"No selected champion is available to reload."
                                  underlyingError:nil];
        }
        return NO;
    }
    return [self selectChampionID:championID forceReload:YES error:error];
}

- (BOOL)selectChampionID:(NSString *)championID forceReload:(BOOL)forceReload error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (_invalidated) {
        if (error != NULL) {
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorRuntimeMissing
                                       championID:championID ?: @"<unknown>"
                                        operation:@"select-champion"
                                      description:@"The champion selection controller is no longer active."
                                  underlyingError:nil];
        }
        return NO;
    }
    MobaChampionCatalogEntry *entry = [self catalogEntryForChampionID:championID];
    if (entry == nil) {
        if (error != NULL) {
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorUnknownChampion
                                       championID:championID ?: @"<unknown>"
                                        operation:@"resolve-catalog-entry"
                                      description:@"The champion is not in the manual selection catalog."
                                  underlyingError:nil];
        }
        return NO;
    }
    @synchronized (self) {
        if (!forceReload && _activeChampionRuntime != nil && [_selectedChampionID isEqualToString:championID]) {
            return YES;
        }
    }

    __block MobaChampionRuntime *candidateRuntime = nil;
    __block MobaSkillControlPackage *candidateControlPackage = nil;
    __block BOOL repositoryAccepted = NO;
    [_lifecycle profileWillReload];
    @try {
        repositoryAccepted = [_repository reloadWithChampionRelativePath:entry.championRelativePath
                                                        candidateValidator:^BOOL(MobaProfileSnapshot *candidate,
                                                                                 NSError **candidateError) {
            candidateRuntime = [self->_runtimeBuilder runtimeFromSnapshot:candidate error:candidateError];
            if (candidateRuntime == nil) {
                return NO;
            }
            if (self->_controlPackageBuilder == nil) {
                return YES;
            }

            candidateControlPackage = [self->_controlPackageBuilder controlPackageForRuntime:candidateRuntime
                                                                                         error:candidateError];
            if (candidateControlPackage != nil && candidateControlPackage.isComplete) {
                return YES;
            }
            if (candidateError != NULL && *candidateError == nil) {
                *candidateError = [self selectionErrorWithCode:MobaChampionSelectionErrorControlPackageBuildFailed
                                                     championID:championID
                                                      operation:@"build-candidate-skill-controls"
                                                    description:@"The candidate skill-control package is incomplete."
                                                underlyingError:nil];
            }
            return NO;
        }
                                                                     error:error];
        if (!repositoryAccepted || candidateRuntime == nil) {
            [self discardControlPackage:candidateControlPackage];
            [self discardRuntime:candidateRuntime];
            if (repositoryAccepted && error != NULL && *error == nil) {
                *error = [self selectionErrorWithCode:MobaChampionSelectionErrorRuntimeMissing
                                           championID:championID
                                            operation:@"build-candidate-runtime"
                                          description:@"The runtime builder accepted no champion runtime."
                                      underlyingError:nil];
            }
            return NO;
        }

        MobaChampionRuntime *oldRuntime = self.activeChampionRuntime;
        for (id<MobaLocalInteractionResetParticipant> participant in oldRuntime.localInteractionResetParticipants) {
            [_lifecycle unregisterLocalInteractionResetParticipant:participant];
        }
        for (id<MobaLocalInteractionResetParticipant> participant in candidateRuntime.localInteractionResetParticipants) {
            [_lifecycle registerLocalInteractionResetParticipant:participant];
        }
        @synchronized (self) {
            _selectedChampionID = [championID copy];
            _activeChampionRuntime = candidateRuntime;
            _activeSkillControlPackage = candidateControlPackage;
        }
        [self.delegate championSelectionController:self
                                   didSelectRuntime:candidateRuntime
                                skillControlPackage:candidateControlPackage];
        return YES;
    }
    @catch (NSException *exception) {
        [self discardControlPackage:candidateControlPackage];
        [self discardRuntime:candidateRuntime];
        if (error != NULL) {
            NSDictionary *details = @{NSLocalizedDescriptionKey: exception.reason ?: @"Runtime selection raised an exception."};
            NSError *underlyingError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                            code:NSFileReadUnknownError
                                                        userInfo:details];
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorUnexpectedException
                                       championID:championID
                                        operation:@"select-champion"
                                      description:@"Champion selection failed unexpectedly."
                                  underlyingError:underlyingError];
        }
        return NO;
    }
    @finally {
        [_lifecycle profileDidReload];
    }
}

- (BOOL)commitPreparedProfileSnapshot:(MobaProfileSnapshot *)snapshot
                               runtime:(MobaChampionRuntime *)runtime
                    skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                                 error:(NSError **)error {
    if (error != NULL) *error = nil;
    NSString *selectedChampionID = self.selectedChampionID;
    if (_invalidated || snapshot == nil || runtime == nil || !skillControlPackage.isComplete ||
        selectedChampionID.length == 0 ||
        ![snapshot.championProfile.championID isEqualToString:selectedChampionID] ||
        ![runtime.championID isEqualToString:selectedChampionID] ||
        _repository.activeSnapshot != snapshot) {
        if (error != NULL) {
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorPreparedCommitRejected
                                       championID:selectedChampionID ?: @"<none>"
                                        operation:@"commit-prepared-profile-runtime"
                                      description:@"The prepared runtime does not match the committed snapshot and selected champion."
                                  underlyingError:nil];
        }
        return NO;
    }
    MobaChampionRuntime *oldRuntime = self.activeChampionRuntime;
    for (id<MobaLocalInteractionResetParticipant> participant in oldRuntime.localInteractionResetParticipants) {
        [_lifecycle unregisterLocalInteractionResetParticipant:participant];
    }
    for (id<MobaLocalInteractionResetParticipant> participant in runtime.localInteractionResetParticipants) {
        [_lifecycle registerLocalInteractionResetParticipant:participant];
    }
    @synchronized (self) {
        _activeChampionRuntime = runtime;
        _activeSkillControlPackage = skillControlPackage;
    }
    [self.delegate championSelectionController:self
                               didSelectRuntime:runtime
                            skillControlPackage:skillControlPackage];
    return YES;
}

- (BOOL)commitPreparedImportedSnapshot:(MobaProfileSnapshot *)snapshot
                                runtime:(MobaChampionRuntime *)runtime
                     skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                  championRelativePath:(NSString *)championRelativePath
                                  error:(NSError **)error {
    MobaChampionPreparedImportState *state = [self prepareImportedSnapshot:snapshot
        runtime:runtime skillControlPackage:skillControlPackage
        championRelativePath:championRelativePath error:error];
    return state != nil && [self commitPreparedImportedState:state error:error];
}

- (MobaChampionPreparedImportState *)prepareImportedSnapshot:(MobaProfileSnapshot *)snapshot
                                                      runtime:(MobaChampionRuntime *)runtime
                                           skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                                        championRelativePath:(NSString *)championRelativePath
                                                        error:(NSError **)error {
    if (error != NULL) *error = nil;
    NSString *championID = snapshot.championProfile.championID;
    if (_invalidated || snapshot == nil || runtime == nil || !skillControlPackage.isComplete ||
        championID.length == 0 || championRelativePath.length == 0 ||
        ![runtime.championID isEqualToString:championID]) {
        if (error != NULL) {
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorPreparedCommitRejected
                                       championID:championID ?: @"<none>"
                                        operation:@"commit-imported-profile-runtime"
                                      description:@"The imported runtime does not match the committed snapshot."
                                  underlyingError:nil];
        }
        return nil;
    }

    MobaChampionCatalogEntry *entry = [[MobaChampionCatalogEntry alloc]
        initWithChampionID:championID
        displayName:snapshot.championProfile.displayName
        championRelativePath:championRelativePath];
    if (entry == nil) {
        if (error != NULL) {
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorPreparedCommitRejected
                                       championID:championID
                                        operation:@"create-imported-catalog-entry"
                                      description:@"The imported Champion catalog entry is invalid."
                                  underlyingError:nil];
        }
        return nil;
    }

    NSMutableArray<MobaChampionCatalogEntry *> *entries = [_catalogEntries mutableCopy];
    NSUInteger existingIndex = [entries indexOfObjectPassingTest:^BOOL(MobaChampionCatalogEntry *candidate,
                                                                        NSUInteger index, BOOL *stop) {
        return [candidate.championID isEqualToString:championID];
    }];
    if (existingIndex == NSNotFound) [entries addObject:entry];
    else entries[existingIndex] = entry;
    MobaChampionPreparedImportState *state = [[MobaChampionPreparedImportState alloc] init];
    state.owner = self;
    state.snapshot = snapshot;
    state.runtime = runtime;
    state.skillControlPackage = skillControlPackage;
    state.championID = championID;
    state.newCatalogEntries = [entries copy];
    state.oldCatalogEntries = [_catalogEntries copy];
    state.oldSelectedChampionID = self.selectedChampionID;
    state.oldRuntime = self.activeChampionRuntime;
    state.oldSkillControlPackage = self.activeSkillControlPackage;
    return state;
}

- (BOOL)commitPreparedImportedState:(MobaChampionPreparedImportState *)state error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (state.owner != self || state.commitStarted || state.rolledBack ||
        _invalidated || _repository.activeSnapshot != state.snapshot) {
        if (error != NULL) *error = [self selectionErrorWithCode:MobaChampionSelectionErrorPreparedCommitRejected
            championID:state.championID ?: @"<none>" operation:@"commit-prepared-import"
            description:@"The prepared Champion import is stale or cannot be committed."
            underlyingError:nil];
        return NO;
    }
    state.commitStarted = YES;
    @try {
        for (id<MobaLocalInteractionResetParticipant> participant in state.oldRuntime.localInteractionResetParticipants) {
            [_lifecycle unregisterLocalInteractionResetParticipant:participant];
        }
        for (id<MobaLocalInteractionResetParticipant> participant in state.runtime.localInteractionResetParticipants) {
            [_lifecycle registerLocalInteractionResetParticipant:participant];
        }
        @synchronized (self) {
            _catalogEntries = state.newCatalogEntries;
            _selectedChampionID = state.championID;
            _activeChampionRuntime = state.runtime;
            _activeSkillControlPackage = state.skillControlPackage;
        }
        [self.delegate championSelectionController:self didSelectRuntime:state.runtime
            skillControlPackage:state.skillControlPackage];
        return YES;
    }
    @catch (NSException *exception) {
        NSError *rollbackError = nil;
        [self rollbackPreparedImportedState:state error:&rollbackError];
        if (error != NULL) {
            NSError *underlying = [NSError errorWithDomain:NSCocoaErrorDomain
                code:NSFileWriteUnknownError
                userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Champion installation raised an exception."}];
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorUnexpectedException
                championID:state.championID operation:@"commit-prepared-import"
                description:@"The prepared Champion installation failed and was restored."
                underlyingError:rollbackError ?: underlying];
        }
        return NO;
    }
}

- (BOOL)rollbackPreparedImportedState:(MobaChampionPreparedImportState *)state error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (state.owner != self) return NO;
    if (state.rolledBack || !state.commitStarted) return YES;
    @try {
        for (id<MobaLocalInteractionResetParticipant> participant in state.runtime.localInteractionResetParticipants) {
            [_lifecycle unregisterLocalInteractionResetParticipant:participant];
        }
        for (id<MobaLocalInteractionResetParticipant> participant in state.oldRuntime.localInteractionResetParticipants) {
            [_lifecycle registerLocalInteractionResetParticipant:participant];
        }
        @synchronized (self) {
            _catalogEntries = state.oldCatalogEntries;
            _selectedChampionID = state.oldSelectedChampionID;
            _activeChampionRuntime = state.oldRuntime;
            _activeSkillControlPackage = state.oldSkillControlPackage;
        }
        [self.delegate championSelectionController:self didSelectRuntime:state.oldRuntime
            skillControlPackage:state.oldSkillControlPackage];
        state.rolledBack = YES;
        return YES;
    }
    @catch (NSException *exception) {
        if (error != NULL) {
            NSError *underlying = [NSError errorWithDomain:NSCocoaErrorDomain
                code:NSFileWriteUnknownError
                userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Champion rollback raised an exception."}];
            *error = [self selectionErrorWithCode:MobaChampionSelectionErrorUnexpectedException
                championID:state.oldSelectedChampionID ?: @"<none>" operation:@"rollback-prepared-import"
                description:@"The previous Champion runtime could not be restored."
                underlyingError:underlying];
        }
        return NO;
    }
}

- (void)invalidate {
    if (_invalidated) {
        return;
    }
    _invalidated = YES;
    MobaChampionRuntime *runtime = self.activeChampionRuntime;
    for (id<MobaLocalInteractionResetParticipant> participant in runtime.localInteractionResetParticipants) {
        [_lifecycle unregisterLocalInteractionResetParticipant:participant];
    }
}

- (void)dealloc {
    [self invalidate];
}

@end
