//
//  MobaProfileImportTransaction.m
//  Moonlight
//

#import "MobaProfileImportTransaction.h"

NSErrorDomain const MobaProfileImportTransactionErrorDomain = @"MobaProfileImportTransactionErrorDomain";
NSString *const MobaProfileImportOriginalErrorKey = @"MobaProfileImportOriginalError";
NSString *const MobaProfileImportRollbackErrorKey = @"MobaProfileImportRollbackError";
NSString *const MobaProfileImportInstallerRollbackErrorKey = @"MobaProfileImportInstallerRollbackError";
NSString *const MobaProfileImportRepositoryRollbackErrorKey = @"MobaProfileImportRepositoryRollbackError";
NSString *const MobaProfileImportStorageRollbackErrorKey = @"MobaProfileImportStorageRollbackError";

@implementation MobaPreparedProfileInstallation
@end

static NSError *MobaRuntimeInstallerError(NSString *operation, NSString *description,
                                          NSError *underlying) {
    NSMutableDictionary *info = [@{
        NSLocalizedDescriptionKey: description,
        @"MobaProfileRuntimeInstallerOperation": operation,
    } mutableCopy];
    if (underlying != nil) info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:@"MobaProfileRuntimeInstallerErrorDomain" code:1 userInfo:info];
}

@interface MobaRuntimePreparedProfileInstallation : MobaPreparedProfileInstallation
@property (nonatomic, weak) id<MobaProfileRuntimeInstallationHost> host;
@property (nonatomic, strong) MobaChampionPreparedImportState *championState;
@property (nonatomic, strong) MobaProfileSnapshot *oldSnapshot;
@property (nonatomic, strong) MobaProfileSnapshot *newSnapshot;
@property (nonatomic, copy) NSString *oldChampionRelativePath;
@property (nonatomic, copy) NSString *newChampionRelativePath;
@property (nonatomic) MobaMovementKeyMapping oldMovementMapping;
@property (nonatomic) MobaMovementKeyMapping newMovementMapping;
@property (nonatomic) uint16_t oldAttackKeyCode;
@property (nonatomic) uint16_t newAttackKeyCode;
@property (nonatomic) NSUInteger oldAttackTapDurationMs;
@property (nonatomic) NSUInteger newAttackTapDurationMs;
@property (nonatomic) BOOL commitStarted;
@property (nonatomic) BOOL rollbackAttempted;
@property (nonatomic) BOOL rollbackComplete;
@property (nonatomic, strong, nullable) NSError *rollbackError;
@end

@implementation MobaRuntimePreparedProfileInstallation
@end

@implementation MobaProfileRuntimeInstaller {
    __weak id<MobaProfileRuntimeInstallationHost> _host;
}

- (instancetype)initWithHost:(id<MobaProfileRuntimeInstallationHost>)host {
    if (host == nil) return nil;
    self = [super init];
    if (self) _host = host;
    return self;
}

