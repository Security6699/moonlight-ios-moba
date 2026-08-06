//
//  MobaSkillTuningTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>
#import <math.h>

#import "../Limelight/Input/MOBA/Profiles/MobaSkillTuning.h"
#import "../Limelight/Input/MOBA/Controls/MobaAimPreviewView.h"
#import "../Limelight/Input/MOBA/Controls/MobaSkillTuningOverlayView.h"

@interface MobaSkillRuntimeDescriptor (SkillTuningOverlayTests)
- (instancetype)initWithSkillSlot:(MobaCanonicalSkillSlot)skillSlot displayLabel:(NSString *)displayLabel
                layoutControlName:(NSString *)layoutControlName inputAction:(NSString *)inputAction
                      hostKeyCode:(uint16_t)hostKeyCode castType:(MobaProfileSkillCastType)castType
                      allowCancel:(BOOL)allowCancel skillProfile:(id)skillProfile
             layoutControlProfile:(id)layoutControlProfile strategy:(id)strategy
                  cursorCoalescer:(id)cursorCoalescer instantConfiguration:(id)instantConfiguration
         directionalConfiguration:(id)directionalConfiguration pointConfiguration:(id)pointConfiguration;
@end

@interface MobaSkillTuningOverlayTouchResponse : NSObject
@property (nonatomic) double deadzoneRatio;
@end
@implementation MobaSkillTuningOverlayTouchResponse
@end

@interface MobaSkillTuningOverlaySkillProfile : NSObject
@property (nonatomic, strong) MobaSkillTuningOverlayTouchResponse *touchResponse;
@end
@implementation MobaSkillTuningOverlaySkillProfile
@end

@interface MobaSkillTuningOverlayLayoutProfile : NSObject
@property (nonatomic, strong) NSNumber *wheelRadiusPt;
@end
@implementation MobaSkillTuningOverlayLayoutProfile
@end

@interface MobaSkillTuningOverlayFakeRuntime : NSObject
@property (nonatomic, strong) MobaSkillRuntimeDescriptor *descriptor;
@end
@implementation MobaSkillTuningOverlayFakeRuntime
- (MobaSkillRuntimeDescriptor *)descriptorForSkillSlot:(MobaCanonicalSkillSlot)slot {
    (void)slot;
    return self.descriptor;
}
@end

@interface MobaSkillTuningOverlayFakeController : NSObject
@property (nonatomic, strong) MobaSkillTuningDraft *draft;
@property (nonatomic, copy) MobaCanonicalSkillSlot selectedSkillSlot;
@property (nonatomic, strong, nullable) id lastValidRuntime;
@property (nonatomic, strong, nullable) NSError *validationError;
@end
@implementation MobaSkillTuningOverlayFakeController
- (BOOL)refreshCandidateWithError:(NSError **)error { (void)error; return YES; }
@end

@interface MobaSkillTuningTests : XCTestCase
@property (nonatomic, strong) MobaProfileDecoder *decoder;
@property (nonatomic, copy) NSData *runtimeData;
@property (nonatomic, copy) NSData *championData;
@end

@implementation MobaSkillTuningTests

- (NSData *)dataNamed:(NSString *)name {
    NSString *testDirectory = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSString *root = [testDirectory stringByDeletingLastPathComponent];
    NSString *path = [[root stringByAppendingPathComponent:@"examples/moba"] stringByAppendingPathComponent:name];
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data);
    return data;
}

- (void)setUp {
    [super setUp];
    self.decoder = [[MobaProfileDecoder alloc] init];
    self.runtimeData = [self dataNamed:@"runtime.json"];
    self.championData = [self dataNamed:@"caitlyn.json"];
}

- (MobaSkillTuningDraft *)draft {
    NSError *error = nil;
    MobaSkillTuningDraft *draft = [[MobaSkillTuningDraft alloc]
        initWithRuntimeData:self.runtimeData championData:self.championData decoder:self.decoder error:&error];
    XCTAssertNotNil(draft);
    XCTAssertNil(error);
    return draft;
}

- (NSMutableDictionary *)JSON:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
}

