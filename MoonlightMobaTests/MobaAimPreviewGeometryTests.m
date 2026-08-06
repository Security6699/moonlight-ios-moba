//
//  MobaAimPreviewGeometryTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Geometry/MobaAimPreviewGeometry.h"
#import "../Limelight/Input/MOBA/Casting/MobaCastStrategyFactory.h"
#import "../Limelight/Input/MOBA/Controls/MobaAimPreviewView.h"
#import "../Limelight/Input/MOBA/Controls/MobaSkillTuningOverlayView.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Geometry/MobaSkillDragSemantics.h"

@interface MobaAimPreviewSink : NSObject <MobaInputSink>
@property (nonatomic) NSUInteger eventCount;
@end

@interface MobaAimPreviewTouchResponse : NSObject
@property (nonatomic) double deadzoneRatio;
@end
@implementation MobaAimPreviewTouchResponse
@end

@interface MobaAimPreviewSkillProfile : NSObject
@property (nonatomic, strong, nullable) MobaAimPreviewTouchResponse *touchResponse;
@end
@implementation MobaAimPreviewSkillProfile
@end

@interface MobaAimPreviewLayoutProfile : NSObject
@property (nonatomic, strong) NSNumber *wheelRadiusPt;
@end
@implementation MobaAimPreviewLayoutProfile
@end
@implementation MobaAimPreviewSink
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down { (void)keyCode; (void)down; self.eventCount++; }
- (void)moveCursorToCanvasPoint:(CGPoint)point { (void)point; self.eventCount++; }
- (void)sendMouseButton:(int)button down:(BOOL)down { (void)button; (void)down; self.eventCount++; }
@end

@interface MobaSkillRuntimeDescriptor (AimPreviewTests)
- (instancetype)initWithSkillSlot:(MobaCanonicalSkillSlot)skillSlot displayLabel:(NSString *)displayLabel
                layoutControlName:(NSString *)layoutControlName inputAction:(NSString *)inputAction
                      hostKeyCode:(uint16_t)hostKeyCode castType:(MobaProfileSkillCastType)castType
                      allowCancel:(BOOL)allowCancel skillProfile:(id)skillProfile
             layoutControlProfile:(id)layoutControlProfile strategy:(id)strategy
                  cursorCoalescer:(id)cursorCoalescer instantConfiguration:(id)instantConfiguration
         directionalConfiguration:(id)directionalConfiguration pointConfiguration:(id)pointConfiguration;
@end

@interface MobaAimPreviewGeometryTests : XCTestCase
@end

@implementation MobaAimPreviewGeometryTests

- (CGPoint)pointAtIndex:(NSUInteger)index inBoundary:(NSArray<NSValue *> *)boundary {
    CGPoint point = CGPointZero;
    [boundary[index] getValue:&point size:sizeof(point)];
    return point;
}

