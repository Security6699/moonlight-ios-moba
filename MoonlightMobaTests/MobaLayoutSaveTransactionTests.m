//
//  MobaLayoutSaveTransactionTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Controls/AttackButtonView.h"
#import "../Limelight/Input/MOBA/Controls/MobaAttackController.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Profiles/MobaLayoutSaveTransaction.h"

@interface MobaSaveInputSink : NSObject <MobaInputSink>
@end
@implementation MobaSaveInputSink
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down { (void)keyCode; (void)down; }
- (void)moveCursorToCanvasPoint:(CGPoint)point { (void)point; }
- (void)sendMouseButton:(int)button down:(BOOL)down { (void)button; (void)down; }
@end

@interface MobaSaveNoopProvider : NSObject <MobaProfileResourceProviding>
@end
@implementation MobaSaveNoopProvider
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)extension {
    (void)name; (void)extension; return nil;
}
@end

@interface MobaSaveFakeStore : MobaProfileStore
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *dataByPath;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *writeCountByPath;
@property (nonatomic, copy) NSDictionary<NSString *, NSSet<NSNumber *> *> *failedWriteNumbersByPath;
@end
@implementation MobaSaveFakeStore
- (instancetype)init {
    self = [super initWithRootDirectoryURL:[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                         resourceProvider:[[MobaSaveNoopProvider alloc] init]
                              fileManager:NSFileManager.defaultManager];
    if (self) {
        _dataByPath = [NSMutableDictionary dictionary];
        _writeCountByPath = [NSMutableDictionary dictionary];
        _failedWriteNumbersByPath = @{};
    }
    return self;
}
- (NSData *)readDataAtRelativePath:(NSString *)relativePath error:(NSError **)error {
    if (error != NULL) *error = nil;
    NSData *data = self.dataByPath[relativePath];
    if (data == nil && error != NULL) {
        *error = [NSError errorWithDomain:@"FakeStore" code:1 userInfo:nil];
    }
    return data;
}
- (BOOL)writeData:(NSData *)data toRelativePath:(NSString *)relativePath
   replaceExisting:(BOOL)replaceExisting error:(NSError **)error {
    (void)replaceExisting;
    NSUInteger number = self.writeCountByPath[relativePath].unsignedIntegerValue + 1;
    self.writeCountByPath[relativePath] = @(number);
    if ([self.failedWriteNumbersByPath[relativePath] containsObject:@(number)]) {
        if (error != NULL) *error = [NSError errorWithDomain:@"FakeStore" code:number userInfo:nil];
        return NO;
    }
    self.dataByPath[relativePath] = [data copy];
    if (error != NULL) *error = nil;
    return YES;
}
@end

@interface MobaSaveFakeRuntimeBuilder : NSObject <MobaChampionRuntimeBuilding>
@property (nonatomic) BOOL fail;
@property (nonatomic, strong) MobaProfileSnapshot *receivedSnapshot;
@end
@implementation MobaSaveFakeRuntimeBuilder
- (MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot error:(NSError **)error {
    self.receivedSnapshot = snapshot;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Runtime" code:1 userInfo:nil];
        return nil;
    }
    return (id)[NSObject new];
}
@end

@interface MobaSaveFakePackage : NSObject
@property (nonatomic, getter=isComplete) BOOL complete;
@property (nonatomic) NSUInteger resetCount;
@end
@implementation MobaSaveFakePackage
- (void)silentResetForReason:(MobaInputInterruptionReason)reason { (void)reason; self.resetCount += 1; }
@end

@interface MobaSaveFakePackageBuilder : NSObject <MobaSkillControlPackageBuilding>
@property (nonatomic) BOOL fail;
@property (nonatomic, strong) MobaSaveFakePackage *package;
@end
@implementation MobaSaveFakePackageBuilder
- (MobaSkillControlPackage *)controlPackageForRuntime:(MobaChampionRuntime *)runtime error:(NSError **)error {
    (void)runtime;
    self.package = [[MobaSaveFakePackage alloc] init];
    self.package.complete = !self.fail;
    if (self.fail && error != NULL) *error = [NSError errorWithDomain:@"Package" code:1 userInfo:nil];
    return (id)self.package;
}
@end

@interface MobaSaveFakeLifecycle : NSObject <MobaLayoutSaveLifecycle>
@property (nonatomic) NSUInteger willCount;
@property (nonatomic) NSUInteger didCount;
@end
@implementation MobaSaveFakeLifecycle
- (void)profileWillReload { self.willCount += 1; }
- (void)profileDidReload { self.didCount += 1; }
@end

@interface MobaSaveFakeInstaller : NSObject <MobaLayoutSaveInstalling>
@property (nonatomic) BOOL fail;
@property (nonatomic) NSUInteger installCount;
@property (nonatomic, strong) MobaProfileSnapshot *installedSnapshot;
@end
@implementation MobaSaveFakeInstaller
- (BOOL)installLayoutSaveSnapshot:(MobaProfileSnapshot *)snapshot
                           runtime:(MobaChampionRuntime *)runtime
               skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                             error:(NSError **)error {
    (void)runtime; (void)skillControlPackage;
    self.installCount += 1;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"Installer" code:1 userInfo:nil];
        return NO;
    }
    self.installedSnapshot = snapshot;
    return YES;
}
@end