- (MobaSkillTuningOverlayView *)overlayViewWithRuntime:(id)runtime {
    MobaSkillTuningOverlayFakeController *controller = [[MobaSkillTuningOverlayFakeController alloc] init];
    controller.draft = self.draft;
    controller.selectedSkillSlot = MobaCanonicalSkillSlotQ;
    controller.lastValidRuntime = runtime;
    MobaSkillTuningOverlayView *overlay = [[MobaSkillTuningOverlayView alloc]
        initWithTuningController:(MobaSkillTuningController *)controller championName:@"Caitlyn"];
    overlay.frame = CGRectMake(0, 0, 1024, 520);
    [overlay setNeedsLayout];
    [overlay layoutIfNeeded];
    return overlay;
}

- (MobaSkillTuningOverlayView *)overlayView {
    return [self overlayViewWithRuntime:nil];
}

- (MobaSkillRuntimeDescriptor *)pointPreviewDescriptor {
    MobaPointCastConfiguration *configuration = [[MobaPointCastConfiguration alloc]
        initWithTargetMode:MobaPointCastTargetModeGround skillKeyCode:87
        heroAnchor:CGPointMake(1280, 720) defaultDirection:MobaAimDefaultUpDirection()
        defaultDistanceRatio:1.0 wheelRadius:100 deadzoneRatio:0.1
        fullRangeRatio:0.9 curveExponent:1.0
        minimumRadii:MobaAimRadiiMake(0, 0, 0, 0)
        maximumRadii:MobaAimRadiiMake(600, 600, 400, 400)
        cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    MobaSkillTuningOverlayTouchResponse *response = [[MobaSkillTuningOverlayTouchResponse alloc] init];
    response.deadzoneRatio = 0.1;
    MobaSkillTuningOverlaySkillProfile *skill = [[MobaSkillTuningOverlaySkillProfile alloc] init];
    skill.touchResponse = response;
    MobaSkillTuningOverlayLayoutProfile *layout = [[MobaSkillTuningOverlayLayoutProfile alloc] init];
    layout.wheelRadiusPt = @100;
    return [[MobaSkillRuntimeDescriptor alloc] initWithSkillSlot:MobaCanonicalSkillSlotW
        displayLabel:@"W" layoutControlName:@"abilityW" inputAction:@"ability2" hostKeyCode:87
        castType:MobaProfileSkillCastTypePoint allowCancel:YES skillProfile:skill
        layoutControlProfile:layout strategy:NSObject.new cursorCoalescer:nil
        instantConfiguration:nil directionalConfiguration:nil pointConfiguration:configuration];
}

- (NSArray<UIView *> *)descendantsOfView:(UIView *)view matchingClass:(Class)classType {
    NSMutableArray<UIView *> *matches = [NSMutableArray array];
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:classType]) [matches addObject:child];
        [matches addObjectsFromArray:[self descendantsOfView:child matchingClass:classType]];
    }
    return matches;
}

- (void)testBaselineIsSeparatedFromMutableDraft {
    MobaSkillTuningDraft *draft = self.draft;
    XCTAssertTrue([draft setHeroAnchorX:1400 y:700 error:nil]);
    XCTAssertTrue(draft.isDirty);
    NSNumber *originalX = [self JSON:self.runtimeData][@"camera"][@"heroAnchorPx"][@"x"];
    XCTAssertEqual(originalX.integerValue, 1280);
    [draft revert];
    XCTAssertEqual(draft.heroAnchorX, 1280);
    XCTAssertFalse(draft.isDirty);
}

- (void)testHeroAnchorAxesAndRateEditIndependently {
    MobaSkillTuningDraft *draft = self.draft;
    XCTAssertTrue([draft setHeroAnchorX:1500 y:600 error:nil]);
    XCTAssertTrue([draft setMouseUpdateRateHz:120 error:nil]);
    XCTAssertEqual(draft.heroAnchorX, 1500);
    XCTAssertEqual(draft.heroAnchorY, 600);
    XCTAssertEqual(draft.mouseUpdateRateHz, 120u);
}

- (void)testDirectionalFourRadiiEditIndependently {
    MobaSkillTuningDraft *draft = self.draft;
    NSArray *fields = @[@(MobaSkillTuningFieldDirectionalLeftPx), @(MobaSkillTuningFieldDirectionalRightPx),
                        @(MobaSkillTuningFieldDirectionalUpPx), @(MobaSkillTuningFieldDirectionalDownPx)];
    for (NSUInteger index = 0; index < fields.count; index++) {
        NSNumber *field = fields[index];
        XCTAssertTrue([draft setValue:@(501 + index) forField:field.integerValue
                             skillSlot:MobaCanonicalSkillSlotQ error:nil]);
    }
    MobaSkillTuningSkillValue *value = [draft skillValueForSlot:MobaCanonicalSkillSlotQ];
    for (NSUInteger index = 0; index < fields.count; index++) {
        XCTAssertEqualObjects(value.numericValues[fields[index]], @(501 + index));
    }
}

