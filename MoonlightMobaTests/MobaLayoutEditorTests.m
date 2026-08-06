//
//  MobaLayoutEditorTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>
#import <math.h>

#import "../Limelight/Input/MOBA/Profiles/MobaLayoutEditor.h"

@interface MobaLayoutEditorTests : XCTestCase
@property (nonatomic, strong) MobaProfileDecoder *decoder;
@property (nonatomic, strong) MobaProfileSnapshot *snapshot;
@property (nonatomic, copy) NSData *runtimeData;
@property (nonatomic, copy) NSData *layoutData;
@end

@implementation MobaLayoutEditorTests

- (NSURL *)exampleURL:(NSString *)name {
    NSString *testDirectory = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *root = [testDirectory stringByDeletingLastPathComponent];
    return [NSURL fileURLWithPath:[[root stringByAppendingPathComponent:@"examples/moba"]
        stringByAppendingPathComponent:name]];
}

- (NSData *)dataNamed:(NSString *)name {
    NSData *data = [NSData dataWithContentsOfURL:[self exampleURL:name]];
    XCTAssertNotNil(data);
    return data;
}

- (void)setUp {
    [super setUp];
    self.decoder = [[MobaProfileDecoder alloc] init];
    self.runtimeData = [self dataNamed:@"runtime.json"];
    self.layoutData = [self dataNamed:@"ipad-pro-13-layout.json"];
    MobaRuntimeProfile *runtime = [self.decoder decodeRuntimeProfileData:self.runtimeData error:nil];
    MobaInputProfile *input = [self.decoder decodeInputProfileData:[self dataNamed:@"input.json"] error:nil];
    MobaLayoutProfile *layout = [self.decoder decodeLayoutProfileData:self.layoutData error:nil];
    MobaChampionProfile *champion = [self.decoder decodeChampionProfileData:[self dataNamed:@"caitlyn.json"] error:nil];
    self.snapshot = [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtime
                                                           inputProfile:input
                                                          layoutProfile:layout
                                                        championProfile:champion];
}

- (MobaLayoutEditorController *)controllerWithRuntime:(NSData *)runtime layout:(NSData *)layout {
    NSError *error = nil;
    MobaLayoutEditorController *controller = [[MobaLayoutEditorController alloc]
        initWithSnapshot:self.snapshot runtimeData:runtime layoutData:layout decoder:self.decoder error:&error];
    XCTAssertNotNil(controller);
    XCTAssertNil(error);
    return controller;
}

- (MobaLayoutEditorController *)controller { return [self controllerWithRuntime:self.runtimeData layout:self.layoutData]; }

- (NSMutableDictionary *)JSONFromData:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
}

- (NSData *)dataFromJSON:(NSDictionary *)json {
    return [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
}

- (void)testDraftStartsFromActiveSnapshot {
    MobaLayoutEditorController *controller = self.controller;
    XCTAssertEqualWithAccuracy(controller.draft.globalOpacityMultiplier, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.14, 0.000001);
    XCTAssertEqualObjects(controller.draft.controlNames,
                          (@[@"move", @"abilityQ", @"abilityW", @"abilityE", @"abilityR", @"attack"]));
}

- (void)testDraftDoesNotMutateImmutableModels {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.55 forField:MobaLayoutEditorControlFieldCenterX];
    XCTAssertEqualWithAccuracy(self.snapshot.layoutProfile.controls[@"move"].centerX, 0.14, 0.000001);
    XCTAssertEqualWithAccuracy(self.snapshot.runtimeProfile.globalOpacityMultiplier, 1.0, 0.000001);
}

- (void)testUnknownRootFieldsSurviveCandidateSerialization {
    NSMutableDictionary *runtime = [self JSONFromData:self.runtimeData];
    NSMutableDictionary *layout = [self JSONFromData:self.layoutData];
    runtime[@"futureRuntime"] = @{ @"flag": @YES };
    layout[@"futureLayout"] = @{ @"nested": @[@1, @2] };
    MobaLayoutEditorController *controller = [self controllerWithRuntime:[self dataFromJSON:runtime]
                                                                  layout:[self dataFromJSON:layout]];
    [controller setGlobalOpacityMultiplierValue:0.5];
    XCTAssertEqualObjects([self JSONFromData:[controller.draft candidateRuntimeDataWithError:nil]][@"futureRuntime"],
                          runtime[@"futureRuntime"]);
    XCTAssertEqualObjects([self JSONFromData:[controller.draft candidateLayoutDataWithError:nil]][@"futureLayout"],
                          layout[@"futureLayout"]);
}

