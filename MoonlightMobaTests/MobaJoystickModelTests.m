//
//  MobaJoystickModelTests.m
//  MoonlightMobaTests
//


#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Controls/MobaJoystickModel.h"

@interface MobaJoystickModelTests : XCTestCase
@end

@implementation MobaJoystickModelTests

- (CGVector)displacementAtDegrees:(CGFloat)degrees magnitude:(CGFloat)magnitude {
    CGFloat radians = degrees * M_PI / 180.0;
    return CGVectorMake(cos(radians) * magnitude, sin(radians) * magnitude);
}

- (MobaJoystickState)stateForDisplacement:(CGVector)displacement
                                  previous:(MobaJoystickState)previous {
    MobaJoystickState state = MobaJoystickStateNeutral;
    XCTAssertTrue(MobaJoystickStateForDisplacement(displacement,
                                                   100.0,
                                                   MobaJoystickDefaultDeadZoneRatio,
                                                   MobaJoystickDefaultDirectionHysteresisDegrees,
                                                   previous,
                                                   &state));
    return state;
}

- (void)testZeroDisplacementIsNeutral {
    XCTAssertEqual([self stateForDisplacement:CGVectorMake(0.0, 0.0)
                                     previous:MobaJoystickStateNeutral],
                   MobaJoystickStateNeutral);
}

- (void)testAllEightBaseDirectionsUseUIKitAngleConvention {
    struct {
        CGFloat degrees;
        MobaJoystickState state;
    } cases[] = {
        { 270.0, MobaJoystickStateUp },
        { 315.0, MobaJoystickStateUpRight },
        { 0.0, MobaJoystickStateRight },
        { 45.0, MobaJoystickStateDownRight },
        { 90.0, MobaJoystickStateDown },
        { 135.0, MobaJoystickStateDownLeft },
        { 180.0, MobaJoystickStateLeft },
        { 225.0, MobaJoystickStateUpLeft },
    };

    for (NSUInteger index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        CGVector displacement = [self displacementAtDegrees:cases[index].degrees magnitude:100.0];
        XCTAssertEqual([self stateForDisplacement:displacement
                                         previous:MobaJoystickStateNeutral],
                       cases[index].state);
    }
}

- (void)testDeadZoneInsideIsNeutralAndOutsideSelectsDirection {
    XCTAssertEqual([self stateForDisplacement:CGVectorMake(15.0, 0.0)
                                     previous:MobaJoystickStateNeutral],
                   MobaJoystickStateNeutral);
    XCTAssertEqual([self stateForDisplacement:CGVectorMake(16.0, 0.0)
                                     previous:MobaJoystickStateNeutral],
                   MobaJoystickStateNeutral);
    XCTAssertEqual([self stateForDisplacement:CGVectorMake(17.0, 0.0)
                                     previous:MobaJoystickStateNeutral],
                   MobaJoystickStateRight);
}

- (void)testReturningToDeadZoneImmediatelyBecomesNeutral {
    XCTAssertEqual([self stateForDisplacement:CGVectorMake(1.0, 0.0)
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateNeutral);
}

- (void)testNonUnitAndUnitDirectionsProduceTheSameState {
    CGVector unit = [self displacementAtDegrees:135.0 magnitude:1.0];
    CGVector nonUnit = [self displacementAtDegrees:135.0 magnitude:250.0];
    MobaJoystickState unitState = MobaJoystickStateNeutral;
    MobaJoystickState nonUnitState = MobaJoystickStateNeutral;

    XCTAssertTrue(MobaJoystickStateForDisplacement(unit,
                                                   1.0,
                                                   0.16,
                                                   8.0,
                                                   MobaJoystickStateNeutral,
                                                   &unitState));
    XCTAssertTrue(MobaJoystickStateForDisplacement(nonUnit,
                                                   1.0,
                                                   0.16,
                                                   8.0,
                                                   MobaJoystickStateNeutral,
                                                   &nonUnitState));
    XCTAssertEqual(unitState, MobaJoystickStateDownLeft);
    XCTAssertEqual(nonUnitState, unitState);
}

- (void)testRightHysteresisPreventsChatterNearBaseBoundary {
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:22.4 magnitude:100.0]
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateRight);
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:23.0 magnitude:100.0]
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateRight);
}

- (void)testRightHoldsThroughExpandedBoundary {
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:30.5 magnitude:100.0]
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateRight);
}

- (void)testRightSwitchesToDownRightAfterExpandedBoundary {
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:30.6 magnitude:100.0]
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateDownRight);
}

- (void)testDownRightUsesOppositeHysteresisBoundaryWhenReturningRight {
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:14.5 magnitude:100.0]
                                     previous:MobaJoystickStateDownRight],
                   MobaJoystickStateDownRight);
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:14.4 magnitude:100.0]
                                     previous:MobaJoystickStateDownRight],
                   MobaJoystickStateRight);
}

- (void)testHysteresisWrapsAcrossZeroAnd360Degrees {
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:350.0 magnitude:100.0]
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateRight);
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:344.0 magnitude:100.0]
                                     previous:MobaJoystickStateUpRight],
                   MobaJoystickStateUpRight);
    XCTAssertEqual([self stateForDisplacement:[self displacementAtDegrees:346.0 magnitude:100.0]
                                     previous:MobaJoystickStateUpRight],
                   MobaJoystickStateRight);
}

- (void)testDeadZoneTakesPriorityOverHysteresis {
    CGVector insideDeadZone = [self displacementAtDegrees:25.0 magnitude:10.0];
    XCTAssertEqual([self stateForDisplacement:insideDeadZone
                                     previous:MobaJoystickStateRight],
                   MobaJoystickStateNeutral);
}

- (void)testNonFiniteDisplacementIsRejectedWithoutChangingOutput {
    MobaJoystickState state = MobaJoystickStateLeft;
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(NAN, 0.0),
                                                    100.0,
                                                    0.16,
                                                    8.0,
                                                    MobaJoystickStateNeutral,
                                                    &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(0.0, INFINITY),
                                                    100.0,
                                                    0.16,
                                                    8.0,
                                                    MobaJoystickStateNeutral,
                                                    &state));
    XCTAssertEqual(state, MobaJoystickStateLeft);
}

- (void)testInvalidConfigurationAndStateAreRejected {
    MobaJoystickState state = MobaJoystickStateLeft;
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 0.0, 0.16, 8.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), -1.0, 0.16, 8.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), INFINITY, 0.16, 8.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, -0.1, 8.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 1.0, 8.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, NAN, 8.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 0.16, -1.0, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 0.16, 22.5, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 0.16, NAN, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 0.16, INFINITY, MobaJoystickStateNeutral, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 0.16, 8.0, (MobaJoystickState)99, &state));
    XCTAssertFalse(MobaJoystickStateForDisplacement(CGVectorMake(100.0, 0.0), 100.0, 0.16, 8.0, MobaJoystickStateNeutral, NULL));
    XCTAssertEqual(state, MobaJoystickStateLeft);
}

@end
