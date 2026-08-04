//
//  MobaOverlayLifecycleTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Core/MobaCursorDiagnostics.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"

@interface MobaLifecycleFakeSink : NSObject <MobaInputSink>
- (NSArray<NSString *> *)eventSnapshot;
- (void)clearEvents;
@end

@implementation MobaLifecycleFakeSink {
    NSMutableArray<NSString *> *_events;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)recordEvent:(NSString *)event {
    @synchronized (self) {
        [_events addObject:event];
    }
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    [self recordEvent:[NSString stringWithFormat:@"key:%u:%@", (unsigned int)keyCode, down ? @"down" : @"up"]];
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    [self recordEvent:[NSString stringWithFormat:@"cursor:%.0f:%.0f", point.x, point.y]];
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    [self recordEvent:[NSString stringWithFormat:@"mouse:%d:%@", button, down ? @"down" : @"up"]];
}

- (NSArray<NSString *> *)eventSnapshot {
    @synchronized (self) {
        return [_events copy];
    }
}

- (void)clearEvents {
    @synchronized (self) {
        [_events removeAllObjects];
    }
}

@end

@interface MobaLifecycleManualScheduler : NSObject <MobaInputScheduling>
- (void)runAll;
@end

@implementation MobaLifecycleManualScheduler {
    NSMutableArray *_blocks;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _blocks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)scheduleAfterMilliseconds:(NSUInteger)delayMs block:(dispatch_block_t)block {
    (void)delayMs;
    @synchronized (self) {
        [_blocks addObject:[block copy]];
    }
}

- (void)runAll {
    NSArray *blocks;
    @synchronized (self) {
        blocks = [_blocks copy];
        [_blocks removeAllObjects];
    }
    for (dispatch_block_t block in blocks) {
        block();
    }
}

@end

@interface MobaLifecycleFakeEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic, getter=isMobaBattleModeSupported) BOOL mobaBattleModeSupported;
@property (nonatomic, readonly) BOOL traditionalControlsSuppressed;
@property (nonatomic, readonly) NSUInteger suppressionChangeCount;
@end

@implementation MobaLifecycleFakeEnvironment {
    BOOL _traditionalControlsSuppressed;
    NSUInteger _suppressionChangeCount;
}

- (BOOL)traditionalControlsSuppressed {
    return _traditionalControlsSuppressed;
}

- (NSUInteger)suppressionChangeCount {
    return _suppressionChangeCount;
}

- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed {
    if (_traditionalControlsSuppressed != suppressed) {
        _traditionalControlsSuppressed = suppressed;
        _suppressionChangeCount++;
    }
}

@end

@interface MobaLifecycleFakeResetParticipant : NSObject <MobaLocalInteractionResetParticipant>
@property (nonatomic, readonly) NSArray<NSNumber *> *resetReasons;
@property (nonatomic, readonly) BOOL interactionEnabled;
@end

@implementation MobaLifecycleFakeResetParticipant {
    NSMutableArray<NSNumber *> *_mutableResetReasons;
    BOOL _interactionEnabled;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableResetReasons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray<NSNumber *> *)resetReasons {
    return [_mutableResetReasons copy];
}

- (BOOL)interactionEnabled {
    return _interactionEnabled;
}

- (void)setMobaLocalInteractionEnabled:(BOOL)enabled {
    _interactionEnabled = enabled;
}

- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason {
    [_mutableResetReasons addObject:@(reason)];
    _interactionEnabled = NO;
}

@end

@interface MobaOverlayLifecycleTests : XCTestCase
@property (nonatomic, strong) MobaLifecycleFakeSink *sink;
@property (nonatomic, strong) MobaLifecycleManualScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaLifecycleFakeEnvironment *environment;
@property (nonatomic, strong) MobaLifecycleFakeResetParticipant *participant;
@property (nonatomic, strong) MobaOverlayLifecycle *lifecycle;
@end

@implementation MobaOverlayLifecycleTests

