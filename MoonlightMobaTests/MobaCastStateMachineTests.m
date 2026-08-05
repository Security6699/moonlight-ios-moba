//
//  MobaCastStateMachineTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastStateMachine.h"

@interface MobaCastStateMachineTests : XCTestCase
@property (nonatomic, strong) MobaCastStateMachine *stateMachine;
@end

@implementation MobaCastStateMachineTests

- (void)setUp {
    [super setUp];
    self.stateMachine = [[MobaCastStateMachine alloc] init];
}

- (void)assertResult:(MobaCastTransitionResult)result
             accepted:(BOOL)accepted
             previous:(MobaCastState)previous
              current:(MobaCastState)current
              outcome:(MobaCastTerminalOutcome)outcome {
    XCTAssertEqual(result.accepted, accepted);
    XCTAssertEqual(result.previousState, previous);
    XCTAssertEqual(result.currentState, current);
    XCTAssertEqual(result.producedTerminalOutcome, outcome != MobaCastTerminalOutcomeNone);
    XCTAssertEqual(result.terminalOutcome, outcome);
}

- (void)testIdleBeginEntersAimingDefault {
    MobaCastTransitionResult result = [self.stateMachine begin];
    [self assertResult:result
              accepted:YES
              previous:MobaCastStateIdle
               current:MobaCastStateAimingDefault
               outcome:MobaCastTerminalOutcomeNone];
}

- (void)testAimingDefaultMeaningfulDragEntersAimingDragged {
    [self.stateMachine begin];
    MobaCastTransitionResult result = [self.stateMachine dragBecameMeaningful];
    [self assertResult:result
              accepted:YES
              previous:MobaCastStateAimingDefault
               current:MobaCastStateAimingDragged
               outcome:MobaCastTerminalOutcomeNone];
}

- (void)testAimingDefaultReleaseCommits {
    [self.stateMachine begin];
    MobaCastTransitionResult result = [self.stateMachine releaseNormally];
    [self assertResult:result
              accepted:YES
              previous:MobaCastStateAimingDefault
               current:MobaCastStateCommitted
               outcome:MobaCastTerminalOutcomeCommitted];
}

- (void)testAimingDraggedReleaseCommits {
    [self.stateMachine begin];
    [self.stateMachine updateWithMeaningfulDrag:YES insideCancelZone:NO];
    MobaCastTransitionResult result = [self.stateMachine releaseNormally];
    [self assertResult:result
              accepted:YES
              previous:MobaCastStateAimingDragged
               current:MobaCastStateCommitted
               outcome:MobaCastTerminalOutcomeCommitted];
}

- (void)testDefaultCancelZoneExitRestoresAimingDefault {
    [self.stateMachine begin];
    [self.stateMachine enterCancelZone];
    XCTAssertEqual(self.stateMachine.state, MobaCastStateCancelArmed);
    MobaCastTransitionResult result = [self.stateMachine exitCancelZone];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.currentState, MobaCastStateAimingDefault);
}

- (void)testDraggedCancelZoneExitRestoresAimingDragged {
    [self.stateMachine begin];
    [self.stateMachine dragBecameMeaningful];
    [self.stateMachine enterCancelZone];
    MobaCastTransitionResult result = [self.stateMachine exitCancelZone];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.currentState, MobaCastStateAimingDragged);
}

- (void)testMeaningfulDragInsideCancelZoneRestoresAimingDraggedOnExit {
    [self.stateMachine begin];
    [self.stateMachine enterCancelZone];
    MobaCastTransitionResult insideResult = [self.stateMachine dragBecameMeaningful];
    XCTAssertEqual(insideResult.currentState, MobaCastStateCancelArmed);
    MobaCastTransitionResult exitResult = [self.stateMachine exitCancelZone];
    XCTAssertEqual(exitResult.currentState, MobaCastStateAimingDragged);
}

- (void)testReleaseWhileCancelArmedCancels {
    [self.stateMachine begin];
    [self.stateMachine enterCancelZone];
    MobaCastTransitionResult result = [self.stateMachine releaseNormally];
    [self assertResult:result
              accepted:YES
              previous:MobaCastStateCancelArmed
               current:MobaCastStateCancelled
               outcome:MobaCastTerminalOutcomeCancelled];
}

