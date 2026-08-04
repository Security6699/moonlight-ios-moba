//
//  MobaPointResponseTests.m
//  MoonlightMobaTests
//


#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Geometry/MobaPointResponse.h"

static const CGFloat MobaPointResponseTestTolerance = 0.000001;

@interface MobaPointResponseTests : XCTestCase
@end

@implementation MobaPointResponseTests

- (BOOL)responseForDragDistance:(CGFloat)dragDistance
                       exponent:(CGFloat)exponent
                          value:(CGFloat *)value {
    return MobaPointResponseDistanceRatio(dragDistance, 100.0, 0.2, 0.8, exponent, value);
}

- (void)testInsideDeadzoneAndDeadzoneBoundaryReturnZero {
    CGFloat value = -1.0;
    XCTAssertTrue([self responseForDragDistance:10.0 exponent:1.0 value:&value]);
    XCTAssertEqualWithAccuracy(value, 0.0, MobaPointResponseTestTolerance);
    XCTAssertTrue([self responseForDragDistance:20.0 exponent:1.0 value:&value]);
    XCTAssertEqualWithAccuracy(value, 0.0, MobaPointResponseTestTolerance);
}

- (void)testFullRangeBoundaryAndGreaterDistancesReturnOne {
    CGFloat value = -1.0;
    XCTAssertTrue([self responseForDragDistance:80.0 exponent:1.0 value:&value]);
    XCTAssertEqualWithAccuracy(value, 1.0, MobaPointResponseTestTolerance);
    XCTAssertTrue([self responseForDragDistance:120.0 exponent:1.0 value:&value]);
    XCTAssertEqualWithAccuracy(value, 1.0, MobaPointResponseTestTolerance);
}

- (void)testExponentOneIsLinearAtTheMidpoint {
    CGFloat value = -1.0;
    XCTAssertTrue([self responseForDragDistance:50.0 exponent:1.0 value:&value]);
    XCTAssertEqualWithAccuracy(value, 0.5, MobaPointResponseTestTolerance);
}

- (void)testExponentGreaterThanOneIsSlowerThanLinear {
    CGFloat value = -1.0;
    XCTAssertTrue([self responseForDragDistance:50.0 exponent:2.0 value:&value]);
    XCTAssertEqualWithAccuracy(value, 0.25, MobaPointResponseTestTolerance);
    XCTAssertLessThan(value, 0.5);
}

- (void)testExponentBetweenZeroAndOneIsFasterThanLinear {
    CGFloat value = -1.0;
    XCTAssertTrue([self responseForDragDistance:50.0 exponent:0.5 value:&value]);
    XCTAssertEqualWithAccuracy(value, sqrt(0.5), MobaPointResponseTestTolerance);
    XCTAssertGreaterThan(value, 0.5);
}

- (void)testResponseIsMonotonicAndAlwaysBounded {
    NSArray<NSNumber *> *dragDistances = @[@(-20.0), @(0.0), @(10.0), @(20.0), @(35.0),
                                           @(50.0), @(65.0), @(80.0), @(120.0)];
    CGFloat previous = 0.0;
    for (NSNumber *dragDistance in dragDistances) {
        CGFloat value = -1.0;
        XCTAssertTrue([self responseForDragDistance:dragDistance.doubleValue exponent:1.5 value:&value]);
        XCTAssertGreaterThanOrEqual(value, 0.0);
        XCTAssertLessThanOrEqual(value, 1.0);
        XCTAssertGreaterThanOrEqual(value, previous);
        previous = value;
    }
}

- (void)testInvalidConfigurationIsRejected {
    CGFloat value = 7.0;
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 0.0, 0.2, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, -1.0, 0.2, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, -0.1, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.8, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.8, 0.7, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.2, 0.8, 0.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.2, 0.8, -1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.2, 0.8, 1.0, NULL));
    XCTAssertEqualWithAccuracy(value, 7.0, MobaPointResponseTestTolerance);
}

- (void)testNonFiniteInputsAreRejected {
    CGFloat value = 7.0;
    XCTAssertFalse(MobaPointResponseDistanceRatio(NAN, 100.0, 0.2, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(INFINITY, 100.0, 0.2, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, INFINITY, 0.2, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, NAN, 0.8, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.2, INFINITY, 1.0, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.2, 0.8, NAN, &value));
    XCTAssertFalse(MobaPointResponseDistanceRatio(50.0, 100.0, 0.2, 0.8, INFINITY, &value));
    XCTAssertEqualWithAccuracy(value, 7.0, MobaPointResponseTestTolerance);
}

@end