- (void)testPointEightRadiiEditIndependently {
    MobaSkillTuningDraft *draft = self.draft;
    for (NSInteger field = MobaSkillTuningFieldPointMinLeftPx;
         field <= MobaSkillTuningFieldPointMaxDownPx; field++) {
        XCTAssertTrue([draft setValue:@(field * 10 + 1) forField:field
                             skillSlot:MobaCanonicalSkillSlotW error:nil]);
    }
    MobaSkillTuningSkillValue *value = [draft skillValueForSlot:MobaCanonicalSkillSlotW];
    for (NSInteger field = MobaSkillTuningFieldPointMinLeftPx;
         field <= MobaSkillTuningFieldPointMaxDownPx; field++) {
        XCTAssertEqualObjects(value.numericValues[@(field)], @(field * 10 + 1));
    }
}

- (void)testDefaultResponseAndAllowCancelFieldsEdit {
    MobaSkillTuningDraft *draft = self.draft;
    XCTAssertTrue([draft setValue:@180 forField:MobaSkillTuningFieldDefaultAngleDegrees
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft setValue:@0.5 forField:MobaSkillTuningFieldDefaultDistanceRatio
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft setValue:@0.12 forField:MobaSkillTuningFieldTouchDeadzoneRatio
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft setValue:@0.95 forField:MobaSkillTuningFieldTouchFullRangeRatio
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft setValue:@1.5 forField:MobaSkillTuningFieldTouchCurveExponent
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft setAllowCancel:NO skillSlot:MobaCanonicalSkillSlotW error:nil]);
    MobaSkillTuningSkillValue *value = [draft skillValueForSlot:MobaCanonicalSkillSlotW];
    XCTAssertEqualObjects(value.defaultAngleDegrees, @180);
    XCTAssertEqualObjects(value.defaultDistanceRatio, @0.5);
    XCTAssertFalse(value.allowCancel);
}

- (void)testUneditedSkillsRemainByteSemanticallyEqual {
    MobaSkillTuningDraft *draft = self.draft;
    NSDictionary *before = [self JSON:self.championData][@"skills"][@"E"];
    XCTAssertTrue([draft setValue:@700 forField:MobaSkillTuningFieldDirectionalLeftPx
                         skillSlot:MobaCanonicalSkillSlotQ error:nil]);
    NSDictionary *after = [self JSON:[draft championDataWithError:nil]][@"skills"][@"E"];
    XCTAssertEqualObjects(after, before);
}

- (void)testUnknownRootNestedAndFutureSkillFieldsSurvive {
    NSMutableDictionary *runtime = [self JSON:self.runtimeData];
    NSMutableDictionary *champion = [self JSON:self.championData];
    runtime[@"futureRuntime"] = @{ @"nested": @[@1, @2] };
    champion[@"futureChampion"] = @YES;
    champion[@"skills"][@"Q"][@"futureAim"] = @{ @"value": @7 };
    NSData *runtimeData = [NSJSONSerialization dataWithJSONObject:runtime options:0 error:nil];
    NSData *championData = [NSJSONSerialization dataWithJSONObject:champion options:0 error:nil];
    MobaSkillTuningDraft *draft = [[MobaSkillTuningDraft alloc] initWithRuntimeData:runtimeData
        championData:championData decoder:self.decoder error:nil];
    XCTAssertTrue([draft setHeroAnchorX:1200 y:700 error:nil]);
    NSDictionary *runtimeAfter = [self JSON:[draft runtimeDataWithError:nil]];
    NSDictionary *championAfter = [self JSON:[draft championDataWithError:nil]];
    XCTAssertEqualObjects(runtimeAfter[@"futureRuntime"], runtime[@"futureRuntime"]);
    XCTAssertEqualObjects(championAfter[@"futureChampion"], @YES);
    XCTAssertEqualObjects(championAfter[@"skills"][@"Q"][@"futureAim"], @{ @"value": @7 });
}

