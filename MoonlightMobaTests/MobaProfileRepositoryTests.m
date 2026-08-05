//
//  MobaProfileRepositoryTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Profiles/MobaProfileError.h"
#import "../Limelight/Input/MOBA/Profiles/MobaProfileRepository.h"

@interface MobaRepositoryResourceProvider : NSObject <MobaProfileResourceProviding>
@property (nonatomic, copy) NSDictionary<NSString *, NSURL *> *resourceURLs;
@end

@implementation MobaRepositoryResourceProvider
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)extension {
    return self.resourceURLs[[name stringByAppendingPathExtension:extension]];
}
@end

@interface MobaProfileRepositoryTests : XCTestCase
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSURL *containerURL;
@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) MobaProfileStore *store;
@property (nonatomic, strong) MobaProfileRepository *repository;
@end

@implementation MobaProfileRepositoryTests

- (NSURL *)exampleURL:(NSString *)fileName {
    NSString *testDirectory = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSMutableArray<NSString *> *roots = [NSMutableArray arrayWithObject:[testDirectory stringByDeletingLastPathComponent]];
    NSString *sourceRoot = NSProcessInfo.processInfo.environment[@"SRCROOT"];
    if (sourceRoot.length > 0) {
        [roots addObject:sourceRoot];
    }
    [roots addObject:NSFileManager.defaultManager.currentDirectoryPath];
    for (NSString *root in roots) {
        NSString *path = [[root stringByAppendingPathComponent:@"examples/moba"]
            stringByAppendingPathComponent:fileName];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            return [NSURL fileURLWithPath:path];
        }
    }
    XCTFail(@"Unable to locate bundled example source %@", fileName);
    return [NSURL fileURLWithPath:fileName];
}

- (void)setUp {
    [super setUp];
    self.fileManager = [[NSFileManager alloc] init];
    NSString *name = [NSString stringWithFormat:@"MobaProfileRepositoryTests-%@", NSUUID.UUID.UUIDString];
    self.containerURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:name isDirectory:YES];
    self.rootURL = [self.containerURL URLByAppendingPathComponent:@"MOBA" isDirectory:YES];
    MobaRepositoryResourceProvider *provider = [[MobaRepositoryResourceProvider alloc] init];
    NSMutableDictionary *resources = [NSMutableDictionary dictionary];
    for (NSString *fileName in @[
        @"runtime.json",
        @"input.json",
        @"ipad-pro-13-layout.json",
        @"caitlyn.json",
        @"debug-instant.json",
    ]) {
        resources[fileName] = [self exampleURL:fileName];
    }
    provider.resourceURLs = resources;
    self.store = [[MobaProfileStore alloc] initWithRootDirectoryURL:self.rootURL
                                                   resourceProvider:provider
                                                        fileManager:self.fileManager];
    NSError *error = nil;
    XCTAssertTrue([self.store bootstrapDefaultsWithError:&error]);
    XCTAssertNil(error);
    self.repository = [[MobaProfileRepository alloc] initWithStore:self.store];
}

- (void)tearDown {
    [self.fileManager removeItemAtURL:self.containerURL error:nil];
    [super tearDown];
}

- (NSMutableDictionary *)storedJSONAtPath:(NSString *)path {
    NSData *data = [self.store readDataAtRelativePath:path error:nil];
    XCTAssertNotNil(data);
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data
                                              options:NSJSONReadingMutableContainers
                                                error:&error];
    XCTAssertNil(error);
    return json;
}

- (void)writeJSON:(NSDictionary *)json path:(NSString *)path {
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    XCTAssertNotNil(data);
    XCTAssertTrue([self.store writeData:data toRelativePath:path replaceExisting:YES error:nil]);
}

- (MobaProfileSnapshot *)loadValidCaitlynSnapshot {
    NSError *error = nil;
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertNil(error);
    XCTAssertNotNil(self.repository.activeSnapshot);
    return self.repository.activeSnapshot;
}

