//
//  MobaInstantCastStrategyTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Casting/MobaInstantCastStrategy.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

@interface MobaInstantStrategyFakeSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
@end

@implementation MobaInstantStrategyFakeSink {
    NSMutableArray<NSString *> *_recordedEvents;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordedEvents = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    @synchronized (self) {
        [_recordedEvents addObject:[NSString stringWithFormat:@"key:%u:%@",
                                    (unsigned int)keyCode,
                                    down ? @"down" : @"up"]];
    }
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    @synchronized (self) {
        [_recordedEvents addObject:[NSString stringWithFormat:@"cursor:%.3f:%.3f", point.x, point.y]];
    }
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    @synchronized (self) {
        [_recordedEvents addObject:[NSString stringWithFormat:@"mouse:%d:%@",
                                    button,
                                    down ? @"down" : @"up"]];
    }
}

- (NSArray<NSString *> *)events {
    @synchronized (self) {
        return [_recordedEvents copy];
    }
}

@end

@interface MobaInstantStrategyManualScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSArray<NSNumber *> *scheduledDelays;
@property (nonatomic, readonly) NSUInteger pendingCount;
- (void)runAll;
@end

@implementation MobaInstantStrategyManualScheduler {
    NSMutableArray<NSNumber *> *_delays;
    NSMutableArray *_blocks;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _delays = [[NSMutableArray alloc] init];
        _blocks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)scheduleAfterMilliseconds:(NSUInteger)delayMs block:(dispatch_block_t)block {
    @synchronized (self) {
        [_delays addObject:@(delayMs)];
        [_blocks addObject:[block copy]];
    }
}

- (NSArray<NSNumber *> *)scheduledDelays {
    @synchronized (self) {
        return [_delays copy];
    }
}

- (NSUInteger)pendingCount {
    @synchronized (self) {
        return _blocks.count;
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

@interface MobaInstantCastStrategyTests : XCTestCase
@property (nonatomic, strong) MobaInstantStrategyFakeSink *sink;
@property (nonatomic, strong) MobaInstantStrategyManualScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaInstantCastStrategy *strategy;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@end

@implementation MobaInstantCastStrategyTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaInstantStrategyFakeSink alloc] init];
    self.scheduler = [[MobaInstantStrategyManualScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
    MobaInstantCastConfiguration *configuration =
        [[MobaInstantCastConfiguration alloc] initWithSkillKeyCode:70 tapDurationMs:45];
    self.strategy = [[MobaInstantCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                          configuration:configuration];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"instant dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (MobaCastTransitionResult)beginCast {
    MobaCastTransitionResult result = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy beginWithTransitionResult:result]);
    return result;
}

- (void)testBeginDoesNotSendInput {
    [self beginCast];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(self.scheduler.pendingCount, 0u);
}

- (void)testAcceptedUpdateDoesNotSendInput {
    [self beginCast];
    MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testCommittedResultEnqueuesOneConfiguredKeyTap {
    [self beginCast];
    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:70:down"]));
    XCTAssertEqualObjects(self.scheduler.scheduledDelays, (@[@45]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
}

- (void)testScheduledCallbackProducesExactlyOneConfiguredKeyUp {
    [self beginCast];
    [self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]];
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:70:down", @"key:70:up"]));
    XCTAssertEqual(self.scheduler.pendingCount, 0u);
}

- (void)testCancelledResultDoesNotTapSkillKey {
    [self beginCast];
    MobaCastTransitionResult cancelled = [self.session cancelInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:cancelled]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(self.scheduler.pendingCount, 0u);
}

- (void)testRejectedAndRepeatedTerminalResultsCannotTapAgain {
    [self beginCast];
    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertFalse([self.strategy commitWithTransitionResult:MobaCastRejectedTransitionResult(MobaCastStateCommitted)]);
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    XCTAssertFalse([self.strategy commitWithTransitionResult:committed]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:70:down"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
}

- (void)testLifecycleInterruptionDoesNotActivateInstantSkill {
    [self beginCast];
    MobaCastTransitionResult interrupted = [self.session interrupt];
    XCTAssertEqual(interrupted.terminalOutcome, MobaCastTerminalOutcomeCancelled);

    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    XCTAssertFalse([self.strategy cancelWithTransitionResult:interrupted]);
    [self drainDispatcher];

    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(self.scheduler.pendingCount, 0u);
    XCTAssertEqual(self.session.state, MobaCastStateIdle);
}

@end
