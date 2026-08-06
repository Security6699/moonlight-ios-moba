//
//  MobaChampionSelectionControllerTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastStrategyFactory.h"
#import "../Limelight/Input/MOBA/Controls/MobaSkillControlPackage.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"
#import "../Limelight/Input/MOBA/Profiles/MobaChampionSelectionController.h"
#import "../Limelight/Input/MOBA/Profiles/MobaProfileStore.h"

@interface MobaSelectionResourceProvider : NSObject <MobaProfileResourceProviding>
@property (nonatomic, copy) NSDictionary<NSString *, NSURL *> *resourceURLs;
@end
@implementation MobaSelectionResourceProvider
- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)extension {
    return self.resourceURLs[[name stringByAppendingPathExtension:extension]];
}
@end

@interface MobaSelectionSink : NSObject <MobaInputSink>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end
@implementation MobaSelectionSink
- (instancetype)init { self = [super init]; if (self) _events = [NSMutableArray array]; return self; }
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    @synchronized (self) { [self.events addObject:[NSString stringWithFormat:@"key-%u-%@", keyCode, down ? @"down" : @"up"]]; }
}
- (void)moveCursorToCanvasPoint:(CGPoint)point {
    @synchronized (self) { [self.events addObject:[NSString stringWithFormat:@"cursor-%.0f-%.0f", point.x, point.y]]; }
}
- (void)sendMouseButton:(int)button down:(BOOL)down {
    @synchronized (self) { [self.events addObject:[NSString stringWithFormat:@"mouse-%d-%@", button, down ? @"down" : @"up"]]; }
}
@end

@interface MobaSelectionDriver : NSObject <MobaDisplayLinkDriving>
@property (nonatomic, getter=isRunning) BOOL running;
@end
@implementation MobaSelectionDriver
- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate tickHandler:(MobaDisplayLinkTickHandler)tickHandler {
    (void)updateRate; (void)tickHandler; self.running = YES; return YES;
}
- (void)stop { self.running = NO; }
@end

@interface MobaSelectionDriverProvider : NSObject <MobaDisplayLinkDriverProviding>
@property (nonatomic, strong) NSMutableArray<MobaSelectionDriver *> *drivers;
@property (nonatomic) NSInteger failAtCreationIndex;
@end
@implementation MobaSelectionDriverProvider
- (instancetype)init { self = [super init]; if (self) { _drivers = [NSMutableArray array]; _failAtCreationIndex = -1; } return self; }
- (id<MobaDisplayLinkDriving>)newDisplayLinkDriver {
    if ((NSInteger)self.drivers.count == self.failAtCreationIndex) return nil;
    MobaSelectionDriver *driver = [[MobaSelectionDriver alloc] init];
    [self.drivers addObject:driver];
    return driver;
}
@end

@interface MobaSelectionLifecycle : NSObject <MobaChampionSelectionLifecycle>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<id<MobaLocalInteractionResetParticipant>> *participants;
@property (nonatomic) NSUInteger willCount;
@property (nonatomic) NSUInteger didCount;
@property (nonatomic) BOOL gateOpen;
@end
@implementation MobaSelectionLifecycle
- (instancetype)init { self = [super init]; if (self) { _events = [NSMutableArray array]; _participants = [NSMutableArray array]; _gateOpen = YES; } return self; }
- (void)profileWillReload {
    self.willCount += 1;
    self.gateOpen = NO;
    [self.events addObject:@"will"];
    for (id<MobaLocalInteractionResetParticipant> participant in [self.participants copy]) {
        if ([participant respondsToSelector:@selector(setMobaLocalInteractionEnabled:)]) {
            [participant setMobaLocalInteractionEnabled:NO];
        }
        [participant resetMobaLocalInteractionForReason:MobaInputInterruptionReasonProfileReload];
    }
}
- (void)profileDidReload { self.didCount += 1; self.gateOpen = YES; [self.events addObject:@"did"]; }
- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    [self.events addObject:@"register"];
    if (![self.participants containsObject:participant]) [self.participants addObject:participant];
}
- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    [self.events addObject:@"unregister"];
    [self.participants removeObject:participant];
}
@end