- (void)assertInvalidReloadAtPath:(NSString *)path mutation:(void (^)(NSMutableDictionary *))mutation {
    MobaProfileSnapshot *original = [self loadValidCaitlynSnapshot];
    NSMutableDictionary *json = [self storedJSONAtPath:path];
    mutation(json);
    [self writeJSON:json path:path];
    NSError *error = nil;
    XCTAssertFalse([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertNotNil(error);
    XCTAssertTrue(self.repository.activeSnapshot == original);
}

- (void)testStoreBootstrapProfilesComposeFirstTransactionalSnapshot {
    MobaProfileSnapshot *snapshot = [self loadValidCaitlynSnapshot];
    XCTAssertEqualObjects(snapshot.runtimeProfile.videoMode, @"aspectFit");
    XCTAssertEqualObjects(snapshot.inputProfile.profileID, @"lol-wasd-default");
    XCTAssertEqualObjects(snapshot.layoutProfile.layoutID, @"ipad-pro-13-default");
    XCTAssertEqualObjects(snapshot.championProfile.championID, @"caitlyn");
}

- (void)testInvalidFirstCandidateLeavesActiveSnapshotNil {
    NSMutableDictionary *runtime = [self storedJSONAtPath:@"runtime.json"];
    runtime[@"videoMode"] = @"stretch";
    [self writeJSON:runtime path:@"runtime.json"];
    NSError *error = nil;
    XCTAssertFalse([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertNotNil(error);
    XCTAssertNil(self.repository.activeSnapshot);
}

- (void)testDebugInstantCanReplaceAnotherFullyValidCandidate {
    MobaProfileSnapshot *caitlyn = [self loadValidCaitlynSnapshot];
    NSError *error = nil;
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/debug-instant.json" error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse(self.repository.activeSnapshot == caitlyn);
    XCTAssertEqualObjects(self.repository.activeSnapshot.championProfile.championID, @"debug-instant");
    XCTAssertEqual(self.repository.activeSnapshot.championProfile.skills[@"Q"].castType,
                   MobaProfileSkillCastTypeInstant);
}

- (void)testInvalidRuntimeReloadPreservesActiveSnapshotIdentity {
    [self assertInvalidReloadAtPath:@"runtime.json" mutation:^(NSMutableDictionary *json) {
        json[@"canvas"][@"width"] = @1920;
    }];
}

- (void)testInvalidInputReloadPreservesActiveSnapshotIdentity {
    [self assertInvalidReloadAtPath:@"input.json" mutation:^(NSMutableDictionary *json) {
        [json[@"movement"] removeObjectForKey:@"up"];
    }];
}

- (void)testInvalidLayoutReloadPreservesActiveSnapshotIdentity {
    [self assertInvalidReloadAtPath:@"active-layout.json" mutation:^(NSMutableDictionary *json) {
        json[@"controls"][@"move"][@"opacity"] = @2;
    }];
}

- (void)testInvalidChampionReloadPreservesActiveSnapshotIdentity {
    [self assertInvalidReloadAtPath:@"champions/caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"W"][@"targetMode"] = @"automatic";
    }];
}

- (void)testCrossProfileMissingActionReportsReferencePathAndPreservesSnapshot {
    MobaProfileSnapshot *original = [self loadValidCaitlynSnapshot];
    NSMutableDictionary *json = [self storedJSONAtPath:@"champions/caitlyn.json"];
    json[@"skills"][@"W"][@"inputAction"] = @"missingAction";
    [self writeJSON:json path:@"champions/caitlyn.json"];
    NSError *error = nil;
    XCTAssertFalse([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertTrue(self.repository.activeSnapshot == original);
    XCTAssertEqual(error.code, MobaProfileErrorCrossProfileReferenceInvalid);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorProfileKindKey], MobaProfileKindChampion);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$.skills.W.inputAction");
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorOperationKey], @"cross-profile-validation");
}

- (void)testStorageReadFailureWrapsStoreErrorAndPreservesSnapshot {
    MobaProfileSnapshot *original = [self loadValidCaitlynSnapshot];
    NSURL *inputURL = [self.rootURL URLByAppendingPathComponent:@"input.json"];
    XCTAssertTrue([self.fileManager removeItemAtURL:inputURL error:nil]);
    NSError *error = nil;
    XCTAssertFalse([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertTrue(self.repository.activeSnapshot == original);
    XCTAssertEqual(error.code, MobaProfileErrorStorageReadFailed);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorProfileKindKey], MobaProfileKindInput);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], @"$");
    XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
}

- (void)testArbitraryStoreBytesAreAcceptedByStoreThenRejectedByDecoder {
    MobaProfileSnapshot *original = [self loadValidCaitlynSnapshot];
    NSData *bytes = [NSData dataWithBytes:(const unsigned char[]){0x00, 0xFF, 0x10} length:3];
    XCTAssertTrue([self.store writeData:bytes
                         toRelativePath:@"runtime.json"
                        replaceExisting:YES
                                  error:nil]);
    XCTAssertEqualObjects([self.store readDataAtRelativePath:@"runtime.json" error:nil], bytes);
    NSError *error = nil;
    XCTAssertFalse([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:&error]);
    XCTAssertTrue(self.repository.activeSnapshot == original);
    XCTAssertEqual(error.code, MobaProfileErrorJSONParseFailed);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorProfileKindKey], MobaProfileKindRuntime);
}

- (void)testSuccessfulV1LoadDoesNotRewriteStoredBytes {
    NSArray<NSString *> *paths = @[
        @"runtime.json",
        @"input.json",
        @"active-layout.json",
        @"champions/caitlyn.json",
    ];
    NSMutableDictionary<NSString *, NSData *> *before = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSDate *> *dates = [NSMutableDictionary dictionary];
    for (NSString *path in paths) {
        NSURL *url = [self.rootURL URLByAppendingPathComponent:path];
        before[path] = [NSData dataWithContentsOfURL:url];
        dates[path] = [self.fileManager attributesOfItemAtPath:url.path error:nil][NSFileModificationDate];
    }
    [self loadValidCaitlynSnapshot];
    for (NSString *path in paths) {
        NSURL *url = [self.rootURL URLByAppendingPathComponent:path];
        XCTAssertEqualObjects([NSData dataWithContentsOfURL:url], before[path]);
        XCTAssertEqualObjects([self.fileManager attributesOfItemAtPath:url.path error:nil][NSFileModificationDate],
                              dates[path]);
    }
}

- (void)testExplicitChampionPathStillUsesStandardRuntimeInputAndLayoutPaths {
    NSError *error = nil;
    XCTAssertTrue([self.repository loadRuntimeRelativePath:MobaRuntimeProfileRelativePath
                                         inputRelativePath:MobaInputProfileRelativePath
                                        layoutRelativePath:MobaActiveLayoutProfileRelativePath
                                      championRelativePath:@"champions/debug-instant.json"
                                                     error:&error]);
    XCTAssertNil(error);
    XCTAssertEqualObjects(self.repository.activeSnapshot.championProfile.championID, @"debug-instant");
}

@end
