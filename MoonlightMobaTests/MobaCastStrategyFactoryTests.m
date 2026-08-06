//
//  MobaCastStrategyFactoryTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastStrategyFactory.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Profiles/MobaProfileDecoder.h"

@interface MobaFactorySink : NSObject <MobaInputSink>
@end
@implementation MobaFactorySink
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down { (void)keyCode; (void)down; }
- (void)moveCursorToCanvasPoint:(CGPoint)point { (void)point; }
- (void)sendMouseButton:(int)button down:(BOOL)down { (void)button; (void)down; }
@end

@interface MobaFactoryDriver : NSObject <MobaDisplayLinkDriving>
@property (nonatomic, getter=isRunning) BOOL running;
@property (nonatomic) MobaCursorUpdateRate updateRate;
@end
@implementation MobaFactoryDriver
- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate tickHandler:(MobaDisplayLinkTickHandler)tickHandler {
    (void)tickHandler;
    self.updateRate = updateRate;
    self.running = YES;
    return YES;
}
- (void)stop { self.running = NO; }
@end

@interface MobaFactoryDriverProvider : NSObject <MobaDisplayLinkDriverProviding>
@property (nonatomic, strong) NSMutableArray<MobaFactoryDriver *> *drivers;
@property (nonatomic) NSInteger failAtCreationIndex;
@end
@implementation MobaFactoryDriverProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _drivers = [NSMutableArray array];
        _failAtCreationIndex = -1;
    }
    return self;
}
- (id<MobaDisplayLinkDriving>)newDisplayLinkDriver {
    if (self.failAtCreationIndex == (NSInteger)self.drivers.count) {
        return nil;
    }
    MobaFactoryDriver *driver = [[MobaFactoryDriver alloc] init];
    [self.drivers addObject:driver];
    return driver;
}
@end

typedef void (^MobaFactoryJSONMutation)(NSMutableDictionary *json);

@interface MobaCastStrategyFactoryTests : XCTestCase
@property (nonatomic, strong) MobaProfileDecoder *decoder;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaFactoryDriverProvider *provider;
@property (nonatomic, strong) MobaCastStrategyFactory *factory;
@end

@implementation MobaCastStrategyFactoryTests

- (void)setUp {
    [super setUp];
    self.decoder = [[MobaProfileDecoder alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:[[MobaFactorySink alloc] init]];
    self.provider = [[MobaFactoryDriverProvider alloc] init];
    self.factory = [[MobaCastStrategyFactory alloc] initWithDispatcher:self.dispatcher
                                                        driverProvider:self.provider];
}

- (NSURL *)exampleURL:(NSString *)fileName {
    NSString *testDirectory = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSArray<NSString *> *roots = @[
        [testDirectory stringByDeletingLastPathComponent],
        NSProcessInfo.processInfo.environment[@"SRCROOT"] ?: @"",
        NSFileManager.defaultManager.currentDirectoryPath,
    ];
    for (NSString *root in roots) {
        NSString *path = [[root stringByAppendingPathComponent:@"examples/moba"]
            stringByAppendingPathComponent:fileName];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            return [NSURL fileURLWithPath:path];
        }
    }
    XCTFail(@"Unable to locate example %@", fileName);
    return [NSURL fileURLWithPath:fileName];
}

- (NSMutableDictionary *)exampleJSON:(NSString *)fileName {
    NSData *data = [NSData dataWithContentsOfURL:[self exampleURL:fileName]];
    XCTAssertNotNil(data);
    NSError *error = nil;
    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:&error];
    XCTAssertNil(error);
    return json;
}

- (NSData *)dataForJSON:(NSDictionary *)json {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    XCTAssertNil(error);
    return data;
}

