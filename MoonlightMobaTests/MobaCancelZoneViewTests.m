//
//  MobaCancelZoneViewTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Controls/MobaCancelZoneController.h"
#import "../Limelight/Input/MOBA/Controls/MobaCancelZoneView.h"

@interface MobaCancelZoneViewTests : XCTestCase
@property (nonatomic, strong) MobaCancelZoneView *view;
@property (nonatomic, strong) MobaCancelZoneController *controller;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@end

@implementation MobaCancelZoneViewTests

- (void)setUp {
    [super setUp];
    self.view = [[MobaCancelZoneView alloc]
        initWithVisualDiameter:MobaCancelZoneDefaultVisualDiameter];
    self.controller = [[MobaCancelZoneController alloc]
        initWithGeometry:MobaCancelZoneGeometryMake(CGPointZero,
                                                     MobaCancelZoneDefaultVisualDiameter,
                                                     8.0)
             presentation:self.view];
    self.view.controller = self.controller;
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
}

- (void)beginCasting {
    XCTAssertTrue([self.session beginInteractionWithToken:self.token].accepted);
    XCTAssertTrue([self.controller beginCastingWithToken:self.token]);
}

- (void)testDefaultPresentationIsHiddenAndNormal {
    XCTAssertTrue(self.view.hidden);
    XCTAssertFalse(self.view.isCastingVisible);
    XCTAssertFalse(self.view.isArmed);
    XCTAssertEqual(self.view.visualState, MobaCancelZoneVisualStateNormal);
    XCTAssertEqualWithAccuracy(self.view.visualDiameter, 112.0, 0.000001);
}

- (void)testCastingUsesVisibleNormalPresentation {
    [self beginCasting];
    XCTAssertFalse(self.view.hidden);
    XCTAssertTrue(self.view.isCastingVisible);
    XCTAssertFalse(self.view.isArmed);
    XCTAssertEqual(self.view.visualState, MobaCancelZoneVisualStateNormal);
    XCTAssertEqualWithAccuracy(self.view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.effectiveVisualOpacity, 0.58, 0.000001);
}

- (void)testAcceptedCancelArmedStateUsesArmedPresentation {
    [self beginCasting];
    MobaCastTransitionResult result = [self.session updateInteractionWithToken:self.token
                                                                 meaningfulDrag:YES
                                                                insideCancelZone:YES];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:result forToken:self.token]);
    XCTAssertTrue(self.view.isArmed);
    XCTAssertEqual(self.view.visualState, MobaCancelZoneVisualStateArmed);
    XCTAssertEqualWithAccuracy(self.view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.effectiveVisualOpacity, 0.86, 0.000001);
}

- (void)testExitingZoneRestoresNormalCastingPresentation {
    [self beginCasting];
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:YES];
    [self.controller applyAcceptedTransitionResult:armed forToken:self.token];
    MobaCastTransitionResult exited = [self.session updateInteractionWithToken:self.token
                                                                 meaningfulDrag:YES
                                                                insideCancelZone:NO];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:exited forToken:self.token]);
    XCTAssertFalse(self.view.hidden);
    XCTAssertFalse(self.view.isArmed);
    XCTAssertEqual(self.view.visualState, MobaCancelZoneVisualStateNormal);
}

- (void)testLifecycleResetHidesAndDisarmsPresentation {
    [self beginCasting];
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:YES];
    [self.controller applyAcceptedTransitionResult:armed forToken:self.token];
    [self.view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonApplicationWillResignActive];
    XCTAssertTrue(self.view.hidden);
    XCTAssertFalse(self.view.isCastingVisible);
    XCTAssertFalse(self.view.isArmed);
    XCTAssertNil(self.controller.activeCastToken);
}

- (void)testUserInteractionIsAlwaysDisabled {
    XCTAssertFalse(self.view.userInteractionEnabled);
    self.view.userInteractionEnabled = YES;
    XCTAssertFalse(self.view.userInteractionEnabled);
    [self beginCasting];
    XCTAssertFalse(self.view.userInteractionEnabled);
    [self.controller silentReset];
    XCTAssertFalse(self.view.userInteractionEnabled);
}

- (void)testDisabledStateHidesWithoutSendingOrEndingSemanticCast {
    [self beginCasting];
    [self.view setMobaLocalInteractionEnabled:NO];
    XCTAssertTrue(self.view.hidden);
    XCTAssertEqual(self.view.visualState, MobaCancelZoneVisualStateDisabled);
    XCTAssertEqualWithAccuracy(self.view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.effectiveVisualOpacity, 0.30, 0.000001);
    XCTAssertTrue(self.controller.isCastingActive);
    XCTAssertTrue(self.controller.activeCastToken == self.token);
}

- (void)testZeroOpacityDoesNotChangeControllerSemantics {
    self.view.normalOpacity = 0.0;
    self.view.armedOpacity = 0.0;
    [self beginCasting];
    XCTAssertEqualWithAccuracy(self.view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.effectiveVisualOpacity, 0.0, 0.000001);

    BOOL inside = NO;
    XCTAssertTrue([self.controller evaluatePoint:CGPointZero
                                        forToken:self.token
                                insideCancelZone:&inside]);
    XCTAssertTrue(inside);
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:inside];
    XCTAssertTrue([self.controller applyAcceptedTransitionResult:armed forToken:self.token]);
    XCTAssertTrue(self.controller.isArmed);
    XCTAssertTrue(self.view.isArmed);
    XCTAssertEqualWithAccuracy(self.view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.effectiveVisualOpacity, 0.0, 0.000001);
}

@end