- (void)testInstantRejectsInapplicableRangeWithoutInjectingFields {
    MobaSkillTuningDraft *draft = [[MobaSkillTuningDraft alloc]
        initWithRuntimeData:self.runtimeData championData:[self dataNamed:@"debug-instant.json"]
        decoder:self.decoder error:nil];
    NSError *error = nil;
    XCTAssertFalse([draft setValue:@100 forField:MobaSkillTuningFieldDirectionalLeftPx
                          skillSlot:MobaCanonicalSkillSlotQ error:&error]);
    XCTAssertNotNil(error);
    NSDictionary *skill = [self JSON:[draft championDataWithError:nil]][@"skills"][@"Q"];
    XCTAssertNil(skill[@"range"]);
    XCTAssertNil(skill[@"touchResponse"]);
}

- (void)testNonFiniteAndWrongTypeValuesAreRejected {
    MobaSkillTuningDraft *draft = self.draft;
    XCTAssertFalse([draft setValue:@(NAN) forField:MobaSkillTuningFieldDirectionalLeftPx
                          skillSlot:MobaCanonicalSkillSlotQ error:nil]);
    XCTAssertFalse([draft setValue:@(INFINITY) forField:MobaSkillTuningFieldDirectionalLeftPx
                          skillSlot:MobaCanonicalSkillSlotQ error:nil]);
    XCTAssertFalse([draft setValue:(id)@"100" forField:MobaSkillTuningFieldDirectionalLeftPx
                          skillSlot:MobaCanonicalSkillSlotQ error:nil]);
}

- (void)testAcceptCurrentValuesMovesRevertBaseline {
    MobaSkillTuningDraft *draft = self.draft;
    [draft setHeroAnchorX:1300 y:710 error:nil];
    XCTAssertTrue([draft acceptCurrentValuesAsBaselineWithError:nil]);
    [draft setHeroAnchorX:1400 y:710 error:nil];
    [draft revert];
    XCTAssertEqual(draft.heroAnchorX, 1300);
    XCTAssertFalse(draft.isDirty);
}

- (void)testManagedDefaultsRestoreOnlyRuntimeAnchorAndUpdateRate {
    NSMutableDictionary *runtime = [self JSON:self.runtimeData];
    runtime[@"camera"][@"heroAnchorPx"][@"x"] = @1500;
    runtime[@"camera"][@"heroAnchorPx"][@"y"] = @600;
    runtime[@"mouseUpdateRateHz"] = @120;
    runtime[@"globalOpacityMultiplier"] = @0.42;
    runtime[@"futureRuntime"] = @{ @"retained": @YES };
    runtime[@"camera"][@"futureCamera"] = @"retained";
    NSData *changedRuntime = [NSJSONSerialization dataWithJSONObject:runtime options:0 error:nil];
    MobaSkillTuningDraft *draft = [[MobaSkillTuningDraft alloc]
        initWithRuntimeData:changedRuntime championData:self.championData decoder:self.decoder error:nil];

    XCTAssertTrue([draft applyManagedDefaultsFromRuntimeData:self.runtimeData
                                               championData:self.championData
                                                    decoder:self.decoder error:nil]);
    NSDictionary *restored = [self JSON:[draft runtimeDataWithError:nil]];
    XCTAssertEqualObjects(restored[@"camera"][@"heroAnchorPx"][@"x"], @1280);
    XCTAssertEqualObjects(restored[@"camera"][@"heroAnchorPx"][@"y"], @720);
    XCTAssertEqualObjects(restored[@"mouseUpdateRateHz"], @60);
    XCTAssertEqualObjects(restored[@"globalOpacityMultiplier"], @0.42);
    XCTAssertEqualObjects(restored[@"futureRuntime"], @{ @"retained": @YES });
    XCTAssertEqualObjects(restored[@"camera"][@"futureCamera"], @"retained");
    XCTAssertEqualObjects(restored[@"camera"][@"mode"], @"locked");
}

