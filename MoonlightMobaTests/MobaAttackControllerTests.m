//
//  MobaAttackControllerTests.m
//  MoonlightMobaTests
//


#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Controls/AttackButtonView.h"
#import "../Limelight/Input/MOBA/Controls/MobaAttackController.h"
#import "../Limelight/Input/MOBA/Controls/MobaMovementController.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"

@interface AttackButtonView (MobaTesting)
- (BOOL)beginInteractionWithToken:(id)token;
- (BOOL)updateInteractionWithToken:(id)token;
- (BOOL)endInteractionWithToken:(id)token;
- (BOOL)cancelInteractionWithToken:(id)token;
@end

@interface MobaAttackFakeSink : NSObject <MobaInputSink>
- (NSArray<NSString *> *)eventSnapshot;
- (void)clearEvents;
@end

@implementation MobaAttackFakeSink {
    NSMutableArray<NSString *> *_events;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    @synchronized (self) {
        [_events addObject:[NSString stringWithFormat:@"key:%u:%@",
                            (unsigned int)keyCode,
                            down ? @"down" : @"up"]];
    }
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    (void)point;
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    (void)button;
    (void)down;
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

@interface MobaAttackManualScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSUInteger pendingCount;
- (NSArray<NSNumber *> *)delaySnapshot;
- (void)runAll;
@end

@implementation MobaAttackManualScheduler {
    NSMutableArray *_blocks;
    NSMutableArray<NSNumber *> *_delays;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _blocks = [[NSMutableArray alloc] init];
        _delays = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)scheduleAfterMilliseconds:(NSUInteger)delayMs block:(dispatch_block_t)block {
    @synchronized (self) {
        [_blocks addObject:[block copy]];
        [_delays addObject:@(delayMs)];
    }
}

- (NSUInteger)pendingCount {
    @synchronized (self) {
        return _blocks.count;
    }
}

- (NSArray<NSNumber *> *)delaySnapshot {
    @synchronized (self) {
        return [_delays copy];
    }
}

- (void)runAll {
    NSArray *blocks;
    @synchronized (self) {
        blocks = [_blocks copy];
        [_blocks removeAllObjects];
        [_delays removeAllObjects];
    }

    for (dispatch_block_t block in blocks) {
        block();
    }
}

@end

@interface MobaAttackLifecycleEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic, getter=isMobaBattleModeSupported) BOOL mobaBattleModeSupported;
@end

@implementation MobaAttackLifecycleEnvironment

- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed {
    (void)suppressed;
}

@end

@interface MobaAttackCancellationDelegate : NSObject <MobaAttackControllerDelegate>
@property (nonatomic, strong) MobaOverlayLifecycle *lifecycle;
@property (nonatomic) NSUInteger cancellationCount;
@end

@implementation MobaAttackCancellationDelegate

- (void)attackControllerDidRequestTouchCancellation:(MobaAttackController *)controller {
    (void)controller;
    self.cancellationCount++;
    [self.lifecycle touchesCancelled];
}

@end

@interface MobaAttackControllerTests : XCTestCase
@property (nonatomic, strong) MobaAttackFakeSink *sink;
@property (nonatomic, strong) MobaAttackManualScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaAttackController *controller;
@property (nonatomic, strong) AttackButtonView *view;
@property (nonatomic, strong) MobaAttackLifecycleEnvironment *lifecycleEnvironment;
@end