@interface MobaLayoutSaveTransactionTests : XCTestCase
@property (nonatomic, strong) MobaSaveFakeStore *store;
@property (nonatomic, strong) MobaProfileRepository *repository;
@property (nonatomic, strong) MobaSaveFakeRuntimeBuilder *runtimeBuilder;
@property (nonatomic, strong) MobaSaveFakePackageBuilder *packageBuilder;
@property (nonatomic, strong) MobaSaveFakeLifecycle *lifecycle;
@property (nonatomic, strong) MobaSaveFakeInstaller *installer;
@property (nonatomic, strong) MobaLayoutSaveTransaction *transaction;
@property (nonatomic, strong) MobaLayoutEditorController *editor;
@property (nonatomic, copy) NSData *originalRuntime;
@property (nonatomic, copy) NSData *originalLayout;
@property (nonatomic, copy) NSData *originalInput;
@property (nonatomic, copy) NSData *originalChampion;
@end

@implementation MobaLayoutSaveTransactionTests

- (NSData *)exampleData:(NSString *)name {
    NSString *tests = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *path = [[tests stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"examples/moba"];
    NSData *data = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:name]];
    XCTAssertNotNil(data);
    return data;
}

- (void)setUp {
    [super setUp];
    self.store = [[MobaSaveFakeStore alloc] init];
    self.originalRuntime = [self exampleData:@"runtime.json"];
    self.originalLayout = [self exampleData:@"ipad-pro-13-layout.json"];
    self.originalInput = [self exampleData:@"input.json"];
    self.originalChampion = [self exampleData:@"caitlyn.json"];
    self.store.dataByPath[MobaRuntimeProfileRelativePath] = self.originalRuntime;
    self.store.dataByPath[MobaInputProfileRelativePath] = self.originalInput;
    self.store.dataByPath[MobaActiveLayoutProfileRelativePath] = self.originalLayout;
    self.store.dataByPath[@"champions/caitlyn.json"] = self.originalChampion;
    self.repository = [[MobaProfileRepository alloc] initWithStore:self.store];
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    MobaProfileSnapshot *snapshot = self.repository.activeSnapshot;
    self.editor = [[MobaLayoutEditorController alloc] initWithSnapshot:snapshot
                                                           runtimeData:self.originalRuntime
                                                            layoutData:self.originalLayout
                                                               decoder:[[MobaProfileDecoder alloc] init]
                                                                 error:nil];
    self.runtimeBuilder = [[MobaSaveFakeRuntimeBuilder alloc] init];
    self.packageBuilder = [[MobaSaveFakePackageBuilder alloc] init];
    self.lifecycle = [[MobaSaveFakeLifecycle alloc] init];
    self.installer = [[MobaSaveFakeInstaller alloc] init];
    self.transaction = [[MobaLayoutSaveTransaction alloc]
        initWithStore:self.store repository:self.repository runtimeBuilder:self.runtimeBuilder
        controlPackageBuilder:self.packageBuilder lifecycle:self.lifecycle installer:self.installer];
}