- (MobaSkillRuntimeDescriptor *)directionalDescriptorWithAnchor:(CGPoint)anchor {
    MobaDirectionalCastConfiguration *configuration = [[MobaDirectionalCastConfiguration alloc]
        initWithSkillKeyCode:81 heroAnchor:anchor radii:MobaAimRadiiMake(400, 600, 300, 500)
        defaultDirection:MobaAimDefaultUpDirection() defaultDistanceRatio:1.0
        cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    MobaAimPreviewSkillProfile *skill = [[MobaAimPreviewSkillProfile alloc] init];
    MobaAimPreviewLayoutProfile *layout = [[MobaAimPreviewLayoutProfile alloc] init];
    layout.wheelRadiusPt = @100;
    return [[MobaSkillRuntimeDescriptor alloc] initWithSkillSlot:MobaCanonicalSkillSlotQ displayLabel:@"Q"
        layoutControlName:@"abilityQ" inputAction:@"ability1" hostKeyCode:81
        castType:MobaProfileSkillCastTypeDirectional allowCancel:YES skillProfile:(id)skill
        layoutControlProfile:(id)layout strategy:(id)NSObject.new cursorCoalescer:nil
        instantConfiguration:nil directionalConfiguration:configuration pointConfiguration:nil];
}

- (MobaSkillRuntimeDescriptor *)pointDescriptor {
    MobaPointCastConfiguration *configuration = [[MobaPointCastConfiguration alloc]
        initWithTargetMode:MobaPointCastTargetModeGround skillKeyCode:87 heroAnchor:CGPointMake(1280, 720)
        defaultDirection:MobaAimDefaultUpDirection() defaultDistanceRatio:1.0 wheelRadius:100
        deadzoneRatio:0.1 fullRangeRatio:0.9 curveExponent:1.0
        minimumRadii:MobaAimRadiiMake(0, 0, 0, 0) maximumRadii:MobaAimRadiiMake(600, 600, 400, 400)
        cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    MobaAimPreviewTouchResponse *response = [[MobaAimPreviewTouchResponse alloc] init];
    response.deadzoneRatio = 0.1;
    MobaAimPreviewSkillProfile *skill = [[MobaAimPreviewSkillProfile alloc] init];
    skill.touchResponse = response;
    MobaAimPreviewLayoutProfile *layout = [[MobaAimPreviewLayoutProfile alloc] init];
    layout.wheelRadiusPt = @100;
    return [[MobaSkillRuntimeDescriptor alloc] initWithSkillSlot:MobaCanonicalSkillSlotW displayLabel:@"W"
        layoutControlName:@"abilityW" inputAction:@"ability2" hostKeyCode:87
        castType:MobaProfileSkillCastTypePoint allowCancel:YES skillProfile:(id)skill
        layoutControlProfile:(id)layout strategy:(id)NSObject.new cursorCoalescer:nil
        instantConfiguration:nil directionalConfiguration:nil pointConfiguration:configuration];
}

- (void)testCanvasCenterMapsToVideoRectCenter {
    CGPoint mapped;
    XCTAssertTrue(MobaAimPreviewMapGamePointToVideoRect(CGPointMake(1280, 720),
        CGRectMake(100, 50, 1280, 720), &mapped));
    XCTAssertEqualWithAccuracy(mapped.x, 740, 0.6);
    XCTAssertEqualWithAccuracy(mapped.y, 410, 0.6);
}

- (void)testCanvasCornersMapToAspectFitEdges {
    CGPoint topLeft;
    CGPoint bottomRight;
    CGRect videoRect = CGRectMake(120, 40, 1024, 576);
    XCTAssertTrue(MobaAimPreviewMapGamePointToVideoRect(CGPointMake(0, 0), videoRect, &topLeft));
    XCTAssertTrue(MobaAimPreviewMapGamePointToVideoRect(CGPointMake(2559, 1439), videoRect, &bottomRight));
    XCTAssertEqual(topLeft.x, CGRectGetMinX(videoRect));
    XCTAssertEqual(topLeft.y, CGRectGetMinY(videoRect));
    XCTAssertEqual(bottomRight.x, CGRectGetMaxX(videoRect));
    XCTAssertEqual(bottomRight.y, CGRectGetMaxY(videoRect));
}

- (void)testBlackBarsRemainPartOfMappingOrigin {
    CGPoint mapped;
    XCTAssertTrue(MobaAimPreviewMapGamePointToVideoRect(CGPointMake(0, 0),
        CGRectMake(200, 100, 1200, 675), &mapped));
    XCTAssertEqual(mapped.x, 200);
    XCTAssertEqual(mapped.y, 100);
}

- (void)testEquivalentLandscapeVideoRectsMapIdentically {
    CGPoint left;
    CGPoint right;
    CGRect rect = CGRectMake(0, 34, 1366, 768);
    MobaAimPreviewMapGamePointToVideoRect(CGPointMake(1280, 720), rect, &left);
    MobaAimPreviewMapGamePointToVideoRect(CGPointMake(1280, 720), rect, &right);
    XCTAssertEqualWithAccuracy(left.x, right.x, 0.000001);
    XCTAssertEqualWithAccuracy(left.y, right.y, 0.000001);
}

- (void)testDirectionalPreviewUsesAsymmetricProductionGeometry {
    MobaAimPreviewResult result;
    XCTAssertTrue(MobaAimPreviewResultForDescriptor([self directionalDescriptorWithAnchor:CGPointMake(1280, 720)],
                                                     CGVectorMake(20, 0), &result));
    XCTAssertEqual(result.target.x, 1880);
    XCTAssertEqual(result.target.y, 720);
    XCTAssertEqual(result.defaultTarget.x, 1280);
    XCTAssertEqual(result.defaultTarget.y, 420);
}

- (void)testAnchorAdjustmentMovesPreviewWithoutSafeAreaInput {
    MobaAimPreviewResult first;
    MobaAimPreviewResult second;
    MobaAimPreviewResultForDescriptor([self directionalDescriptorWithAnchor:CGPointMake(1280, 720)],
                                      CGVectorMake(20, 0), &first);
    MobaAimPreviewResultForDescriptor([self directionalDescriptorWithAnchor:CGPointMake(1300, 700)],
                                      CGVectorMake(20, 0), &second);
    XCTAssertEqual(second.target.x - first.target.x, 20);
    XCTAssertEqual(second.target.y - first.target.y, -20);
}

- (void)testPointPreviewReusesResponseAndPointGeometry {
    MobaAimPreviewResult result;
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(self.pointDescriptor, CGVectorMake(50, 0), &result));
    XCTAssertTrue(result.pointCast);
    XCTAssertEqualWithAccuracy(result.distanceRatio, 0.5, 0.000001);
    XCTAssertEqual(result.target.x, 1580);
    XCTAssertEqual(result.target.y, 720);
}

- (void)testPreviewTargetClampsThroughGameCanvas {
    MobaAimPreviewResult result;
    XCTAssertTrue(MobaAimPreviewResultForDescriptor([self directionalDescriptorWithAnchor:CGPointMake(2500, 1400)],
                                                     CGVectorMake(100, 100), &result));
    XCTAssertLessThanOrEqual(result.target.x, 2559);
    XCTAssertLessThanOrEqual(result.target.y, 1439);
}

- (void)testInstantAndNonFinitePreviewInputsAreRejected {
    XCTAssertFalse(MobaAimPreviewMapGamePointToVideoRect(CGPointMake(NAN, 0), CGRectMake(0, 0, 100, 100), NULL));
    MobaAimPreviewResult result;
    XCTAssertFalse(MobaAimPreviewResultForDescriptor(self.pointDescriptor, CGVectorMake(INFINITY, 0), &result));
}

- (void)testPreviewOnlyGeometryAndDrawingProduceZeroDispatcherEvents {
    MobaAimPreviewSink *sink = [[MobaAimPreviewSink alloc] init];
    MobaInputDispatcher *dispatcher = [[MobaInputDispatcher alloc] initWithSink:sink];
    MobaAimPreviewResult result;
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(self.pointDescriptor, CGVectorMake(40, 20), &result));
    MobaAimPreviewView *view = [[MobaAimPreviewView alloc] initWithFrame:CGRectMake(0, 0, 1000, 700)];
    view.videoRect = CGRectMake(0, 69, 1000, 562.5);
    [view setPreviewResult:result valid:YES];
    XCTestExpectation *idle = [self expectationWithDescription:@"dispatcher idle"];
    [dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
    XCTAssertEqual(sink.eventCount, 0u);
    XCTAssertFalse(view.userInteractionEnabled);
}

- (void)testAsymmetricBoundaryCardinalsUseProductionRadii {
    CGPoint anchor = CGPointMake(1280, 720);
    MobaAimRadii radii = MobaAimRadiiMake(400, 600, 300, 500);
    NSArray<NSValue *> *boundary = MobaAimPreviewBoundaryPoints(anchor, radii, 8);
    XCTAssertEqual(boundary.count, 8u);
    XCTAssertEqualWithAccuracy([self pointAtIndex:0 inBoundary:boundary].x, 1880, 0.001);
    XCTAssertEqualWithAccuracy([self pointAtIndex:2 inBoundary:boundary].y, 1220, 0.001);
    XCTAssertEqualWithAccuracy([self pointAtIndex:4 inBoundary:boundary].x, 880, 0.001);
    XCTAssertEqualWithAccuracy([self pointAtIndex:6 inBoundary:boundary].y, 420, 0.001);
}

- (void)testAsymmetricBoundaryDiagonalsMatchProductionAimGeometry {
    CGPoint anchor = CGPointMake(1280, 720);
    MobaAimRadii radii = MobaAimRadiiMake(400, 600, 300, 500);
    NSArray<NSValue *> *boundary = MobaAimPreviewBoundaryPoints(anchor, radii, 8);
    for (NSUInteger index = 1; index < 8; index += 2) {
        CGFloat angle = 2.0 * M_PI * (CGFloat)index / 8.0;
        CGPoint expected = CGPointZero;
        XCTAssertTrue(MobaAimTargetForDirection(anchor, CGVectorMake(cos(angle), sin(angle)),
                                                radii, 1.0, &expected));
        CGPoint actual = [self pointAtIndex:index inBoundary:boundary];
        XCTAssertEqualWithAccuracy(actual.x, trunc(expected.x), 0.001);
        XCTAssertEqualWithAccuracy(actual.y, trunc(expected.y), 0.001);
    }
}

- (void)testZeroBoundaryDegeneratesToClampedAnchor {
    NSArray<NSValue *> *boundary = MobaAimPreviewBoundaryPoints(
        CGPointMake(3000, -10), MobaAimRadiiMake(0, 0, 0, 0), 32);
    XCTAssertEqual(boundary.count, 1u);
    CGPoint point = [self pointAtIndex:0 inBoundary:boundary];
    XCTAssertEqual(point.x, 2559);
    XCTAssertEqual(point.y, 0);
}

- (void)testPointMinimumAndMaximumBoundariesUseTheirOwnAsymmetricRadii {
    CGPoint anchor = CGPointMake(1000, 700);
    NSArray<NSValue *> *minimum = MobaAimPreviewBoundaryPoints(
        anchor, MobaAimRadiiMake(100, 200, 80, 160), 8);
    NSArray<NSValue *> *maximum = MobaAimPreviewBoundaryPoints(
        anchor, MobaAimRadiiMake(400, 600, 300, 500), 8);
    XCTAssertEqualWithAccuracy([self pointAtIndex:0 inBoundary:minimum].x, 1200, 0.001);
    XCTAssertEqualWithAccuracy([self pointAtIndex:6 inBoundary:minimum].y, 620, 0.001);
    XCTAssertEqualWithAccuracy([self pointAtIndex:0 inBoundary:maximum].x, 1600, 0.001);
    XCTAssertEqualWithAccuracy([self pointAtIndex:6 inBoundary:maximum].y, 400, 0.001);
}

- (void)testBoundarySamplesClampAndMapInsideVideoRect {
    CGRect videoRect = CGRectMake(100, 40, 1280, 720);
    NSArray<NSValue *> *boundary = MobaAimPreviewBoundaryPoints(
        CGPointMake(2500, 1400), MobaAimRadiiMake(900, 900, 900, 900), 64);
    for (NSValue *value in boundary) {
        CGPoint gamePoint = CGPointZero;
        [value getValue:&gamePoint size:sizeof(gamePoint)];
        CGPoint mapped = CGPointZero;
        XCTAssertTrue(MobaAimPreviewMapGamePointToVideoRect(gamePoint, videoRect, &mapped));
        XCTAssertGreaterThanOrEqual(mapped.x, CGRectGetMinX(videoRect));
        XCTAssertLessThanOrEqual(mapped.x, CGRectGetMaxX(videoRect));
        XCTAssertGreaterThanOrEqual(mapped.y, CGRectGetMinY(videoRect));
        XCTAssertLessThanOrEqual(mapped.y, CGRectGetMaxY(videoRect));
    }
}

- (void)testDirectionalMeaningfulThresholdIsStrictAndSharedWithPreview {
    MobaSkillRuntimeDescriptor *descriptor = [self directionalDescriptorWithAnchor:CGPointMake(1280, 720)];
    MobaAimPreviewResult below;
    MobaAimPreviewResult equal;
    MobaAimPreviewResult above;
    XCTAssertFalse(MobaSkillMeaningfulDragForDescriptor(descriptor, CGVectorMake(9.99, 0)));
    XCTAssertFalse(MobaSkillMeaningfulDragForDescriptor(descriptor, CGVectorMake(10, 0)));
    XCTAssertTrue(MobaSkillMeaningfulDragForDescriptor(descriptor, CGVectorMake(10.01, 0)));
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(descriptor, CGVectorMake(9.99, 0), &below));
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(descriptor, CGVectorMake(10, 0), &equal));
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(descriptor, CGVectorMake(10.01, 0), &above));
    XCTAssertEqual(below.target.x, below.defaultTarget.x);
    XCTAssertEqual(equal.target.x, equal.defaultTarget.x);
    XCTAssertGreaterThan(above.target.x, above.defaultTarget.x);
}