- (MobaProfileSnapshot *)snapshotForChampionFile:(NSString *)championFile
                                  runtimeMutation:(MobaFactoryJSONMutation)runtimeMutation
                                    inputMutation:(MobaFactoryJSONMutation)inputMutation
                                   layoutMutation:(MobaFactoryJSONMutation)layoutMutation
                                 championMutation:(MobaFactoryJSONMutation)championMutation {
    NSMutableDictionary *runtimeJSON = [self exampleJSON:@"runtime.json"];
    NSMutableDictionary *inputJSON = [self exampleJSON:@"input.json"];
    NSMutableDictionary *layoutJSON = [self exampleJSON:@"ipad-pro-13-layout.json"];
    NSMutableDictionary *championJSON = [self exampleJSON:championFile];
    if (runtimeMutation != nil) runtimeMutation(runtimeJSON);
    if (inputMutation != nil) inputMutation(inputJSON);
    if (layoutMutation != nil) layoutMutation(layoutJSON);
    if (championMutation != nil) championMutation(championJSON);

    NSError *error = nil;
    MobaRuntimeProfile *runtime = [self.decoder decodeRuntimeProfileData:[self dataForJSON:runtimeJSON] error:&error];
    XCTAssertNotNil(runtime); XCTAssertNil(error);
    MobaInputProfile *input = [self.decoder decodeInputProfileData:[self dataForJSON:inputJSON] error:&error];
    XCTAssertNotNil(input); XCTAssertNil(error);
    MobaLayoutProfile *layout = [self.decoder decodeLayoutProfileData:[self dataForJSON:layoutJSON] error:&error];
    XCTAssertNotNil(layout); XCTAssertNil(error);
    MobaChampionProfile *champion = [self.decoder decodeChampionProfileData:[self dataForJSON:championJSON] error:&error];
    XCTAssertNotNil(champion); XCTAssertNil(error);
    return [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtime
                                                  inputProfile:input
                                                 layoutProfile:layout
                                               championProfile:champion];
}

- (MobaProfileSnapshot *)caitlynSnapshot {
    return [self snapshotForChampionFile:@"caitlyn.json"
                         runtimeMutation:nil inputMutation:nil layoutMutation:nil championMutation:nil];
}

- (MobaChampionRuntime *)runtimeForSnapshot:(MobaProfileSnapshot *)snapshot {
    NSError *error = nil;
    MobaChampionRuntime *runtime = [self.factory runtimeFromSnapshot:snapshot error:&error];
    XCTAssertNotNil(runtime);
    XCTAssertNil(error);
    return runtime;
}

- (void)testCaitlynUsesDirectionalGroundDirectionalAndUnitStrategies {
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:self.caitlynSnapshot];
    XCTAssertTrue([[runtime descriptorForSkillSlot:MobaCanonicalSkillSlotQ].strategy isKindOfClass:MobaDirectionalCastStrategy.class]);
    XCTAssertEqual([runtime descriptorForSkillSlot:MobaCanonicalSkillSlotW].pointConfiguration.targetMode, MobaPointCastTargetModeGround);
    XCTAssertTrue([[runtime descriptorForSkillSlot:MobaCanonicalSkillSlotE].strategy isKindOfClass:MobaDirectionalCastStrategy.class]);
    XCTAssertEqual([runtime descriptorForSkillSlot:MobaCanonicalSkillSlotR].pointConfiguration.targetMode, MobaPointCastTargetModeUnit);
}

- (void)testCaitlynHasNoInstantActiveSkill {
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:self.caitlynSnapshot];
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        XCTAssertFalse([[runtime descriptorForSkillSlot:slot].strategy isKindOfClass:MobaInstantCastStrategy.class]);
        XCTAssertNil([runtime descriptorForSkillSlot:slot].instantConfiguration);
    }
}

- (void)testDebugProfileMapsAllCanonicalSlotsToInstantWithoutCoalescers {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"debug-instant.json"
                                                  runtimeMutation:nil inputMutation:nil layoutMutation:nil championMutation:nil];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        MobaSkillRuntimeDescriptor *descriptor = [runtime descriptorForSkillSlot:slot];
        XCTAssertTrue([descriptor.strategy isKindOfClass:MobaInstantCastStrategy.class]);
        XCTAssertNil(descriptor.cursorCoalescer);
        XCTAssertEqual(descriptor.instantConfiguration.tapDurationMs, 30u);
    }
    XCTAssertEqual(self.provider.drivers.count, 0u);
}