@interface MobaSelectionObservingBuilder : NSObject <MobaChampionRuntimeBuilding>
@property (nonatomic, strong) id<MobaChampionRuntimeBuilding> wrappedBuilder;
@property (nonatomic, copy) void (^buildObserver)(MobaProfileSnapshot *snapshot);
@end
@implementation MobaSelectionObservingBuilder
- (MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot error:(NSError **)error {
    if (self.buildObserver != nil) self.buildObserver(snapshot);
    return [self.wrappedBuilder runtimeFromSnapshot:snapshot error:error];
}
@end

@interface MobaSelectionEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic, getter=isMobaBattleModeSupported) BOOL mobaBattleModeSupported;
@end
@implementation MobaSelectionEnvironment
- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed { (void)suppressed; }
- (void)setMobaNativeTouchRoutingEnabled:(BOOL)enabled { (void)enabled; }
@end

@interface MobaSelectionFakeSkillController : NSObject
@property (nonatomic) NSUInteger silentResetCount;
- (void)silentReset;
@end
@implementation MobaSelectionFakeSkillController
- (void)silentReset { self.silentResetCount += 1; }
@end

@interface MobaSelectionFakeSkillView : NSObject <MobaLocalInteractionResetParticipant>
@property (nonatomic) NSUInteger resetCount;
@property (nonatomic) NSUInteger disableCount;
@end
@implementation MobaSelectionFakeSkillView
- (void)setMobaLocalInteractionEnabled:(BOOL)enabled {
    if (!enabled) self.disableCount += 1;
}
- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason {
    (void)reason;
    self.resetCount += 1;
}
@end

@interface MobaSelectionControlPackageBuilder : NSObject <MobaSkillControlPackageBuilding>
@property (nonatomic) BOOL failNextBuild;
@property (nonatomic) NSUInteger buildCount;
@property (nonatomic, strong, nullable) MobaSkillControlPackage *lastBuiltPackage;
@property (nonatomic, strong, nullable) MobaSelectionFakeSkillController *lastPartialController;
@end
@implementation MobaSelectionControlPackageBuilder
- (nullable MobaSkillControlPackage *)controlPackageForRuntime:(MobaChampionRuntime *)runtime
                                                         error:(NSError **)error {
    (void)runtime;
    self.buildCount += 1;
    NSMutableDictionary *controllers = [NSMutableDictionary dictionary];
    NSMutableDictionary *views = [NSMutableDictionary dictionary];
    NSArray<NSString *> *slots = self.failNextBuild ? @[MobaCanonicalSkillSlotQ] : MobaCanonicalSkillSlots();
    for (MobaCanonicalSkillSlot slot in slots) {
        MobaSelectionFakeSkillController *controller = [[MobaSelectionFakeSkillController alloc] init];
        controllers[slot] = controller;
        if (self.failNextBuild) {
            self.lastPartialController = controller;
            break;
        }
        views[slot] = [[MobaSelectionFakeSkillView alloc] init];
    }
    self.failNextBuild = NO;
    self.lastBuiltPackage = [[MobaSkillControlPackage alloc]
        initWithControllers:(NSDictionary *)controllers skillButtonViews:(NSDictionary *)views];
    if (!self.lastBuiltPackage.isComplete && error != NULL) {
        *error = [NSError errorWithDomain:MobaChampionSelectionErrorDomain
                                     code:MobaChampionSelectionErrorControlPackageBuildFailed
                                 userInfo:@{NSLocalizedDescriptionKey: @"Injected package build failure."}];
    }
    return self.lastBuiltPackage;
}
@end