- (MobaPreparedProfileInstallation *)prepareInstallationForSnapshot:(MobaProfileSnapshot *)snapshot
                                                              runtime:(MobaChampionRuntime *)runtime
                                                  skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                                               championRelativePath:(NSString *)championRelativePath
                                                               error:(NSError **)error {
    if (error != NULL) *error = nil;
    id<MobaProfileRuntimeInstallationHost> host = _host;
    MobaMovementController *movement = host.profileImportMovementController;
    MobaAttackController *attack = host.profileImportAttackController;
    MobaChampionSelectionController *selection = host.profileImportChampionSelectionController;
    NSNumber *attackCode = [snapshot.inputProfile keyCodeForAction:@"attack"];
    MobaMovementProfile *inputMovement = snapshot.inputProfile.movement;
    BOOL identityValid = snapshot != nil && runtime != nil && skillControlPackage.isComplete &&
        [runtime.championID isEqualToString:snapshot.championProfile.championID];
    BOOL inputValid = inputMovement != nil && inputMovement.upKeyCode > 0 &&
        inputMovement.leftKeyCode > 0 && inputMovement.downKeyCode > 0 &&
        inputMovement.rightKeyCode > 0 && attackCode.unsignedIntegerValue > 0 &&
        attackCode.unsignedIntegerValue <= UINT16_MAX && snapshot.inputProfile.attackTapDurationMs > 0;
    if (!NSThread.isMainThread || host == nil || host.profileImportActiveSnapshot == nil ||
        !host.profileImportInputSuspended ||
        movement == nil || attack == nil || selection == nil ||
        ![movement canApplyCommittedKeyMapping] || ![attack canApplyCommittedAttackProfile] ||
        !identityValid || !inputValid || championRelativePath.length == 0) {
        if (error != NULL) *error = MobaRuntimeInstallerError(@"prepare",
            @"Profile installation requires a suspended, neutral, token-free control boundary and a complete matching runtime.", nil);
        return nil;
    }
    NSError *selectionError = nil;
    MobaChampionPreparedImportState *championState = [selection prepareImportedSnapshot:snapshot
        runtime:runtime skillControlPackage:skillControlPackage
        championRelativePath:championRelativePath error:&selectionError];
    if (championState == nil) {
        if (error != NULL) *error = MobaRuntimeInstallerError(@"prepare-champion",
            @"Champion Selection rejected the prepared imported runtime.", selectionError);
        return nil;
    }
    MobaRuntimePreparedProfileInstallation *installation =
        [[MobaRuntimePreparedProfileInstallation alloc] init];
    installation.host = host;
    installation.championState = championState;
    installation.oldSnapshot = host.profileImportActiveSnapshot;
    installation.newSnapshot = snapshot;
    installation.oldChampionRelativePath = host.profileImportActiveChampionRelativePath;
    installation.newChampionRelativePath = championRelativePath;
    installation.oldMovementMapping = movement.keyMapping;
    installation.newMovementMapping = MobaMovementKeyMappingMake(inputMovement.upKeyCode,
        inputMovement.leftKeyCode, inputMovement.downKeyCode, inputMovement.rightKeyCode);
    installation.oldAttackKeyCode = attack.attackKeyCode;
    installation.oldAttackTapDurationMs = attack.tapDurationMs;
    installation.newAttackKeyCode = attackCode.unsignedShortValue;
    installation.newAttackTapDurationMs = snapshot.inputProfile.attackTapDurationMs;
    return installation;
}

- (BOOL)commitPreparedInstallation:(MobaPreparedProfileInstallation *)prepared error:(NSError **)error {
    if (error != NULL) *error = nil;
    MobaRuntimePreparedProfileInstallation *installation =
        [prepared isKindOfClass:[MobaRuntimePreparedProfileInstallation class]] ? (id)prepared : nil;
    id<MobaProfileRuntimeInstallationHost> host = installation.host;
    if (installation == nil || host == nil || installation.commitStarted ||
        installation.rollbackAttempted || !host.profileImportInputSuspended) {
        if (error != NULL) *error = MobaRuntimeInstallerError(@"commit",
            @"The prepared profile installation is stale or already consumed.", nil);
        return NO;
    }
    installation.commitStarted = YES;
    NSError *stepError = nil;
    @try {
        if (![host.profileImportChampionSelectionController
            commitPreparedImportedState:installation.championState error:&stepError] ||
            ![host applyProfileImportMovementMapping:installation.newMovementMapping error:&stepError] ||
            ![host applyProfileImportAttackKeyCode:installation.newAttackKeyCode
                tapDurationMs:installation.newAttackTapDurationMs error:&stepError]) {
            @throw [NSException exceptionWithName:@"MobaProfileInstallationCommitFailure"
                                           reason:stepError.localizedDescription ?: @"Profile commit step failed."
                                         userInfo:nil];
        }
        [host setProfileImportActiveChampionRelativePath:installation.newChampionRelativePath];
        if (![host applyProfileImportPresentationForSnapshot:installation.newSnapshot error:&stepError]) {
            @throw [NSException exceptionWithName:@"MobaProfileInstallationPresentationFailure"
                                           reason:stepError.localizedDescription ?: @"Profile presentation failed."
                                         userInfo:nil];
        }
        return YES;
    }
    @catch (NSException *exception) {
        NSError *original = stepError ?: MobaRuntimeInstallerError(@"commit-exception",
            exception.reason ?: @"Profile installation raised an exception.", nil);
        NSError *rollbackError = nil;
        [self rollbackPreparedInstallation:installation error:&rollbackError];
        if (error != NULL) *error = MobaRuntimeInstallerError(@"commit",
            @"Profile installation failed and attempted to restore its captured state.",
            rollbackError ?: original);
        return NO;
    }
}

