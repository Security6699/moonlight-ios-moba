//
//  MobaProfileImportTransaction.m
//  Moonlight
//

#import "MobaProfileImportTransaction.h"

NSErrorDomain const MobaProfileImportTransactionErrorDomain = @"MobaProfileImportTransactionErrorDomain";
NSString *const MobaProfileImportOriginalErrorKey = @"MobaProfileImportOriginalError";
NSString *const MobaProfileImportRollbackErrorKey = @"MobaProfileImportRollbackError";

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
        if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorBackupFailed
            description:@"Unable to finish the profile backup manifest."
            underlying:jsonError ?: writeError];
        return nil;
    }
    return directory;
}

- (void)reportRollbackForPlan:(MobaProfileImportPlan *)plan
                    committed:(BOOL)repositoryCommitted
                 originalError:(NSError *)originalError
                         error:(NSError **)error {
    NSError *repositoryError = nil;
    NSError *storageError = nil;
    BOOL repositoryRestored = !repositoryCommitted ||
        [_repository rollbackImportCandidate:plan.repositoryCandidate error:&repositoryError];
    BOOL storageRestored = plan.destinationPreviouslyExisted
        ? [_store writeData:plan.previousDestinationData toRelativePath:plan.targetRelativePath
             replaceExisting:YES error:&storageError]
        : [_store removeDataAtRelativePath:plan.targetRelativePath error:&storageError];
    if (repositoryRestored && storageRestored) {
        if (error != NULL) *error = originalError;
        return;
    }
    NSError *rollbackError = repositoryError ?: storageError;
    NSMutableDictionary *info = [@{
        NSLocalizedDescriptionKey: @"Profile import failed and restoring the previous active state also failed.",
        MobaProfileImportOriginalErrorKey: originalError,
        MobaProfileImportRollbackErrorKey: rollbackError ?: originalError,
    } mutableCopy];
    info[NSUnderlyingErrorKey] = rollbackError ?: originalError;
    if (error != NULL) *error = [NSError errorWithDomain:MobaProfileImportTransactionErrorDomain
        code:MobaProfileImportTransactionErrorRollbackFailed userInfo:info];
}

- (MobaProfileImportResult *)applyImportPlan:(MobaProfileImportPlan *)plan error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Profile import transactions require the main thread.");
    if (error != NULL) *error = nil;
    if (plan == nil || _repository.activeSnapshot != plan.baseSnapshot) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileImportTransactionErrorStalePlan
            description:@"The active profile snapshot changed. Select the import file again."
            underlying:nil];
        return nil;
    }
    if (![self activeBytesStillMatchPlan:plan error:error]) return nil;

    BOOL repositoryCommitted = NO;
    [_lifecycle profileWillReload];
    @try {
        NSError *stepError = nil;
        NSString *backupPath = [self createBackupForPlan:plan error:&stepError];
        if (backupPath == nil) {
            if (error != NULL) *error = stepError;
            return nil;
        }
        if (![_store writeData:plan.importData toRelativePath:plan.targetRelativePath
               replaceExisting:plan.destinationPreviouslyExisted error:&stepError]) {
            NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorPersistenceFailed
                description:@"Unable to atomically replace the imported profile destination."
                underlying:stepError];
            [self reportRollbackForPlan:plan committed:NO originalError:importError error:error];
            return nil;
        }
        if (![_repository commitImportCandidate:plan.repositoryCandidate error:&stepError]) {
            NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorRepositoryCommitFailed
                description:@"The exact-base imported snapshot could not be committed."
                underlying:stepError];
            [self reportRollbackForPlan:plan committed:NO originalError:importError error:error];
            return nil;
        }
        repositoryCommitted = YES;
        NSString *activeChampionPath = [plan.profileKind isEqualToString:MobaProfileKindChampion]
            ? plan.targetRelativePath : plan.activeChampionRelativePath;
        if (![_installer installImportedProfileSnapshot:plan.repositoryCandidate.snapshot
            runtime:plan.runtime skillControlPackage:plan.skillControlPackage
            championRelativePath:activeChampionPath error:&stepError]) {
            NSError *importError = [self errorWithCode:MobaProfileImportTransactionErrorRuntimeInstallFailed
                description:@"The imported runtime and controls could not be installed."
                underlying:stepError];
            [self reportRollbackForPlan:plan committed:repositoryCommitted originalError:importError error:error];
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
        [self reportRollbackForPlan:plan committed:repositoryCommitted originalError:importError error:error];
        return nil;
    }
    @finally {
        [_lifecycle profileDidReload];
    }
}

@end