@interface MobaSelectionRuntimeDelegate : NSObject <MobaChampionSelectionControllerDelegate>
@property (nonatomic, strong) NSMutableArray<MobaChampionRuntime *> *runtimes;
@property (nonatomic, strong) NSMutableArray<MobaSkillControlPackage *> *packages;
@property (nonatomic, weak, nullable) MobaSelectionLifecycle *lifecycle;
@property (nonatomic, strong, nullable) MobaSkillControlPackage *installedPackage;
@end
@implementation MobaSelectionRuntimeDelegate
- (instancetype)init {
    self = [super init];
    if (self) {
        _runtimes = [[NSMutableArray alloc] init];
        _packages = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)championSelectionController:(MobaChampionSelectionController *)controller
                    didSelectRuntime:(MobaChampionRuntime *)runtime
                 skillControlPackage:(nullable MobaSkillControlPackage *)skillControlPackage {
    (void)controller;
    [self.runtimes addObject:runtime];
    if (skillControlPackage != nil) {
        [self.packages addObject:skillControlPackage];
    }
    for (id<MobaLocalInteractionResetParticipant> participant in self.installedPackage.localInteractionResetParticipants) {
        [self.lifecycle unregisterLocalInteractionResetParticipant:participant];
    }
    self.installedPackage = skillControlPackage;
    for (id<MobaLocalInteractionResetParticipant> participant in skillControlPackage.localInteractionResetParticipants) {
        [self.lifecycle registerLocalInteractionResetParticipant:participant];
    }
}
@end

@interface MobaChampionSelectionControllerTests : XCTestCase
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSURL *containerURL;
@property (nonatomic, strong) MobaProfileStore *store;
@property (nonatomic, strong) MobaProfileRepository *repository;
@property (nonatomic, strong) MobaSelectionSink *sink;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaSelectionDriverProvider *provider;
@property (nonatomic, strong) MobaCastStrategyFactory *factory;
@property (nonatomic, strong) MobaSelectionLifecycle *lifecycle;
@property (nonatomic, strong) MobaChampionSelectionController *selection;
@end

@implementation MobaChampionSelectionControllerTests

- (NSURL *)exampleURL:(NSString *)fileName {
    NSString *testDirectory = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSArray *roots = @[[testDirectory stringByDeletingLastPathComponent],
                       NSProcessInfo.processInfo.environment[@"SRCROOT"] ?: @"",
                       NSFileManager.defaultManager.currentDirectoryPath];
    for (NSString *root in roots) {
        NSString *path = [[root stringByAppendingPathComponent:@"examples/moba"] stringByAppendingPathComponent:fileName];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) return [NSURL fileURLWithPath:path];
    }
    XCTFail(@"Unable to locate example %@", fileName);
    return [NSURL fileURLWithPath:fileName];
}

- (void)setUp {
    [super setUp];
    self.fileManager = [[NSFileManager alloc] init];
    self.containerURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"MobaChampionSelection-%@", NSUUID.UUID.UUIDString]
                    isDirectory:YES];
    NSURL *rootURL = [self.containerURL URLByAppendingPathComponent:@"MOBA" isDirectory:YES];
    MobaSelectionResourceProvider *resources = [[MobaSelectionResourceProvider alloc] init];
    NSMutableDictionary *urls = [NSMutableDictionary dictionary];
    for (NSString *name in @[@"runtime.json", @"input.json", @"ipad-pro-13-layout.json", @"caitlyn.json", @"debug-instant.json"]) {
        urls[name] = [self exampleURL:name];
    }
    resources.resourceURLs = urls;
    self.store = [[MobaProfileStore alloc] initWithRootDirectoryURL:rootURL
                                                   resourceProvider:resources
                                                        fileManager:self.fileManager];
    NSError *error = nil;
    XCTAssertTrue([self.store bootstrapDefaultsWithError:&error]);
    XCTAssertNil(error);
    self.repository = [[MobaProfileRepository alloc] initWithStore:self.store];
    self.sink = [[MobaSelectionSink alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink];
    self.provider = [[MobaSelectionDriverProvider alloc] init];
    self.factory = [[MobaCastStrategyFactory alloc] initWithDispatcher:self.dispatcher driverProvider:self.provider];
    self.lifecycle = [[MobaSelectionLifecycle alloc] init];
    self.selection = [[MobaChampionSelectionController alloc] initWithRepository:self.repository
                                                                   runtimeBuilder:self.factory
                                                                        lifecycle:self.lifecycle];
}