@implementation MobaAttackControllerTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaAttackFakeSink alloc] init];
    self.scheduler = [[MobaAttackManualScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
    self.controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    self.view = [[AttackButtonView alloc] initWithAttackController:self.controller];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"attack dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (MobaOverlayLifecycle *)startedLifecycleWithCancellationDelegate:(MobaAttackCancellationDelegate **)delegateResult {
    self.lifecycleEnvironment = [[MobaAttackLifecycleEnvironment alloc] init];
    self.lifecycleEnvironment.mobaBattleModeSupported = YES;
    MobaOverlayLifecycle *lifecycle = [[MobaOverlayLifecycle alloc]
        initWithEnvironment:self.lifecycleEnvironment
             inputDispatcher:self.dispatcher];
    [lifecycle registerLocalInteractionResetParticipant:self.view];
    [lifecycle start];

    MobaAttackCancellationDelegate *delegate = [[MobaAttackCancellationDelegate alloc] init];
    delegate.lifecycle = lifecycle;
    self.controller.delegate = delegate;
    if (delegateResult != NULL) {
        *delegateResult = delegate;
    }
    return lifecycle;
}

- (void)testFirstTouchDownSendsOneDefaultTap {
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqual(self.controller.attackKeyCode, 67);
    XCTAssertEqual(self.controller.tapDurationMs, 30u);
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:down"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
    XCTAssertEqualObjects(self.scheduler.delaySnapshot, (@[@30]));

    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:down", @"key:67:up"]));
}

- (void)testConfiguredKeyAndDurationUseDispatcherTap {
    MobaAttackController *configured = [[MobaAttackController alloc]
        initWithInputDispatcher:self.dispatcher
                  attackKeyCode:99
                  tapDurationMs:45];
    NSObject *owner = [[NSObject alloc] init];

    XCTAssertTrue([configured beginInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:99:down"]));
    XCTAssertEqualObjects(self.scheduler.delaySnapshot, (@[@45]));
}

- (void)testHoldMoveAndRepeatedBeginDoNotRepeatTap {
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    XCTAssertTrue([self.view updateInteractionWithToken:owner]);
    XCTAssertTrue([self.view updateInteractionWithToken:owner]);
    XCTAssertFalse([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:down"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
    XCTAssertTrue(self.controller.isPressed);
    XCTAssertTrue(self.view.isPressed);
}

- (void)testSecondTokenIsRejectedWhileOwnerExists {
    NSObject *owner = [[NSObject alloc] init];
    NSObject *other = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertFalse([self.view beginInteractionWithToken:other]);
    [self drainDispatcher];

    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
    XCTAssertEqual(self.controller.activeTouchToken, owner);
}

- (void)testOwnerEndOnlyClearsLocalStateAndIsIdempotent {
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.view endInteractionWithToken:owner]);
    XCTAssertFalse([self.view endInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(self.controller.isPressed);
    XCTAssertFalse(self.view.isPressed);
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
}

- (void)testNonOwnerMoveEndAndCancelAreIgnored {
    NSObject *owner = [[NSObject alloc] init];
    NSObject *other = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertFalse([self.view updateInteractionWithToken:other]);
    XCTAssertFalse([self.view endInteractionWithToken:other]);
    XCTAssertFalse([self.view cancelInteractionWithToken:other]);
    [self drainDispatcher];

    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertEqual(self.controller.activeTouchToken, owner);
    XCTAssertTrue(self.controller.isPressed);
    XCTAssertTrue(self.view.isPressed);
}

- (void)testOwnerCancellationReleasesPendingTapExactlyOnce {
    MobaAttackCancellationDelegate *delegate;
    MobaOverlayLifecycle *lifecycle = [self startedLifecycleWithCancellationDelegate:&delegate];
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.view cancelInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqual(delegate.cancellationCount, 1u);
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:up"]));
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(self.controller.isPressed);
    XCTAssertFalse(self.view.isPressed);
    XCTAssertTrue(lifecycle.isBattleInputAllowed);

    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:up"]));
}

- (void)testCancellationAfterNaturalTapEndDoesNotSendExtraInput {
    MobaAttackCancellationDelegate *delegate;
    [self startedLifecycleWithCancellationDelegate:&delegate];
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.view cancelInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqual(delegate.cancellationCount, 1u);
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(self.view.isPressed);
}

- (void)testLifecycleDisableReleaseAllAndResetDoNotDuplicateKeyUp {
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:owner]);
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.view setMobaLocalInteractionEnabled:NO];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertFalse(self.view.userInteractionEnabled);
    XCTAssertFalse(self.controller.isInteractionEnabled);
    XCTAssertEqualWithAccuracy(self.view.alpha, self.view.disabledOpacity, 0.000001);

    [self.dispatcher releaseAllInputs];
    [self.view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonApplicationWillResignActive];
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:up"]));
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(self.controller.isPressed);
    XCTAssertFalse(self.view.isPressed);
    XCTAssertFalse([self.view updateInteractionWithToken:owner]);
    XCTAssertFalse([self.view endInteractionWithToken:owner]);
    XCTAssertFalse([self.view cancelInteractionWithToken:owner]);
}

- (void)testConfigurationDisableIsSilentIdempotentAndInvalidatesOldToken {
    NSObject *oldToken = [[NSObject alloc] init];
    NSObject *newToken = [[NSObject alloc] init];
    XCTAssertTrue([self.view beginInteractionWithToken:oldToken]);
    [self drainDispatcher];

    self.view.interactionEnabled = NO;
    self.view.interactionEnabled = NO;
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:down"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(self.controller.isPressed);
    XCTAssertFalse(self.view.isPressed);
    XCTAssertFalse(self.view.userInteractionEnabled);
    XCTAssertFalse([self.view updateInteractionWithToken:oldToken]);
    XCTAssertFalse([self.view endInteractionWithToken:oldToken]);
    XCTAssertFalse([self.view cancelInteractionWithToken:oldToken]);

    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:67:down", @"key:67:up"]));

    self.view.interactionEnabled = YES;
    XCTAssertFalse([self.view updateInteractionWithToken:oldToken]);
    XCTAssertTrue([self.view beginInteractionWithToken:newToken]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"key:67:down", @"key:67:up", @"key:67:down"]));
    XCTAssertEqual(self.controller.activeTouchToken, newToken);
}

