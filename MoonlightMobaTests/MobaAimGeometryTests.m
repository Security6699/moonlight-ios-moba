//
//  MobaAimGeometryTests.m
//  MoonlightMobaTests
//


#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Geometry/MobaAimGeometry.h"

static const CGFloat MobaAimTestTolerance = 0.000001;

@interface MobaAimGeometryTests : XCTestCase
@end

@implementation MobaAimGeometryTests

- (MobaAimRadii)asymmetricRadii {
    return MobaAimRadiiMake(30.0, 40.0, 50.0, 60.0);
}

- (void)assertDirection:(CGVector)direction
            usesRadiusX:(CGFloat)radiusX
                radiusY:(CGFloat)radiusY {
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero,
                                            direction,
                                            [self asymmetricRadii],
                                            1.0,
                                            &target));

    CGFloat unitComponent = 1.0 / sqrt(2.0);
    CGFloat maxDistance = 1.0 / sqrt((unitComponent * unitComponent) / (radiusX * radiusX) +
                                     (unitComponent * unitComponent) / (radiusY * radiusY));
    CGFloat expectedX = copysign(unitComponent * maxDistance, direction.dx);
    CGFloat expectedY = copysign(unitComponent * maxDistance, direction.dy);
    XCTAssertEqualWithAccuracy(target.x, expectedX, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, expectedY, MobaAimTestTolerance);
}

- (void)testDefaultDirectionIs270DegreesAndTargetsAboveAnchor {
    CGVector direction = MobaAimDefaultUpDirection();
    XCTAssertEqualWithAccuracy(direction.dx, 0.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(direction.dy, -1.0, MobaAimTestTolerance);

    CGPoint anchor = CGPointMake(200.0, 300.0);
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaAimTargetForDirection(anchor,
                                            direction,
                                            [self asymmetricRadii],
                                            1.0,
                                            &target));
    XCTAssertEqualWithAccuracy(target.x, 200.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, 250.0, MobaAimTestTolerance);
}

- (void)testCardinalDirectionsUseTheirCorrespondingRadii {
    CGPoint target = CGPointZero;
    MobaAimRadii radii = [self asymmetricRadii];

    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0), radii, 1.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 40.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, 0.0, MobaAimTestTolerance);

    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero, CGVectorMake(0.0, 1.0), radii, 1.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 0.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, 60.0, MobaAimTestTolerance);

    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero, CGVectorMake(-1.0, 0.0), radii, 1.0, &target));
    XCTAssertEqualWithAccuracy(target.x, -30.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, 0.0, MobaAimTestTolerance);

    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero, CGVectorMake(0.0, -1.0), radii, 1.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 0.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, -50.0, MobaAimTestTolerance);
}

- (void)testDiagonalDirectionsUseTheRadiiForTheirQuadrants {
    [self assertDirection:CGVectorMake(1.0, 1.0) usesRadiusX:40.0 radiusY:60.0];
    [self assertDirection:CGVectorMake(-1.0, 1.0) usesRadiusX:30.0 radiusY:60.0];
    [self assertDirection:CGVectorMake(-1.0, -1.0) usesRadiusX:30.0 radiusY:50.0];
    [self assertDirection:CGVectorMake(1.0, -1.0) usesRadiusX:40.0 radiusY:50.0];
}

- (void)testSymmetricCircleProducesExpectedRayIntersection {
    CGPoint target = CGPointZero;
    MobaAimRadii circle = MobaAimRadiiMake(100.0, 100.0, 100.0, 100.0);
    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero,
                                            CGVectorMake(3.0, 4.0),
                                            circle,
                                            1.0,
                                            &target));
    XCTAssertEqualWithAccuracy(target.x, 60.0, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(target.y, 80.0, MobaAimTestTolerance);
}

- (void)testAsymmetricResultRemainsCollinearWithDirection {
    CGVector direction = CGVectorMake(2.0, -5.0);
    CGPoint anchor = CGPointMake(10.0, 20.0);
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaAimTargetForDirection(anchor,
                                            direction,
                                            [self asymmetricRadii],
                                            0.75,
                                            &target));

    CGFloat deltaX = target.x - anchor.x;
    CGFloat deltaY = target.y - anchor.y;
    XCTAssertEqualWithAccuracy(deltaX * direction.dy - deltaY * direction.dx,
                               0.0,
                               MobaAimTestTolerance);
    XCTAssertGreaterThan(deltaX * direction.dx + deltaY * direction.dy, 0.0);
}

