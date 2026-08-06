//
//  MobaProfileTransferServiceTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Profiles/MobaProfileTransferService.h"
#import "../Limelight/Input/MOBA/Profiles/MobaProfileImportTransaction.h"
#import "../Limelight/Input/MOBA/Controls/MobaProfileTransferViewController.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaInputSink.h"

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
@interface MobaTransferFakeRuntime : NSObject
@property (nonatomic, copy) NSString *championID;
@property (nonatomic, copy) NSArray<id<MobaLocalInteractionResetParticipant>> *localInteractionResetParticipants;
@end
@interface MobaTransferFakePackage : NSObject
@property (nonatomic, getter=isComplete) BOOL complete;
@property (nonatomic) NSUInteger resetCount;
@property (nonatomic, copy) NSArray<id<MobaLocalInteractionResetParticipant>> *localInteractionResetParticipants;
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
@property (nonatomic) BOOL failPrepare;
@property (nonatomic) BOOL failRollback;
@property (nonatomic) NSUInteger installCount;
@property (nonatomic) NSUInteger rollbackCount;
@property (nonatomic, copy) NSString *installedChampionPath;
@property (nonatomic, strong) MobaProfileSnapshot *installedSnapshot;
@property (nonatomic, copy) NSString *preparedChampionPath;
@property (nonatomic, strong) MobaProfileSnapshot *preparedSnapshot;
@end
@interface MobaTransferFixedBackupProvider : NSObject <MobaProfileBackupDirectoryNameProviding>
@property (nonatomic) NSUInteger count;
@end
@interface MobaTransferViewControllerDelegate : NSObject <MobaProfileTransferViewControllerDelegate>
@property (nonatomic) NSUInteger closeCount;
@property (nonatomic) NSUInteger importCount;
@property (nonatomic, strong, nullable) MobaProfileTransferViewController *retainedController;
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
- (void)testInteractiveDismissalClearsPendingPlanAndTemporaryExport {
    XCTAssertNotNil([self.viewController prepareImportFromData:[self exampleData:@"input.json"]
        sourceFileName:nil error:nil]);
    NSURL *url = [self.viewController prepareTemporaryExportForProfileKind:MobaProfileKindRuntime error:nil];
    MobaTransferViewControllerDelegate *delegate = [[MobaTransferViewControllerDelegate alloc] init];
    delegate.retainedController = self.viewController;
    self.viewController.delegate = delegate;
    [self.viewController presentationControllerDidDismiss:nil];
    XCTAssertNil(self.viewController.pendingImportPlan);
    XCTAssertNil(self.viewController.temporaryExportURL);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:url.path]);
    XCTAssertNil(delegate.retainedController);
    XCTAssertEqual(delegate.closeCount, 1u);
}
- (void)testRepeatedInteractiveDismissalIsIdempotent {
    MobaTransferViewControllerDelegate *delegate = [[MobaTransferViewControllerDelegate alloc] init];
    self.viewController.delegate = delegate;
    [self.viewController presentationControllerDidDismiss:nil];
    [self.viewController presentationControllerDidDismiss:nil];
    XCTAssertEqual(delegate.closeCount, 1u);
}
- (void)testExplicitCloseAndDismissalNotifyOnce {
    MobaTransferViewControllerDelegate *delegate = [[MobaTransferViewControllerDelegate alloc] init];
    self.viewController.delegate = delegate;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.viewController performSelector:@selector(closeTapped)];
#pragma clang diagnostic pop
    [self.viewController presentationControllerDidDismiss:nil];
    XCTAssertEqual(delegate.closeCount, 1u);
}
- (void)testPickerCancelDoesNotCloseProfileManager {
    MobaTransferViewControllerDelegate *delegate = [[MobaTransferViewControllerDelegate alloc] init];
    self.viewController.delegate = delegate;
    [self.viewController documentPickerWasCancelled:nil];
    XCTAssertEqual(delegate.closeCount, 0u);
}
- (void)testDismissalAllowsDelegateToOpenAnotherController {
    MobaTransferViewControllerDelegate *delegate = [[MobaTransferViewControllerDelegate alloc] init];
    delegate.retainedController = self.viewController;
    self.viewController.delegate = delegate;
    [self.viewController presentationControllerDidDismiss:nil];
    XCTAssertNil(delegate.retainedController);
    delegate.retainedController = [[MobaProfileTransferViewController alloc]
        initWithTransferService:self.service importTransaction:self.transaction
        activeChampionRelativePath:@"champions/caitlyn.json"];
    XCTAssertNotNil(delegate.retainedController);
}
@end

