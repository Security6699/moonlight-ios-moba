//
//  MobaSkillTuningTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>
#import <math.h>

#import "../Limelight/Input/MOBA/Profiles/MobaSkillTuning.h"

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

@end