- (void)testNonUnitAndNormalizedDirectionsProduceTheSameTarget {
    CGVector direction = CGVectorMake(3.0, -4.0);
    CGVector normalized = CGVectorMake(0.6, -0.8);
    CGPoint nonUnitTarget = CGPointZero;
    CGPoint normalizedTarget = CGPointZero;

    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero, direction, [self asymmetricRadii], 1.0, &nonUnitTarget));
    XCTAssertTrue(MobaAimTargetForDirection(CGPointZero, normalized, [self asymmetricRadii], 1.0, &normalizedTarget));
    XCTAssertEqualWithAccuracy(nonUnitTarget.x, normalizedTarget.x, MobaAimTestTolerance);
    XCTAssertEqualWithAccuracy(nonUnitTarget.y, normalizedTarget.y, MobaAimTestTolerance);
}

- (void)testDistanceRatiosZeroHalfAndOneScaleTheTarget {
    CGPoint anchor = CGPointMake(10.0, 20.0);
    CGPoint target = CGPointZero;

    XCTAssertTrue(MobaAimTargetForDirection(anchor, CGVectorMake(1.0, 0.0), [self asymmetricRadii], 0.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 10.0, MobaAimTestTolerance);

    XCTAssertTrue(MobaAimTargetForDirection(anchor, CGVectorMake(1.0, 0.0), [self asymmetricRadii], 0.5, &target));
    XCTAssertEqualWithAccuracy(target.x, 30.0, MobaAimTestTolerance);

    XCTAssertTrue(MobaAimTargetForDirection(anchor, CGVectorMake(1.0, 0.0), [self asymmetricRadii], 1.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 50.0, MobaAimTestTolerance);
}

- (void)testDistanceRatioIsClampedToZeroAndOne {
    CGPoint anchor = CGPointMake(10.0, 20.0);
    CGPoint target = CGPointZero;

    XCTAssertTrue(MobaAimTargetForDirection(anchor, CGVectorMake(1.0, 0.0), [self asymmetricRadii], -1.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 10.0, MobaAimTestTolerance);

    XCTAssertTrue(MobaAimTargetForDirection(anchor, CGVectorMake(1.0, 0.0), [self asymmetricRadii], 2.0, &target));
    XCTAssertEqualWithAccuracy(target.x, 50.0, MobaAimTestTolerance);
}

- (void)testZeroDirectionIsRejected {
    CGPoint target = CGPointMake(7.0, 8.0);
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero,
                                             CGVectorMake(0.0, 0.0),
                                             [self asymmetricRadii],
                                             1.0,
                                             &target));
    XCTAssertTrue(CGPointEqualToPoint(target, CGPointMake(7.0, 8.0)));
}

- (void)testSelectedZeroOrNegativeRadiiAreRejected {
    CGPoint target = CGPointMake(7.0, 8.0);
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero,
                                             CGVectorMake(1.0, 0.0),
                                             MobaAimRadiiMake(30.0, 0.0, 50.0, 60.0),
                                             1.0,
                                             &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero,
                                             CGVectorMake(-1.0, 0.0),
                                             MobaAimRadiiMake(-1.0, 40.0, 50.0, 60.0),
                                             1.0,
                                             &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero,
                                             CGVectorMake(0.0, -1.0),
                                             MobaAimRadiiMake(30.0, 40.0, 0.0, 60.0),
                                             1.0,
                                             &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero,
                                             CGVectorMake(0.0, 1.0),
                                             MobaAimRadiiMake(30.0, 40.0, 50.0, -1.0),
                                             1.0,
                                             &target));
    XCTAssertTrue(CGPointEqualToPoint(target, CGPointMake(7.0, 8.0)));
}

- (void)testNonFiniteInputsAreRejected {
    CGPoint target = CGPointMake(7.0, 8.0);
    MobaAimRadii radii = [self asymmetricRadii];

    XCTAssertFalse(MobaAimTargetForDirection(CGPointMake(NAN, 0.0), CGVectorMake(1.0, 0.0), radii, 1.0, &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero, CGVectorMake(INFINITY, 0.0), radii, 1.0, &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0), MobaAimRadiiMake(NAN, 40.0, 50.0, 60.0), 1.0, &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0), MobaAimRadiiMake(30.0, 40.0, INFINITY, 60.0), 1.0, &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0), radii, NAN, &target));
    XCTAssertFalse(MobaAimTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0), radii, INFINITY, &target));
    XCTAssertTrue(CGPointEqualToPoint(target, CGPointMake(7.0, 8.0)));
}

@end