- (void)tearDown {
    [self.selection invalidate];
    [self.fileManager removeItemAtURL:self.containerURL error:nil];
    [super tearDown];
}

- (void)waitForDispatcher:(MobaInputDispatcher *)dispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"dispatcher idle"];
    [dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)testDefaultCatalogCentralizesOnlyCaitlynAndDebugPaths {
    XCTAssertEqual(self.selection.catalogEntries.count, 2u);
    MobaChampionCatalogEntry *caitlyn = [self.selection catalogEntryForChampionID:@"caitlyn"];
    MobaChampionCatalogEntry *debug = [self.selection catalogEntryForChampionID:@"debug-instant"];
    XCTAssertEqualObjects(caitlyn.championRelativePath, @"champions/caitlyn.json");
    XCTAssertEqualObjects(debug.championRelativePath, @"champions/debug-instant.json");
}

- (void)testInitialCaitlynSelectionSucceedsTransactionally {
    NSError *error = nil;
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:&error]);
    XCTAssertNil(error);
    XCTAssertEqualObjects(self.selection.selectedChampionID, @"caitlyn");
    XCTAssertEqualObjects(self.selection.activeChampionRuntime.championID, @"caitlyn");
    XCTAssertEqualObjects(self.repository.activeSnapshot.championProfile.championID, @"caitlyn");
}

- (void)testCaitlynDebugAndBackSelectionsSucceed {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    XCTAssertEqualObjects(self.selection.activeChampionRuntime.championID, @"debug-instant");
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertEqualObjects(self.selection.activeChampionRuntime.championID, @"caitlyn");
}

- (void)testRepeatedSelectionIsNoOpWithoutReloadOrRuntimeReplacement {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    MobaChampionRuntime *runtime = self.selection.activeChampionRuntime;
    MobaProfileSnapshot *snapshot = self.repository.activeSnapshot;
    NSUInteger willCount = self.lifecycle.willCount;
    NSUInteger didCount = self.lifecycle.didCount;
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertTrue(runtime == self.selection.activeChampionRuntime);
    XCTAssertTrue(snapshot == self.repository.activeSnapshot);
    XCTAssertEqual(self.lifecycle.willCount, willCount);
    XCTAssertEqual(self.lifecycle.didCount, didCount);
}

- (void)testInvalidProfilePreservesSnapshotRuntimeSelectionAndParticipants {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    MobaProfileSnapshot *snapshot = self.repository.activeSnapshot;
    MobaChampionRuntime *runtime = self.selection.activeChampionRuntime;
    NSArray *participants = [self.lifecycle.participants copy];
    NSData *invalid = [@"not-json" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.store writeData:invalid
                         toRelativePath:@"champions/debug-instant.json"
                        replaceExisting:YES error:nil]);
    NSError *error = nil;
    XCTAssertFalse([self.selection selectChampionID:@"debug-instant" error:&error]);
    XCTAssertNotNil(error);
    XCTAssertTrue(snapshot == self.repository.activeSnapshot);
    XCTAssertTrue(runtime == self.selection.activeChampionRuntime);
    XCTAssertEqualObjects(self.selection.selectedChampionID, @"caitlyn");
    XCTAssertEqualObjects(self.lifecycle.participants, participants);
}

