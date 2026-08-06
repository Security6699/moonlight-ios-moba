//
//  MobaProfileTransferServiceTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Profiles/MobaProfileTransferService.h"
#import "../Limelight/Input/MOBA/Profiles/MobaProfileImportTransaction.h"
#import "../Limelight/Input/MOBA/Controls/MobaProfileTransferViewController.h"

@interface MobaTransferNoopResources : NSObject <MobaProfileResourceProviding>
@end

@interface MobaTransferMemoryStore : MobaProfileStore
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *files;
@property (nonatomic, strong) NSMutableArray<NSString *> *operations;
@property (nonatomic, copy, nullable) NSString *failWritePath;
@property (nonatomic, copy, nullable) NSString *failRemovePath;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *writeCounts;
@property (nonatomic, copy) NSDictionary<NSString *, NSSet<NSNumber *> *> *failedWriteOrdinals;
@end
@interface MobaTransferFakeRuntimeBuilder : NSObject <MobaChampionRuntimeBuilding>
@property (nonatomic) BOOL fail;
@property (nonatomic) NSUInteger buildCount;
@end
@interface MobaTransferFakePackage : NSObject
@property (nonatomic, getter=isComplete) BOOL complete;
@property (nonatomic) NSUInteger resetCount;
@end
@interface MobaTransferFakePackageBuilder : NSObject <MobaSkillControlPackageBuilding>
@property (nonatomic) BOOL fail;
@property (nonatomic) NSUInteger buildCount;
@end
@interface MobaTransferFakeRepository : MobaProfileRepository
@property (nonatomic) BOOL failCommit;
@property (nonatomic) BOOL failRollback;
@property (nonatomic) NSUInteger commitCount;
@property (nonatomic) NSUInteger rollbackCount;
@end
@interface MobaTransferFakeLifecycle : NSObject <MobaProfileImportLifecycle>
@property (nonatomic) NSUInteger willCount;
@property (nonatomic) NSUInteger didCount;
@end
@interface MobaTransferFakeInstaller : NSObject <MobaProfileImportInstalling>
@property (nonatomic) BOOL fail;
@property (nonatomic) NSUInteger installCount;
@property (nonatomic, copy) NSString *installedChampionPath;
@property (nonatomic, strong) MobaProfileSnapshot *installedSnapshot;
@end
@interface MobaTransferFixedBackupProvider : NSObject <MobaProfileBackupDirectoryNameProviding>
@property (nonatomic) NSUInteger count;
@end

@interface MobaProfileTransferViewControllerTests : XCTestCase
@property (nonatomic, strong) MobaTransferMemoryStore *store;
@property (nonatomic, strong) MobaProfileTransferService *service;
@property (nonatomic, strong) MobaProfileImportTransaction *transaction;
@property (nonatomic, strong) MobaProfileTransferViewController *viewController;
@end