- (void)configureLifecycleStarted:(BOOL)started {
    self.sink = [[MobaLifecycleFakeSink alloc] init];
    self.scheduler = [[MobaLifecycleManualScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
    self.environment = [[MobaLifecycleFakeEnvironment alloc] init];
    self.environment.mobaBattleModeSupported = YES;
    self.lifecycle = [[MobaOverlayLifecycle alloc] initWithEnvironment:self.environment
                                                       inputDispatcher:self.dispatcher];
    self.participant = [[MobaLifecycleFakeResetParticipant alloc] init];
    [self.lifecycle registerLocalInteractionResetParticipant:self.participant];
    if (started) {
        [self.lifecycle start];
    }
}

- (void)setUp {
    [super setUp];
    [self configureLifecycleStarted:YES];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)holdKeyAndMouse {
    [self.dispatcher setKeyCode:87 down:YES];
    [self.dispatcher setMouseButton:1 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];
}

- (void)assertHeldInputsReleasedOnceForReason:(MobaInputInterruptionReason)reason {
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"mouse:1:up"]));
    XCTAssertEqualObjects(self.participant.resetReasons, (@[@(reason)]));
    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    XCTAssertFalse(self.participant.interactionEnabled);
}

- (void)testResignActiveReleasesEveryStateExactlyOnce {
    [self holdKeyAndMouse];

    [self.lifecycle applicationWillResignActive];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonApplicationWillResignActive];
}

- (void)testBackgroundReleasesEveryStateExactlyOnce {
    [self holdKeyAndMouse];

    [self.lifecycle applicationDidEnterBackground];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonApplicationDidEnterBackground];
}

- (void)testStreamDisconnectReleasesThenStopsAndRestoresTraditionalControls {
    [self holdKeyAndMouse];

    [self.lifecycle streamDidDisconnect];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonStreamDisconnectOrTeardown];
    XCTAssertFalse(self.lifecycle.isRunning);
    XCTAssertFalse(self.environment.traditionalControlsSuppressed);
}

- (void)testStopThenDestructionDoesNotRepeatRelease {
    [self holdKeyAndMouse];

    [self.lifecycle stop];
    [self.lifecycle invalidateForDestruction];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonCoordinatorStop];
}

- (void)testBattleToUIReleasesAndRejectsFurtherDiagnostics {
    [self holdKeyAndMouse];
    MobaCursorDiagnostics *diagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:self.dispatcher
                                                                                 inputGate:(id<MobaBattleInputGate>)self.lifecycle];

    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeUI]);
    XCTAssertFalse([diagnostics sendPointAtIndex:4]);

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonBattleToUI];
    XCTAssertEqual(self.lifecycle.mode, MobaOverlayModeUI);
    XCTAssertTrue(self.environment.traditionalControlsSuppressed);
}

- (void)testBattleToLayoutEditReleasesAndResets {
    [self holdKeyAndMouse];

    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeLayoutEdit]);

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonBattleToLayoutEdit];
}

- (void)testBattleToSkillTuningReleasesAndResets {
    [self holdKeyAndMouse];

    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeSkillTuning]);

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonBattleToSkillTuning];
}

- (void)testTransitionToSameModeDoesNotReleaseOrReset {
    [self holdKeyAndMouse];

    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeBattle]);
    [self drainDispatcher];

    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertEqual(self.participant.resetReasons.count, 0u);
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
}

- (void)testOrientationChangeReleasesAndResetsThenCanResume {
    [self holdKeyAndMouse];

    [self.lifecycle orientationWillChange];
    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonOrientationChange];
    [self.lifecycle orientationDidChange];

    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
    XCTAssertTrue(self.participant.interactionEnabled);
}

- (void)testProfileReloadReleasesAndResetsThenCanResume {
    [self holdKeyAndMouse];

    [self.lifecycle profileWillReload];
    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonProfileReload];
    [self.lifecycle profileDidReload];

    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
}

- (void)testFeatureDisableReleasesStopsAndRestoresTraditionalControls {
    [self holdKeyAndMouse];
    XCTAssertTrue(self.environment.traditionalControlsSuppressed);

    [self.lifecycle mobaFeatureWillDisable];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonFeatureDisable];
    XCTAssertFalse(self.lifecycle.isRunning);
    XCTAssertFalse(self.environment.traditionalControlsSuppressed);
    XCTAssertEqual(self.environment.suppressionChangeCount, 2u);
}