- (void)makeDraftDirty {
    [self.editor selectControlNamed:@"move"];
    [self.editor setSelectedControlValue:0.35 forField:MobaLayoutEditorControlFieldCenterX];
    [self.editor setGlobalOpacityMultiplierValue:0.7];
}

- (void)testSuccessfulSavePersistsBothFilesAndCommitsSnapshot {
    MobaProfileSnapshot *old = self.repository.activeSnapshot;
    [self makeDraftDirty];
    MobaLayoutSaveResult *result = [self.transaction saveDraft:self.editor.draft error:nil];
    XCTAssertNotNil(result);
    XCTAssertFalse(self.repository.activeSnapshot == old);
    XCTAssertTrue(self.repository.activeSnapshot == result.snapshot);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], result.runtimeData);
    XCTAssertEqualObjects(self.store.dataByPath[MobaActiveLayoutProfileRelativePath], result.layoutData);
    XCTAssertTrue(self.installer.installedSnapshot == result.snapshot);
}

- (void)testSuccessfulSavePreservesInputAndChampionBytes {
    [self makeDraftDirty];
    XCTAssertNotNil([self.transaction saveDraft:self.editor.draft error:nil]);
    XCTAssertEqualObjects(self.store.dataByPath[MobaInputProfileRelativePath], self.originalInput);
    XCTAssertEqualObjects(self.store.dataByPath[@"champions/caitlyn.json"], self.originalChampion);
}

- (void)testSuccessfulSaveKeepsChampionIdentity {
    [self makeDraftDirty];
    MobaLayoutSaveResult *result = [self.transaction saveDraft:self.editor.draft error:nil];
    XCTAssertEqualObjects(result.snapshot.championProfile.championID, @"caitlyn");
    XCTAssertTrue(result.snapshot.championProfile == self.repository.activeSnapshot.championProfile);
}

- (void)testSavedAttackWidthAndHeightRebuildExactVisualBounds {
    [self.editor selectControlNamed:@"attack"];
    XCTAssertTrue([self.editor setSelectedControlValue:140
                                              forField:MobaLayoutEditorControlFieldVisualWidth]);
    XCTAssertTrue([self.editor setSelectedControlValue:90
                                              forField:MobaLayoutEditorControlFieldVisualHeight]);
    MobaLayoutSaveResult *result = [self.transaction saveDraft:self.editor.draft error:nil];
    XCTAssertNotNil(result);

    MobaLayoutControlProfile *profile = result.snapshot.layoutProfile.controls[@"attack"];
    XCTAssertEqual(profile.visualWidthPt, 140);
    XCTAssertEqual(profile.visualHeightPt, 90);
    MobaControlLayoutPresentation *presentation = [[MobaControlLayoutPresentation alloc]
        initWithCenterX:profile.centerX centerY:profile.centerY
        visualSize:CGSizeMake(profile.visualWidthPt, profile.visualHeightPt)
        hitAreaScale:profile.hitAreaScale wheelRadiusPt:profile.wheelRadiusPt
        normalOpacity:profile.opacity pressedOpacity:profile.pressedOpacity
        disabledOpacity:profile.disabledOpacity zIndex:profile.zIndex
        interactionEnabled:profile.isInteractionEnabled];
    MobaInputDispatcher *dispatcher = [[MobaInputDispatcher alloc]
        initWithSink:[[MobaSaveInputSink alloc] init]];
    MobaAttackController *controller = [[MobaAttackController alloc]
        initWithInputDispatcher:dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:presentation
                 globalOpacityMultiplier:result.snapshot.runtimeProfile.globalOpacityMultiplier
                            previewState:MobaControlOpacityPreviewStateAutomatic];
    CGSize hitSize = view.intrinsicContentSize;
    view.frame = (CGRect){ CGPointZero, hitSize };
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertTrue(CGSizeEqualToSize(view.renderedVisualSize, CGSizeMake(140, 90)));
}