- (void)testAimingDefaultTouchCancellationCancels {
    [self.stateMachine begin];
    MobaCastTransitionResult result = [self.stateMachine cancelForTouchCancellation];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.currentState, MobaCastStateCancelled);
    XCTAssertEqual(result.terminalOutcome, MobaCastTerminalOutcomeCancelled);
}

- (void)testAimingDraggedLifecycleInterruptionCancels {
    [self.stateMachine begin];
    [self.stateMachine updateWithMeaningfulDrag:YES insideCancelZone:NO];
    MobaCastTransitionResult result = [self.stateMachine interrupt];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.previousState, MobaCastStateAimingDragged);
    XCTAssertEqual(result.currentState, MobaCastStateCancelled);
}

- (void)testTerminalResetReturnsToIdleWithoutOutcome {
    [self.stateMachine begin];
    [self.stateMachine releaseNormally];
    MobaCastTransitionResult result = [self.stateMachine reset];
    [self assertResult:result
              accepted:YES
              previous:MobaCastStateCommitted
               current:MobaCastStateIdle
               outcome:MobaCastTerminalOutcomeNone];
}

- (void)testRepeatedBeginWhileActiveIsRejected {
    [self.stateMachine begin];
    MobaCastTransitionResult result = [self.stateMachine begin];
    [self assertResult:result
              accepted:NO
              previous:MobaCastStateAimingDefault
               current:MobaCastStateAimingDefault
               outcome:MobaCastTerminalOutcomeNone];
}

- (void)testIdleCommitCancelAndExitZoneEventsAreRejected {
    MobaCastTransitionResult release = [self.stateMachine releaseNormally];
    MobaCastTransitionResult cancel = [self.stateMachine cancelForTouchCancellation];
    MobaCastTransitionResult exitZone = [self.stateMachine exitCancelZone];
    XCTAssertFalse(release.accepted);
    XCTAssertFalse(cancel.accepted);
    XCTAssertFalse(exitZone.accepted);
    XCTAssertEqual(self.stateMachine.state, MobaCastStateIdle);
}

- (void)testTerminalStateRejectsFurtherUpdatesCommitAndCancel {
    [self.stateMachine begin];
    [self.stateMachine releaseNormally];
    MobaCastTransitionResult update = [self.stateMachine updateWithMeaningfulDrag:YES
                                                                  insideCancelZone:YES];
    MobaCastTransitionResult release = [self.stateMachine releaseNormally];
    MobaCastTransitionResult cancel = [self.stateMachine cancelForTouchCancellation];
    XCTAssertFalse(update.accepted);
    XCTAssertFalse(release.accepted);
    XCTAssertFalse(cancel.accepted);
    XCTAssertEqual(self.stateMachine.state, MobaCastStateCommitted);
}

- (void)testTransitionResultReportsExactPreviousCurrentAndOutcome {
    MobaCastTransitionResult begin = [self.stateMachine begin];
    XCTAssertEqual(begin.previousState, MobaCastStateIdle);
    XCTAssertEqual(begin.currentState, MobaCastStateAimingDefault);
    XCTAssertFalse(begin.producedTerminalOutcome);
    XCTAssertEqual(begin.terminalOutcome, MobaCastTerminalOutcomeNone);

    MobaCastTransitionResult committed = [self.stateMachine releaseNormally];
    XCTAssertEqual(committed.previousState, MobaCastStateAimingDefault);
    XCTAssertEqual(committed.currentState, MobaCastStateCommitted);
    XCTAssertTrue(committed.producedTerminalOutcome);
    XCTAssertEqual(committed.terminalOutcome, MobaCastTerminalOutcomeCommitted);
}

- (void)testDragReturningBelowMeaningfulThresholdRestoresAimingDefault {
    [self.stateMachine begin];
    [self.stateMachine dragBecameMeaningful];
    MobaCastTransitionResult result = [self.stateMachine dragReturnedBelowMeaningfulThreshold];
    XCTAssertTrue(result.accepted);
    XCTAssertEqual(result.previousState, MobaCastStateAimingDragged);
    XCTAssertEqual(result.currentState, MobaCastStateAimingDefault);
}

@end
