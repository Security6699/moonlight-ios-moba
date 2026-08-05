//
//  MobaPointCastGeometryTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Geometry/MobaPointCastGeometry.h"

static const CGFloat MobaPointCastGeometryTolerance = 0.000001;

@interface MobaPointCastGeometryTests : XCTestCase
@end

@implementation MobaPointCastGeometryTests

- (MobaAimRadii)minimumRadii {
    return MobaAimRadiiMake(10.0, 20.0, 30.0, 40.0);
}

- (MobaAimRadii)maximumRadii {
    return MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0);
}

- (void)assertPoint:(CGPoint)point equals:(CGPoint)expected {
    XCTAssertEqualWithAccuracy(point.x, expected.x, MobaPointCastGeometryTolerance);
    XCTAssertEqualWithAccuracy(point.y, expected.y, MobaPointCastGeometryTolerance);
}

- (CGFloat)rayDistanceForDirection:(CGVector)direction radii:(MobaAimRadii)radii {
    CGFloat length = hypot(direction.dx, direction.dy);
    CGFloat unitX = direction.dx / length;
    CGFloat unitY = direction.dy / length;
    CGFloat radiusX = unitX >= 0.0 ? radii.rightPx : radii.leftPx;
    CGFloat radiusY = unitY >= 0.0 ? radii.downPx : radii.upPx;
    return 1.0 / sqrt((unitX * unitX) / (radiusX * radiusX) +
                      (unitY * unitY) / (radiusY * radiusY));
}

- (void)testCardinalDirectionsUseRightDownLeftAndUpRanges {
    CGPoint anchor = CGPointMake(1000.0, 700.0);
    CGPoint target = CGPointZero;

    XCTAssertTrue(MobaPointCastTargetForDirection(anchor, CGVectorMake(1.0, 0.0),
                                                  self.minimumRadii, self.maximumRadii, 1.0, &target));
    [self assertPoint:target equals:CGPointMake(1200.0, 700.0)];
    XCTAssertTrue(MobaPointCastTargetForDirection(anchor, CGVectorMake(0.0, 1.0),
                                                  self.minimumRadii, self.maximumRadii, 1.0, &target));
    [self assertPoint:target equals:CGPointMake(1000.0, 1100.0)];
    XCTAssertTrue(MobaPointCastTargetForDirection(anchor, CGVectorMake(-1.0, 0.0),
                                                  self.minimumRadii, self.maximumRadii, 1.0, &target));
    [self assertPoint:target equals:CGPointMake(900.0, 700.0)];
    XCTAssertTrue(MobaPointCastTargetForDirection(anchor, CGVectorMake(0.0, -1.0),
                                                  self.minimumRadii, self.maximumRadii, 1.0, &target));
    [self assertPoint:target equals:CGPointMake(1000.0, 400.0)];
}

- (void)testDiagonalDirectionsUseAsymmetricQuadrantRanges {
    CGVector directions[] = {
        CGVectorMake(1.0, 1.0),
        CGVectorMake(-1.0, 1.0),
        CGVectorMake(-1.0, -1.0),
        CGVectorMake(1.0, -1.0),
    };
    for (NSUInteger index = 0; index < 4; index++) {
        CGVector direction = directions[index];
        CGFloat length = hypot(direction.dx, direction.dy);
        CGFloat distance = [self rayDistanceForDirection:direction radii:self.maximumRadii];
        CGPoint expected = CGPointMake(direction.dx / length * distance,
                                       direction.dy / length * distance);
        CGPoint target = CGPointZero;
        XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, direction,
                                                      self.minimumRadii, self.maximumRadii,
                                                      1.0, &target));
        [self assertPoint:target equals:expected];
    }
}

- (void)testRatioZeroProducesExactMinimumIntersection {
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                  self.minimumRadii, self.maximumRadii,
                                                  0.0, &target));
    [self assertPoint:target equals:CGPointMake(20.0, 0.0)];
}

- (void)testRatioHalfInterpolatesRayDistanceMidway {
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                  self.minimumRadii, self.maximumRadii,
                                                  0.5, &target));
    [self assertPoint:target equals:CGPointMake(110.0, 0.0)];
}

- (void)testRatioOneProducesExactMaximumIntersection {
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(-1.0, 0.0),
                                                  self.minimumRadii, self.maximumRadii,
                                                  1.0, &target));
    [self assertPoint:target equals:CGPointMake(-100.0, 0.0)];
}