- (void)testUnknownNestedControlFieldSurvivesCandidateSerialization {
    NSMutableDictionary *layout = [self JSONFromData:self.layoutData];
    layout[@"controls"][@"move"][@"futureNested"] = @{ @"value": @7 };
    MobaLayoutEditorController *controller = [self controllerWithRuntime:self.runtimeData
                                                                  layout:[self dataFromJSON:layout]];
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.4 forField:MobaLayoutEditorControlFieldCenterX];
    NSDictionary *candidate = [self JSONFromData:[controller.draft candidateLayoutDataWithError:nil]];
    XCTAssertEqualObjects(candidate[@"controls"][@"move"][@"futureNested"], @{ @"value": @7 });
}

- (void)testFutureUninstalledControlSurvivesCandidateSerialization {
    NSMutableDictionary *layout = [self JSONFromData:self.layoutData];
    NSMutableDictionary *future = [layout[@"controls"][@"attack"] mutableCopy];
    future[@"custom"] = @"preserved";
    layout[@"controls"][@"futureControl"] = future;
    MobaLayoutEditorController *controller = [self controllerWithRuntime:self.runtimeData
                                                                  layout:[self dataFromJSON:layout]];
    NSDictionary *candidate = [self JSONFromData:[controller.draft candidateLayoutDataWithError:nil]];
    XCTAssertEqualObjects(candidate[@"controls"][@"futureControl"], future);
    XCTAssertFalse([controller.draft.controlNames containsObject:@"futureControl"]);
}

- (void)testSafeAreaPointConvertsToNormalizedCenter {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    XCTAssertTrue([controller moveSelectedControlToPoint:CGPointMake(300, 250)
                                            safeAreaFrame:CGRectMake(100, 50, 400, 400)]);
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.5, 0.000001);
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerY, 0.5, 0.000001);
}

- (void)testNormalizedCenterClampsToUnitRange {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"attack"];
    [controller moveSelectedControlToPoint:CGPointMake(-50, 900)
                              safeAreaFrame:CGRectMake(100, 100, 400, 300)];
    XCTAssertEqual([controller.draft controlNamed:@"attack"].centerX, 0.0);
    XCTAssertEqual([controller.draft controlNamed:@"attack"].centerY, 1.0);
}

- (void)testSafeAreaBlackBarPointIsNotClampedToVideoRect {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"abilityQ"];
    [controller moveSelectedControlToPoint:CGPointMake(500, 40)
                              safeAreaFrame:CGRectMake(0, 0, 1000, 800)];
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"abilityQ"].centerY, 0.05, 0.000001);
}

- (void)testSelectionUsesHighestOverlappingZIndex {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"abilityQ"];
    [controller setSelectedControlValue:0.5 forField:MobaLayoutEditorControlFieldCenterX];
    [controller setSelectedControlValue:0.5 forField:MobaLayoutEditorControlFieldCenterY];
    [controller selectControlNamed:@"abilityR"];
    [controller setSelectedControlValue:0.5 forField:MobaLayoutEditorControlFieldCenterX];
    [controller setSelectedControlValue:0.5 forField:MobaLayoutEditorControlFieldCenterY];
    XCTAssertEqualObjects([controller selectTopmostControlAtPoint:CGPointMake(500, 400)
                                                    safeAreaFrame:CGRectMake(0, 0, 1000, 800)], @"abilityR");
}

- (void)testZeroOpacityControlRemainsSelectable {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"attack"];
    [controller setSelectedControlValue:0 forField:MobaLayoutEditorControlFieldNormalOpacity];
    MobaLayoutEditorControlDraft *attack = [controller.draft controlNamed:@"attack"];
    CGPoint point = CGPointMake(attack.centerX * 1000, attack.centerY * 800);
    XCTAssertEqualObjects([controller selectTopmostControlAtPoint:point safeAreaFrame:CGRectMake(0, 0, 1000, 800)],
                          @"attack");
}

- (void)testDisabledControlRemainsSelectableByEditor {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"attack"];
    [controller setSelectedControlInteractionEnabled:NO];
    MobaLayoutEditorControlDraft *attack = [controller.draft controlNamed:@"attack"];
    XCTAssertFalse(attack.isInteractionEnabled);
    XCTAssertEqualObjects([controller selectTopmostControlAtPoint:CGPointMake(attack.centerX * 1000, attack.centerY * 800)
                                                     safeAreaFrame:CGRectMake(0, 0, 1000, 800)], @"attack");
}