- (BOOL)rollbackPreparedInstallation:(MobaPreparedProfileInstallation *)prepared error:(NSError **)error {
    if (error != NULL) *error = nil;
    MobaRuntimePreparedProfileInstallation *installation =
        [prepared isKindOfClass:[MobaRuntimePreparedProfileInstallation class]] ? (id)prepared : nil;
    id<MobaProfileRuntimeInstallationHost> host = installation.host;
    if (installation == nil || host == nil) {
        if (error != NULL) *error = MobaRuntimeInstallerError(@"rollback",
            @"The prepared profile installation cannot be restored because its host or token is unavailable.", nil);
        return NO;
    }
    if (installation.rollbackAttempted) {
        if (!installation.rollbackComplete && error != NULL) *error = installation.rollbackError;
        return installation.rollbackComplete;
    }
    installation.rollbackAttempted = YES;
    NSError *firstError = nil;
    NSError *stepError = nil;
    if (installation.commitStarted) {
        if (![host applyProfileImportAttackKeyCode:installation.oldAttackKeyCode
             tapDurationMs:installation.oldAttackTapDurationMs error:&stepError] && firstError == nil) {
            firstError = stepError ?: MobaRuntimeInstallerError(@"rollback-attack",
                @"The previous attack input profile could not be restored.", nil);
        }
        stepError = nil;
        if (![host applyProfileImportMovementMapping:installation.oldMovementMapping error:&stepError] && firstError == nil) {
            firstError = stepError ?: MobaRuntimeInstallerError(@"rollback-movement",
                @"The previous movement input profile could not be restored.", nil);
        }
        [host setProfileImportActiveChampionRelativePath:installation.oldChampionRelativePath];
    }
    stepError = nil;
    if (![host.profileImportChampionSelectionController rollbackPreparedImportedState:installation.championState
                                                                                 error:&stepError] && firstError == nil) {
        firstError = stepError ?: MobaRuntimeInstallerError(@"rollback-champion",
            @"The previous Champion runtime could not be restored.", nil);
    }
    if (installation.commitStarted) {
        stepError = nil;
        if (![host applyProfileImportPresentationForSnapshot:installation.oldSnapshot error:&stepError] &&
            firstError == nil) {
            firstError = stepError ?: MobaRuntimeInstallerError(@"rollback-presentation",
                @"The previous control presentation could not be restored.", nil);
        }
    }
    installation.rollbackComplete = firstError == nil;
    installation.rollbackError = firstError;
    if (firstError != nil && error != NULL) *error = firstError;
    return installation.rollbackComplete;
}

@end

static NSString *MobaProfileUTCString(NSDate *date) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    });
    @synchronized (formatter) {
        return [formatter stringFromDate:date];
    }
}

@interface MobaDefaultBackupDirectoryProvider : NSObject <MobaProfileBackupDirectoryNameProviding>
@end
@implementation MobaDefaultBackupDirectoryProvider
- (NSString *)nextBackupDirectoryName {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyyMMdd'T'HHmmss.SSS'Z'";
    });
    NSString *timestamp = nil;
    @synchronized (formatter) {
        timestamp = [formatter stringFromDate:[NSDate date]];
    }
    return [NSString stringWithFormat:@"%@-%@", timestamp, NSUUID.UUID.UUIDString];
}
@end

@interface MobaProfileImportResult ()
- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
               backupRelativePath:(NSString *)backupRelativePath
        activeChampionRelativePath:(NSString *)activeChampionRelativePath;
@end
@implementation MobaProfileImportResult
- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
               backupRelativePath:(NSString *)backupRelativePath
        activeChampionRelativePath:(NSString *)activeChampionRelativePath {
    self = [super init];
    if (self) {
        _snapshot = snapshot;
        _backupRelativePath = [backupRelativePath copy];
        _activeChampionRelativePath = [activeChampionRelativePath copy];
    }
    return self;
}
@end

