//
//  MobaCursorCoalescerLifecycleTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Core/MobaCursorCoalescer.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"

@interface MobaCoalescerLifecycleTimeline : NSObject
@property (nonatomic, readonly) NSArray<NSString *> *events;
- (void)add:(NSString *)event;
- (void)clear;
@end


@implementation MobaCoalescerLifecycleTimeline {
    NSMutableArray<NSString *> *_events;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray<NSString *> *)events {
    @synchronized (self) { return [_events copy]; }
}

- (void)add:(NSString *)event {
    @synchronized (self) { [_events addObject:event]; }
}

- (void)clear {
    @synchronized (self) { [_events removeAllObjects]; }
}

@end

@interface MobaCoalescerLifecycleSink : NSObject <MobaInputSink>
@property (nonatomic, strong) MobaCoalescerLifecycleTimeline *timeline;
@end

@implementation MobaCoalescerLifecycleSink

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    [self.timeline add:[NSString stringWithFormat:@"key:%u:%@",
                        (unsigned int)keyCode,
                        down ? @"down" : @"up"]];
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    [self.timeline add:@"cursor"];
}

- (void)sendMouseButton:(int)button down:(BOOL)down {}

@end

@interface MobaCoalescerLifecycleDriver : NSObject <MobaDisplayLinkDriving>
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, strong) MobaCoalescerLifecycleTimeline *timeline;
@property (nonatomic, readonly) NSUInteger startCount;
- (void)fireTickAtIndex:(NSUInteger)index;
@end

@implementation MobaCoalescerLifecycleDriver {
    NSMutableArray *_callbacks;
    BOOL _running;
    NSUInteger _startCount;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _callbacks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (BOOL)isRunning { return _running; }
- (NSUInteger)startCount { return _startCount; }

- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate
                tickHandler:(MobaDisplayLinkTickHandler)tickHandler {
    if (_running) {
        return YES;
    }
    _running = YES;
    _startCount += 1;
    [_callbacks addObject:[tickHandler copy]];
    return YES;
}

- (void)stop {
    if (!_running) {
        return;
    }
    _running = NO;
    [self.timeline add:@"driver-stop"];
}

- (void)fireTickAtIndex:(NSUInteger)index {
    if (index < _callbacks.count) {
        MobaDisplayLinkTickHandler callback = _callbacks[index];
        callback();
    }
}

@end

@interface MobaCoalescerLifecycleEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic) BOOL supported;
@end

@implementation MobaCoalescerLifecycleEnvironment
- (BOOL)isMobaBattleModeSupported { return self.supported; }
- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed {}
- (void)setMobaNativeTouchRoutingEnabled:(BOOL)enabled {}
@end

@interface MobaCursorCoalescerLifecycleTests : XCTestCase
@property (nonatomic, strong) MobaCoalescerLifecycleTimeline *timeline;
@property (nonatomic, strong) MobaCoalescerLifecycleSink *sink;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaCoalescerLifecycleDriver *driver;
@property (nonatomic, strong) MobaCursorCoalescer *coalescer;
@property (nonatomic, strong) MobaCoalescerLifecycleEnvironment *environment;
@property (nonatomic, strong) MobaOverlayLifecycle *lifecycle;
@end

@implementation MobaCursorCoalescerLifecycleTests

- (void)setUp {
    [super setUp];
    [self createStartedHarness];
}

- (void)createStartedHarness {
    self.timeline = [[MobaCoalescerLifecycleTimeline alloc] init];
    self.sink = [[MobaCoalescerLifecycleSink alloc] init];
    self.sink.timeline = self.timeline;
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink];
    self.driver = [[MobaCoalescerLifecycleDriver alloc] init];
    self.driver.timeline = self.timeline;
    self.coalescer = [[MobaCursorCoalescer alloc] initWithDispatcher:self.dispatcher
                                                              driver:self.driver];
    self.environment = [[MobaCoalescerLifecycleEnvironment alloc] init];
    self.environment.supported = YES;
    self.lifecycle = [[MobaOverlayLifecycle alloc] initWithEnvironment:self.environment
                                                        inputDispatcher:self.dispatcher];
    [self.lifecycle registerLocalInteractionResetParticipant:self.coalescer];
    [self.lifecycle start];
    XCTAssertTrue([self.coalescer start]);
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"lifecycle coalescer dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)prepareTrackedKeyAndPendingCursor {
    [self.dispatcher setKeyCode:81 down:YES];
    [self.coalescer submitLatestPoint:CGPointMake(10.0, 20.0)];
    [self drainDispatcher];
    [self.timeline clear];
}