- (void)testAllControlPresentationFieldsUpdateTypedDraft {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:240 forField:MobaLayoutEditorControlFieldVisualWidth];
    [controller setSelectedControlValue:220 forField:MobaLayoutEditorControlFieldVisualHeight];
    [controller setSelectedControlValue:1.5 forField:MobaLayoutEditorControlFieldHitAreaScale];
    [controller setSelectedControlValue:120 forField:MobaLayoutEditorControlFieldWheelRadius];
    [controller setSelectedControlValue:0.2 forField:MobaLayoutEditorControlFieldNormalOpacity];
    [controller setSelectedControlValue:0.4 forField:MobaLayoutEditorControlFieldPressedOpacity];
    [controller setSelectedControlValue:0.1 forField:MobaLayoutEditorControlFieldDisabledOpacity];
    MobaLayoutEditorControlDraft *move = [controller.draft controlNamed:@"move"];
    XCTAssertEqual(move.visualWidthPt, 240);
    XCTAssertEqual(move.visualHeightPt, 220);
    XCTAssertEqual(move.hitAreaScale, 1.5);
    XCTAssertEqualObjects(move.wheelRadiusPt, @120);
    XCTAssertEqual(move.opacity, 0.2);
    XCTAssertEqual(move.pressedOpacity, 0.4);
    XCTAssertEqual(move.disabledOpacity, 0.1);
}

- (void)testWheelRadiusCannotBeAddedToAttack {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"attack"];
    XCTAssertFalse([controller setSelectedControlValue:100 forField:MobaLayoutEditorControlFieldWheelRadius]);
    XCTAssertNil([controller.draft controlNamed:@"attack"].wheelRadiusPt);
}

- (void)testZIndexMovesByOne {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    NSInteger original = [controller.draft controlNamed:@"move"].zIndex;
    XCTAssertTrue([controller adjustSelectedControlZIndexBy:1]);
    XCTAssertEqual([controller.draft controlNamed:@"move"].zIndex, original + 1);
    XCTAssertTrue([controller adjustSelectedControlZIndexBy:-1]);
    XCTAssertEqual([controller.draft controlNamed:@"move"].zIndex, original);
}

- (void)testZIndexIncrementProtectsPlatformIntegerOverflow {
    NSMutableDictionary *layout = [self JSONFromData:self.layoutData];
    layout[@"controls"][@"move"][@"zIndex"] = @(NSIntegerMax);
    MobaLayoutProfile *profile = [self.decoder decodeLayoutProfileData:[self dataFromJSON:layout] error:nil];
    MobaProfileSnapshot *snapshot = [[MobaProfileSnapshot alloc]
        initWithRuntimeProfile:self.snapshot.runtimeProfile inputProfile:self.snapshot.inputProfile
        layoutProfile:profile championProfile:self.snapshot.championProfile];
    MobaLayoutEditorController *controller = [[MobaLayoutEditorController alloc]
        initWithSnapshot:snapshot runtimeData:self.runtimeData layoutData:[self dataFromJSON:layout]
        decoder:self.decoder error:nil];
    [controller selectControlNamed:@"move"];
    XCTAssertFalse([controller adjustSelectedControlZIndexBy:1]);
    XCTAssertEqual([controller.draft controlNamed:@"move"].zIndex, NSIntegerMax);
}

- (void)testZIndexAdjustmentRejectsValuesOtherThanOneStep {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    XCTAssertFalse([controller adjustSelectedControlZIndexBy:2]);
    XCTAssertFalse([controller adjustSelectedControlZIndexBy:-2]);
}

- (void)testCancelZoneFieldsAreTypedAndIndependent {
    MobaLayoutEditorController *controller = self.controller;
    [controller setCancelZoneValue:0.25 forField:MobaLayoutEditorCancelZoneFieldCenterX];
    [controller setCancelZoneValue:160 forField:MobaLayoutEditorCancelZoneFieldDiameter];
    [controller setCancelZoneValue:12 forField:MobaLayoutEditorCancelZoneFieldActivationInset];
    [controller setCancelZoneValue:0 forField:MobaLayoutEditorCancelZoneFieldOpacity];
    [controller setCancelZoneVisibleOnlyWhileCasting:NO];
    XCTAssertEqual(controller.draft.cancelZone.centerX, 0.25);
    XCTAssertEqual(controller.draft.cancelZone.diameterPt, 160);
    XCTAssertEqual(controller.draft.cancelZone.activationInsetPt, 12);
    XCTAssertEqual(controller.draft.cancelZone.opacity, 0);
    XCTAssertFalse(controller.draft.cancelZone.visibleOnlyWhileCasting);
}