@implementation MobaProfileImportTransaction {
    MobaProfileStore *_store;
    MobaProfileRepository *_repository;
    id<MobaProfileImportLifecycle> _lifecycle;
    id<MobaProfileImportInstalling> _installer;
    id<MobaProfileBackupDirectoryNameProviding> _backupDirectoryProvider;
}

- (instancetype)initWithStore:(MobaProfileStore *)store repository:(MobaProfileRepository *)repository
                      lifecycle:(id<MobaProfileImportLifecycle>)lifecycle
                       installer:(id<MobaProfileImportInstalling>)installer {
    return [self initWithStore:store repository:repository lifecycle:lifecycle installer:installer
       backupDirectoryProvider:[[MobaDefaultBackupDirectoryProvider alloc] init]];
}

- (instancetype)initWithStore:(MobaProfileStore *)store repository:(MobaProfileRepository *)repository
                      lifecycle:(id<MobaProfileImportLifecycle>)lifecycle
                       installer:(id<MobaProfileImportInstalling>)installer
         backupDirectoryProvider:(id<MobaProfileBackupDirectoryNameProviding>)backupDirectoryProvider {
    if (store == nil || repository == nil || lifecycle == nil || installer == nil ||
        backupDirectoryProvider == nil) return nil;
    self = [super init];
    if (self) {
        _store = store;
        _repository = repository;
        _lifecycle = lifecycle;
        _installer = installer;
        _backupDirectoryProvider = backupDirectoryProvider;
    }
    return self;
}

- (NSError *)errorWithCode:(MobaProfileImportTransactionErrorCode)code
                description:(NSString *)description underlying:(NSError *)underlying {
    NSMutableDictionary *info = [@{NSLocalizedDescriptionKey: description} mutableCopy];
    if (underlying != nil) info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:MobaProfileImportTransactionErrorDomain code:code userInfo:info];
}

- (BOOL)activeBytesStillMatchPlan:(MobaProfileImportPlan *)plan error:(NSError **)error {
    for (NSString *path in plan.activeProfileDataByRelativePath) {
        NSError *readError = nil;
        NSData *current = [_store readDataAtRelativePath:path error:&readError];
        if (current == nil || ![current isEqualToData:plan.activeProfileDataByRelativePath[path]]) {
            if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorActiveBytesChanged
                description:@"An active profile file changed after the import plan was prepared."
                underlying:readError];
            return NO;
        }
    }
    NSError *existenceError = nil;
    BOOL exists = [_store dataExistsAtRelativePath:plan.targetRelativePath error:&existenceError];
    if (existenceError != nil || exists != plan.destinationPreviouslyExisted) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorActiveBytesChanged
            description:@"The import destination changed after the plan was prepared."
            underlying:existenceError];
        return NO;
    }
    if (exists) {
        NSData *current = [_store readDataAtRelativePath:plan.targetRelativePath error:&existenceError];
        if (current == nil || ![current isEqualToData:plan.previousDestinationData]) {
            if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorActiveBytesChanged
                description:@"The destination bytes changed after the import plan was prepared."
                underlying:existenceError];
            return NO;
        }
    }
    return YES;
}