- (void)testManagedDefaultsPreserveChampionIdentityMetadataInputAndUnknownFields {
    NSMutableDictionary *champion = [self JSON:self.championData];
    champion[@"displayName"] = @"Locally Named Caitlyn";
    champion[@"calibrationStatus"] = @"local-metadata";
    champion[@"futureChampion"] = @7;
    champion[@"skills"][@"FutureSkill"] = @{
        @"inputAction": @"ability1", @"castType": @"instant",
        @"activation": @"onRelease", @"tapDurationMs": @30,
        @"allowCancel": @NO, @"future": @YES,
    };
    champion[@"skills"][@"Q"][@"inputAction"] = @"ability1";
    champion[@"skills"][@"Q"][@"futureSkill"] = @{ @"retained": @YES };
    champion[@"skills"][@"Q"][@"range"][@"leftPx"] = @501;
    NSData *changedChampion = [NSJSONSerialization dataWithJSONObject:champion options:0 error:nil];
    MobaSkillTuningDraft *draft = [[MobaSkillTuningDraft alloc]
        initWithRuntimeData:self.runtimeData championData:changedChampion decoder:self.decoder error:nil];

    XCTAssertTrue([draft applyManagedDefaultsFromRuntimeData:self.runtimeData
                                               championData:self.championData
                                                    decoder:self.decoder error:nil]);
    NSDictionary *restored = [self JSON:[draft championDataWithError:nil]];
    XCTAssertEqualObjects(restored[@"championId"], @"caitlyn");
    XCTAssertEqualObjects(restored[@"displayName"], @"Locally Named Caitlyn");
    XCTAssertEqualObjects(restored[@"calibrationStatus"], @"local-metadata");
    XCTAssertEqualObjects(restored[@"futureChampion"], @7);
    XCTAssertEqualObjects(restored[@"skills"][@"Q"][@"inputAction"], @"ability1");
    XCTAssertEqualObjects(restored[@"skills"][@"Q"][@"castType"], @"directional");
    XCTAssertEqualObjects(restored[@"skills"][@"Q"][@"futureSkill"], @{ @"retained": @YES });
    XCTAssertEqualObjects(restored[@"skills"][@"FutureSkill"], champion[@"skills"][@"FutureSkill"]);
    XCTAssertEqualObjects(restored[@"skills"][@"Q"][@"range"][@"leftPx"], @720);
}

- (void)testManagedDefaultsRestoreDirectionalAndPointFieldsIndependently {
    MobaSkillTuningDraft *draft = self.draft;
    XCTAssertTrue([draft setValue:@111 forField:MobaSkillTuningFieldDirectionalRightPx
                         skillSlot:MobaCanonicalSkillSlotQ error:nil]);
    XCTAssertTrue([draft setValue:@222 forField:MobaSkillTuningFieldPointMaxDownPx
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft setValue:@0.2 forField:MobaSkillTuningFieldTouchDeadzoneRatio
                         skillSlot:MobaCanonicalSkillSlotW error:nil]);
    XCTAssertTrue([draft applyManagedDefaultsFromRuntimeData:self.runtimeData
                                               championData:self.championData
                                                    decoder:self.decoder error:nil]);
    MobaSkillTuningSkillValue *q = [draft skillValueForSlot:MobaCanonicalSkillSlotQ];
    MobaSkillTuningSkillValue *w = [draft skillValueForSlot:MobaCanonicalSkillSlotW];
    XCTAssertEqualObjects(q.numericValues[@(MobaSkillTuningFieldDirectionalRightPx)], @720);
    XCTAssertEqualObjects(w.numericValues[@(MobaSkillTuningFieldPointMaxDownPx)], @450);
    XCTAssertEqualObjects(w.numericValues[@(MobaSkillTuningFieldTouchDeadzoneRatio)], @0.10);
}