- (void)testPendingTapDoesNotSendDuplicateKeyUpAfterInterruption {
    [self.dispatcher tapKeyCode:67 durationMs:30];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.lifecycle applicationWillResignActive];
    [self drainDispatcher];
    [self.lifecycle applicationDidBecomeActive];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:up"]));
}

- (void)testConsecutiveInterruptionsReleaseAndResetOnlyOnce {
    [self holdKeyAndMouse];

    [self.lifecycle applicationWillResignActive];
    [self.lifecycle applicationDidEnterBackground];
    [self.lifecycle orientationWillChange];
    [self.lifecycle profileWillReload];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonApplicationWillResignActive];
}

- (void)testDiagnosticsAreRejectedImmediatelyWhenInterruptionIsSubmitted {
    MobaCursorDiagnostics *diagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:self.dispatcher
                                                                                 inputGate:(id<MobaBattleInputGate>)self.lifecycle];
    [self.lifecycle applicationWillResignActive];

    XCTAssertFalse([diagnostics sendPointAtIndex:0]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
}

- (void)testResumeActiveDoesNotRestorePreviouslyPressedState {
    [self holdKeyAndMouse];

    [self.lifecycle applicationWillResignActive];
    [self drainDispatcher];
    [self.lifecycle applicationDidBecomeActive];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"mouse:1:up"]));
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
}

- (void)testTouchCancellationUsesUnifiedReleaseAndResetBoundary {
    [self holdKeyAndMouse];

    [self.lifecycle touchesCancelled];

    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"mouse:1:up"]));
    XCTAssertEqualObjects(self.participant.resetReasons,
                          (@[@(MobaInputInterruptionReasonTouchCancellation)]));
    XCTAssertFalse(self.lifecycle.isInputSuspended);
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
    XCTAssertTrue(self.participant.interactionEnabled);
}

- (void)testViewControllerDisappearanceReleasesAndStops {
    [self holdKeyAndMouse];

    [self.lifecycle viewControllerWillDisappear];

    [self assertHeldInputsReleasedOnceForReason:MobaInputInterruptionReasonViewControllerDisappearance];
    XCTAssertFalse(self.lifecycle.isRunning);
}

- (void)testInvalidResolutionCannotResumeBattleInput {
    [self holdKeyAndMouse];
    [self.lifecycle orientationWillChange];
    [self drainDispatcher];
    self.environment.mobaBattleModeSupported = NO;

    [self.lifecycle orientationDidChange];

    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    XCTAssertFalse(self.participant.interactionEnabled);
}

- (void)testBecomeActiveCannotResumeBeforeOrientationCompletes {
    [self.lifecycle orientationWillChange];

    [self.lifecycle applicationDidBecomeActive];

    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    [self.lifecycle orientationDidChange];
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
}

- (void)testBecomeActiveCannotResumeBeforeProfileReloadCompletes {
    [self.lifecycle profileWillReload];

    [self.lifecycle applicationDidBecomeActive];

    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    [self.lifecycle profileDidReload];
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
}

- (void)testOrientationBlockerBeforeStartPersistsUntilOrientationCompletes {
    [self configureLifecycleStarted:NO];
    [self.lifecycle orientationWillChange];

    [self.lifecycle start];

    XCTAssertTrue(self.lifecycle.isRunning);
    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    XCTAssertTrue(self.environment.traditionalControlsSuppressed);
    [self.lifecycle orientationDidChange];
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
}

- (void)testProfileReloadBlockerBeforeStartPersistsUntilReloadCompletes {
    [self configureLifecycleStarted:NO];
    [self.lifecycle profileWillReload];

    [self.lifecycle start];

    XCTAssertTrue(self.lifecycle.isRunning);
    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    XCTAssertTrue(self.environment.traditionalControlsSuppressed);
    [self.lifecycle profileDidReload];
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
}

- (void)testInactiveBlockerBeforeStartPersistsUntilApplicationBecomesActive {
    [self configureLifecycleStarted:NO];
    [self.lifecycle applicationWillResignActive];

    [self.lifecycle start];

    XCTAssertTrue(self.lifecycle.isRunning);
    XCTAssertTrue(self.lifecycle.isInputSuspended);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
    XCTAssertTrue(self.environment.traditionalControlsSuppressed);
    [self.lifecycle applicationDidBecomeActive];
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
}

@end