@implementation MobaProfileTransferViewControllerTests
- (NSData *)exampleData:(NSString *)name {
    NSString *tests = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *path = [[tests stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"examples/moba"];
    return [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:name]];
}
- (void)setUp {
    [super setUp];
    self.store = [[MobaTransferMemoryStore alloc] init];
    self.store.files[MobaRuntimeProfileRelativePath] = [self exampleData:@"runtime.json"];
    self.store.files[MobaInputProfileRelativePath] = [self exampleData:@"input.json"];
    self.store.files[MobaActiveLayoutProfileRelativePath] = [self exampleData:@"ipad-pro-13-layout.json"];
    self.store.files[@"champions/caitlyn.json"] = [self exampleData:@"caitlyn.json"];
    MobaTransferFakeRepository *repository = [[MobaTransferFakeRepository alloc] initWithStore:self.store];
    XCTAssertTrue([repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    self.service = [[MobaProfileTransferService alloc] initWithStore:self.store repository:repository
        runtimeBuilder:[[MobaTransferFakeRuntimeBuilder alloc] init]
        controlPackageBuilder:[[MobaTransferFakePackageBuilder alloc] init]];
    self.transaction = [[MobaProfileImportTransaction alloc] initWithStore:self.store repository:repository
        lifecycle:[[MobaTransferFakeLifecycle alloc] init] installer:[[MobaTransferFakeInstaller alloc] init]
        backupDirectoryProvider:[[MobaTransferFixedBackupProvider alloc] init]];
    self.viewController = [[MobaProfileTransferViewController alloc]
        initWithTransferService:self.service importTransaction:self.transaction
        activeChampionRelativePath:@"champions/caitlyn.json"];
    [self.store.operations removeAllObjects];
}
- (void)testWrongFileNameStillPreviewsByContent {
    MobaProfileImportPlan *plan = [self.viewController prepareImportFromData:[self exampleData:@"input.json"]
        sourceFileName:@"definitely-a-layout.json" error:nil];
    XCTAssertEqualObjects(plan.profileKind, MobaProfileKindInput);
}
- (void)testCancelClearsPlanWithoutWriting {
    XCTAssertNotNil([self.viewController prepareImportFromData:[self exampleData:@"input.json"]
        sourceFileName:nil error:nil]);
    [self.viewController cancelPendingTransfer];
    XCTAssertNil(self.viewController.pendingImportPlan);
    XCTAssertFalse([[self.store.operations componentsJoinedByString:@" "] containsString:@"write:"]);
}
- (void)testConfirmationDelegatesToTransaction {
    XCTAssertNotNil([self.viewController prepareImportFromData:[self exampleData:@"input.json"]
        sourceFileName:nil error:nil]);
    XCTAssertNotNil([self.viewController confirmPendingImportWithError:nil]);
    XCTAssertNil(self.viewController.pendingImportPlan);
}
- (void)testTemporaryExportUsesRawBytesAndCleanup {
    NSURL *url = [self.viewController prepareTemporaryExportForProfileKind:MobaProfileKindRuntime error:nil];
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:url], self.store.files[MobaRuntimeProfileRelativePath]);
    [self.viewController cleanupTemporaryExport];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:url.path]);
}
- (void)testRepeatedTemporaryExportCleansPreviousDirectory {
    NSURL *first = [self.viewController prepareTemporaryExportForProfileKind:MobaProfileKindRuntime error:nil];
    NSURL *second = [self.viewController prepareTemporaryExportForProfileKind:MobaProfileKindInput error:nil];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:first.path]);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:second.path]);
    [self.viewController cleanupTemporaryExport];
}
@end

@implementation MobaTransferFakeRepository
- (BOOL)commitImportCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    self.commitCount += 1;
    if (self.failCommit) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Repository" code:1 userInfo:nil];
        return NO;
    }
    return [super commitImportCandidate:candidate error:error];
}
- (BOOL)rollbackImportCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    self.rollbackCount += 1;
    if (self.failRollback) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Repository" code:2 userInfo:nil];
        return NO;
    }
    return [super rollbackImportCandidate:candidate error:error];
}
@end

@implementation MobaTransferFakeLifecycle
- (void)profileWillReload { self.willCount += 1; }
- (void)profileDidReload { self.didCount += 1; }
@end

@implementation MobaTransferFakeInstaller
- (BOOL)installImportedProfileSnapshot:(MobaProfileSnapshot *)snapshot
                                runtime:(MobaChampionRuntime *)runtime
                    skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                 championRelativePath:(NSString *)championRelativePath
                                  error:(NSError **)error {
    (void)runtime; (void)skillControlPackage;
    self.installCount += 1;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Installer" code:1 userInfo:nil];
        return NO;
    }
    self.installedSnapshot = snapshot;
    self.installedChampionPath = championRelativePath;
    return YES;
}
@end

@implementation MobaTransferFixedBackupProvider
- (NSString *)nextBackupDirectoryName {
    self.count += 1;
    return [NSString stringWithFormat:@"fixed-%lu", (unsigned long)self.count];
}
@end

@interface MobaProfileImportTransactionTests : XCTestCase
@property (nonatomic, strong) MobaTransferMemoryStore *store;
@property (nonatomic, strong) MobaTransferFakeRepository *repository;
@property (nonatomic, strong) MobaTransferFakeRuntimeBuilder *runtimeBuilder;
@property (nonatomic, strong) MobaTransferFakePackageBuilder *packageBuilder;
@property (nonatomic, strong) MobaProfileTransferService *service;
@property (nonatomic, strong) MobaTransferFakeLifecycle *lifecycle;
@property (nonatomic, strong) MobaTransferFakeInstaller *installer;
@property (nonatomic, strong) MobaTransferFixedBackupProvider *backupProvider;
@property (nonatomic, strong) MobaProfileImportTransaction *transaction;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *originalFiles;
@end