- (void)testDistanceRatioClampsToZeroAndOne {
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(0.0, 1.0),
                                                  self.minimumRadii, self.maximumRadii,
                                                  -5.0, &target));
    [self assertPoint:target equals:CGPointMake(0.0, 40.0)];
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(0.0, 1.0),
                                                  self.minimumRadii, self.maximumRadii,
                                                  5.0, &target));
    [self assertPoint:target equals:CGPointMake(0.0, 400.0)];
}

- (void)testAllZeroMinimumRadiiReturnAnchorAtRatioZero {
    CGPoint anchor = CGPointMake(50.0, 60.0);
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(anchor, CGVectorMake(1.0, -1.0),
                                                  MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0),
                                                  self.maximumRadii, 0.0, &target));
    [self assertPoint:target equals:anchor];
}

- (void)testSelectedZeroMinimumAxisDefinesZeroMinimumDistanceWithoutNaN {
    MobaAimRadii minimum = MobaAimRadiiMake(10.0, 0.0, 30.0, 40.0);
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, -1.0),
                                                  minimum, self.maximumRadii, 0.5, &target));
    XCTAssertTrue(isfinite(target.x));
    XCTAssertTrue(isfinite(target.y));
    CGFloat maximumDistance = [self rayDistanceForDirection:CGVectorMake(1.0, -1.0)
                                                      radii:self.maximumRadii];
    CGFloat component = maximumDistance * 0.5 / sqrt(2.0);
    [self assertPoint:target equals:CGPointMake(component, -component)];
}

- (void)testNonUnitAndNormalizedDirectionsProduceSameTarget {
    CGPoint nonUnit = CGPointZero;
    CGPoint normalized = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(3.0, -4.0),
                                                  self.minimumRadii, self.maximumRadii, 0.6, &nonUnit));
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(0.6, -0.8),
                                                  self.minimumRadii, self.maximumRadii, 0.6, &normalized));
    [self assertPoint:nonUnit equals:normalized];
}

- (void)testTargetRemainsCollinearWithDirection {
    CGPoint anchor = CGPointMake(10.0, 20.0);
    CGVector direction = CGVectorMake(-2.0, 5.0);
    CGPoint target = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(anchor, direction,
                                                  self.minimumRadii, self.maximumRadii, 0.75, &target));
    CGFloat deltaX = target.x - anchor.x;
    CGFloat deltaY = target.y - anchor.y;
    XCTAssertEqualWithAccuracy(deltaX * direction.dy - deltaY * direction.dx,
                               0.0, MobaPointCastGeometryTolerance);
    XCTAssertGreaterThan(deltaX * direction.dx + deltaY * direction.dy, 0.0);
}

- (void)testZeroAndNonFiniteDirectionsAreRejectedWithoutChangingOutput {
    CGPoint target = CGPointMake(7.0, 8.0);
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(0.0, 0.0),
                                                   self.minimumRadii, self.maximumRadii, 0.5, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(NAN, 1.0),
                                                   self.minimumRadii, self.maximumRadii, 0.5, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, INFINITY),
                                                   self.minimumRadii, self.maximumRadii, 0.5, &target));
    [self assertPoint:target equals:CGPointMake(7.0, 8.0)];
}

- (void)testInvalidRangesAndNonFiniteInputsAreRejected {
    CGPoint target = CGPointMake(7.0, 8.0);
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                   MobaAimRadiiMake(-1.0, 0.0, 0.0, 0.0),
                                                   self.maximumRadii, 0.5, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                   self.minimumRadii,
                                                   MobaAimRadiiMake(100.0, 0.0, 300.0, 400.0),
                                                   0.5, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                   MobaAimRadiiMake(10.0, 201.0, 30.0, 40.0),
                                                   self.maximumRadii, 0.5, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointMake(NAN, 0.0), CGVectorMake(1.0, 0.0),
                                                   self.minimumRadii, self.maximumRadii, 0.5, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                   self.minimumRadii, self.maximumRadii, INFINITY, &target));
    XCTAssertFalse(MobaPointCastTargetForDirection(CGPointZero, CGVectorMake(1.0, 0.0),
                                                   self.minimumRadii, self.maximumRadii, 0.5, NULL));
    [self assertPoint:target equals:CGPointMake(7.0, 8.0)];
}

@end
