//
//  MobaTouchRoutingTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Controls/MobaModeToolbarView.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaNativeTouchRoutingController.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"

@interface MobaRoutingFakeCancellationConsumer : NSObject <MobaNativeTouchSequenceCancelling>
@property (nonatomic) NSUInteger cancellationCount;
@end

@implementation MobaRoutingFakeCancellationConsumer
- (void)cancelActiveNativeTouchSequence {
    self.cancellationCount++;
}
@end

@interface MobaRoutingFakeSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
- (void)clearEvents;
@end

@implementation MobaRoutingFakeSink {
    NSMutableArray<NSString *> *_mutableEvents;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableEvents = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    @synchronized (self) {
        [_mutableEvents addObject:[NSString stringWithFormat:@"key:%u:%@", keyCode, down ? @"down" : @"up"]];
    }
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    (void)point;
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    @synchronized (self) {
        [_mutableEvents addObject:[NSString stringWithFormat:@"mouse:%d:%@", button, down ? @"down" : @"up"]];
    }
}

- (NSArray<NSString *> *)events {
    @synchronized (self) {
        return [_mutableEvents copy];
    }
}

- (void)clearEvents {
    @synchronized (self) {
        [_mutableEvents removeAllObjects];
    }
}
@end

@interface MobaRoutingManualScheduler : NSObject <MobaInputScheduling>
- (void)runAll;
@end

@implementation MobaRoutingManualScheduler {
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
    [_blocks addObject:[block copy]];
}

- (void)runAll {
    NSArray *blocks = [_blocks copy];
    [_blocks removeAllObjects];
    for (dispatch_block_t block in blocks) {
        block();
    }
}
@end

@interface MobaRoutingFakeEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic, getter=isMobaBattleModeSupported) BOOL mobaBattleModeSupported;
@property (nonatomic, getter=isNativeTouchRoutingEnabled) BOOL nativeTouchRoutingEnabled;
@property (nonatomic) BOOL traditionalControlsSuppressed;
@property (nonatomic, strong) NSMutableArray<NSString *> *eventLog;
@end

@implementation MobaRoutingFakeEnvironment

- (instancetype)init {
    self = [super init];
    if (self) {
        _nativeTouchRoutingEnabled = YES;
        _eventLog = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed {
    _traditionalControlsSuppressed = suppressed;
    [_eventLog addObject:suppressed ? @"osc:off" : @"osc:on"];
}

- (void)setMobaNativeTouchRoutingEnabled:(BOOL)enabled {
    if (_nativeTouchRoutingEnabled == enabled) {
        return;
    }
    _nativeTouchRoutingEnabled = enabled;
    [_eventLog addObject:enabled ? @"native:on" : @"native:off"];
}
@end

@interface MobaRoutingFakeParticipant : NSObject <MobaLocalInteractionResetParticipant>
@property (nonatomic) NSUInteger resetCount;
@property (nonatomic) BOOL interactionEnabled;
@property (nonatomic, strong) NSMutableArray<NSString *> *eventLog;
@end

@implementation MobaRoutingFakeParticipant
- (void)setMobaLocalInteractionEnabled:(BOOL)enabled {
    _interactionEnabled = enabled;
    [_eventLog addObject:enabled ? @"controls:on" : @"controls:off"];
}
- (void)resetMobaLocalInteractionForReason:(MobaInputInterruptionReason)reason {
    (void)reason;
    self.resetCount++;
    [self.eventLog addObject:@"controls:reset"];
}
@end

@interface MobaRoutingToolbarDelegate : NSObject <MobaModeToolbarViewDelegate>
@property (nonatomic) BOOL acceptsRequest;
@property (nonatomic) MobaOverlayMode requestedMode;
@end

@implementation MobaRoutingToolbarDelegate
- (BOOL)mobaModeToolbarView:(MobaModeToolbarView *)toolbar requestMode:(MobaOverlayMode)mode {
    (void)toolbar;
    self.requestedMode = mode;
    return self.acceptsRequest;
}
@end

@interface MobaTouchRoutingTests : XCTestCase
@property (nonatomic, strong) MobaRoutingFakeSink *sink;
@property (nonatomic, strong) MobaRoutingManualScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaRoutingFakeEnvironment *environment;
@property (nonatomic, strong) MobaRoutingFakeParticipant *participant;
@property (nonatomic, strong) MobaOverlayLifecycle *lifecycle;
@end

@implementation MobaTouchRoutingTests

- (void)setUpLifecycleWithBattleSupported:(BOOL)supported {
    self.sink = [[MobaRoutingFakeSink alloc] init];
    self.scheduler = [[MobaRoutingManualScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
    self.environment = [[MobaRoutingFakeEnvironment alloc] init];
    self.environment.mobaBattleModeSupported = supported;
    self.lifecycle = [[MobaOverlayLifecycle alloc] initWithEnvironment:self.environment
                                                       inputDispatcher:self.dispatcher];
    self.participant = [[MobaRoutingFakeParticipant alloc] init];
    self.participant.eventLog = self.environment.eventLog;
    [self.lifecycle registerLocalInteractionResetParticipant:self.participant];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (MobaNativeTouchRoutingController *)routingControllerWithConsumer:(MobaRoutingFakeCancellationConsumer *)consumer {
    return [[MobaNativeTouchRoutingController alloc] initWithCancellationConsumer:consumer];
}

- (void)testNativeRoutingDefaultsEnabledWithoutCoordinator {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    XCTAssertTrue(routing.isNativeTouchRoutingEnabled);
    XCTAssertTrue([routing allowsTouchKind:MobaNativeTouchKindDirect]);
}

- (void)testBattleRoutingBlocksDirectTouch {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    [routing setNativeTouchRoutingEnabled:NO];
    XCTAssertFalse([routing allowsTouchKind:MobaNativeTouchKindDirect]);
}

- (void)testBattleRoutingBlocksPencilTouch {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    [routing setNativeTouchRoutingEnabled:NO];
    XCTAssertFalse([routing allowsTouchKind:MobaNativeTouchKindPencil]);
}

- (void)testBattleRoutingPreservesIndirectPointer {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    [routing setNativeTouchRoutingEnabled:NO];
    XCTAssertTrue([routing allowsTouchKind:MobaNativeTouchKindIndirectPointer]);
}

- (void)testBattleRoutingMakesThreeFingerKeyboardUnreachable {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    [routing setNativeTouchRoutingEnabled:NO];
    XCTAssertFalse([routing allowsThreeFingerKeyboardGesture]);
}

- (void)testUIRoutingAllowsDirectTouchAndThreeFingerKeyboard {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    [routing setNativeTouchRoutingEnabled:NO];
    [routing setNativeTouchRoutingEnabled:YES];
    XCTAssertTrue([routing allowsTouchKind:MobaNativeTouchKindDirect]);
    XCTAssertTrue([routing allowsThreeFingerKeyboardGesture]);
}

- (void)testEnabledToDisabledCancelsConsumerOnceAndRepeatedDisableIsIdempotent {
    MobaRoutingFakeCancellationConsumer *consumer = [[MobaRoutingFakeCancellationConsumer alloc] init];
    MobaNativeTouchRoutingController *routing = [self routingControllerWithConsumer:consumer];
    [routing setNativeTouchRoutingEnabled:NO];
    [routing setNativeTouchRoutingEnabled:NO];
    XCTAssertEqual(consumer.cancellationCount, 1u);
}

- (void)testSupportedStartChoosesBattleAndDisablesNativeRouting {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    XCTAssertEqual(self.lifecycle.mode, MobaOverlayModeBattle);
    XCTAssertFalse(self.environment.isNativeTouchRoutingEnabled);
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
}

- (void)testUnsupportedStartChoosesUIAndRejectsBattleWithoutChangingRouting {
    [self setUpLifecycleWithBattleSupported:NO];
    [self.lifecycle start];
    XCTAssertEqual(self.lifecycle.mode, MobaOverlayModeUI);
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
    XCTAssertFalse([self.lifecycle transitionToMode:MobaOverlayModeBattle]);
    XCTAssertEqual(self.lifecycle.mode, MobaOverlayModeUI);
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
}

- (void)testBattleToUIReleasesHeldMovementAndPendingAttackBeforeRestoringNativeRouting {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.dispatcher setKeyCode:87 down:YES];
    [self.dispatcher tapKeyCode:67 durationMs:30];
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeUI]);
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:67:up", @"key:87:up"]));
    XCTAssertEqual(self.participant.resetCount, 1u);
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
    XCTAssertFalse(self.lifecycle.isBattleInputAllowed);
}

- (void)testUIToBattleClosesNativeRoutingBeforeEnablingBattleControls {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.lifecycle transitionToMode:MobaOverlayModeUI];
    [self.environment.eventLog removeAllObjects];

    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeBattle]);

    NSUInteger routingIndex = [self.environment.eventLog indexOfObject:@"native:off"];
    NSUInteger controlsIndex = [self.environment.eventLog indexOfObject:@"controls:on"];
    XCTAssertNotEqual(routingIndex, NSNotFound);
    XCTAssertNotEqual(controlsIndex, NSNotFound);
    XCTAssertLessThan(routingIndex, controlsIndex);
}