@implementation MobaTransferViewControllerDelegate
- (void)mobaProfileTransferViewControllerDidRequestClose:(MobaProfileTransferViewController *)controller {
    self.closeCount += 1;
    if (self.retainedController == controller) self.retainedController = nil;
}
- (void)mobaProfileTransferViewController:(MobaProfileTransferViewController *)controller
              didImportActiveChampionPath:(NSString *)activeChampionRelativePath {
    (void)controller; (void)activeChampionRelativePath;
    self.importCount += 1;
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
- (MobaPreparedProfileInstallation *)prepareInstallationForSnapshot:(MobaProfileSnapshot *)snapshot
                                                              runtime:(MobaChampionRuntime *)runtime
                                                  skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                                               championRelativePath:(NSString *)championRelativePath
                                                               error:(NSError **)error {
    (void)runtime; (void)skillControlPackage;
    if (self.failPrepare) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Installer" code:1 userInfo:nil];
        return nil;
    }
    self.preparedSnapshot = snapshot;
    self.preparedChampionPath = championRelativePath;
    return [[MobaPreparedProfileInstallation alloc] init];
}
- (BOOL)commitPreparedInstallation:(MobaPreparedProfileInstallation *)installation error:(NSError **)error {
    (void)installation;
    self.installCount += 1;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Installer" code:2 userInfo:nil];
        return NO;
    }
    self.installedSnapshot = self.preparedSnapshot;
    self.installedChampionPath = self.preparedChampionPath;
    return YES;
}
- (BOOL)rollbackPreparedInstallation:(MobaPreparedProfileInstallation *)installation error:(NSError **)error {
    (void)installation;
    self.rollbackCount += 1;
    if (self.failRollback) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Installer" code:3 userInfo:nil];
        return NO;
    }
    self.installedSnapshot = nil;
    self.installedChampionPath = nil;
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