- (void)testValidProfileFactoryFailurePreservesAllActiveStateAndLeavesDriversStopped {
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    MobaProfileSnapshot *snapshot = self.repository.activeSnapshot;
    MobaChampionRuntime *runtime = self.selection.activeChampionRuntime;
    self.provider.failAtCreationIndex = 2;
    NSError *error = nil;
    XCTAssertFalse([self.selection selectChampionID:@"caitlyn" error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorDisplayLinkCreationFailed);
    XCTAssertTrue(snapshot == self.repository.activeSnapshot);
    XCTAssertTrue(runtime == self.selection.activeChampionRuntime);
    XCTAssertEqualObjects(self.selection.selectedChampionID, @"debug-instant");
    for (MobaSelectionDriver *driver in self.provider.drivers) XCTAssertFalse(driver.isRunning);
}

- (void)testWillReloadPrecedesOldParticipantUnregistrationAndDidAlwaysPairs {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    [self.lifecycle.events removeAllObjects];
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    XCTAssertEqualObjects(self.lifecycle.events.firstObject, @"will");
    XCTAssertTrue([self.lifecycle.events indexOfObject:@"unregister"] > [self.lifecycle.events indexOfObject:@"will"]);
    XCTAssertEqualObjects(self.lifecycle.events.lastObject, @"did");
    NSUInteger didBeforeFailure = self.lifecycle.didCount;
    XCTAssertFalse([self.selection selectChampionID:@"unknown" error:nil]);
    XCTAssertEqual(self.lifecycle.didCount, didBeforeFailure);
    NSData *invalid = [@"{" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.store writeData:invalid toRelativePath:@"champions/caitlyn.json" replaceExisting:YES error:nil]);
    XCTAssertFalse([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertEqual(self.lifecycle.willCount, self.lifecycle.didCount);
}

- (void)testSuccessfulSwitchUnregistersOldCoalescersAndRegistersNewOnes {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    NSArray *oldParticipants = [self.lifecycle.participants copy];
    XCTAssertEqual(oldParticipants.count, 4u);
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    XCTAssertEqual(self.lifecycle.participants.count, 0u);
    for (id participant in oldParticipants) XCTAssertFalse([self.lifecycle.participants containsObject:participant]);
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertEqual(self.lifecycle.participants.count, 4u);
    for (id participant in oldParticipants) XCTAssertFalse([self.lifecycle.participants containsObject:participant]);
}

- (void)testSuccessfulSelectionNotifiesRuntimeDelegateInsideExistingTransaction {
    MobaSelectionRuntimeDelegate *delegate = [[MobaSelectionRuntimeDelegate alloc] init];
    self.selection.delegate = delegate;
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertEqual(delegate.runtimes.count, 1u);
    XCTAssertEqual(delegate.runtimes.firstObject, self.selection.activeChampionRuntime);
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    XCTAssertEqual(delegate.runtimes.count, 2u);
    XCTAssertEqual(delegate.runtimes.lastObject, self.selection.activeChampionRuntime);
}

- (void)testCandidateControlPackageFailurePreservesAllCommittedStateAndCleansCandidate {
    MobaSelectionControlPackageBuilder *packageBuilder = [[MobaSelectionControlPackageBuilder alloc] init];
    MobaSelectionRuntimeDelegate *delegate = [[MobaSelectionRuntimeDelegate alloc] init];
    delegate.lifecycle = self.lifecycle;
    MobaChampionSelectionController *selection = [[MobaChampionSelectionController alloc]
        initWithRepository:self.repository
             runtimeBuilder:self.factory
    controlPackageBuilder:packageBuilder
                  lifecycle:self.lifecycle];
    selection.delegate = delegate;
    XCTAssertTrue([selection selectChampionID:@"caitlyn" error:nil]);

    MobaProfileSnapshot *snapshot = self.repository.activeSnapshot;
    MobaChampionRuntime *runtime = selection.activeChampionRuntime;
    MobaSkillControlPackage *package = selection.activeSkillControlPackage;
    NSDictionary *views = package.skillButtonViews;
    NSArray *participants = [self.lifecycle.participants copy];
    NSUInteger didCount = self.lifecycle.didCount;
    [self.sink.events removeAllObjects];

    packageBuilder.failNextBuild = YES;
    NSError *error = nil;
    XCTAssertFalse([selection selectChampionID:@"debug-instant" error:&error]);
    XCTAssertEqual(error.code, MobaChampionSelectionErrorControlPackageBuildFailed);
    XCTAssertTrue(snapshot == self.repository.activeSnapshot);
    XCTAssertTrue(runtime == selection.activeChampionRuntime);
    XCTAssertEqualObjects(selection.selectedChampionID, @"caitlyn");
    XCTAssertTrue(package == selection.activeSkillControlPackage);
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        XCTAssertTrue(views[slot] == selection.activeSkillControlPackage.skillButtonViews[slot]);
    }
    XCTAssertEqualObjects(self.lifecycle.participants, participants);
    XCTAssertEqual(packageBuilder.lastPartialController.silentResetCount, 1u);
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(self.lifecycle.didCount, didCount + 1);
    XCTAssertEqual(delegate.packages.count, 1u);
    [selection invalidate];
}

- (void)testSuccessfulSelectionInstallsOnePrebuiltPackageAndSwapsViewParticipantsOnce {
    MobaSelectionControlPackageBuilder *packageBuilder = [[MobaSelectionControlPackageBuilder alloc] init];
    MobaSelectionRuntimeDelegate *delegate = [[MobaSelectionRuntimeDelegate alloc] init];
    delegate.lifecycle = self.lifecycle;
    MobaChampionSelectionController *selection = [[MobaChampionSelectionController alloc]
        initWithRepository:self.repository
             runtimeBuilder:self.factory
    controlPackageBuilder:packageBuilder
                  lifecycle:self.lifecycle];
    selection.delegate = delegate;
    XCTAssertTrue([selection selectChampionID:@"caitlyn" error:nil]);
    MobaSkillControlPackage *oldPackage = selection.activeSkillControlPackage;
    NSArray *oldViewParticipants = oldPackage.localInteractionResetParticipants;
    [self.lifecycle.events removeAllObjects];
    NSUInteger buildsBefore = packageBuilder.buildCount;

    XCTAssertTrue([selection selectChampionID:@"debug-instant" error:nil]);
    MobaSkillControlPackage *newPackage = selection.activeSkillControlPackage;
    XCTAssertTrue(newPackage == packageBuilder.lastBuiltPackage);
    XCTAssertTrue(newPackage == delegate.installedPackage);
    XCTAssertEqual(packageBuilder.buildCount, buildsBefore + 1);
    XCTAssertEqual(newPackage.skillButtonViews.count, 4u);
    for (id participant in oldViewParticipants) {
        XCTAssertFalse([self.lifecycle.participants containsObject:participant]);
    }
    for (id participant in newPackage.localInteractionResetParticipants) {
        XCTAssertTrue([self.lifecycle.participants containsObject:participant]);
        NSUInteger occurrences = 0;
        for (id registeredParticipant in self.lifecycle.participants) {
            if (registeredParticipant == participant) occurrences += 1;
        }
        XCTAssertEqual(occurrences, 1u);
    }
    NSPredicate *unregisterEvent = [NSPredicate predicateWithFormat:@"SELF == 'unregister'"];
    NSPredicate *registerEvent = [NSPredicate predicateWithFormat:@"SELF == 'register'"];
    XCTAssertEqual([[self.lifecycle.events filteredArrayUsingPredicate:unregisterEvent] count], 8u);
    XCTAssertEqual([[self.lifecycle.events filteredArrayUsingPredicate:registerEvent] count], 4u);
    XCTAssertEqual(delegate.packages.count, 2u);
    [selection invalidate];
}

- (void)testFailedSelectionDoesNotNotifyRuntimeDelegate {
    MobaSelectionRuntimeDelegate *delegate = [[MobaSelectionRuntimeDelegate alloc] init];
    self.selection.delegate = delegate;
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertEqual(delegate.runtimes.count, 1u);
    NSData *invalid = [@"{" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([self.store writeData:invalid
                         toRelativePath:@"champions/debug-instant.json"
                       replaceExisting:YES
                                  error:nil]);
    XCTAssertFalse([self.selection selectChampionID:@"debug-instant" error:nil]);
    XCTAssertEqual(delegate.runtimes.count, 1u);
}

- (void)testFailedSwitchKeepsOldCoalescersRegisteredAndCleansCandidateDrivers {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    NSArray *oldParticipants = [self.lifecycle.participants copy];
    NSMutableDictionary *debugJSON = [NSJSONSerialization JSONObjectWithData:[self.store readDataAtRelativePath:@"champions/debug-instant.json" error:nil]
                                                                      options:NSJSONReadingMutableContainers error:nil];
    [debugJSON[@"skills"] removeObjectForKey:@"W"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:debugJSON options:0 error:nil];
    XCTAssertTrue([self.store writeData:data toRelativePath:@"champions/debug-instant.json" replaceExisting:YES error:nil]);
    XCTAssertFalse([self.selection selectChampionID:@"debug-instant" error:nil]);
    XCTAssertEqualObjects(self.lifecycle.participants, oldParticipants);
    for (MobaSelectionDriver *driver in self.provider.drivers) XCTAssertFalse(driver.isRunning);
}

- (void)testRuntimeBuildOccursWhileProfileReloadGateIsClosed {
    MobaSelectionObservingBuilder *builder = [[MobaSelectionObservingBuilder alloc] init];
    builder.wrappedBuilder = self.factory;
    __block BOOL observedClosedGate = NO;
    builder.buildObserver = ^(MobaProfileSnapshot *snapshot) {
        (void)snapshot;
        observedClosedGate = !self.lifecycle.gateOpen;
    };
    MobaChampionSelectionController *selection = [[MobaChampionSelectionController alloc]
        initWithRepository:self.repository runtimeBuilder:builder lifecycle:self.lifecycle];
    XCTAssertTrue([selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertTrue(observedClosedGate);
    [selection invalidate];
}

- (void)testRepositoryCandidateValidatorFailurePreservesExactErrorAndSnapshot {
    XCTAssertTrue([self.repository reloadWithChampionRelativePath:@"champions/caitlyn.json" error:nil]);
    MobaProfileSnapshot *snapshot = self.repository.activeSnapshot;
    NSError *expected = [NSError errorWithDomain:MobaCastStrategyFactoryErrorDomain
                                             code:MobaCastStrategyFactoryErrorConfigurationRejected
                                         userInfo:@{MobaCastStrategyFactoryFieldPathKey: @"$.skills.W"}];
    NSError *error = nil;
    XCTAssertFalse([self.repository reloadWithChampionRelativePath:@"champions/debug-instant.json"
                                                 candidateValidator:^BOOL(MobaProfileSnapshot *candidate, NSError **candidateError) {
        (void)candidate;
        if (candidateError != NULL) *candidateError = expected;
        return NO;
    } error:&error]);
    XCTAssertTrue(snapshot == self.repository.activeSnapshot);
    XCTAssertTrue(error == expected);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryFieldPathKey], @"$.skills.W");
}

- (void)testSelectionDoesNotRewriteProfileBytesOrModificationDates {
    NSArray *paths = @[@"runtime.json", @"input.json", @"active-layout.json",
                       @"champions/caitlyn.json", @"champions/debug-instant.json"];
    NSMutableDictionary *bytes = [NSMutableDictionary dictionary];
    NSMutableDictionary *dates = [NSMutableDictionary dictionary];
    for (NSString *path in paths) {
        bytes[path] = [self.store readDataAtRelativePath:path error:nil];
        NSURL *url = [self.store.rootDirectoryURL URLByAppendingPathComponent:path];
        dates[path] = [[self.fileManager attributesOfItemAtPath:url.path error:nil] fileModificationDate];
    }
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    for (NSString *path in paths) {
        XCTAssertEqualObjects([self.store readDataAtRelativePath:path error:nil], bytes[path]);
        NSURL *url = [self.store.rootDirectoryURL URLByAppendingPathComponent:path];
        XCTAssertEqualObjects([[self.fileManager attributesOfItemAtPath:url.path error:nil] fileModificationDate], dates[path]);
    }
}

- (void)testChampionSwitchPreservesRuntimeInputAndLayoutConfigurationContents {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    MobaProfileSnapshot *before = self.repository.activeSnapshot;
    XCTAssertTrue([self.selection selectChampionID:@"debug-instant" error:nil]);
    MobaProfileSnapshot *after = self.repository.activeSnapshot;
    XCTAssertEqual(before.runtimeProfile.mouseUpdateRateHz, after.runtimeProfile.mouseUpdateRateHz);
    XCTAssertEqualWithAccuracy(before.runtimeProfile.camera.heroAnchor.x, after.runtimeProfile.camera.heroAnchor.x, 0.0001);
    XCTAssertEqualObjects(before.inputProfile.profileID, after.inputProfile.profileID);
    XCTAssertEqualObjects(before.inputProfile.actions, after.inputProfile.actions);
    XCTAssertEqualObjects(before.layoutProfile.layoutID, after.layoutProfile.layoutID);
    XCTAssertEqual(before.layoutProfile.controls.count, after.layoutProfile.controls.count);
}

- (void)testActualLifecycleReloadReleasesTrackedKeyOnceWithoutCancelAction {
    MobaSelectionSink *sink = [[MobaSelectionSink alloc] init];
    MobaInputDispatcher *dispatcher = [[MobaInputDispatcher alloc] initWithSink:sink];
    MobaSelectionEnvironment *environment = [[MobaSelectionEnvironment alloc] init];
    environment.mobaBattleModeSupported = YES;
    MobaOverlayLifecycle *lifecycle = [[MobaOverlayLifecycle alloc] initWithEnvironment:environment
                                                                        inputDispatcher:dispatcher];
    MobaSelectionDriverProvider *provider = [[MobaSelectionDriverProvider alloc] init];
    MobaCastStrategyFactory *factory = [[MobaCastStrategyFactory alloc] initWithDispatcher:dispatcher driverProvider:provider];
    MobaChampionSelectionController *selection = [[MobaChampionSelectionController alloc]
        initWithRepository:self.repository runtimeBuilder:factory lifecycle:(id<MobaChampionSelectionLifecycle>)lifecycle];
    XCTAssertTrue([selection selectChampionID:@"caitlyn" error:nil]);
    [lifecycle start];
    [dispatcher setKeyCode:87 down:YES];
    [self waitForDispatcher:dispatcher];
    XCTAssertTrue([selection selectChampionID:@"debug-instant" error:nil]);
    [self waitForDispatcher:dispatcher];
    NSPredicate *wUp = [NSPredicate predicateWithFormat:@"SELF == %@", @"key-87-up"];
    NSPredicate *escapeEvent = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", @"key-27-"];
    NSPredicate *mouseEvent = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", @"mouse-"];
    XCTAssertEqual([[sink.events filteredArrayUsingPredicate:wUp] count], 1u);
    XCTAssertEqual([[sink.events filteredArrayUsingPredicate:escapeEvent] count], 0u);
    XCTAssertEqual([[sink.events filteredArrayUsingPredicate:mouseEvent] count], 0u);
    [selection invalidate];
    [lifecycle stop];
}

- (void)testExplicitReloadRebuildsSameChampionWithoutChangingSelection {
    XCTAssertTrue([self.selection selectChampionID:@"caitlyn" error:nil]);
    MobaProfileSnapshot *oldSnapshot = self.repository.activeSnapshot;
    MobaChampionRuntime *oldRuntime = self.selection.activeChampionRuntime;
    NSUInteger willCount = self.lifecycle.willCount;
    NSUInteger didCount = self.lifecycle.didCount;
    XCTAssertTrue([self.selection reloadSelectedChampionWithError:nil]);
    XCTAssertEqualObjects(self.selection.selectedChampionID, @"caitlyn");
    XCTAssertFalse(self.repository.activeSnapshot == oldSnapshot);
    XCTAssertFalse(self.selection.activeChampionRuntime == oldRuntime);
    XCTAssertEqual(self.lifecycle.willCount, willCount + 1);
    XCTAssertEqual(self.lifecycle.didCount, didCount + 1);
}

@end