@implementation MobaProfileImportTransactionTests

- (NSData *)exampleData:(NSString *)name {
    NSString *tests = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *path = [[tests stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"examples/moba"];
    return [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:name]];
}
- (NSMutableDictionary *)mutableJSONFromData:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
}
- (NSData *)dataFromJSON:(NSDictionary *)json {
    return [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingSortedKeys error:nil];
}
- (void)setUp {
    [super setUp];
    self.store = [[MobaTransferMemoryStore alloc] init];
    self.originalFiles = @{
        MobaRuntimeProfileRelativePath: [self exampleData:@"runtime.json"],
        MobaInputProfileRelativePath: [self exampleData:@"input.json"],
        MobaActiveLayoutProfileRelativePath: [self exampleData:@"ipad-pro-13-layout.json"],
        @"champions/caitlyn.json": [self exampleData:@"caitlyn.json"],
    };
    [self.store.files addEntriesFromDictionary:self.originalFiles];
    self.repository = [[MobaTransferFakeRepository alloc] initWithStore:self.store];
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    self.runtimeBuilder = [[MobaTransferFakeRuntimeBuilder alloc] init];
    self.packageBuilder = [[MobaTransferFakePackageBuilder alloc] init];
    self.service = [[MobaProfileTransferService alloc] initWithStore:self.store
        repository:self.repository runtimeBuilder:self.runtimeBuilder
        controlPackageBuilder:self.packageBuilder];
    self.lifecycle = [[MobaTransferFakeLifecycle alloc] init];
    self.installer = [[MobaTransferFakeInstaller alloc] init];
    self.backupProvider = [[MobaTransferFixedBackupProvider alloc] init];
    self.transaction = [[MobaProfileImportTransaction alloc] initWithStore:self.store
        repository:self.repository lifecycle:self.lifecycle installer:self.installer
        backupDirectoryProvider:self.backupProvider];
    [self.store.operations removeAllObjects];
    [self.store.writeCounts removeAllObjects];
}