- (void)testMismatchedChampionDefaultsFailWithoutMutatingDraft {
    MobaSkillTuningDraft *draft = self.draft;
    XCTAssertTrue([draft setHeroAnchorX:1400 y:700 error:nil]);
    NSData *runtimeBefore = [draft runtimeDataWithError:nil];
    NSData *championBefore = [draft championDataWithError:nil];
    NSError *error = nil;
    XCTAssertFalse([draft applyManagedDefaultsFromRuntimeData:self.runtimeData
                                                championData:[self dataNamed:@"debug-instant.json"]
                                                     decoder:self.decoder error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects([self JSON:[draft runtimeDataWithError:nil]], [self JSON:runtimeBefore]);
    XCTAssertEqualObjects([self JSON:[draft championDataWithError:nil]], [self JSON:championBefore]);
}

- (void)testInstantManagedDefaultsDoNotInjectOrRemoveInapplicableFields {
    NSMutableDictionary *instant = [self JSON:[self dataNamed:@"debug-instant.json"]];
    instant[@"skills"][@"Q"][@"futureInapplicableRange"] = @{ @"value": @42 };
    NSData *current = [NSJSONSerialization dataWithJSONObject:instant options:0 error:nil];
    MobaSkillTuningDraft *draft = [[MobaSkillTuningDraft alloc]
        initWithRuntimeData:self.runtimeData championData:current decoder:self.decoder error:nil];
    XCTAssertTrue([draft applyManagedDefaultsFromRuntimeData:self.runtimeData
                                               championData:[self dataNamed:@"debug-instant.json"]
                                                    decoder:self.decoder error:nil]);
    NSDictionary *skill = [self JSON:[draft championDataWithError:nil]][@"skills"][@"Q"];
    XCTAssertEqualObjects(skill[@"futureInapplicableRange"], @{ @"value": @42 });
    XCTAssertNil(skill[@"range"]);
    XCTAssertNil(skill[@"touchResponse"]);
}

- (void)testInspectorUsesPermanentLabeledScrollableRowsAndAccessibleActions {
    MobaSkillTuningOverlayView *overlay = [self overlayView];
    NSArray<NSString *> *labels = overlay.visibleFieldLabels;
    XCTAssertTrue([labels containsObject:@"Hero Anchor X (px)"]);
    XCTAssertTrue([labels containsObject:@"Hero Anchor Y (px)"]);
    XCTAssertTrue([labels containsObject:@"Mouse Update Rate (Hz)"]);
    XCTAssertTrue([labels containsObject:@"Allow Cancel"]);
    XCTAssertTrue([labels containsObject:@"Default Angle (deg)"]);
    for (NSString *label in @[@"Default Distance Ratio", @"Left Range (px)", @"Right Range (px)",
                               @"Up Range (px)", @"Down Range (px)", @"Deadzone Ratio"]) {
        XCTAssertTrue([labels containsObject:label], @"Missing permanent label %@", label);
    }
    BOOL foundCastType = NO;
    for (UILabel *label in (NSArray<UILabel *> *)[self descendantsOfView:overlay
                                                               matchingClass:UILabel.class]) {
        if ([label.text hasPrefix:@"Cast type:"]) foundCastType = YES;
    }
    XCTAssertTrue(foundCastType);
    XCTAssertGreaterThan(overlay.inspectorScrollView.contentSize.height,
                         CGRectGetHeight(overlay.inspectorScrollView.bounds));
    CGRect scrollFrame = [overlay.inspectorScrollView.superview
        convertRect:overlay.inspectorScrollView.frame toView:overlay];
    for (UIButton *button in (NSArray<UIButton *> *)[self descendantsOfView:overlay
                                                               matchingClass:UIButton.class]) {
        NSString *title = [button titleForState:UIControlStateNormal];
        if (![@[@"Save", @"Revert", @"Defaults"] containsObject:title]) continue;
        CGRect buttonFrame = [button.superview convertRect:button.frame toView:overlay];
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(buttonFrame), CGRectGetMaxY(scrollFrame));
    }
    for (NSString *label in labels) {
        XCTAssertFalse([label localizedCaseInsensitiveContainsString:@"host"]);
        XCTAssertFalse([label localizedCaseInsensitiveContainsString:@"ability"]);
    }
}

- (void)testLiveModeDisablesManagedControlsButKeepsLabelsAndExitSegmentAvailable {
    MobaSkillTuningOverlayView *overlay = [self overlayView];
    NSArray<NSString *> *before = overlay.visibleFieldLabels;
    [overlay setCastMode:MobaSkillTuningCastModeLiveCast];
    [overlay setEditingEnabled:NO];
    XCTAssertFalse(overlay.isEditingEnabled);
    XCTAssertTrue(overlay.castModeControl.enabled);
    XCTAssertEqualObjects(overlay.visibleFieldLabels, before);
    for (UITextField *field in (NSArray<UITextField *> *)[self descendantsOfView:overlay
                                                                    matchingClass:UITextField.class]) {
        XCTAssertFalse(field.enabled);
    }
}

- (void)testPointInspectorKeepsAllMinimumMaximumAndResponseLabelsVisibleAfterValuesExist {
    MobaSkillTuningOverlayView *overlay = [self overlayView];
    MobaSkillTuningOverlayFakeController *controller =
        (MobaSkillTuningOverlayFakeController *)overlay.tuningController;
    controller.selectedSkillSlot = MobaCanonicalSkillSlotW;
    [overlay refreshFromDraft];
    NSArray<NSString *> *labels = overlay.visibleFieldLabels;
    for (NSString *label in @[@"Min Left (px)", @"Min Right (px)", @"Min Up (px)", @"Min Down (px)",
                               @"Max Left (px)", @"Max Right (px)", @"Max Up (px)", @"Max Down (px)",
                               @"Deadzone Ratio", @"Full Range Ratio", @"Curve Exponent"]) {
        XCTAssertTrue([labels containsObject:label], @"Missing permanent label %@", label);
    }
    for (UITextField *field in (NSArray<UITextField *> *)[self descendantsOfView:overlay
                                                                    matchingClass:UITextField.class]) {
        if (field.text.length > 0) field.text = @"123.5";
    }
    XCTAssertEqualObjects(overlay.visibleFieldLabels, labels);
}

- (void)testPreviewEndAppliesFinalEndpointBeforeClearingToken {
    MobaSkillTuningOverlayFakeRuntime *runtime = [[MobaSkillTuningOverlayFakeRuntime alloc] init];
    runtime.descriptor = [self pointPreviewDescriptor];
    MobaSkillTuningOverlayView *overlay = [self overlayViewWithRuntime:runtime];
    NSObject *token = [[NSObject alloc] init];
    XCTAssertTrue([overlay beginPreviewWithToken:token streamViewPoint:CGPointMake(100, 100)]);
    XCTAssertTrue([overlay endPreviewWithToken:token streamViewPoint:CGPointMake(124, 112)]);
    XCTAssertEqualWithAccuracy(overlay.previewDisplacement.dx, 24, 0.000001);
    XCTAssertEqualWithAccuracy(overlay.previewDisplacement.dy, 12, 0.000001);
    XCTAssertTrue(overlay.aimPreviewView.hasPreviewResult);
    XCTAssertNotEqual(overlay.aimPreviewView.previewResult.target.x,
                      overlay.aimPreviewView.previewResult.defaultTarget.x);
    XCTAssertFalse([overlay updatePreviewWithToken:token streamViewPoint:CGPointMake(200, 200)]);
}

- (void)testInvalidFinalPreviewEndpointCancelsSafely {
    MobaSkillTuningOverlayView *overlay = [self overlayView];
    NSObject *token = [[NSObject alloc] init];
    XCTAssertTrue([overlay beginPreviewWithToken:token streamViewPoint:CGPointMake(100, 100)]);
    XCTAssertTrue([overlay updatePreviewWithToken:token streamViewPoint:CGPointMake(120, 100)]);
    XCTAssertFalse([overlay endPreviewWithToken:token streamViewPoint:CGPointMake(NAN, 100)]);
    XCTAssertEqual(overlay.previewDisplacement.dx, 0);
    XCTAssertEqual(overlay.previewDisplacement.dy, 0);
    XCTAssertFalse([overlay updatePreviewWithToken:token streamViewPoint:CGPointMake(130, 100)]);
}

- (void)testFinalPreviewEndpointReturningToDeadzoneRestoresDefaultTarget {
    MobaSkillTuningOverlayFakeRuntime *runtime = [[MobaSkillTuningOverlayFakeRuntime alloc] init];
    runtime.descriptor = [self pointPreviewDescriptor];
    MobaSkillTuningOverlayView *overlay = [self overlayViewWithRuntime:runtime];
    NSObject *token = [[NSObject alloc] init];
    XCTAssertTrue([overlay beginPreviewWithToken:token streamViewPoint:CGPointMake(100, 100)]);
    XCTAssertTrue([overlay updatePreviewWithToken:token streamViewPoint:CGPointMake(150, 100)]);
    XCTAssertNotEqual(overlay.aimPreviewView.previewResult.target.x,
                      overlay.aimPreviewView.previewResult.defaultTarget.x);
    XCTAssertTrue([overlay endPreviewWithToken:token streamViewPoint:CGPointMake(105, 100)]);
    XCTAssertEqual(overlay.aimPreviewView.previewResult.target.x,
                   overlay.aimPreviewView.previewResult.defaultTarget.x);
    XCTAssertEqual(overlay.aimPreviewView.previewResult.target.y,
                   overlay.aimPreviewView.previewResult.defaultTarget.y);
}

@end
