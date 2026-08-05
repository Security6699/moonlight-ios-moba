//
//  MobaCancelZoneGeometryTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Geometry/MobaCancelZoneGeometry.h"

@interface MobaCancelZoneGeometryTests : XCTestCase
@end

@implementation MobaCancelZoneGeometryTests

- (MobaCancelZoneGeometry)geometry {
    return MobaCancelZoneGeometryMake(CGPointMake(100.0, 100.0), 100.0, 10.0);
}

- (void)assertPoint:(CGPoint)point isInside:(BOOL)expected {
    BOOL inside = !expected;
    XCTAssertTrue(MobaCancelZoneContainsPoint(self.geometry, point, &inside));
    XCTAssertEqual(inside, expected);
}

- (void)testCenterPointIsInside {
    [self assertPoint:CGPointMake(100.0, 100.0) isInside:YES];
}

- (void)testPointWithinActivationRadiusIsInside {
    [self assertPoint:CGPointMake(139.999, 100.0) isInside:YES];
}

- (void)testActivationBoundaryIsInside {
    [self assertPoint:CGPointMake(140.0, 100.0) isInside:YES];
}

- (void)testPointImmediatelyOutsideBoundaryIsOutside {
    [self assertPoint:CGPointMake(140.0001, 100.0) isInside:NO];
}

- (void)testFourAxisPointsUseCircularRadius {
    CGPoint points[] = {
        CGPointMake(140.0, 100.0),
        CGPointMake(100.0, 140.0),
        CGPointMake(60.0, 100.0),
        CGPointMake(100.0, 60.0),
    };
    for (NSUInteger index = 0; index < 4; index++) {
        [self assertPoint:points[index] isInside:YES];
    }
}

- (void)testFourDiagonalBoundaryPointsUseCircularRadius {
    CGFloat component = 40.0 / sqrt(2.0);
    CGPoint points[] = {
        CGPointMake(100.0 + component, 100.0 + component),
        CGPointMake(100.0 - component, 100.0 + component),
        CGPointMake(100.0 - component, 100.0 - component),
        CGPointMake(100.0 + component, 100.0 - component),
    };
    for (NSUInteger index = 0; index < 4; index++) {
        [self assertPoint:points[index] isInside:YES];
    }
}

- (void)testActivationInsetShrinksEffectiveRadius {
    BOOL withoutInset = NO;
    BOOL withInset = YES;
    CGPoint point = CGPointMake(145.0, 100.0);
    XCTAssertTrue(MobaCancelZoneContainsPoint(MobaCancelZoneGeometryMake(CGPointMake(100.0, 100.0),
                                                                        100.0,
                                                                        0.0),
                                               point,
                                               &withoutInset));
    XCTAssertTrue(MobaCancelZoneContainsPoint(self.geometry, point, &withInset));
    XCTAssertTrue(withoutInset);
    XCTAssertFalse(withInset);
}

- (void)testNonFinitePointIsRejectedWithoutChangingOutput {
    BOOL inside = YES;
    XCTAssertFalse(MobaCancelZoneContainsPoint(self.geometry, CGPointMake(NAN, 100.0), &inside));
    XCTAssertFalse(MobaCancelZoneContainsPoint(self.geometry, CGPointMake(100.0, INFINITY), &inside));
    XCTAssertTrue(inside);
}

- (void)testNonFiniteCenterIsRejected {
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointMake(NAN, 0.0),
                                                                            100.0,
                                                                            10.0)));
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointMake(0.0, INFINITY),
                                                                            100.0,
                                                                            10.0)));
}

- (void)testNonPositiveDiameterIsRejected {
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointZero, 0.0, 0.0)));
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointZero, -1.0, 0.0)));
}

- (void)testNegativeInsetIsRejected {
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointZero, 100.0, -0.001)));
}

- (void)testInsetAtOrBeyondVisualRadiusIsRejected {
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointZero, 100.0, 50.0)));
    XCTAssertFalse(MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometryMake(CGPointZero, 100.0, 51.0)));
}

@end