- (void)testOpacityAndInteractionAreIndependent {
    XCTAssertTrue(CGSizeEqualToSize(self.view.visualSize, CGSizeMake(110.0, 110.0)));
    XCTAssertEqualWithAccuracy(self.view.hitAreaScale, 1.18, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.normalOpacity, 0.78, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.pressedOpacity, 0.92, 0.000001);
    XCTAssertEqualWithAccuracy(self.view.disabledOpacity, 0.30, 0.000001);

    self.view.normalOpacity = 0.0;
    XCTAssertEqualWithAccuracy(self.view.alpha, 0.0, 0.000001);
    XCTAssertTrue(self.view.userInteractionEnabled);
    XCTAssertTrue(self.controller.isInteractionEnabled);

    self.view.interactionEnabled = NO;
    XCTAssertFalse(self.view.userInteractionEnabled);
    XCTAssertFalse(self.controller.isInteractionEnabled);
    XCTAssertEqualWithAccuracy(self.view.alpha, self.view.disabledOpacity, 0.000001);
}

- (void)testCustomVisualSizeAndHitAreaScaleAreApplied {
    AttackButtonView *customView = [[AttackButtonView alloc]
        initWithAttackController:self.controller
                      visualSize:CGSizeMake(96.0, 88.0)
                     hitAreaScale:1.4];

    XCTAssertTrue(CGSizeEqualToSize(customView.visualSize, CGSizeMake(96.0, 88.0)));
    XCTAssertEqualWithAccuracy(customView.hitAreaScale, 1.4, 0.000001);
    XCTAssertEqualWithAccuracy(customView.intrinsicContentSize.width, 134.4, 0.000001);
    XCTAssertEqualWithAccuracy(customView.intrinsicContentSize.height, 123.2, 0.000001);
}

- (void)testAttackTapCoexistsWithHeldMovementWithoutReleasingW {
    MobaMovementController *movementController = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher
                     keyMapping:MobaDefaultMovementKeyMapping()
                    wheelRadius:100.0
                  deadZoneRatio:0.16
     directionHysteresisDegrees:8.0];
    NSObject *attackToken = [[NSObject alloc] init];

    XCTAssertTrue([movementController updateDisplacement:CGVectorMake(0.0, -100.0)]);
    XCTAssertTrue([self.view beginInteractionWithToken:attackToken]);
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertTrue([self.view endInteractionWithToken:attackToken]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"key:87:down", @"key:67:down", @"key:67:up"]));
    XCTAssertEqual(movementController.state, MobaJoystickStateUp);
}

@end