- (void)testCanonicalLabelsAndBundledInputResolveToQWERTMapping {
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:self.caitlynSnapshot];
    NSArray<NSNumber *> *expectedKeys = @[@81, @69, @82, @84];
    NSArray<NSString *> *expectedControls = @[@"abilityQ", @"abilityW", @"abilityE", @"abilityR"];
    [MobaCanonicalSkillSlots() enumerateObjectsUsingBlock:^(MobaCanonicalSkillSlot slot, NSUInteger index, BOOL *stop) {
        MobaSkillRuntimeDescriptor *descriptor = [runtime descriptorForSkillSlot:slot];
        XCTAssertEqualObjects(descriptor.displayLabel, slot);
        XCTAssertEqual(descriptor.hostKeyCode, expectedKeys[index].unsignedShortValue);
        XCTAssertEqualObjects(descriptor.layoutControlName, expectedControls[index]);
    }];
}

- (void)testResolvedHostKeysFollowInputProfileMutation {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil
                                                    inputMutation:^(NSMutableDictionary *json) {
        json[@"actions"][@"ability1"] = @101;
        json[@"actions"][@"ability2"] = @102;
        json[@"actions"][@"ability3"] = @103;
        json[@"actions"][@"ability4"] = @104;
    } layoutMutation:nil championMutation:nil];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    [MobaCanonicalSkillSlots() enumerateObjectsUsingBlock:^(MobaCanonicalSkillSlot slot, NSUInteger index, BOOL *stop) {
        XCTAssertEqual([runtime descriptorForSkillSlot:slot].hostKeyCode, 101 + index);
    }];
}

- (void)testAllAimedConfigurationsUseRuntimeHeroAnchor {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:^(NSMutableDictionary *json) {
        json[@"camera"][@"heroAnchorPx"][@"x"] = @777;
        json[@"camera"][@"heroAnchorPx"][@"y"] = @333;
    } inputMutation:nil layoutMutation:nil championMutation:nil];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        MobaSkillRuntimeDescriptor *descriptor = [runtime descriptorForSkillSlot:slot];
        CGPoint anchor = descriptor.directionalConfiguration != nil ?
            descriptor.directionalConfiguration.heroAnchor : descriptor.pointConfiguration.heroAnchor;
        XCTAssertEqualWithAccuracy(anchor.x, 777, 0.0001);
        XCTAssertEqualWithAccuracy(anchor.y, 333, 0.0001);
    }
}

- (void)testCoalescerUpdateRateFollowsAllSupportedRuntimeRates {
    for (NSNumber *rate in @[@30, @60, @120]) {
        self.provider = [[MobaFactoryDriverProvider alloc] init];
        self.factory = [[MobaCastStrategyFactory alloc] initWithDispatcher:self.dispatcher driverProvider:self.provider];
        MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                      runtimeMutation:^(NSMutableDictionary *json) {
            json[@"mouseUpdateRateHz"] = rate;
        } inputMutation:nil layoutMutation:nil championMutation:nil];
        MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
        for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
            XCTAssertEqual([runtime descriptorForSkillSlot:slot].cursorCoalescer.updateRate, rate.unsignedIntegerValue);
        }
    }
}

- (void)testDefaultAngleAndDistanceRatioComeFromEachSkillProfile {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil layoutMutation:nil
                                                championMutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"defaultAim"][@"angleDeg"] = @0;
        json[@"skills"][@"Q"][@"defaultAim"][@"distanceRatio"] = @0.4;
        json[@"skills"][@"W"][@"defaultAim"][@"angleDeg"] = @90;
        json[@"skills"][@"W"][@"defaultAim"][@"distanceRatio"] = @0.25;
    }];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    MobaDirectionalCastConfiguration *q = [runtime descriptorForSkillSlot:MobaCanonicalSkillSlotQ].directionalConfiguration;
    XCTAssertEqualWithAccuracy(q.defaultDirection.dx, 1, 0.0001);
    XCTAssertEqualWithAccuracy(q.defaultDirection.dy, 0, 0.0001);
    XCTAssertEqualWithAccuracy(q.defaultDistanceRatio, 0.4, 0.0001);
    MobaPointCastConfiguration *w = [runtime descriptorForSkillSlot:MobaCanonicalSkillSlotW].pointConfiguration;
    XCTAssertEqualWithAccuracy(w.defaultDirection.dx, 0, 0.0001);
    XCTAssertEqualWithAccuracy(w.defaultDirection.dy, 1, 0.0001);
    XCTAssertEqualWithAccuracy(w.defaultDistanceRatio, 0.25, 0.0001);
}

