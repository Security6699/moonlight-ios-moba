//
//  MobaGameCanvasTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>
#import <math.h>
#import "../Limelight/Input/MOBA/Geometry/MobaGameCanvas.h"

@interface MobaGameCanvasTests : XCTestCase
@end

@implementation MobaGameCanvasTests

- (void)assertPoint:(CGPoint)point becomesX:(int16_t)x y:(int16_t)y {
    MobaGameCanvasPosition position;
    XCTAssertTrue(MobaGameCanvasPositionFromPoint(point, &position));
    XCTAssertEqual(position.x, x);
    XCTAssertEqual(position.y, y);
}

- (void)testCenterPointIsPreserved {
    [self assertPoint:CGPointMake(1280, 720) becomesX:1280 y:720];
}

- (void)testNegativeCoordinatesClampToZero {
    [self assertPoint:CGPointMake(-1, -100) becomesX:0 y:0];
}

- (void)testCoordinatesAboveCanvasClampToMaximumPixel {
    [self assertPoint:CGPointMake(3000, 2000) becomesX:2559 y:1439];
}

- (void)testFractionalCoordinatesDiscardFractionTowardZero {
    [self assertPoint:CGPointMake(1280.99, 720.75) becomesX:1280 y:720];
}

- (void)testFourCornersArePreserved {
    CGPoint corners[] = {
        CGPointMake(0, 0),
        CGPointMake(2559, 0),
        CGPointMake(0, 1439),
        CGPointMake(2559, 1439),
    };

    for (NSUInteger index = 0; index < sizeof(corners) / sizeof(corners[0]); index++) {
        CGPoint point = corners[index];
        [self assertPoint:point becomesX:(int16_t)point.x y:(int16_t)point.y];
    }
}

- (void)testNineDiagnosticPointsArePreserved {
    CGPoint points[] = {
        CGPointMake(0, 0), CGPointMake(1280, 0), CGPointMake(2559, 0),
        CGPointMake(0, 720), CGPointMake(1280, 720), CGPointMake(2559, 720),
        CGPointMake(0, 1439), CGPointMake(1280, 1439), CGPointMake(2559, 1439),
    };

    for (NSUInteger index = 0; index < sizeof(points) / sizeof(points[0]); index++) {
        CGPoint point = points[index];
        [self assertPoint:point becomesX:(int16_t)point.x y:(int16_t)point.y];
    }
}

- (void)testNonFiniteCoordinatesAreRejected {
    MobaGameCanvasPosition position = { 12, 34 };
    XCTAssertFalse(MobaGameCanvasPositionFromPoint(CGPointMake(NAN, 0), &position));
    XCTAssertFalse(MobaGameCanvasPositionFromPoint(CGPointMake(0, INFINITY), &position));
    XCTAssertEqual(position.x, 12);
    XCTAssertEqual(position.y, 34);
}

@end