- (void)testBattleToLayoutEditReleasesAndKeepsNativeRoutingDisabled {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.dispatcher setKeyCode:87 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];
    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeLayoutEdit]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:87:up"]));
    XCTAssertFalse(self.environment.isNativeTouchRoutingEnabled);
}

- (void)testBattleToSkillTuningReleasesAndKeepsNativeRoutingDisabled {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.dispatcher setKeyCode:87 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];
    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeSkillTuning]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:87:up"]));
    XCTAssertFalse(self.environment.isNativeTouchRoutingEnabled);
}

- (void)testSameModeTransitionDoesNotReleaseOrReset {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeBattle]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(self.participant.resetCount, 0u);
}

- (void)testStopRestoresNativeRoutingAndTraditionalControls {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.lifecycle stop];
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
    XCTAssertFalse(self.environment.traditionalControlsSuppressed);
}

- (void)testDisconnectRestoresNativeRouting {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.lifecycle streamDidDisconnect];
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
}

- (void)testFeatureDisableRestoresNativeRouting {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.lifecycle mobaFeatureWillDisable];
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
}

- (void)testDestructionBoundaryRestoresNativeRouting {
    [self setUpLifecycleWithBattleSupported:YES];
    [self.lifecycle start];
    [self.lifecycle invalidateForDestruction];
    XCTAssertTrue(self.environment.isNativeTouchRoutingEnabled);
}

- (void)testToolbarTracksAcceptedModeAndRestoresSelectionAfterRejectedBattle {
    MobaModeToolbarView *toolbar = [[MobaModeToolbarView alloc] initWithFrame:CGRectZero];
    MobaRoutingToolbarDelegate *delegate = [[MobaRoutingToolbarDelegate alloc] init];
    toolbar.delegate = delegate;
    delegate.acceptsRequest = YES;
    XCTAssertTrue([toolbar requestMode:MobaOverlayModeUI]);
    XCTAssertEqual(toolbar.selectedMode, MobaOverlayModeUI);
    toolbar.battleModeAvailable = NO;
    XCTAssertFalse([toolbar requestMode:MobaOverlayModeBattle]);
    XCTAssertEqual(toolbar.selectedMode, MobaOverlayModeUI);
}

@end