- (MobaProfileImportPlan *)runtimePlan {
    NSMutableDictionary *json = [self mutableJSONFromData:self.originalFiles[MobaRuntimeProfileRelativePath]];
    json[@"globalOpacityMultiplier"] = @0.73;
    json[@"futureRoot"] = @{@"preserved": @YES};
    return [self.service prepareImportPlanForData:[self dataFromJSON:json]
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
}

- (MobaProfileImportPlan *)newChampionPlan {
    NSMutableDictionary *json = [self mutableJSONFromData:self.originalFiles[@"champions/caitlyn.json"]];
    json[@"championId"] = @"imported";
    json[@"displayName"] = @"Imported";
    return [self.service prepareImportPlanForData:[self dataFromJSON:json]
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
}

- (MobaProfileImportResult *)apply:(MobaProfileImportPlan *)plan error:(NSError **)error {
    return [self.transaction applyImportPlan:plan error:error];
}

- (void)testBackupFilesPrecedeTargetWrite {
    MobaProfileImportPlan *plan = [self runtimePlan];
    XCTAssertNotNil([self apply:plan error:nil]);
    NSUInteger target = [self.store.operations indexOfObject:@"write:runtime.json"];
    XCTAssertTrue([self.store.operations indexOfObject:@"write:backups/fixed-1/manifest.json"] < target);
}

- (void)testFirstBackupFailureLeavesActiveBytesUnchanged {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.store.failWritePath = @"backups/fixed-1/runtime.json";
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqualObjects(self.store.files[MobaRuntimeProfileRelativePath], self.originalFiles[MobaRuntimeProfileRelativePath]);
}

- (void)testMiddleBackupFailureLeavesActiveBytesUnchanged {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.store.failWritePath = @"backups/fixed-1/input.json";
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqualObjects(self.store.files[MobaRuntimeProfileRelativePath], self.originalFiles[MobaRuntimeProfileRelativePath]);
}

- (void)testTargetWriteFailurePreservesSnapshotIdentity {
    MobaProfileImportPlan *plan = [self runtimePlan];
    MobaProfileSnapshot *before = self.repository.activeSnapshot;
    self.store.failedWriteOrdinals = @{MobaRuntimeProfileRelativePath: [NSSet setWithObject:@1]};
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertTrue(self.repository.activeSnapshot == before);
}

- (void)testRepositoryCommitFailureRestoresOldBytes {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.repository.failCommit = YES;
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqualObjects(self.store.files[MobaRuntimeProfileRelativePath], self.originalFiles[MobaRuntimeProfileRelativePath]);
}

- (void)testInstallerFailureRestoresBytesAndSnapshot {
    MobaProfileImportPlan *plan = [self runtimePlan];
    MobaProfileSnapshot *before = self.repository.activeSnapshot;
    self.installer.fail = YES;
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqualObjects(self.store.files[MobaRuntimeProfileRelativePath], self.originalFiles[MobaRuntimeProfileRelativePath]);
    XCTAssertTrue(self.repository.activeSnapshot == before);
}

- (void)testRollbackFailurePreservesOriginalAndRollbackErrors {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.installer.fail = YES;
    self.repository.failRollback = YES;
    NSError *error = nil;
    XCTAssertNil([self apply:plan error:&error]);
    XCTAssertEqual(error.code, MobaProfileImportTransactionErrorRollbackFailed);
    XCTAssertNotNil(error.userInfo[MobaProfileImportOriginalErrorKey]);
    XCTAssertNotNil(error.userInfo[MobaProfileImportRollbackErrorKey]);
}

- (void)testSuccessfulImportCommitsRepositoryOnce {
    XCTAssertNotNil([self apply:[self runtimePlan] error:nil]);
    XCTAssertEqual(self.repository.commitCount, 1u);
}

- (void)testSuccessfulImportInstallsOnce {
    XCTAssertNotNil([self apply:[self runtimePlan] error:nil]);
    XCTAssertEqual(self.installer.installCount, 1u);
}

- (void)testSuccessfulImportCreatesUniqueBackupDirectory {
    MobaProfileImportResult *result = [self apply:[self runtimePlan] error:nil];
    XCTAssertEqualObjects(result.backupRelativePath, @"backups/fixed-1");
    XCTAssertEqual(self.backupProvider.count, 1u);
}

- (void)testSuccessfulImportPersistsUnknownFields {
    MobaProfileImportPlan *plan = [self runtimePlan];
    XCTAssertNotNil([self apply:plan error:nil]);
    XCTAssertEqualObjects(self.store.files[MobaRuntimeProfileRelativePath], plan.importData);
}

- (void)testExportImportExportKeepsEquivalentJSON {
    MobaProfileImportPlan *plan = [self runtimePlan];
    XCTAssertNotNil([self apply:plan error:nil]);
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindRuntime
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertEqualObjects([NSJSONSerialization JSONObjectWithData:payload.data options:0 error:nil],
                          [NSJSONSerialization JSONObjectWithData:plan.importData options:0 error:nil]);
}

- (void)testUnreplacedProfileBytesRemainExact {
    XCTAssertNotNil([self apply:[self runtimePlan] error:nil]);
    XCTAssertEqualObjects(self.store.files[MobaInputProfileRelativePath], self.originalFiles[MobaInputProfileRelativePath]);
    XCTAssertEqualObjects(self.store.files[MobaActiveLayoutProfileRelativePath], self.originalFiles[MobaActiveLayoutProfileRelativePath]);
    XCTAssertEqualObjects(self.store.files[@"champions/caitlyn.json"], self.originalFiles[@"champions/caitlyn.json"]);
}

- (void)testSameChampionReplacementSucceeds {
    MobaProfileImportPlan *plan = [self.service prepareImportPlanForData:self.originalFiles[@"champions/caitlyn.json"]
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertNotNil([self apply:plan error:nil]);
    XCTAssertEqualObjects(self.installer.installedChampionPath, @"champions/caitlyn.json");
}

- (void)testNewChampionSwitchesActivePath {
    MobaProfileImportResult *result = [self apply:[self newChampionPlan] error:nil];
    XCTAssertEqualObjects(result.activeChampionRelativePath, @"champions/imported.json");
    XCTAssertEqualObjects(self.installer.installedChampionPath, @"champions/imported.json");
}

- (void)testExistingChampionDestinationIsBackedUp {
    self.store.files[@"champions/imported.json"] = [@"old-target" dataUsingEncoding:NSUTF8StringEncoding];
    MobaProfileImportPlan *plan = [self newChampionPlan];
    XCTAssertNotNil([self apply:plan error:nil]);
    XCTAssertNotNil(self.store.files[@"backups/fixed-1/target-champion.json"]);
}

- (void)testNewChampionFailureRemovesNewFile {
    MobaProfileImportPlan *plan = [self newChampionPlan];
    self.installer.fail = YES;
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertNil(self.store.files[@"champions/imported.json"]);
}

- (void)testStaleSnapshotPlanIsRejectedBeforeLifecycle {
    MobaProfileImportPlan *plan = [self runtimePlan];
    MobaProfileRepositoryCandidate *other = [self.repository prepareImportCandidateWithProfileKind:MobaProfileKindInput
        data:self.originalFiles[MobaInputProfileRelativePath] error:nil];
    XCTAssertTrue([self.repository commitImportCandidate:other error:nil]);
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqual(self.lifecycle.willCount, 0u);
}

- (void)testChangedActiveBytesRejectPlanBeforeLifecycle {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.store.files[MobaInputProfileRelativePath] = [@"changed" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqual(self.lifecycle.willCount, 0u);
}

- (void)testLifecycleBoundaryPairsOnSuccess {
    XCTAssertNotNil([self apply:[self runtimePlan] error:nil]);
    XCTAssertEqual(self.lifecycle.willCount, 1u);
    XCTAssertEqual(self.lifecycle.didCount, 1u);
}

- (void)testLifecycleBoundaryPairsOnBackupFailure {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.store.failWritePath = @"backups/fixed-1/runtime.json";
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqual(self.lifecycle.willCount, 1u);
    XCTAssertEqual(self.lifecycle.didCount, 1u);
}

- (void)testManifestRecordsDestinationExistence {
    XCTAssertNotNil([self apply:[self runtimePlan] error:nil]);
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:
        self.store.files[@"backups/fixed-1/manifest.json"] options:0 error:nil];
    XCTAssertEqualObjects(manifest[@"destinationPreviouslyExisted"], @YES);
}

- (void)testManifestRecordsSelectedChampionAndPath {
    XCTAssertNotNil([self apply:[self runtimePlan] error:nil]);
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:
        self.store.files[@"backups/fixed-1/manifest.json"] options:0 error:nil];
    XCTAssertEqualObjects(manifest[@"selectedChampionIdBeforeImport"], @"caitlyn");
    XCTAssertEqualObjects(manifest[@"activeChampionRelativePath"], @"champions/caitlyn.json");
}

- (void)testNoRepositoryCommitOccursWhenBackupFails {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.store.failWritePath = @"backups/fixed-1/manifest.json";
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqual(self.repository.commitCount, 0u);
}

- (void)testNoInstallerOccursWhenRepositoryCommitFails {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.repository.failCommit = YES;
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertEqual(self.installer.installCount, 0u);
}

- (void)testRollbackWriteFailureIsReportedSeparately {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.installer.fail = YES;
    self.store.failedWriteOrdinals = @{MobaRuntimeProfileRelativePath: [NSSet setWithObject:@2]};
    NSError *error = nil;
    XCTAssertNil([self apply:plan error:&error]);
    XCTAssertEqual(error.code, MobaProfileImportTransactionErrorRollbackFailed);
}

@end
@implementation MobaTransferNoopResources
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)extension {
    (void)name; (void)extension; return nil;
}
@end

@implementation MobaTransferMemoryStore
- (instancetype)init {
    self = [super initWithRootDirectoryURL:[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                         resourceProvider:[[MobaTransferNoopResources alloc] init]
                              fileManager:NSFileManager.defaultManager];
    if (self) {
        _files = [NSMutableDictionary dictionary];
        _operations = [NSMutableArray array];
        _writeCounts = [NSMutableDictionary dictionary];
        _failedWriteOrdinals = @{};
    }
    return self;
}
- (NSData *)readDataAtRelativePath:(NSString *)path error:(NSError **)error {
    [self.operations addObject:[@"read:" stringByAppendingString:path]];
    NSData *data = self.files[path];
    if (error != NULL) *error = data == nil ? [NSError errorWithDomain:@"Store" code:1 userInfo:nil] : nil;
    return data;
}
- (BOOL)dataExistsAtRelativePath:(NSString *)path error:(NSError **)error {
    [self.operations addObject:[@"exists:" stringByAppendingString:path]];
    if (error != NULL) *error = nil;
    return self.files[path] != nil;
}
- (BOOL)writeData:(NSData *)data toRelativePath:(NSString *)path
   replaceExisting:(BOOL)replace error:(NSError **)error {
    (void)replace;
    [self.operations addObject:[@"write:" stringByAppendingString:path]];
    NSUInteger ordinal = self.writeCounts[path].unsignedIntegerValue + 1;
    self.writeCounts[path] = @(ordinal);
    if ([path isEqualToString:self.failWritePath] ||
        [self.failedWriteOrdinals[path] containsObject:@(ordinal)]) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Store" code:2 userInfo:nil];
        return NO;
    }
    self.files[path] = [data copy];
    if (error != NULL) *error = nil;
    return YES;
}
- (BOOL)removeDataAtRelativePath:(NSString *)path error:(NSError **)error {
    [self.operations addObject:[@"remove:" stringByAppendingString:path]];
    if ([path isEqualToString:self.failRemovePath]) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Store" code:3 userInfo:nil];
        return NO;
    }
    [self.files removeObjectForKey:path];
    if (error != NULL) *error = nil;
    return YES;
}
@end