- (MobaProfileImportPlan *)championPlanWithIdentifier:(NSString *)identifier {
    NSMutableDictionary *json = [self mutableJSONFromData:self.originalFiles[@"champions/caitlyn.json"]];
    json[@"championId"] = identifier;
    json[@"displayName"] = identifier;
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

- (void)testPartialBackupDirectoryIsRemovedWhenManifestWasNotCompleted {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.store.failWritePath = @"backups/fixed-1/input.json";
    XCTAssertNil([self apply:plan error:nil]);
    XCTAssertFalse([[self.store.files.allKeys componentsJoinedByString:@" "]
        containsString:@"backups/fixed-1/"]);
    XCTAssertTrue([self.store.operations containsObject:@"remove-directory:backups/fixed-1"]);
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

- (void)testInstallerRollbackFailureIsRecordedIndependently {
    MobaProfileImportPlan *plan = [self runtimePlan];
    self.installer.fail = YES;
    self.installer.failRollback = YES;
    NSError *error = nil;
    XCTAssertNil([self apply:plan error:&error]);
    XCTAssertEqual(error.code, MobaProfileImportTransactionErrorRollbackFailed);
    XCTAssertNotNil(error.userInfo[MobaProfileImportInstallerRollbackErrorKey]);
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

- (void)testUnsafeChampionIdentifierExportImportExportKeepsEquivalentJSON {
    MobaProfileImportPlan *plan = [self championPlanWithIdentifier:@"Kai'Sa"];
    MobaProfileImportResult *result = [self apply:plan error:nil];
    XCTAssertNotNil(result);
    MobaProfileExportPayload *payload = [self.service exportPayloadForProfileKind:MobaProfileKindChampion
        activeChampionRelativePath:result.activeChampionRelativePath error:nil];
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
- (BOOL)removeDirectoryAtRelativePath:(NSString *)path error:(NSError **)error {
    [self.operations addObject:[@"remove-directory:" stringByAppendingString:path]];
    NSArray<NSString *> *keys = self.files.allKeys.copy;
    NSString *prefix = [path stringByAppendingString:@"/"];
    for (NSString *key in keys) {
        if ([key hasPrefix:prefix]) [self.files removeObjectForKey:key];
    }
    if (error != NULL) *error = nil;
    return YES;
}
@end

@implementation MobaTransferFakeRuntimeBuilder
- (MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot error:(NSError **)error {
    self.buildCount += 1;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Runtime" code:1 userInfo:nil];
        return nil;
    }
    MobaTransferFakeRuntime *runtime = [[MobaTransferFakeRuntime alloc] init];
    runtime.championID = snapshot.championProfile.championID;
    runtime.localInteractionResetParticipants = @[];
    return (id)runtime;
}
@end

@implementation MobaTransferFakeRuntime
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

@interface MobaTransferRecordingSink : NSObject <MobaInputSink>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end
@implementation MobaTransferRecordingSink
- (instancetype)init { self = [super init]; if (self) _events = [NSMutableArray array]; return self; }
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    [self.events addObject:[NSString stringWithFormat:@"key:%u:%@", keyCode, down ? @"down" : @"up"]];
}
- (void)moveCursorToCanvasPoint:(CGPoint)point { (void)point; [self.events addObject:@"cursor"]; }
- (void)sendMouseButton:(int)button down:(BOOL)down {
    [self.events addObject:[NSString stringWithFormat:@"mouse:%d:%@", button, down ? @"down" : @"up"]];
}
@end

@interface MobaTransferResetToken : NSObject <MobaLocalInteractionResetParticipant>
@end
@implementation MobaTransferResetToken
- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason { (void)reason; }
@end

@interface MobaTransferInstallerLifecycle : NSObject <MobaChampionSelectionLifecycle>
@property (nonatomic, strong) NSMutableArray *participants;
@property (nonatomic) BOOL failNextRegistration;
@property (nonatomic) NSUInteger registerCount;
@property (nonatomic) NSUInteger unregisterCount;
@end
@implementation MobaTransferInstallerLifecycle
- (instancetype)init { self = [super init]; if (self) _participants = [NSMutableArray array]; return self; }
- (void)profileWillReload {}
- (void)profileDidReload {}
- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    if (self.failNextRegistration) {
        self.failNextRegistration = NO;
        [NSException raise:@"InjectedParticipantRegistrationFailure" format:@"injected"];
    }
    self.registerCount += 1;
    if (participant != nil && ![self.participants containsObject:participant]) [self.participants addObject:participant];
}
- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    self.unregisterCount += 1;
    if (participant != nil) [self.participants removeObject:participant];
}
@end

@interface MobaTransferInstallerHost : NSObject <MobaProfileRuntimeInstallationHost,
                                                 MobaChampionSelectionControllerDelegate>
@property (nonatomic) BOOL profileImportInputSuspended;
@property (nonatomic, strong) MobaChampionSelectionController *profileImportChampionSelectionController;
@property (nonatomic, strong) MobaMovementController *profileImportMovementController;
@property (nonatomic, strong) MobaAttackController *profileImportAttackController;
@property (nonatomic, strong) MobaProfileRepository *repository;
@property (nonatomic, copy) NSString *profileImportActiveChampionRelativePath;
@property (nonatomic, strong) MobaChampionRuntime *installedRuntime;
@property (nonatomic, strong) MobaSkillControlPackage *installedPackage;
@property (nonatomic, strong) MobaProfileSnapshot *presentedSnapshot;
@property (nonatomic) NSUInteger delegateInstallCount;
@property (nonatomic) NSUInteger presentationCount;
@property (nonatomic) BOOL failMovementApply;
@property (nonatomic) BOOL failAttackApply;
@property (nonatomic) BOOL failPresentation;
@property (nonatomic) BOOL throwNextDelegateInstall;
@end
@implementation MobaTransferInstallerHost
- (MobaProfileSnapshot *)profileImportActiveSnapshot { return self.repository.activeSnapshot; }
- (NSError *)injectedError:(NSString *)operation {
    return [NSError errorWithDomain:@"MobaTransferInstallerHost" code:1
        userInfo:@{NSLocalizedDescriptionKey: operation}];
}
- (BOOL)applyProfileImportMovementMapping:(MobaMovementKeyMapping)mapping error:(NSError **)error {
    if (self.failMovementApply) {
        self.failMovementApply = NO;
        if (error != NULL) *error = [self injectedError:@"movement"];
        return NO;
    }
    if (![self.profileImportMovementController canApplyCommittedKeyMapping]) return NO;
    [self.profileImportMovementController applyCommittedKeyMappingAfterPreflight:mapping];
    return YES;
}
- (BOOL)applyProfileImportAttackKeyCode:(uint16_t)attackKeyCode
                           tapDurationMs:(NSUInteger)tapDurationMs error:(NSError **)error {
    if (self.failAttackApply) {
        self.failAttackApply = NO;
        if (error != NULL) *error = [self injectedError:@"attack"];
        return NO;
    }
    if (![self.profileImportAttackController canApplyCommittedAttackProfile]) return NO;
    [self.profileImportAttackController applyCommittedAttackKeyCodeAfterPreflight:attackKeyCode
        tapDurationMs:tapDurationMs];
    return YES;
}
- (void)setProfileImportActiveChampionRelativePath:(NSString *)relativePath {
    _profileImportActiveChampionRelativePath = [relativePath copy];
}
- (BOOL)applyProfileImportPresentationForSnapshot:(MobaProfileSnapshot *)snapshot error:(NSError **)error {
    self.presentationCount += 1;
    if (self.failPresentation) {
        self.failPresentation = NO;
        if (error != NULL) *error = [self injectedError:@"presentation"];
        return NO;
    }
    self.presentedSnapshot = snapshot;
    return YES;
}
- (void)championSelectionController:(MobaChampionSelectionController *)controller
                    didSelectRuntime:(MobaChampionRuntime *)runtime
                 skillControlPackage:(MobaSkillControlPackage *)skillControlPackage {
    (void)controller;
    self.delegateInstallCount += 1;
    self.installedRuntime = runtime;
    self.installedPackage = skillControlPackage;
    if (self.throwNextDelegateInstall) {
        self.throwNextDelegateInstall = NO;
        [NSException raise:@"InjectedViewInstallationFailure" format:@"injected"];
    }
}
@end

@interface MobaProfileRuntimeInstallerTests : XCTestCase
@property (nonatomic, strong) MobaTransferMemoryStore *store;
@property (nonatomic, strong) MobaTransferFakeRepository *repository;
@property (nonatomic, strong) MobaTransferFakeRuntimeBuilder *runtimeBuilder;
@property (nonatomic, strong) MobaTransferFakePackageBuilder *packageBuilder;
@property (nonatomic, strong) MobaProfileTransferService *service;
@property (nonatomic, strong) MobaTransferInstallerLifecycle *selectionLifecycle;
@property (nonatomic, strong) MobaTransferRecordingSink *sink;
@property (nonatomic, strong) MobaTransferInstallerHost *host;
@property (nonatomic, strong) MobaProfileRuntimeInstaller *installer;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *originalFiles;
@end

@implementation MobaProfileRuntimeInstallerTests
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
    self.selectionLifecycle = [[MobaTransferInstallerLifecycle alloc] init];
    MobaChampionSelectionController *selection = [[MobaChampionSelectionController alloc]
        initWithRepository:self.repository runtimeBuilder:self.runtimeBuilder
        controlPackageBuilder:self.packageBuilder lifecycle:self.selectionLifecycle];
    XCTAssertTrue([selection selectChampionID:@"caitlyn" error:nil]);
    self.selectionLifecycle.registerCount = 0;
    self.selectionLifecycle.unregisterCount = 0;
    self.sink = [[MobaTransferRecordingSink alloc] init];
    MobaInputDispatcher *dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink];
    MobaMovementController *movement = [[MobaMovementController alloc]
        initWithInputDispatcher:dispatcher keyMapping:MobaDefaultMovementKeyMapping()
        wheelRadius:95 deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
        directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
    MobaAttackController *attack = [[MobaAttackController alloc] initWithInputDispatcher:dispatcher];
    [movement setInteractionEnabled:NO];
    [attack setInteractionEnabled:NO];
    self.host = [[MobaTransferInstallerHost alloc] init];
    self.host.profileImportInputSuspended = YES;
    self.host.profileImportChampionSelectionController = selection;
    self.host.profileImportMovementController = movement;
    self.host.profileImportAttackController = attack;
    self.host.repository = self.repository;
    self.host.profileImportActiveChampionRelativePath = @"champions/caitlyn.json";
    self.host.installedRuntime = selection.activeChampionRuntime;
    self.host.installedPackage = selection.activeSkillControlPackage;
    self.host.presentedSnapshot = self.repository.activeSnapshot;
    selection.delegate = self.host;
    self.installer = [[MobaProfileRuntimeInstaller alloc] initWithHost:self.host];
    self.service = [[MobaProfileTransferService alloc] initWithStore:self.store
        repository:self.repository runtimeBuilder:self.runtimeBuilder
        controlPackageBuilder:self.packageBuilder];
    [self.store.operations removeAllObjects];
    [self.sink.events removeAllObjects];
}
- (MobaProfileImportPlan *)planForData:(NSData *)data {
    return [self.service prepareImportPlanForData:data
        activeChampionRelativePath:self.host.profileImportActiveChampionRelativePath error:nil];
}
- (MobaProfileImportPlan *)inputPlan {
    NSMutableDictionary *json = [self mutableJSONFromData:self.originalFiles[MobaInputProfileRelativePath]];
    json[@"movement"] = @{@"up": @38, @"left": @37, @"down": @40, @"right": @39};
    NSMutableDictionary *actions = [json[@"actions"] mutableCopy];
    actions[@"attack"] = @88;
    json[@"actions"] = actions;
    json[@"attackTapDurationMs"] = @45;
    return [self planForData:[self dataFromJSON:json]];
}
- (MobaPreparedProfileInstallation *)prepare:(MobaProfileImportPlan *)plan error:(NSError **)error {
    NSString *activeChampionPath = [plan.profileKind isEqualToString:MobaProfileKindChampion]
        ? plan.targetRelativePath : plan.activeChampionRelativePath;
    return [self.installer prepareInstallationForSnapshot:plan.repositoryCandidate.snapshot
        runtime:plan.runtime skillControlPackage:plan.skillControlPackage
        championRelativePath:activeChampionPath error:error];
}
- (BOOL)commitPlanDirectly:(MobaProfileImportPlan *)plan error:(NSError **)error {
    MobaPreparedProfileInstallation *installation = [self prepare:plan error:error];
    if (installation == nil || ![self.repository commitImportCandidate:plan.repositoryCandidate error:error]) return NO;
    return [self.installer commitPreparedInstallation:installation error:error];
}
- (void)testPrepareRejectsMovementNonNeutralWithoutChangingState {
    [self.host.profileImportMovementController setInteractionEnabled:YES];
    XCTAssertTrue([self.host.profileImportMovementController updateDisplacement:CGVectorMake(80, 0)]);
    [self.host.profileImportMovementController setInteractionEnabled:NO];
    MobaMovementKeyMapping before = self.host.profileImportMovementController.keyMapping;
    XCTAssertNil([self prepare:[self inputPlan] error:nil]);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.upKeyCode, before.upKeyCode);
    XCTAssertEqualObjects(self.host.profileImportChampionSelectionController.selectedChampionID, @"caitlyn");
}
- (void)testPrepareRejectsMovementOwnedToken {
    NSObject *token = [[NSObject alloc] init];
    [self.host.profileImportMovementController setInteractionEnabled:YES];
    XCTAssertTrue([self.host.profileImportMovementController beginInteractionWithToken:token
        displacement:CGVectorMake(0, 0)]);
    [self.host.profileImportMovementController setInteractionEnabled:NO];
    XCTAssertNil([self prepare:[self inputPlan] error:nil]);
    XCTAssertTrue(self.host.profileImportMovementController.activeTouchToken == token);
}
- (void)testPrepareRejectsAttackPressed {
    [self.host.profileImportAttackController setValue:@YES forKey:@"pressed"];
    XCTAssertNil([self prepare:[self inputPlan] error:nil]);
    XCTAssertTrue(self.host.profileImportAttackController.isPressed);
}
- (void)testPrepareRejectsAttackOwnedToken {
    NSObject *token = [[NSObject alloc] init];
    [self.host.profileImportAttackController setValue:token forKey:@"activeTouchToken"];
    XCTAssertNil([self prepare:[self inputPlan] error:nil]);
    XCTAssertTrue(self.host.profileImportAttackController.activeTouchToken == token);
}
- (void)testChampionPrepareRejectionDoesNotChangeInputControllers {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaTransferFakeRuntime *wrongRuntime = [[MobaTransferFakeRuntime alloc] init];
    wrongRuntime.championID = @"wrong";
    XCTAssertNil([self.installer prepareInstallationForSnapshot:plan.repositoryCandidate.snapshot
        runtime:(id)wrongRuntime skillControlPackage:plan.skillControlPackage
        championRelativePath:plan.activeChampionRelativePath error:nil]);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.upKeyCode, 87);
    XCTAssertEqual(self.host.profileImportAttackController.attackKeyCode, 67);
}
- (void)testDelegateViewInstallationExceptionRestoresOldObjectIdentities {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaChampionRuntime *oldRuntime = self.host.installedRuntime;
    MobaSkillControlPackage *oldPackage = self.host.installedPackage;
    self.host.throwNextDelegateInstall = YES;
    XCTAssertFalse([self commitPlanDirectly:plan error:nil]);
    XCTAssertTrue(self.host.installedRuntime == oldRuntime);
    XCTAssertTrue(self.host.installedPackage == oldPackage);
    XCTAssertEqualObjects(self.host.profileImportChampionSelectionController.selectedChampionID, @"caitlyn");
}
- (void)testParticipantRegistrationExceptionRestoresOldParticipants {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaTransferResetToken *candidateParticipant = [[MobaTransferResetToken alloc] init];
    ((MobaTransferFakeRuntime *)(id)plan.runtime).localInteractionResetParticipants = @[candidateParticipant];
    self.selectionLifecycle.failNextRegistration = YES;
    XCTAssertFalse([self commitPlanDirectly:plan error:nil]);
    XCTAssertFalse([self.selectionLifecycle.participants containsObject:candidateParticipant]);
}
- (void)testMovementApplyFailureRestoresRuntimePackageAndCatalog {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaChampionRuntime *oldRuntime = self.host.installedRuntime;
    MobaSkillControlPackage *oldPackage = self.host.installedPackage;
    NSArray *oldCatalog = self.host.profileImportChampionSelectionController.catalogEntries;
    self.host.failMovementApply = YES;
    XCTAssertFalse([self commitPlanDirectly:plan error:nil]);
    XCTAssertTrue(self.host.installedRuntime == oldRuntime);
    XCTAssertTrue(self.host.installedPackage == oldPackage);
    XCTAssertEqualObjects(self.host.profileImportChampionSelectionController.catalogEntries, oldCatalog);
}
- (void)testAttackApplyFailureRestoresMovementMapping {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaMovementKeyMapping oldMapping = self.host.profileImportMovementController.keyMapping;
    self.host.failAttackApply = YES;
    XCTAssertFalse([self commitPlanDirectly:plan error:nil]);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.upKeyCode, oldMapping.upKeyCode);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.rightKeyCode, oldMapping.rightKeyCode);
    XCTAssertEqual(self.host.profileImportAttackController.attackKeyCode, 67);
}
- (void)testPresentationFailureRestoresPathAndOldPresentation {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaProfileSnapshot *oldSnapshot = self.host.presentedSnapshot;
    self.host.failPresentation = YES;
    XCTAssertFalse([self commitPlanDirectly:plan error:nil]);
    XCTAssertEqualObjects(self.host.profileImportActiveChampionRelativePath, @"champions/caitlyn.json");
    XCTAssertTrue(self.host.presentedSnapshot == oldSnapshot);
}
- (void)testSuccessfulInputInstallationUpdatesMovementAndAttack {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaTransferResetToken *participant = [[MobaTransferResetToken alloc] init];
    ((MobaTransferFakeRuntime *)(id)plan.runtime).localInteractionResetParticipants = @[participant];
    XCTAssertTrue([self commitPlanDirectly:plan error:nil]);
    MobaMovementKeyMapping mapping = self.host.profileImportMovementController.keyMapping;
    XCTAssertEqual(mapping.upKeyCode, 38);
    XCTAssertEqual(mapping.leftKeyCode, 37);
    XCTAssertEqual(mapping.downKeyCode, 40);
    XCTAssertEqual(mapping.rightKeyCode, 39);
    XCTAssertEqual(self.host.profileImportAttackController.attackKeyCode, 88);
    XCTAssertEqual(self.host.profileImportAttackController.tapDurationMs, 45u);
    XCTAssertEqual(self.host.delegateInstallCount, 1u);
    XCTAssertEqual(self.host.presentationCount, 1u);
    XCTAssertEqual(self.selectionLifecycle.registerCount, 1u);
    XCTAssertTrue([self.selectionLifecycle.participants containsObject:participant]);
}
- (void)testRuntimeImportDoesNotChangeInputConfiguration {
    MobaMovementKeyMapping oldMapping = self.host.profileImportMovementController.keyMapping;
    XCTAssertTrue([self commitPlanDirectly:[self planForData:self.originalFiles[MobaRuntimeProfileRelativePath]] error:nil]);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.upKeyCode, oldMapping.upKeyCode);
    XCTAssertEqual(self.host.profileImportAttackController.attackKeyCode, 67);
}
- (void)testLayoutImportDoesNotChangeInputConfiguration {
    MobaMovementKeyMapping oldMapping = self.host.profileImportMovementController.keyMapping;
    XCTAssertTrue([self commitPlanDirectly:[self planForData:self.originalFiles[MobaActiveLayoutProfileRelativePath]] error:nil]);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.leftKeyCode, oldMapping.leftKeyCode);
    XCTAssertEqual(self.host.profileImportAttackController.tapDurationMs, 30u);
}
- (void)testChampionImportDoesNotChangeInputConfigurationAndKeepsOriginalID {
    NSMutableDictionary *json = [self mutableJSONFromData:self.originalFiles[@"champions/caitlyn.json"]];
    json[@"championId"] = @"Kai'Sa";
    json[@"displayName"] = @"Kai'Sa";
    MobaProfileImportPlan *plan = [self planForData:[self dataFromJSON:json]];
    XCTAssertTrue([self commitPlanDirectly:plan error:nil]);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.upKeyCode, 87);
    XCTAssertEqual(self.host.profileImportAttackController.attackKeyCode, 67);
    XCTAssertEqualObjects(self.host.profileImportChampionSelectionController.selectedChampionID, @"Kai'Sa");
    MobaChampionCatalogEntry *entry = [self.host.profileImportChampionSelectionController
        catalogEntryForChampionID:@"Kai'Sa"];
    XCTAssertEqualObjects(entry.championID, @"Kai'Sa");
    XCTAssertEqualObjects(entry.championRelativePath, plan.targetRelativePath);
}
- (void)testProductionInstallerFailurePathSendsNoDispatcherEvents {
    self.host.failAttackApply = YES;
    XCTAssertFalse([self commitPlanDirectly:[self inputPlan] error:nil]);
    XCTAssertEqual(self.sink.events.count, 0u);
}
- (void)testTransactionRestoresRepositoryAndBytesAfterProductionInstallerRollback {
    MobaProfileImportPlan *plan = [self inputPlan];
    MobaProfileSnapshot *oldSnapshot = self.repository.activeSnapshot;
    NSData *oldBytes = self.store.files[MobaInputProfileRelativePath];
    MobaTransferFakeLifecycle *lifecycle = [[MobaTransferFakeLifecycle alloc] init];
    MobaProfileImportTransaction *transaction = [[MobaProfileImportTransaction alloc]
        initWithStore:self.store repository:self.repository lifecycle:lifecycle installer:self.installer
        backupDirectoryProvider:[[MobaTransferFixedBackupProvider alloc] init]];
    self.host.failAttackApply = YES;
    XCTAssertNil([transaction applyImportPlan:plan error:nil]);
    XCTAssertTrue(self.repository.activeSnapshot == oldSnapshot);
    XCTAssertEqualObjects(self.store.files[MobaInputProfileRelativePath], oldBytes);
    XCTAssertEqual(self.host.profileImportMovementController.keyMapping.upKeyCode, 87);
    XCTAssertEqual(self.host.profileImportAttackController.attackKeyCode, 67);
    XCTAssertEqual(lifecycle.willCount, 1u);
    XCTAssertEqual(lifecycle.didCount, 1u);
    XCTAssertEqual(self.sink.events.count, 0u);
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
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    NSDictionary *input = [self mutableJSONFromData:[self exampleData:@"input.json"]];
    for (NSString *key in @[@"profileId", @"movement", @"actions", @"cancelCastAction"]) {
        json[key] = input[key];
    }
    NSData *data = [self dataFromJSON:json];
    XCTAssertNil([self planForData:data error:&error]);
    XCTAssertEqual(error.code, MobaProfileErrorAmbiguousProfileType);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$");
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorOperationKey], @"detect-profile-type");
}