- (void)testLifecycleReloadBoundaryIsPairedOnce {
    [self makeDraftDirty];
    XCTAssertNotNil([self.transaction saveDraft:self.editor.draft error:nil]);
    XCTAssertEqual(self.lifecycle.willCount, 1u);
    XCTAssertEqual(self.lifecycle.didCount, 1u);
}

- (void)testInvalidCandidateDoesNotWriteOrEnterLifecycle {
    [self.editor selectControlNamed:@"move"];
    [self.editor setSelectedControlValue:700 forField:MobaLayoutEditorControlFieldVisualWidth];
    NSError *error = nil;
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:&error]);
    XCTAssertEqual(error.code, MobaLayoutSaveTransactionErrorCandidateRejected);
    XCTAssertEqual(self.store.writeCountByPath.count, 0u);
    XCTAssertEqual(self.lifecycle.willCount, 0u);
}

- (void)testRuntimeFactoryFailurePreservesDiskAndSnapshot {
    MobaProfileSnapshot *old = self.repository.activeSnapshot;
    self.runtimeBuilder.fail = YES;
    [self makeDraftDirty];
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:nil]);
    XCTAssertTrue(self.repository.activeSnapshot == old);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.originalRuntime);
    XCTAssertEqualObjects(self.store.dataByPath[MobaActiveLayoutProfileRelativePath], self.originalLayout);
}

- (void)testPackageFailurePreservesDiskAndSnapshot {
    MobaProfileSnapshot *old = self.repository.activeSnapshot;
    self.packageBuilder.fail = YES;
    [self makeDraftDirty];
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:nil]);
    XCTAssertTrue(self.repository.activeSnapshot == old);
    XCTAssertEqual(self.lifecycle.willCount, 0u);
}

- (void)testLayoutWriteFailureLeavesBothOldFiles {
    self.store.failedWriteNumbersByPath = @{ MobaActiveLayoutProfileRelativePath: [NSSet setWithObject:@1] };
    [self makeDraftDirty];
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:nil]);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.originalRuntime);
    XCTAssertEqualObjects(self.store.dataByPath[MobaActiveLayoutProfileRelativePath], self.originalLayout);
}

- (void)testRuntimeWriteFailureRollsBackLayout {
    self.store.failedWriteNumbersByPath = @{ MobaRuntimeProfileRelativePath: [NSSet setWithObject:@1] };
    [self makeDraftDirty];
    NSError *error = nil;
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:&error]);
    XCTAssertEqual(error.code, MobaLayoutSaveTransactionErrorPersistenceFailed);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.originalRuntime);
    XCTAssertEqualObjects(self.store.dataByPath[MobaActiveLayoutProfileRelativePath], self.originalLayout);
    XCTAssertEqual(self.lifecycle.willCount, 1u);
    XCTAssertEqual(self.lifecycle.didCount, 1u);
}

- (void)testInstallerFailureRollsBackDiskAndRepository {
    MobaProfileSnapshot *old = self.repository.activeSnapshot;
    self.installer.fail = YES;
    [self makeDraftDirty];
    NSError *error = nil;
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:&error]);
    XCTAssertEqual(error.code, MobaLayoutSaveTransactionErrorRuntimeInstallFailed);
    XCTAssertTrue(self.repository.activeSnapshot == old);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.originalRuntime);
    XCTAssertEqualObjects(self.store.dataByPath[MobaActiveLayoutProfileRelativePath], self.originalLayout);
}

- (void)testRollbackFailureIsReportedExplicitly {
    self.installer.fail = YES;
    self.store.failedWriteNumbersByPath = @{
        MobaActiveLayoutProfileRelativePath: [NSSet setWithObject:@2],
    };
    [self makeDraftDirty];
    NSError *error = nil;
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:&error]);
    XCTAssertEqual(error.code, MobaLayoutSaveTransactionErrorRollbackFailed);
}

- (void)testFailedSaveLeavesEditorDraftDirtyForRetry {
    self.installer.fail = YES;
    [self makeDraftDirty];
    XCTAssertNil([self.transaction saveDraft:self.editor.draft error:nil]);
    XCTAssertTrue(self.editor.isDirty);
    XCTAssertEqualWithAccuracy([self.editor.draft controlNamed:@"move"].centerX, 0.35, 0.000001);
}

@end