- (void)testDirectionalRadiiFollowQAndEProfilesIndependently {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil layoutMutation:nil
                                                championMutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"range"][@"leftPx"] = @701;
        json[@"skills"][@"E"][@"range"][@"downPx"] = @419;
    }];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    XCTAssertEqualWithAccuracy([runtime descriptorForSkillSlot:MobaCanonicalSkillSlotQ].directionalConfiguration.aimRadii.leftPx, 701, 0.0001);
    XCTAssertEqualWithAccuracy([runtime descriptorForSkillSlot:MobaCanonicalSkillSlotE].directionalConfiguration.aimRadii.downPx, 419, 0.0001);
}

- (void)testPointRangesResponsesAndWheelRadiiFollowProfiles {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil
                                                   layoutMutation:^(NSMutableDictionary *json) {
        json[@"controls"][@"abilityW"][@"wheelRadiusPt"] = @177;
        json[@"controls"][@"abilityR"][@"wheelRadiusPt"] = @188;
    } championMutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"W"][@"range"][@"minLeftPx"] = @20;
        json[@"skills"][@"W"][@"range"][@"maxRightPx"] = @777;
        json[@"skills"][@"W"][@"touchResponse"][@"deadzoneRatio"] = @0.2;
        json[@"skills"][@"W"][@"touchResponse"][@"fullRangeRatio"] = @1.1;
        json[@"skills"][@"W"][@"touchResponse"][@"curveExponent"] = @1.5;
    }];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    MobaPointCastConfiguration *w = [runtime descriptorForSkillSlot:MobaCanonicalSkillSlotW].pointConfiguration;
    MobaPointCastConfiguration *r = [runtime descriptorForSkillSlot:MobaCanonicalSkillSlotR].pointConfiguration;
    XCTAssertEqualWithAccuracy(w.minimumRadii.leftPx, 20, 0.0001);
    XCTAssertEqualWithAccuracy(w.maximumRadii.rightPx, 777, 0.0001);
    XCTAssertEqualWithAccuracy(w.deadzoneRatio, 0.2, 0.0001);
    XCTAssertEqualWithAccuracy(w.fullRangeRatio, 1.1, 0.0001);
    XCTAssertEqualWithAccuracy(w.curveExponent, 1.5, 0.0001);
    XCTAssertEqualWithAccuracy(w.wheelRadius, 177, 0.0001);
    XCTAssertEqualWithAccuracy(r.wheelRadius, 188, 0.0001);
}

- (void)testEveryAimedSkillOwnsDistinctDriverAndCoalescer {
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:self.caitlynSnapshot];
    NSMutableSet *coalescers = [NSMutableSet set];
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        [coalescers addObject:[runtime descriptorForSkillSlot:slot].cursorCoalescer];
    }
    XCTAssertEqual(coalescers.count, 4u);
    XCTAssertEqual(self.provider.drivers.count, 4u);
    XCTAssertEqual(runtime.localInteractionResetParticipants.count, 4u);
}

- (MobaCastCancelAction *)qCancelActionForType:(NSString *)type {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil
                                                    inputMutation:^(NSMutableDictionary *json) {
        json[@"cancelCastAction"][@"type"] = type;
        if (![type isEqualToString:@"keyboard"]) {
            [json[@"cancelCastAction"] removeObjectForKey:@"keyCode"];
        }
    } layoutMutation:nil championMutation:nil];
    return [self runtimeForSnapshot:snapshot].skillDescriptors[MobaCanonicalSkillSlotQ].directionalConfiguration.cancelAction;
}