- (void)testGlobalOpacityUpdatesRuntimeCandidateOnlyManagedField {
    MobaLayoutEditorController *controller = self.controller;
    [controller setGlobalOpacityMultiplierValue:0.33];
    NSDictionary *candidate = [self JSONFromData:[controller.draft candidateRuntimeDataWithError:nil]];
    XCTAssertEqualObjects(candidate[@"globalOpacityMultiplier"], @0.33);
    XCTAssertEqualObjects(candidate[@"canvas"], [self JSONFromData:self.runtimeData][@"canvas"]);
}

- (void)testRevertRestoresBaselineWithoutWriting {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.7 forField:MobaLayoutEditorControlFieldCenterX];
    XCTAssertTrue(controller.isDirty);
    [controller revert];
    XCTAssertFalse(controller.isDirty);
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.14, 0.000001);
}

- (void)testRestoreDefaultsChangesDraftButNotBaselineUntilSave {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.6 forField:MobaLayoutEditorControlFieldCenterX];
    XCTAssertTrue([controller restoreDefaultsFromRuntimeData:self.runtimeData layoutData:self.layoutData error:nil]);
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.14, 0.000001);
    [controller revert];
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.14, 0.000001);
}

- (void)testAcceptedSaveBecomesNewBaseline {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.42 forField:MobaLayoutEditorControlFieldCenterX];
    NSData *runtime = [controller.draft candidateRuntimeDataWithError:nil];
    NSData *layout = [controller.draft candidateLayoutDataWithError:nil];
    MobaRuntimeProfile *runtimeProfile = [self.decoder decodeRuntimeProfileData:runtime error:nil];
    MobaLayoutProfile *layoutProfile = [self.decoder decodeLayoutProfileData:layout error:nil];
    MobaProfileSnapshot *saved = [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtimeProfile
                                                                        inputProfile:self.snapshot.inputProfile
                                                                       layoutProfile:layoutProfile
                                                                     championProfile:self.snapshot.championProfile];
    XCTAssertTrue([controller acceptSavedSnapshot:saved runtimeData:runtime layoutData:layout error:nil]);
    XCTAssertFalse(controller.isDirty);
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.8 forField:MobaLayoutEditorControlFieldCenterX];
    [controller revert];
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.42, 0.000001);
}

- (void)testInvalidCenterSerializesButExistingDecoderRejectsSaveCandidate {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:1.1 forField:MobaLayoutEditorControlFieldCenterX];
    NSError *error = nil;
    XCTAssertNil([self.decoder decodeLayoutProfileData:[controller.draft candidateLayoutDataWithError:nil] error:&error]);
    XCTAssertNotNil(error);
}

- (void)testInvalidCancelInsetEqualToRadiusIsRejected {
    MobaLayoutEditorController *controller = self.controller;
    [controller setCancelZoneValue:100 forField:MobaLayoutEditorCancelZoneFieldDiameter];
    [controller setCancelZoneValue:50 forField:MobaLayoutEditorCancelZoneFieldActivationInset];
    XCTAssertNil([self.decoder decodeLayoutProfileData:[controller.draft candidateLayoutDataWithError:nil] error:nil]);
}

- (void)testOpacityPreviewStateChangesNoDraftData {
    MobaLayoutEditorController *controller = self.controller;
    NSData *before = [controller.draft candidateLayoutDataWithError:nil];
    controller.opacityPreviewState = MobaControlOpacityPreviewStatePressed;
    controller.opacityPreviewState = MobaControlOpacityPreviewStateDisabled;
    XCTAssertEqualObjects([controller.draft candidateLayoutDataWithError:nil], before);
    XCTAssertFalse(controller.isDirty);
}

- (void)testUnknownControlNameCannotBecomeSelection {
    MobaLayoutEditorController *controller = self.controller;
    XCTAssertFalse([controller selectControlNamed:@"futureControl"]);
    XCTAssertNil(controller.selectedControlName);
}

- (void)testCancelZoneCanBeSelectedAndDraggedWithSafeAreaCoordinates {
    MobaLayoutEditorController *controller = self.controller;
    XCTAssertTrue([controller selectControlNamed:MobaLayoutEditorControlCancelZone]);
    XCTAssertTrue([controller moveSelectedControlToPoint:CGPointMake(250, 350)
                                            safeAreaFrame:CGRectMake(50, 50, 400, 400)]);
    XCTAssertEqualWithAccuracy(controller.draft.cancelZone.centerX, 0.5, 0.000001);
    XCTAssertEqualWithAccuracy(controller.draft.cancelZone.centerY, 0.75, 0.000001);
}

