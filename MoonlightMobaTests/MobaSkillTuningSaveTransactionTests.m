//
//  MobaSkillTuningSaveTransactionTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Profiles/MobaSkillTuningSaveTransaction.h"

@interface MobaTuningSaveNoopProvider : NSObject <MobaProfileResourceProviding>
@end
@implementation MobaTuningSaveNoopProvider
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)extension {
    (void)name; (void)extension; return nil;
}
@end

@interface MobaTuningSaveStore : MobaProfileStore
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *dataByPath;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *writeCountByPath;
@property (nonatomic, copy) NSDictionary<NSString *, NSSet<NSNumber *> *> *failedWrites;
@end
@implementation MobaTuningSaveStore
- (instancetype)init {
    self = [super initWithRootDirectoryURL:[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        resourceProvider:[[MobaTuningSaveNoopProvider alloc] init] fileManager:NSFileManager.defaultManager];
    if (self) {
        _dataByPath = [NSMutableDictionary dictionary];
        _writeCountByPath = [NSMutableDictionary dictionary];
        _failedWrites = @{};
    }
    return self;
}
- (NSData *)readDataAtRelativePath:(NSString *)path error:(NSError **)error {
    if (error != NULL) *error = nil;
    return self.dataByPath[path];
}
- (BOOL)writeData:(NSData *)data toRelativePath:(NSString *)path
   replaceExisting:(BOOL)replaceExisting error:(NSError **)error {
    (void)replaceExisting;
    NSUInteger count = self.writeCountByPath[path].unsignedIntegerValue + 1;
    self.writeCountByPath[path] = @(count);
    if ([self.failedWrites[path] containsObject:@(count)]) {
        if (error != NULL) *error = [NSError errorWithDomain:@"TuningStore" code:count userInfo:nil];
        return NO;
    }
    self.dataByPath[path] = [data copy];
    return YES;
}
@end

@interface MobaTuningSaveRepository : MobaProfileRepository
@property (nonatomic) BOOL failCommit;
@end
@implementation MobaTuningSaveRepository
- (BOOL)commitSkillTuningCandidate:(MobaProfileRepositoryCandidate *)candidate error:(NSError **)error {
    if (self.failCommit) {
        if (error != NULL) *error = [NSError errorWithDomain:@"TuningRepository" code:1 userInfo:nil];
        return NO;
    }
    return [super commitSkillTuningCandidate:candidate error:error];
}
@end

@interface MobaTuningSaveRuntimeBuilder : NSObject <MobaChampionRuntimeBuilding>
@end
@implementation MobaTuningSaveRuntimeBuilder
- (MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot error:(NSError **)error {
    (void)snapshot; if (error != NULL) *error = nil; return (id)NSObject.new;
}
@end

@interface MobaTuningSavePackage : NSObject
@property (nonatomic, getter=isComplete) BOOL complete;
@property (nonatomic) NSUInteger resetCount;
@end
@implementation MobaTuningSavePackage
- (void)silentResetForReason:(MobaInputInterruptionReason)reason { (void)reason; self.resetCount += 1; }
@end

@interface MobaTuningSavePackageBuilder : NSObject <MobaSkillControlPackageBuilding>
@property (nonatomic, strong) MobaTuningSavePackage *package;
@end
@implementation MobaTuningSavePackageBuilder
- (MobaSkillControlPackage *)controlPackageForRuntime:(MobaChampionRuntime *)runtime error:(NSError **)error {
    (void)runtime; if (error != NULL) *error = nil;
    self.package = [[MobaTuningSavePackage alloc] init];
    self.package.complete = YES;
    return (id)self.package;
}
@end

@interface MobaTuningSaveLifecycle : NSObject <MobaSkillTuningSaveLifecycle>
@property (nonatomic) NSUInteger willCount;
@property (nonatomic) NSUInteger didCount;
@end
@implementation MobaTuningSaveLifecycle
- (void)profileWillReload { self.willCount += 1; }
- (void)profileDidReload { self.didCount += 1; }
@end

@interface MobaTuningSaveInstaller : NSObject <MobaSkillTuningSaveInstalling>
@property (nonatomic) BOOL fail;
@property (nonatomic, strong) MobaProfileSnapshot *snapshot;
@end
@implementation MobaTuningSaveInstaller
- (BOOL)installSkillTuningSnapshot:(MobaProfileSnapshot *)snapshot runtime:(MobaChampionRuntime *)runtime
               skillControlPackage:(MobaSkillControlPackage *)package error:(NSError **)error {
    (void)runtime; (void)package;
    if (self.fail) {
        if (error != NULL) *error = [NSError errorWithDomain:@"TuningInstaller" code:1 userInfo:nil];
        return NO;
    }
    self.snapshot = snapshot;
    return YES;
}
@end

@interface MobaSkillTuningSaveTransactionTests : XCTestCase
@property (nonatomic, strong) MobaTuningSaveStore *store;
@property (nonatomic, strong) MobaTuningSaveRepository *repository;
@property (nonatomic, strong) MobaTuningSaveRuntimeBuilder *runtimeBuilder;
@property (nonatomic, strong) MobaTuningSavePackageBuilder *packageBuilder;
@property (nonatomic, strong) MobaTuningSaveLifecycle *lifecycle;
@property (nonatomic, strong) MobaTuningSaveInstaller *installer;
@property (nonatomic, strong) MobaSkillTuningSaveTransaction *transaction;
@property (nonatomic, strong) MobaSkillTuningDraft *draft;
@property (nonatomic, copy) NSData *runtimeData;
@property (nonatomic, copy) NSData *championData;
@property (nonatomic, copy) NSData *inputData;
@property (nonatomic, copy) NSData *layoutData;
@end

@implementation MobaSkillTuningSaveTransactionTests
- (NSData *)example:(NSString *)name {
    NSString *tests = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *path = [[[tests stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"examples/moba"]
        stringByAppendingPathComponent:name];
    return [NSData dataWithContentsOfFile:path];
}
- (void)setUp {
    [super setUp];
    self.runtimeData = [self example:@"runtime.json"];
    self.championData = [self example:@"caitlyn.json"];
    self.inputData = [self example:@"input.json"];
    self.layoutData = [self example:@"ipad-pro-13-layout.json"];
    self.store = [[MobaTuningSaveStore alloc] init];
    self.store.dataByPath[MobaRuntimeProfileRelativePath] = self.runtimeData;
    self.store.dataByPath[MobaInputProfileRelativePath] = self.inputData;
    self.store.dataByPath[MobaActiveLayoutProfileRelativePath] = self.layoutData;
    self.store.dataByPath[@"champions/caitlyn.json"] = self.championData;
    self.repository = [[MobaTuningSaveRepository alloc] initWithStore:self.store];
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    self.draft = [[MobaSkillTuningDraft alloc] initWithRuntimeData:self.runtimeData
        championData:self.championData decoder:[[MobaProfileDecoder alloc] init] error:nil];
    [self.draft setHeroAnchorX:1300 y:700 error:nil];
    [self.draft setValue:@701 forField:MobaSkillTuningFieldDirectionalLeftPx
               skillSlot:MobaCanonicalSkillSlotQ error:nil];
    self.runtimeBuilder = [[MobaTuningSaveRuntimeBuilder alloc] init];
    self.packageBuilder = [[MobaTuningSavePackageBuilder alloc] init];
    self.lifecycle = [[MobaTuningSaveLifecycle alloc] init];
    self.installer = [[MobaTuningSaveInstaller alloc] init];
    self.transaction = [[MobaSkillTuningSaveTransaction alloc] initWithStore:self.store
        repository:self.repository runtimeBuilder:self.runtimeBuilder controlPackageBuilder:self.packageBuilder
        lifecycle:self.lifecycle installer:self.installer];
}

- (void)testSuccessfulSaveWritesRuntimeAndCurrentChampionOnly {
    MobaSkillTuningSaveResult *result = [self.transaction saveDraft:self.draft
        championRelativePath:@"champions/caitlyn.json" error:nil];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(self.store.dataByPath[MobaInputProfileRelativePath], self.inputData);
    XCTAssertEqualObjects(self.store.dataByPath[MobaActiveLayoutProfileRelativePath], self.layoutData);
    XCTAssertEqual(self.store.writeCountByPath[MobaRuntimeProfileRelativePath].unsignedIntegerValue, 1u);
    XCTAssertEqual(self.store.writeCountByPath[@"champions/caitlyn.json"].unsignedIntegerValue, 1u);
    XCTAssertTrue(self.repository.activeSnapshot == result.snapshot);
    XCTAssertTrue(self.installer.snapshot == result.snapshot);
    XCTAssertEqual(self.lifecycle.willCount, 1u);
    XCTAssertEqual(self.lifecycle.didCount, 1u);
}

- (void)testSaveAfterManagedDefaultsPreservesUnmanagedRuntimeAndChampionFields {
    NSMutableDictionary *runtime = [NSJSONSerialization JSONObjectWithData:self.runtimeData
        options:NSJSONReadingMutableContainers error:nil];
    NSMutableDictionary *champion = [NSJSONSerialization JSONObjectWithData:self.championData
        options:NSJSONReadingMutableContainers error:nil];
    runtime[@"globalOpacityMultiplier"] = @0.37;
    runtime[@"futureRuntime"] = @{ @"retained": @YES };
    runtime[@"camera"][@"heroAnchorPx"][@"x"] = @1500;
    champion[@"displayName"] = @"Local Caitlyn";
    champion[@"skills"][@"Q"][@"futureSkill"] = @99;
    champion[@"skills"][@"Q"][@"range"][@"leftPx"] = @501;
    NSData *currentRuntime = [NSJSONSerialization dataWithJSONObject:runtime options:0 error:nil];
    NSData *currentChampion = [NSJSONSerialization dataWithJSONObject:champion options:0 error:nil];
    self.store.dataByPath[MobaRuntimeProfileRelativePath] = currentRuntime;
    self.store.dataByPath[@"champions/caitlyn.json"] = currentChampion;
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    self.draft = [[MobaSkillTuningDraft alloc] initWithRuntimeData:currentRuntime
        championData:currentChampion decoder:[[MobaProfileDecoder alloc] init] error:nil];
    XCTAssertTrue([self.draft applyManagedDefaultsFromRuntimeData:self.runtimeData
                                                    championData:self.championData
                                                         decoder:[[MobaProfileDecoder alloc] init]
                                                           error:nil]);

    XCTAssertNotNil([self.transaction saveDraft:self.draft
                           championRelativePath:@"champions/caitlyn.json" error:nil]);
    NSDictionary *savedRuntime = [NSJSONSerialization JSONObjectWithData:
        self.store.dataByPath[MobaRuntimeProfileRelativePath] options:0 error:nil];
    NSDictionary *savedChampion = [NSJSONSerialization JSONObjectWithData:
        self.store.dataByPath[@"champions/caitlyn.json"] options:0 error:nil];
    XCTAssertEqualObjects(savedRuntime[@"globalOpacityMultiplier"], @0.37);
    XCTAssertEqualObjects(savedRuntime[@"futureRuntime"], @{ @"retained": @YES });
    XCTAssertEqualObjects(savedRuntime[@"camera"][@"heroAnchorPx"][@"x"], @1280);
    XCTAssertEqualObjects(savedChampion[@"displayName"], @"Local Caitlyn");
    XCTAssertEqualObjects(savedChampion[@"skills"][@"Q"][@"futureSkill"], @99);
    XCTAssertEqualObjects(savedChampion[@"skills"][@"Q"][@"range"][@"leftPx"], @720);
}

- (void)testChampionWriteFailureRollsBackFirstRuntimeWrite {
    self.store.failedWrites = @{ @"champions/caitlyn.json": [NSSet setWithObject:@1] };
    MobaProfileSnapshot *base = self.repository.activeSnapshot;
    NSError *error = nil;
    XCTAssertNil([self.transaction saveDraft:self.draft championRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.runtimeData);
    XCTAssertEqualObjects(self.store.dataByPath[@"champions/caitlyn.json"], self.championData);
    XCTAssertTrue(self.repository.activeSnapshot == base);
}

- (void)testRepositoryCommitFailureRollsBackBothFilesAndIdentity {
    self.repository.failCommit = YES;
    MobaProfileSnapshot *base = self.repository.activeSnapshot;
    XCTAssertNil([self.transaction saveDraft:self.draft championRelativePath:@"champions/caitlyn.json" error:nil]);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.runtimeData);
    XCTAssertEqualObjects(self.store.dataByPath[@"champions/caitlyn.json"], self.championData);
    XCTAssertTrue(self.repository.activeSnapshot == base);
}

- (void)testInstallerFailureRollsBackRepositoryAndBothFiles {
    self.installer.fail = YES;
    MobaProfileSnapshot *base = self.repository.activeSnapshot;
    XCTAssertNil([self.transaction saveDraft:self.draft championRelativePath:@"champions/caitlyn.json" error:nil]);
    XCTAssertTrue(self.repository.activeSnapshot == base);
    XCTAssertEqualObjects(self.store.dataByPath[MobaRuntimeProfileRelativePath], self.runtimeData);
    XCTAssertEqualObjects(self.store.dataByPath[@"champions/caitlyn.json"], self.championData);
}

- (void)testRollbackFailureUsesIndependentError {
    self.installer.fail = YES;
    self.store.failedWrites = @{ @"champions/caitlyn.json": [NSSet setWithObject:@2] };
    NSError *error = nil;
    XCTAssertNil([self.transaction saveDraft:self.draft championRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertEqualObjects(error.domain, MobaSkillTuningSaveTransactionErrorDomain);
    XCTAssertEqual(error.code, MobaSkillTuningSaveTransactionErrorRollbackFailed);
}

@end