@implementation MobaTransferFakeRuntimeBuilder
- (MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot error:(NSError **)error {
    (void)snapshot; self.buildCount += 1;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Runtime" code:1 userInfo:nil];
        return nil;
    }
    return (id)[NSObject new];
}
@end

@implementation MobaTransferFakePackage
- (void)silentResetForReason:(MobaInputInterruptionReason)reason {
    (void)reason; self.resetCount += 1;
}
@end

@implementation MobaTransferFakePackageBuilder
- (MobaSkillControlPackage *)controlPackageForRuntime:(MobaChampionRuntime *)runtime error:(NSError **)error {
    (void)runtime; self.buildCount += 1;
    MobaTransferFakePackage *package = [[MobaTransferFakePackage alloc] init];
    package.complete = !self.fail;
    if (self.fail && error != NULL) *error = [NSError errorWithDomain:@"Package" code:1 userInfo:nil];
    return (id)package;
}
@end

@interface MobaProfileTransferServiceTests : XCTestCase
@property (nonatomic, strong) MobaTransferMemoryStore *store;
@property (nonatomic, strong) MobaProfileRepository *repository;
@property (nonatomic, strong) MobaTransferFakeRuntimeBuilder *runtimeBuilder;
@property (nonatomic, strong) MobaTransferFakePackageBuilder *packageBuilder;
@property (nonatomic, strong) MobaProfileTransferService *service;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *originalFiles;
@end