- (void)testKeyboardRightMouseAndReleaseOnlyCancelActionsMapExactly {
    MobaCastCancelAction *keyboard = [self qCancelActionForType:@"keyboard"];
    XCTAssertEqual(keyboard.type, MobaCastCancelActionTypeKeyboard);
    XCTAssertEqual(keyboard.keyCode, 27);
    XCTAssertEqual(keyboard.tapDurationMs, MobaDefaultKeyboardCancelTapDurationMs);
    MobaCastCancelAction *mouse = [self qCancelActionForType:@"rightMouse"];
    XCTAssertEqual(mouse.type, MobaCastCancelActionTypeRightMouse);
    MobaCastCancelAction *release = [self qCancelActionForType:@"releaseOnly"];
    XCTAssertEqual(release.type, MobaCastCancelActionTypeReleaseOnly);
}

- (void)testKeyboardCancelDurationDoesNotReuseAttackTapDuration {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil
                                                    inputMutation:^(NSMutableDictionary *json) {
        json[@"attackTapDurationMs"] = @99;
    } layoutMutation:nil championMutation:nil];
    MobaCastCancelAction *cancelAction = [self runtimeForSnapshot:snapshot]
        .skillDescriptors[MobaCanonicalSkillSlotQ].directionalConfiguration.cancelAction;
    XCTAssertEqual(cancelAction.tapDurationMs, MobaDefaultKeyboardCancelTapDurationMs);
    XCTAssertNotEqual(cancelAction.tapDurationMs, snapshot.inputProfile.attackTapDurationMs);
}

- (void)testAllowCancelFalseUsesReleaseOnlyInsteadOfConfiguredEscape {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil layoutMutation:nil
                                                championMutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"allowCancel"] = @NO;
    }];
    MobaSkillRuntimeDescriptor *q = [[self runtimeForSnapshot:snapshot] descriptorForSkillSlot:MobaCanonicalSkillSlotQ];
    XCTAssertFalse(q.allowCancel);
    XCTAssertEqual(q.directionalConfiguration.cancelAction.type, MobaCastCancelActionTypeReleaseOnly);
}

- (void)testCancelOrderingFalseFailsAtExactProfilePath {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil
                                                    inputMutation:^(NSMutableDictionary *json) {
        json[@"cancelCastAction"][@"cancelBeforeSkillKeyUp"] = @NO;
    } layoutMutation:nil championMutation:nil];
    NSError *error = nil;
    XCTAssertNil([self.factory runtimeFromSnapshot:snapshot error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorInvalidCancelOrdering);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryFieldPathKey], @"$.cancelCastAction.cancelBeforeSkillKeyUp");
}

- (void)testEveryMissingCanonicalSkillFailsAtItsSpecificPath {
    for (NSString *slot in MobaCanonicalSkillSlots()) {
        MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                      runtimeMutation:nil inputMutation:nil layoutMutation:nil
                                                    championMutation:^(NSMutableDictionary *json) {
            [json[@"skills"] removeObjectForKey:slot];
        }];
        NSError *error = nil;
        XCTAssertNil([self.factory runtimeFromSnapshot:snapshot error:&error]);
        XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorMissingCanonicalSkill);
        XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryFieldPathKey],
                              [NSString stringWithFormat:@"$.skills.%@", slot]);
    }
}

- (void)testMissingCanonicalLayoutControlFailsAtSpecificPath {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil
                                                   layoutMutation:^(NSMutableDictionary *json) {
        [json[@"controls"] removeObjectForKey:@"abilityE"];
    } championMutation:nil];
    NSError *error = nil;
    XCTAssertNil([self.factory runtimeFromSnapshot:snapshot error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorMissingLayoutControl);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryFieldPathKey], @"$.controls.abilityE");
}

- (void)testPointMissingWheelRadiusFailsAtSpecificPath {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil
                                                   layoutMutation:^(NSMutableDictionary *json) {
        [json[@"controls"][@"abilityW"] removeObjectForKey:@"wheelRadiusPt"];
    } championMutation:nil];
    NSError *error = nil;
    XCTAssertNil([self.factory runtimeFromSnapshot:snapshot error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorMissingAimedWheelRadius);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryFieldPathKey], @"$.controls.abilityW.wheelRadiusPt");
}

