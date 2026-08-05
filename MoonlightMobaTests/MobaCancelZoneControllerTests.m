//
//  MobaCancelZoneControllerTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Controls/MobaCancelZoneController.h"

@interface MobaCancelZoneFakePresentation : NSObject <MobaCancelZonePresenting>
@property (nonatomic, readonly, getter=isCastingVisible) BOOL castingVisible;
@property (nonatomic, readonly, getter=isArmed) BOOL armed;
@property (nonatomic, readonly) NSUInteger resetCount;
@end

@implementation MobaCancelZoneFakePresentation {
    BOOL _castingVisible;
    BOOL _armed;
    NSUInteger _resetCount;
}

- (BOOL)isCastingVisible {
    return _castingVisible;
}

- (BOOL)isArmed {
    return _armed;
}

- (NSUInteger)resetCount {
    return _resetCount;
}

- (void)setCancelZoneCastingVisible:(BOOL)visible {
    _castingVisible = visible;
    if (!visible) {
        _armed = NO;
    }
}

- (void)setCancelZoneArmed:(BOOL)armed {
    _armed = _castingVisible && armed;
}

- (void)resetCancelZonePresentation {
    _castingVisible = NO;
    _armed = NO;
    _resetCount++;
}

@end

@interface MobaCancelZoneControllerTests : XCTestCase
@property (nonatomic, strong) MobaCancelZoneFakePresentation *presentation;
@property (nonatomic, strong) MobaCancelZoneController *controller;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@end

@implementation MobaCancelZoneControllerTests

- (void)setUp {
    [super setUp];
    self.presentation = [[MobaCancelZoneFakePresentation alloc] init];
    self.controller = [[MobaCancelZoneController alloc]
        initWithGeometry:MobaCancelZoneGeometryMake(CGPointZero, 100.0, 10.0)
             presentation:self.presentation];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
}

- (MobaCastTransitionResult)beginCast {
    MobaCastTransitionResult result = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue(result.accepted);
    XCTAssertTrue([self.controller beginCastingWithToken:self.token]);
    return result;
}

- (void)testBeginShowsNormalCastingPresentation {
    [self beginCast];
    XCTAssertTrue(self.controller.isCastingActive);
    XCTAssertFalse(self.controller.isArmed);
    XCTAssertTrue(self.presentation.isCastingVisible);
    XCTAssertFalse(self.presentation.isArmed);
}

- (void)testFirstTokenObtainsIdentityOwnership {
    [self beginCast];
    XCTAssertTrue(self.controller.activeCastToken == self.token);
}

- (void)testSecondTokenCannotReplaceOwner {
    [self beginCast];
    NSObject *other = [[NSObject alloc] init];
    XCTAssertFalse([self.controller beginCastingWithToken:other]);
    XCTAssertTrue(self.controller.activeCastToken == self.token);
}

- (void)testOwnerPointEvaluationReturnsInsideWithoutArming {
    [self beginCast];
    BOOL inside = NO;
    XCTAssertTrue([self.controller evaluatePoint:CGPointZero
                                        forToken:self.token
                                insideCancelZone:&inside]);
    XCTAssertTrue(inside);
    XCTAssertFalse(self.controller.isArmed);
    XCTAssertFalse(self.presentation.isArmed);
}

- (void)testAcceptedCancelArmedResultArmsPresentation {
    [self beginCast];
    MobaCastTransitionResult result = [self.session updateInteractionWithToken:self.token
                                                                 meaningfulDrag:YES
                                                                insideCancelZone:YES];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:result forToken:self.token]);
    XCTAssertTrue(self.controller.isArmed);
    XCTAssertTrue(self.presentation.isArmed);
}

- (void)testAcceptedAimingStatesDisarmPresentation {
    [self beginCast];
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:YES];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:armed forToken:self.token]);
    MobaCastTransitionResult dragged = [self.session updateInteractionWithToken:self.token
                                                                  meaningfulDrag:YES
                                                                 insideCancelZone:NO];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:dragged forToken:self.token]);
    XCTAssertFalse(self.controller.isArmed);
    XCTAssertFalse(self.presentation.isArmed);

    MobaCastTransitionResult defaultState = [self.session updateInteractionWithToken:self.token
                                                                        meaningfulDrag:NO
                                                                       insideCancelZone:NO];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:defaultState forToken:self.token]);
    XCTAssertFalse(self.controller.isArmed);
}

- (void)testNonOwnerUpdateAndEndDoNotChangeState {
    [self beginCast];
    NSObject *other = [[NSObject alloc] init];
    BOOL inside = YES;
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:YES];
    XCTAssertFalse([self.controller evaluatePoint:CGPointZero
                                         forToken:other
                                 insideCancelZone:&inside]);
    XCTAssertFalse([self.controller applyAcceptedTransitionResult:armed forToken:other]);
    XCTAssertFalse([self.controller endCastingWithToken:other]);
    XCTAssertTrue(inside);
    XCTAssertTrue(self.controller.activeCastToken == self.token);
    XCTAssertFalse(self.controller.isArmed);
    XCTAssertTrue(self.presentation.isCastingVisible);
}

- (void)testOwnerEndHidesAndClearsOwnership {
    [self beginCast];
    XCTAssertTrue([self.controller endCastingWithToken:self.token]);
    XCTAssertFalse(self.controller.isCastingActive);
    XCTAssertFalse(self.controller.isArmed);
    XCTAssertNil(self.controller.activeCastToken);
    XCTAssertFalse(self.presentation.isCastingVisible);
    XCTAssertEqual(self.presentation.resetCount, 1u);
}

- (void)testStaleTokenIsInvalidAfterOwnerEnd {
    [self beginCast];
    XCTAssertTrue([self.controller endCastingWithToken:self.token]);
    BOOL inside = YES;
    XCTAssertFalse([self.controller evaluatePoint:CGPointZero
                                         forToken:self.token
                                 insideCancelZone:&inside]);
    XCTAssertFalse([self.controller endCastingWithToken:self.token]);
    XCTAssertTrue(inside);
}

- (void)testRepeatedEndAndSilentResetAreIdempotent {
    [self beginCast];
    XCTAssertTrue([self.controller endCastingWithToken:self.token]);
    XCTAssertFalse([self.controller endCastingWithToken:self.token]);
    [self.controller silentReset];
    [self.controller silentReset];
    XCTAssertEqual(self.presentation.resetCount, 1u);
}

- (void)testSilentResetHidesDisarmsAndInvalidatesToken {
    [self beginCast];
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:YES];
    [self.controller applyAcceptedTransitionResult:armed forToken:self.token];
    [self.controller silentReset];
    XCTAssertFalse(self.controller.isCastingActive);
    XCTAssertFalse(self.controller.isArmed);
    XCTAssertNil(self.controller.activeCastToken);
    XCTAssertFalse(self.presentation.isCastingVisible);
    XCTAssertFalse(self.presentation.isArmed);
}

@end