@implementation MobaProfileTransferServiceTests

- (NSData *)exampleData:(NSString *)name {
    NSString *tests = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *path = [[tests stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"examples/moba"];
    NSData *data = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:name]];
    XCTAssertNotNil(data);
    return data;
}

- (NSMutableDictionary *)mutableJSONFromData:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
}

- (NSData *)dataFromJSON:(NSDictionary *)json {
    return [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingSortedKeys error:nil];
}

- (void)setUp {
    [super setUp];
    self.store = [[MobaTransferMemoryStore alloc] init];
    self.originalFiles = @{
        MobaRuntimeProfileRelativePath: [self exampleData:@"runtime.json"],
        MobaInputProfileRelativePath: [self exampleData:@"input.json"],
        MobaActiveLayoutProfileRelativePath: [self exampleData:@"ipad-pro-13-layout.json"],
        @"champions/caitlyn.json": [self exampleData:@"caitlyn.json"],
    };
    [self.store.files addEntriesFromDictionary:self.originalFiles];
    self.repository = [[MobaProfileRepository alloc] initWithStore:self.store];
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    self.runtimeBuilder = [[MobaTransferFakeRuntimeBuilder alloc] init];
    self.packageBuilder = [[MobaTransferFakePackageBuilder alloc] init];
    self.service = [[MobaProfileTransferService alloc] initWithStore:self.store
        repository:self.repository runtimeBuilder:self.runtimeBuilder
        controlPackageBuilder:self.packageBuilder];
    [self.store.operations removeAllObjects];
}

- (MobaProfileImportPlan *)planForData:(NSData *)data error:(NSError **)error {
    return [self.service prepareImportPlanForData:data
        activeChampionRelativePath:@"champions/caitlyn.json" error:error];
}