- (void)testUnresolvedInputActionFailsAtSkillPath {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil layoutMutation:nil
                                                championMutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"R"][@"inputAction"] = @"futureAction";
    }];
    NSError *error = nil;
    XCTAssertNil([self.factory runtimeFromSnapshot:snapshot error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorUnresolvedInputAction);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryFieldPathKey], @"$.skills.R.inputAction");
}

- (void)testInjectedDriverCreationFailureReturnsStructuredError {
    self.provider.failAtCreationIndex = 1;
    NSError *error = nil;
    XCTAssertNil([self.factory runtimeFromSnapshot:self.caitlynSnapshot error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorDisplayLinkCreationFailed);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactorySkillSlotKey], MobaCanonicalSkillSlotW);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactoryOperationKey], @"create-display-link-driver");
    XCTAssertFalse(self.provider.drivers.firstObject.isRunning);
}

- (void)testNilFactoryDependenciesFailSafelyWithoutAssertion {
    XCTAssertNil([[MobaCastStrategyFactory alloc] initWithDispatcher:nil driverProvider:self.provider]);
    XCTAssertNil([[MobaCastStrategyFactory alloc] initWithDispatcher:self.dispatcher driverProvider:nil]);
}

- (void)testInjectedTypedConfigurationRejectionReturnsErrorWithoutAssertion {
    MobaProfileSnapshot *snapshot = self.caitlynSnapshot;
    [snapshot.championProfile.skills[@"Q"].directionalRange setValue:@0 forKey:@"leftPx"];
    NSError *error = nil;
    XCTAssertNil([self.factory runtimeFromSnapshot:snapshot error:&error]);
    XCTAssertEqual(error.code, MobaCastStrategyFactoryErrorConfigurationRejected);
    XCTAssertEqualObjects(error.userInfo[MobaCastStrategyFactorySkillSlotKey], MobaCanonicalSkillSlotQ);
}

- (void)testExtraNoncanonicalSkillIsIgnoredByCanonicalRuntime {
    MobaProfileSnapshot *snapshot = [self snapshotForChampionFile:@"caitlyn.json"
                                                  runtimeMutation:nil inputMutation:nil layoutMutation:nil
                                                championMutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Passive"] = [json[@"skills"][@"Q"] mutableCopy];
    }];
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:snapshot];
    XCTAssertEqual(runtime.skillDescriptors.count, 4u);
    XCTAssertNil(runtime.skillDescriptors[@"Passive"]);
}

- (void)testRuntimeMetadataAndCollectionsAreDefensiveCopies {
    MobaChampionRuntime *runtime = [self runtimeForSnapshot:self.caitlynSnapshot];
    XCTAssertEqualObjects(runtime.championID, @"caitlyn");
    XCTAssertEqualObjects(runtime.displayName, @"Caitlyn");
    XCTAssertEqualObjects(runtime.calibrationStatus, @"placeholder");
    XCTAssertFalse([runtime.skillDescriptors isKindOfClass:NSMutableDictionary.class]);
    XCTAssertFalse([runtime.localInteractionResetParticipants isKindOfClass:NSMutableArray.class]);
}

- (void)testStrategyImplementationFilesContainNoCaitlynOrCalibrationPlaceholderConstants {
    for (NSString *fileName in @[@"MobaDirectionalCastStrategy.m", @"MobaPointCastStrategy.m", @"MobaInstantCastStrategy.m"]) {
        NSString *path = [[[[self exampleURL:@"runtime.json"].path stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
        path = [[path stringByAppendingPathComponent:@"Limelight/Input/MOBA/Casting"]
            stringByAppendingPathComponent:fileName];
        NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        XCTAssertNotNil(source);
        XCTAssertEqual([source rangeOfString:@"Caitlyn" options:NSCaseInsensitiveSearch].location, NSNotFound);
        XCTAssertEqual([source rangeOfString:@"placeholder" options:NSCaseInsensitiveSearch].location, NSNotFound);
    }
}

@end