- (void)assertStoppedBeforeReleaseAll {
    [self drainDispatcher];
    XCTAssertFalse(self.driver.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    XCTAssertEqualObjects(self.timeline.events, (@[@"driver-stop", @"key:81:up"]));
}

- (void)testBattleToUIStopsSynchronouslyBeforeDispatcherReleaseAll {
    [self prepareTrackedKeyAndPendingCursor];
    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeUI]);
    [self assertStoppedBeforeReleaseAll];
}

- (void)testBattleToLayoutEditStopsCoalescer {
    [self prepareTrackedKeyAndPendingCursor];
    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeLayoutEdit]);
    [self assertStoppedBeforeReleaseAll];
}

- (void)testBattleToSkillTuningStopsCoalescer {
    [self prepareTrackedKeyAndPendingCursor];
    XCTAssertTrue([self.lifecycle transitionToMode:MobaOverlayModeSkillTuning]);
    [self assertStoppedBeforeReleaseAll];
}

- (void)testApplicationResignAndBackgroundEachStopCoalescer {
    [self prepareTrackedKeyAndPendingCursor];
    [self.lifecycle applicationWillResignActive];
    [self assertStoppedBeforeReleaseAll];

    [self createStartedHarness];
    [self prepareTrackedKeyAndPendingCursor];
    [self.lifecycle applicationDidEnterBackground];
    [self assertStoppedBeforeReleaseAll];
}

- (void)testDisconnectStopAndFeatureDisableEachStopCoalescer {
    NSArray<NSNumber *> *paths = @[@0, @1, @2];
    for (NSNumber *path in paths) {
        [self createStartedHarness];
        [self prepareTrackedKeyAndPendingCursor];
        switch (path.integerValue) {
            case 0:
                [self.lifecycle streamDidDisconnect];
                break;
            case 1:
                [self.lifecycle stop];
                break;
            default:
                [self.lifecycle mobaFeatureWillDisable];
                break;
        }
        [self assertStoppedBeforeReleaseAll];
    }
}

- (void)testOrientationAndProfileReloadEachStopCoalescer {
    [self prepareTrackedKeyAndPendingCursor];
    [self.lifecycle orientationWillChange];
    [self assertStoppedBeforeReleaseAll];

    [self createStartedHarness];
    [self prepareTrackedKeyAndPendingCursor];
    [self.lifecycle profileWillReload];
    [self assertStoppedBeforeReleaseAll];
}

- (void)testReleaseAllThenStaleTickDoesNotSendCursor {
    [self prepareTrackedKeyAndPendingCursor];
    [self.lifecycle applicationWillResignActive];
    [self drainDispatcher];
    NSArray *eventsAfterRelease = self.timeline.events;
    [self.driver fireTickAtIndex:0];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.timeline.events, eventsAfterRelease);
    XCTAssertFalse([self.timeline.events containsObject:@"cursor"]);
}

- (void)testRecoveryDoesNotRestoreOldPointOrRestartDriver {
    [self.coalescer submitLatestPoint:CGPointMake(10.0, 20.0)];
    [self.lifecycle applicationWillResignActive];
    [self.lifecycle applicationDidBecomeActive];
    XCTAssertTrue(self.lifecycle.isBattleInputAllowed);
    XCTAssertFalse(self.coalescer.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    XCTAssertEqual(self.driver.startCount, 1u);
    XCTAssertFalse([self.coalescer submitLatestPoint:CGPointMake(30.0, 40.0)]);
    [self.driver fireTickAtIndex:0];
    [self drainDispatcher];
    XCTAssertFalse([self.timeline.events containsObject:@"cursor"]);
    XCTAssertTrue([self.coalescer start]);
    XCTAssertEqual(self.driver.startCount, 2u);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

@end