- (void)testChampionUnknownActionsDoesNotCollideWithInput {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"actions"] = @{@"futureMetadata": @YES};
    XCTAssertEqualObjects([self planForData:[self dataFromJSON:json] error:nil].profileKind,
                          MobaProfileKindChampion);
}

- (void)testChampionUnknownControlsDoesNotCollideWithLayout {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"controls"] = @{@"future": @YES};
    XCTAssertEqualObjects([self planForData:[self dataFromJSON:json] error:nil].profileKind,
                          MobaProfileKindChampion);
}

- (void)testChampionUnknownProfileIDDoesNotCollideWithInput {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"profileId"] = @"future-metadata";
    XCTAssertEqualObjects([self planForData:[self dataFromJSON:json] error:nil].profileKind,
                          MobaProfileKindChampion);
}

- (void)testInputUnknownSkillsDoesNotCollideWithChampion {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"input.json"]];
    json[@"skills"] = @{@"future": @YES};
    XCTAssertEqualObjects([self planForData:[self dataFromJSON:json] error:nil].profileKind,
                          MobaProfileKindInput);
}

- (void)testLayoutUnknownCameraDoesNotCollideWithRuntime {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"ipad-pro-13-layout.json"]];
    json[@"camera"] = @{@"future": @YES};
    XCTAssertEqualObjects([self planForData:[self dataFromJSON:json] error:nil].profileKind,
                          MobaProfileKindLayout);
}

