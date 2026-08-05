//
//  MobaCastSessionTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"

@interface MobaEqualToken : NSObject
@end

@implementation MobaEqualToken
- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:MobaEqualToken.class];
}
- (NSUInteger)hash {
    return 1;
}
@end

@interface MobaCastSessionTests : XCTestCase
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *owner;
@end

@implementation MobaCastSessionTests

- (void)setUp {
    [super setUp];
    self.session = [[MobaCastSession alloc] init];
    self.owner = [[NSObject alloc] init];
}

- (void)testSecondTokenBeginIsRejectedWithoutOwnershipTransfer {
    NSObject *second = [[NSObject alloc] init];
    XCTAssertTrue([self.session beginInteractionWithToken:self.owner].accepted);
    MobaCastTransitionResult result = [self.session beginInteractionWithToken:second];
    XCTAssertFalse(result.accepted);
    XCTAssertEqual(self.session.activeInteractionToken, self.owner);
    XCTAssertEqual(self.session.state, MobaCastStateAimingDefault);
}

- (void)testNonOwnerUpdateReleaseAndCancelAreRejected {
    NSObject *other = [[NSObject alloc] init];
    [self.session beginInteractionWithToken:self.owner];
    XCTAssertFalse([self.session updateInteractionWithToken:other
                                             meaningfulDrag:YES
                                            insideCancelZone:NO].accepted);
    XCTAssertFalse([self.session releaseInteractionWithToken:other].accepted);
    XCTAssertFalse([self.session cancelInteractionWithToken:other].accepted);
    XCTAssertEqual(self.session.activeInteractionToken, self.owner);
    XCTAssertEqual(self.session.state, MobaCastStateAimingDefault);
}

- (void)testOwnerCommitClearsToken {
    [self.session beginInteractionWithToken:self.owner];
    MobaCastTransitionResult result = [self.session releaseInteractionWithToken:self.owner];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.terminalOutcome, MobaCastTerminalOutcomeCommitted);
    XCTAssertNil(self.session.activeInteractionToken);
    XCTAssertFalse([self.session updateInteractionWithToken:self.owner
                                             meaningfulDrag:YES
                                            insideCancelZone:NO].accepted);
}

- (void)testOwnerCancelClearsToken {
    [self.session beginInteractionWithToken:self.owner];
    MobaCastTransitionResult result = [self.session cancelInteractionWithToken:self.owner];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.terminalOutcome, MobaCastTerminalOutcomeCancelled);
    XCTAssertNil(self.session.activeInteractionToken);
    XCTAssertFalse([self.session releaseInteractionWithToken:self.owner].accepted);
}

- (void)testInterruptClearsTokenAndInvalidatesStaleOwner {
    [self.session beginInteractionWithToken:self.owner];
    MobaCastTransitionResult interruption = [self.session interrupt];
    XCTAssertTrue(interruption.accepted);
    XCTAssertEqual(interruption.currentState, MobaCastStateCancelled);
    XCTAssertNil(self.session.activeInteractionToken);
    XCTAssertFalse([self.session updateInteractionWithToken:self.owner
                                             meaningfulDrag:YES
                                            insideCancelZone:NO].accepted);
    XCTAssertFalse([self.session releaseInteractionWithToken:self.owner].accepted);
}

- (void)testRepeatedInterruptionIsIdempotent {
    [self.session beginInteractionWithToken:self.owner];
    MobaCastTransitionResult first = [self.session interrupt];
    MobaCastTransitionResult second = [self.session interrupt];
    XCTAssertTrue(first.accepted);
    XCTAssertFalse(second.accepted);
    XCTAssertEqual(second.previousState, MobaCastStateCancelled);
    XCTAssertEqual(second.currentState, MobaCastStateCancelled);
    XCTAssertFalse(second.producedTerminalOutcome);
}

- (void)testRepeatedSilentResetIsIdempotent {
    [self.session beginInteractionWithToken:self.owner];
    [self.session interrupt];
    MobaCastTransitionResult first = [self.session silentReset];
    MobaCastTransitionResult second = [self.session silentReset];
    XCTAssertTrue(first.accepted);
    XCTAssertTrue(second.accepted);
    XCTAssertEqual(first.currentState, MobaCastStateIdle);
    XCTAssertEqual(second.previousState, MobaCastStateIdle);
    XCTAssertEqual(second.currentState, MobaCastStateIdle);
    XCTAssertNil(self.session.activeInteractionToken);
}

- (void)testSilentResetOfActiveSessionInvalidatesStaleTokenWithoutOutcome {
    [self.session beginInteractionWithToken:self.owner];
    MobaCastTransitionResult result = [self.session silentReset];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.previousState, MobaCastStateAimingDefault);
    XCTAssertEqual(result.currentState, MobaCastStateIdle);
    XCTAssertFalse(result.producedTerminalOutcome);
    XCTAssertNil(self.session.activeInteractionToken);
    XCTAssertFalse([self.session cancelInteractionWithToken:self.owner].accepted);
}

- (void)testTwoIndependentSessionsOwnDifferentTokens {
    MobaCastSession *secondSession = [[MobaCastSession alloc] init];
    NSObject *secondToken = [[NSObject alloc] init];
    XCTAssertTrue([self.session beginInteractionWithToken:self.owner].accepted);
    XCTAssertTrue([secondSession beginInteractionWithToken:secondToken].accepted);
    XCTAssertEqual(self.session.activeInteractionToken, self.owner);
    XCTAssertEqual(secondSession.activeInteractionToken, secondToken);

    [self.session cancelInteractionWithToken:self.owner];
    XCTAssertNil(self.session.activeInteractionToken);
    XCTAssertEqual(secondSession.activeInteractionToken, secondToken);
    XCTAssertEqual(secondSession.state, MobaCastStateAimingDefault);
}

- (void)testOwnershipUsesIdentityRatherThanIsEqual {
    MobaEqualToken *owner = [[MobaEqualToken alloc] init];
    MobaEqualToken *equalButDistinct = [[MobaEqualToken alloc] init];
    XCTAssertTrue([owner isEqual:equalButDistinct]);
    XCTAssertTrue([self.session beginInteractionWithToken:owner].accepted);
    XCTAssertFalse([self.session updateInteractionWithToken:equalButDistinct
                                             meaningfulDrag:YES
                                            insideCancelZone:NO].accepted);
    XCTAssertFalse([self.session releaseInteractionWithToken:equalButDistinct].accepted);
    XCTAssertEqual(self.session.activeInteractionToken, owner);
}

- (void)testOwnerReleaseWhileCancelArmedEndsCancelled {
    [self.session beginInteractionWithToken:self.owner];
    [self.session updateInteractionWithToken:self.owner
                              meaningfulDrag:NO
                             insideCancelZone:YES];
    MobaCastTransitionResult result = [self.session releaseInteractionWithToken:self.owner];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.previousState, MobaCastStateCancelArmed);
    XCTAssertEqual(result.currentState, MobaCastStateCancelled);
    XCTAssertEqual(result.terminalOutcome, MobaCastTerminalOutcomeCancelled);
    XCTAssertNil(self.session.activeInteractionToken);
}

@end