- (void)testNonFiniteGlobalOpacityIsRejectedWithoutDirtyingDraft {
    MobaLayoutEditorController *controller = self.controller;
    XCTAssertFalse([controller setGlobalOpacityMultiplierValue:NAN]);
    XCTAssertFalse([controller setGlobalOpacityMultiplierValue:INFINITY]);
    XCTAssertEqual(controller.draft.globalOpacityMultiplier, 1.0);
    XCTAssertFalse(controller.isDirty);
}

- (void)testAimedSkillWheelRadiusAppearsInPresentationOverride {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"abilityW"];
    XCTAssertTrue([controller setSelectedControlValue:222 forField:MobaLayoutEditorControlFieldWheelRadius]);
    XCTAssertEqualObjects([controller.draft controlNamed:@"abilityW"].presentation.wheelRadiusPt, @222);
}

- (void)testLiveZIndexChangeChangesOverlapWinner {
    MobaLayoutEditorController *controller = self.controller;
    for (NSString *name in @[@"abilityQ", @"abilityW"]) {
        [controller selectControlNamed:name];
        [controller setSelectedControlValue:0.5 forField:MobaLayoutEditorControlFieldCenterX];
        [controller setSelectedControlValue:0.5 forField:MobaLayoutEditorControlFieldCenterY];
    }
    [controller selectControlNamed:@"abilityQ"];
    for (NSUInteger index = 0; index < 3; index++) [controller adjustSelectedControlZIndexBy:1];
    XCTAssertEqualObjects([controller selectTopmostControlAtPoint:CGPointMake(500, 400)
                                                    safeAreaFrame:CGRectMake(0, 0, 1000, 800)], @"abilityQ");
}

- (void)testLayoutIdentityFieldsRemainByteSemanticValues {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller setSelectedControlValue:0.2 forField:MobaLayoutEditorControlFieldCenterX];
    NSDictionary *before = [self JSONFromData:self.layoutData];
    NSDictionary *after = [self JSONFromData:[controller.draft candidateLayoutDataWithError:nil]];
    XCTAssertEqualObjects(after[@"schemaVersion"], before[@"schemaVersion"]);
    XCTAssertEqualObjects(after[@"layoutId"], before[@"layoutId"]);
    XCTAssertEqualObjects(after[@"deviceClass"], before[@"deviceClass"]);
}

- (void)testRuntimeNonOpacityFieldsRemainUnchangedAfterDraftEdit {
    MobaLayoutEditorController *controller = self.controller;
    [controller setGlobalOpacityMultiplierValue:0.21];
    NSDictionary *before = [self JSONFromData:self.runtimeData];
    NSDictionary *after = [self JSONFromData:[controller.draft candidateRuntimeDataWithError:nil]];
    for (NSString *key in before) {
        if (![key isEqualToString:@"globalOpacityMultiplier"]) {
            XCTAssertEqualObjects(after[key], before[key]);
        }
    }
}

- (void)testControllerPresentationNeverUsesFixedGameCanvasDimensions {
    MobaLayoutEditorController *controller = self.controller;
    [controller selectControlNamed:@"move"];
    [controller moveSelectedControlToPoint:CGPointMake(640, 360)
                              safeAreaFrame:CGRectMake(0, 0, 1280, 720)];
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerX, 0.5, 0.000001);
    XCTAssertEqualWithAccuracy([controller.draft controlNamed:@"move"].centerY, 0.5, 0.000001);
}

- (void)testInstantSkillWheelRadiusIsPreservedButNotEditable {
    MobaChampionProfile *instant = [self.decoder
        decodeChampionProfileData:[self dataNamed:@"debug-instant.json"] error:nil];
    MobaProfileSnapshot *snapshot = [[MobaProfileSnapshot alloc]
        initWithRuntimeProfile:self.snapshot.runtimeProfile
        inputProfile:self.snapshot.inputProfile
        layoutProfile:self.snapshot.layoutProfile
        championProfile:instant];
    MobaLayoutEditorController *controller = [[MobaLayoutEditorController alloc]
        initWithSnapshot:snapshot runtimeData:self.runtimeData layoutData:self.layoutData
        decoder:self.decoder error:nil];
    [controller selectControlNamed:@"abilityQ"];
    NSNumber *original = [controller.draft controlNamed:@"abilityQ"].wheelRadiusPt;
    XCTAssertFalse([controller setSelectedControlValue:200 forField:MobaLayoutEditorControlFieldWheelRadius]);
    XCTAssertEqualObjects([controller.draft controlNamed:@"abilityQ"].wheelRadiusPt, original);
}

@end