- (void)testRuntimeUnknownChampionIDDoesNotCollideWithChampion {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"runtime.json"]];
    json[@"championId"] = @"future-metadata";
    XCTAssertEqualObjects([self planForData:[self dataFromJSON:json] error:nil].profileKind,
                          MobaProfileKindRuntime);
}

- (void)testMissingRuntimeFieldKeepsDecoderPath {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"runtime.json"]];
    [json removeObjectForKey:@"canvas"];
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.canvas");
}

- (void)testMissingChampionSkillsKeepsDecoderPath {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    [json removeObjectForKey:@"skills"];
    NSError *error = nil;
    XCTAssertNil([self planForData:[self dataFromJSON:json] error:&error]);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.skills");
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

- (void)testEachSummaryUsesItsImportedProfileSchemaVersion {
    // Make the active Runtime version intentionally distinct so the Input,
    // Layout, and Champion assertions catch accidental Runtime coupling.
    [self.repository.activeSnapshot.runtimeProfile setValue:@77 forKey:@"schemaVersion"];
    NSDictionary *files = @{
        MobaProfileKindRuntime: @"runtime.json",
        MobaProfileKindInput: @"input.json",
        MobaProfileKindLayout: @"ipad-pro-13-layout.json",
        MobaProfileKindChampion: @"caitlyn.json",
    };
    for (MobaProfileKind kind in files) {
        MobaProfileImportPlan *plan = [self planForData:[self exampleData:files[kind]] error:nil];
        NSString *expected = [NSString stringWithFormat:@"Schema Version: %lu",
            (unsigned long)plan.schemaVersion];
        NSString *summary = [plan.summaryLines componentsJoinedByString:@" "];
        XCTAssertTrue([summary containsString:expected]);
        XCTAssertFalse([summary containsString:@"Schema Version: 77"]);
    }
}

- (void)testSummaryUsesReadableCancelAndCastTypes {
    NSString *input = [[[self planForData:[self exampleData:@"input.json"] error:nil]
        summaryLines] componentsJoinedByString:@" "];
    NSString *champion = [[[self planForData:[self exampleData:@"caitlyn.json"] error:nil]
        summaryLines] componentsJoinedByString:@" "];
    XCTAssertTrue([input containsString:@"keyboard"]);
    XCTAssertTrue([champion containsString:@"directional"]);
    XCTAssertTrue([champion containsString:@"point"]);
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

- (void)testChampionPathTraversalLikeIdentifierIsSafelyEncoded {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"championId"] = @"../new";
    MobaProfileImportPlan *plan = [self planForData:[self dataFromJSON:json] error:nil];
    XCTAssertNotNil(plan);
    XCTAssertTrue([plan.targetRelativePath hasPrefix:@"champions/encoded/id-"]);
    XCTAssertFalse([plan.targetRelativePath containsString:@".."]);
}

- (void)testExistingSafeChampionIDKeepsOriginalPath {
    XCTAssertEqualObjects([self planForData:[self exampleData:@"caitlyn.json"] error:nil].targetRelativePath,
                          @"champions/caitlyn.json");
}

- (MobaProfileImportPlan *)championPlanWithIdentifier:(NSString *)identifier {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"championId"] = identifier;
    json[@"displayName"] = identifier;
    return [self planForData:[self dataFromJSON:json] error:nil];
}