- (void)assertKind:(MobaProfileKind)kind file:(NSString *)file {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:file] error:nil];
    XCTAssertEqualObjects(plan.profileKind, kind);
}

- (void)testDetectsRuntimeFromContent { [self assertKind:MobaProfileKindRuntime file:@"runtime.json"]; }
- (void)testDetectsInputFromContent { [self assertKind:MobaProfileKindInput file:@"input.json"]; }
- (void)testDetectsLayoutFromContent { [self assertKind:MobaProfileKindLayout file:@"ipad-pro-13-layout.json"]; }
- (void)testDetectsChampionFromContent { [self assertKind:MobaProfileKindChampion file:@"caitlyn.json"]; }

- (void)testFileNameIsNotPartOfDetection {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:@"input.json"] error:nil];
    XCTAssertEqualObjects(plan.profileKind, MobaProfileKindInput);
}

- (void)testMalformedJSONReportsRootPath {
    NSError *error = nil;
    XCTAssertNil([self planForData:[@"{" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$");
}

- (void)testArrayRootIsRejected {
    NSError *error = nil;
    XCTAssertNil([self planForData:[@"[]" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
    XCTAssertEqual(error.code, MobaProfileErrorRootTypeMismatch);
}

- (void)testUnknownTypeReportsRootPath {
    NSError *error = nil;
    XCTAssertNil([self planForData:[@"{\"schemaVersion\":1}" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
    XCTAssertEqual(error.code, MobaProfileErrorUnknownProfileType);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$");
}

- (void)testAmbiguousTypeReportsRootPath {
    NSError *error = nil;
    NSData *data = [@"{\"schemaVersion\":1,\"canvas\":{},\"skills\":{}}" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNil([self planForData:data error:&error]);
    XCTAssertEqual(error.code, MobaProfileErrorAmbiguousProfileType);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$");
}

- (void)testMissingRuntimeFieldKeepsDecoderPath {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"runtime.json"]];
    [json removeObjectForKey:@"canvas"];
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.canvas");
}

- (void)testInvalidEnumKeepsDecoderPath {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"runtime.json"]];
    json[@"videoMode"] = @"stretch";
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.videoMode");
}

- (void)testUnsupportedSchemaKeepsMigrationError {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"input.json"]];
    json[@"schemaVersion"] = @99;
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqual(error.code, MobaProfileErrorUnsupportedSchemaVersion);
}

- (void)testPreviewDoesNotWriteStore {
    XCTAssertNotNil([self planForData:[self exampleData:@"runtime.json"] error:nil]);
    NSPredicate *writes = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'write:'"];
    XCTAssertEqual([[self.store.operations filteredArrayUsingPredicate:writes] count], 0u);
}

- (void)testPreviewPreservesActiveSnapshotIdentity {
    MobaProfileSnapshot *before = self.repository.activeSnapshot;
    XCTAssertNotNil([self planForData:[self exampleData:@"input.json"] error:nil]);
    XCTAssertTrue(self.repository.activeSnapshot == before);
}

- (void)testPreviewBuildsRuntimeOnce {
    XCTAssertNotNil([self planForData:[self exampleData:@"runtime.json"] error:nil]);
    XCTAssertEqual(self.runtimeBuilder.buildCount, 1u);
}

- (void)testPreviewBuildsPackageOnce {
    XCTAssertNotNil([self planForData:[self exampleData:@"runtime.json"] error:nil]);
    XCTAssertEqual(self.packageBuilder.buildCount, 1u);
}

- (void)testRuntimeSummaryContainsRequiredFields {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:@"runtime.json"] error:nil];
    NSString *summary = [plan.summaryLines componentsJoinedByString:@" "];
    XCTAssertTrue([summary containsString:@"Runtime"]);
    XCTAssertTrue([summary containsString:@"Schema Version"]);
    XCTAssertTrue([summary containsString:@"runtime.json"]);
}

- (void)testInputSummaryContainsIdentifier {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:@"input.json"] error:nil];
    XCTAssertTrue([[plan.summaryLines componentsJoinedByString:@" "] containsString:plan.profileIdentifier]);
}

- (void)testLayoutSummaryContainsControlCount {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:@"ipad-pro-13-layout.json"] error:nil];
    XCTAssertTrue([[plan.summaryLines componentsJoinedByString:@" "] containsString:@"Control Count"]);
}