- (void)testPointBelowOrAtDeadzoneUsesDefaultTargetAndAboveUsesResponse {
    MobaSkillRuntimeDescriptor *descriptor = self.pointDescriptor;
    MobaAimPreviewResult below;
    MobaAimPreviewResult equal;
    MobaAimPreviewResult above;
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(descriptor, CGVectorMake(5, 0), &below));
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(descriptor, CGVectorMake(10, 0), &equal));
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(descriptor, CGVectorMake(50, 0), &above));
    XCTAssertEqual(below.target.x, below.defaultTarget.x);
    XCTAssertEqual(equal.target.x, equal.defaultTarget.x);
    XCTAssertEqualWithAccuracy(above.distanceRatio, 0.5, 0.000001);
    XCTAssertGreaterThan(above.target.x, above.defaultTarget.x);
}

- (void)testReturningToDeadzoneRestoresDefaultPreview {
    MobaAimPreviewResult dragged;
    MobaAimPreviewResult returned;
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(self.pointDescriptor, CGVectorMake(80, 0), &dragged));
    XCTAssertTrue(MobaAimPreviewResultForDescriptor(self.pointDescriptor, CGVectorMake(4, 0), &returned));
    XCTAssertNotEqual(dragged.target.x, dragged.defaultTarget.x);
    XCTAssertEqual(returned.target.x, returned.defaultTarget.x);
    XCTAssertEqual(returned.target.y, returned.defaultTarget.y);
}

@end