- (void)testUnsafeChampionIdentifiersUseSafeEncodedNamespace {
    for (NSString *identifier in @[@"Kai'Sa", @"Dr. Mundo", @"Nunu & Willump", @"瑟提"]) {
        MobaProfileImportPlan *plan = [self championPlanWithIdentifier:identifier];
        XCTAssertNotNil(plan);
        XCTAssertTrue([plan.targetRelativePath hasPrefix:@"champions/encoded/id-"]);
        XCTAssertFalse([plan.targetRelativePath containsString:identifier]);
        XCTAssertEqualObjects(plan.repositoryCandidate.snapshot.championProfile.championID, identifier);
    }
}

- (void)testUnsafeChampionStorageEncodingAvoidsSanitizationCollision {
    MobaProfileImportPlan *apostrophe = [self championPlanWithIdentifier:@"Kai'Sa"];
    MobaProfileImportPlan *space = [self championPlanWithIdentifier:@"Kai Sa"];
    XCTAssertNotEqualObjects(apostrophe.targetRelativePath, space.targetRelativePath);
}

- (void)testEncodedChampionStorageComponentsContainOnlySafeCharacters {
    for (NSString *identifier in @[@"../new", @"Kai'Sa", @"Dr. Mundo", @"瑟提", @"a:b\\c"]) {
        NSString *component = [MobaProfileTransferService
            safeChampionStorageComponentForIdentifier:identifier error:nil];
        XCTAssertNotNil(component);
        XCTAssertEqual([component rangeOfCharacterFromSet:
            [NSCharacterSet characterSetWithCharactersInString:
                @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"].invertedSet].location,
            NSNotFound);
        XCTAssertFalse([component containsString:@".."]);
    }
}

- (void)testExternalFileNameCannotChangeChampionStoragePath {
    NSMutableDictionary *json = [self mutableJSONFromData:[self exampleData:@"caitlyn.json"]];
    json[@"championId"] = @"Kai'Sa";
    NSData *data = [self dataFromJSON:json];
    MobaProfileImportPlan *direct = [self planForData:data error:nil];
    MobaProfileTransferViewController *controller = [[MobaProfileTransferViewController alloc]
        initWithTransferService:self.service
        importTransaction:(id)[NSObject new]
        activeChampionRelativePath:@"champions/caitlyn.json"];
    MobaProfileImportPlan *named = [controller prepareImportFromData:data
        sourceFileName:@"../../different.json" error:nil];
    XCTAssertEqualObjects(direct.targetRelativePath, named.targetRelativePath);
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
