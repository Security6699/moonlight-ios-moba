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
        if (_activeChampionRuntime != nil && [_selectedChampionID isEqualToString:championID]) {
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