- (NSString *)createBackupForPlan:(MobaProfileImportPlan *)plan error:(NSError **)error {
    NSString *directoryName = [_backupDirectoryProvider nextBackupDirectoryName];
    NSString *directory = [@"backups" stringByAppendingPathComponent:directoryName];
    NSDictionary<NSString *, NSString *> *backupNames = @{
        MobaRuntimeProfileRelativePath: @"runtime.json",
        MobaInputProfileRelativePath: @"input.json",
        MobaActiveLayoutProfileRelativePath: @"active-layout.json",
        plan.activeChampionRelativePath: @"active-champion.json",
    };
    NSMutableDictionary *manifestFiles = [NSMutableDictionary dictionary];
    for (NSString *activePath in backupNames) {
        NSString *backupName = backupNames[activePath];
        NSString *backupPath = [directory stringByAppendingPathComponent:backupName];
        NSError *writeError = nil;
        if (![_store writeData:plan.activeProfileDataByRelativePath[activePath]
                 toRelativePath:backupPath replaceExisting:NO error:&writeError]) {
            [_store removeDirectoryAtRelativePath:directory error:nil];
            if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorBackupFailed
                description:@"Unable to create the complete active-profile backup."
                underlying:writeError];
            return nil;
        }
        manifestFiles[backupName] = activePath;
    }
    BOOL targetIsActive = plan.activeProfileDataByRelativePath[plan.targetRelativePath] != nil;
    if (plan.destinationPreviouslyExisted && !targetIsActive) {
        NSString *targetBackupPath = [directory stringByAppendingPathComponent:@"target-champion.json"];
        NSError *writeError = nil;
        if (![_store writeData:plan.previousDestinationData toRelativePath:targetBackupPath
               replaceExisting:NO error:&writeError]) {
            [_store removeDirectoryAtRelativePath:directory error:nil];
            if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorBackupFailed
                description:@"Unable to back up the existing import destination."
                underlying:writeError];
            return nil;
        }
        manifestFiles[@"target-champion.json"] = plan.targetRelativePath;
    }
    NSDictionary *manifest = @{
        @"backupFormatVersion": @1,
        @"utcTimestamp": MobaProfileUTCString([NSDate date]),
        @"importProfileKind": plan.profileKind,
        @"selectedChampionIdBeforeImport": plan.baseSnapshot.championProfile.championID,
        @"activeChampionRelativePath": plan.activeChampionRelativePath,
        @"replacedTargetRelativePath": plan.targetRelativePath,
        @"destinationPreviouslyExisted": @(plan.destinationPreviouslyExisted),
        @"files": manifestFiles,
    };
    NSError *jsonError = nil;
    NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifest
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&jsonError];
    NSError *writeError = nil;
    if (manifestData == nil || ![_store writeData:manifestData
        toRelativePath:[directory stringByAppendingPathComponent:@"manifest.json"]
        replaceExisting:NO error:&writeError]) {
        [_store removeDirectoryAtRelativePath:directory error:nil];
        if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorBackupFailed
            description:@"Unable to finish the profile backup manifest."
            underlying:jsonError ?: writeError];
        return nil;
    }
    return directory;
}

- (void)reportRollbackForPlan:(MobaProfileImportPlan *)plan
                 installation:(MobaPreparedProfileInstallation *)installation
          repositoryCommitted:(BOOL)repositoryCommitted
                targetWritten:(BOOL)targetWritten
                 originalError:(NSError *)originalError
                         error:(NSError **)error {
    NSError *installerError = nil;
    NSError *repositoryError = nil;
    NSError *storageError = nil;
    BOOL installerRestored = installation == nil ||
        [_installer rollbackPreparedInstallation:installation error:&installerError];
    BOOL repositoryRestored = !repositoryCommitted ||
        [_repository rollbackImportCandidate:plan.repositoryCandidate error:&repositoryError];
    BOOL storageRestored = YES;
    if (targetWritten) {
        storageRestored = plan.destinationPreviouslyExisted
            ? [_store writeData:plan.previousDestinationData toRelativePath:plan.targetRelativePath
                 replaceExisting:YES error:&storageError]
            : [_store removeDataAtRelativePath:plan.targetRelativePath error:&storageError];
    }
    if (!installerRestored && installerError == nil) {
        installerError = [self errorWithCode:MobaProfileImportTransactionErrorRollbackFailed
            description:@"The runtime installer did not restore its prepared state."
            underlying:nil];
    }
    if (!repositoryRestored && repositoryError == nil) {
        repositoryError = [self errorWithCode:MobaProfileImportTransactionErrorRollbackFailed
            description:@"The Profile Repository did not restore its exact-base candidate."
            underlying:nil];
    }
    if (!storageRestored && storageError == nil) {
        storageError = [self errorWithCode:MobaProfileImportTransactionErrorRollbackFailed
            description:@"The imported destination bytes were not restored."
            underlying:nil];
    }
    if (installerRestored && repositoryRestored && storageRestored) {
        if (error != NULL) *error = originalError;
        return;
    }
    NSError *rollbackError = installerError ?: repositoryError ?: storageError;
    NSMutableDictionary *info = [@{
        NSLocalizedDescriptionKey: @"Profile import failed and restoring the previous active state also failed.",
        MobaProfileImportOriginalErrorKey: originalError,
        MobaProfileImportRollbackErrorKey: rollbackError ?: originalError,
    } mutableCopy];
    if (installerError != nil) info[MobaProfileImportInstallerRollbackErrorKey] = installerError;
    if (repositoryError != nil) info[MobaProfileImportRepositoryRollbackErrorKey] = repositoryError;
    if (storageError != nil) info[MobaProfileImportStorageRollbackErrorKey] = storageError;
    info[NSUnderlyingErrorKey] = rollbackError ?: originalError;
    if (error != NULL) *error = [NSError errorWithDomain:MobaProfileImportTransactionErrorDomain
        code:MobaProfileImportTransactionErrorRollbackFailed userInfo:info];
}