- (void)testChampionSummaryContainsCastTypes {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:@"caitlyn.json"] error:nil];
    XCTAssertTrue([[plan.summaryLines componentsJoinedByString:@" "] containsString:@"Cast Types"]);
}

- (void)testRuntimeExportMatchesRawBytes {
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindRuntime
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertEqualObjects(payload.data, self.originalFiles[MobaRuntimeProfileRelativePath]);
}

- (void)testInputExportMatchesRawBytes {
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindInput
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertEqualObjects(payload.data, self.originalFiles[MobaInputProfileRelativePath]);
}

- (void)testLayoutExportMatchesRawBytes {
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindLayout
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertEqualObjects(payload.data, self.originalFiles[MobaActiveLayoutProfileRelativePath]);
}

- (void)testChampionExportMatchesRawBytes {
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindChampion
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertEqualObjects(payload.data, self.originalFiles[@"champions/caitlyn.json"]);
}

- (void)testExportPreservesUnknownFields {
    NSMutableDictionary *json = [self mutableJSONFromData:self.originalFiles[MobaInputProfileRelativePath]];
    json[@"future"] = @{@"nested": @[@1, @2]};
    NSData *bytes = [self dataFromJSON:json];
    self.store.files[MobaInputProfileRelativePath] = bytes;
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindInput
        activeChampionRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertEqualObjects(payload.data, bytes);
}

- (void)testExportFileComponentIsSafe {
    XCTAssertEqualObjects([MobaProfileTransferService safeExportFileComponent:@"a/../b c"], @"a-b-c");
}

- (void)testExportFileNameUsesSanitizedIdentifier {
    XCTAssertEqualObjects([MobaProfileTransferService safeExportFileComponent:@"../../"], @"profile");
}

- (void)testMissingExportFileReportsReadOperation {
    [self.store.files removeObjectForKey:MobaRuntimeProfileRelativePath];
    NSError *error = nil;
    XCTAssertNil([self.service exportPayloadForProfileKind:MobaProfileKindRuntime
        activeChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorOperationKey], @"read-active-profile");
}

- (void)testChampionPathUsesValidatedIdentifier {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"championId"] = @"new-champion";
    MobaProfileImportPlan *plan = [self planForData:[self dataFromJSON:json] error:nil];
    XCTAssertEqualObjects(plan.targetRelativePath, @"champions/new-champion.json");
}

- (void)testChampionPathTraversalIsRejected {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"championId"] = @"../new";
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.championId");
}

- (void)testNewChampionPlanDeclaresActiveSwitch {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"championId"] = @"new-champion";
    MobaProfileImportPlan *plan = [self planForData:[self dataFromJSON:json] error:nil];
    XCTAssertTrue(plan.switchesActiveChampion);
}

- (void)testSameChampionPlanDoesNotDeclareSwitch {
    MobaProfileImportPlan *plan = [self planForData:[self exampleData:@"caitlyn.json"] error:nil];
    XCTAssertFalse(plan.switchesActiveChampion);
}

- (void)testIncompatibleChampionActionFailsBeforeWrite {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"skills"][@"Q"][@"inputAction"] = @"missing";
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.skills.Q.inputAction");
    XCTAssertFalse([[self.store.operations componentsJoinedByString:@" "] containsString:@"write:"]);
}

- (void)testRuntimeBuildFailureDoesNotWrite {
    self.runtimeBuilder.fail = YES;
    XCTAssertNil([self planForData:[self exampleData:@"runtime.json"] error:nil]);
    XCTAssertFalse([[self.store.operations componentsJoinedByString:@" "] containsString:@"write:"]);
}

- (void)testPackageBuildFailureDoesNotWrite {
    self.packageBuilder.fail = YES;
    XCTAssertNil([self planForData:[self exampleData:@"runtime.json"] error:nil]);
    XCTAssertFalse([[self.store.operations componentsJoinedByString:@" "] containsString:@"write:"]);
}

- (void)testImportPlanCopiesRawBytes {
    NSMutableData *bytes = [[self exampleData:@"runtime.json"] mutableCopy];
    MobaProfileImportPlan *plan = [self planForData:bytes error:nil];
    NSData *saved = plan.importData;
    [bytes resetBytesInRange:NSMakeRange(0, bytes.length)];
    XCTAssertFalse([saved isEqualToData:bytes]);
}

@end