- (MobaProfileImportResult *)applyImportPlan:(MobaProfileImportPlan *)plan error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (!NSThread.isMainThread) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorRuntimeInstallFailed
            description:@"Profile import transactions require the main thread."
            underlying:nil];
        return nil;
    }
    if (plan == nil || _repository.activeSnapshot != plan.baseSnapshot) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorStalePlan
            description:@"The active profile snapshot changed. Select the import file again."
            underlying:nil];
        return nil;
    }
    if (![self activeBytesStillMatchPlan:plan error:error]) return nil;

    BOOL repositoryCommitted = NO;
    BOOL targetWritten = NO;
    MobaPreparedProfileInstallation *installation = nil;
    NSString *activeChampionPath = [plan.profileKind isEqualToString:MobaProfileKindChampion]
        ? plan.targetRelativePath : plan.activeChampionRelativePath;
    [_lifecycle profileWillReload];
    @try {
        NSError *stepError = nil;
        installation = [_installer prepareInstallationForSnapshot:plan.repositoryCandidate.snapshot
            runtime:plan.runtime skillControlPackage:plan.skillControlPackage
            championRelativePath:activeChampionPath error:&stepError];
        if (installation == nil) {
            if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorRuntimeInstallFailed
                description:@"The imported runtime installation could not be prepared."
                underlying:stepError];
            return nil;
        }
        NSString *backupPath = [self createBackupForPlan:plan error:&stepError];
        if (backupPath == nil) {
            [self reportRollbackForPlan:plan installation:installation repositoryCommitted:NO
                targetWritten:NO originalError:stepError error:error];
            return nil;
        }
        if (![_store writeData:plan.importData toRelativePath:plan.targetRelativePath
               replaceExisting:plan.destinationPreviouslyExisted error:&stepError]) {
            NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorPersistenceFailed
                description:@"Unable to atomically replace the imported profile destination."
                underlying:stepError];
            [self reportRollbackForPlan:plan installation:installation repositoryCommitted:NO
                targetWritten:NO originalError:importError error:error];
            return nil;
        }
        targetWritten = YES;
        if (![_repository commitImportCandidate:plan.repositoryCandidate error:&stepError]) {
            NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorRepositoryCommitFailed
                description:@"The exact-base imported snapshot could not be committed."
                underlying:stepError];
            [self reportRollbackForPlan:plan installation:installation repositoryCommitted:NO
                targetWritten:targetWritten originalError:importError error:error];
            return nil;
        }
        repositoryCommitted = YES;
        if (![_installer commitPreparedInstallation:installation error:&stepError]) {
            NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorRuntimeInstallFailed
                description:@"The imported runtime and controls could not be installed."
                underlying:stepError];
            [self reportRollbackForPlan:plan installation:installation
                repositoryCommitted:repositoryCommitted targetWritten:targetWritten
                originalError:importError error:error];
            return nil;
        }
        return [[MobaProfileImportResult alloc] initWithSnapshot:plan.repositoryCandidate.snapshot
            backupRelativePath:backupPath activeChampionRelativePath:activeChampionPath];
    }
    @catch (NSException *exception) {
        NSError *cause = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError
            userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile import raised an exception."}];
        NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorRuntimeInstallFailed
            description:@"Profile import failed unexpectedly." underlying:cause];
        [self reportRollbackForPlan:plan installation:installation
            repositoryCommitted:repositoryCommitted targetWritten:targetWritten
            originalError:importError error:error];
        return nil;
    }
    @finally {
        [_lifecycle profileDidReload];
    }
}

@end
