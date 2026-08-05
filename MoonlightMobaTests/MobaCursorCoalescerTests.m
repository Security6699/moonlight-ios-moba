//
//  MobaCursorCoalescerTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Core/MobaCursorCoalescer.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

static NSValue *MobaCoalescerValueWithPoint(CGPoint point) {
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

static CGPoint MobaCoalescerPointFromValue(NSValue *value) {
    CGPoint point;
    [value getValue:&point size:sizeof(point)];
    return point;
}

@interface MobaCoalescerFakeSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSValue *> *cursorPoints;
@end

@implementation MobaCoalescerFakeSink {
    NSMutableArray<NSValue *> *_cursorPoints;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cursorPoints = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {}
- (void)sendMouseButton:(int)button down:(BOOL)down {}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    @synchronized (self) {
        [_cursorPoints addObject:MobaCoalescerValueWithPoint(point)];
    }
}

- (NSArray<NSValue *> *)cursorPoints {
    @synchronized (self) {
        return [_cursorPoints copy];
    }
}

@end

@interface MobaCoalescerFakeDriver : NSObject <MobaDisplayLinkDriving>
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) NSUInteger startCount;
@property (nonatomic, readonly) NSUInteger stopCount;
@property (nonatomic, readonly) NSArray<NSNumber *> *rates;
@property (nonatomic) BOOL startSucceeds;
- (void)fireCurrentTick;
- (void)fireTickAtIndex:(NSUInteger)index;
@end

@implementation MobaCoalescerFakeDriver {
    NSMutableArray *_callbacks;
    NSMutableArray<NSNumber *> *_rates;
    BOOL _running;
    NSUInteger _startCount;
    NSUInteger _stopCount;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _callbacks = [[NSMutableArray alloc] init];
        _rates = [[NSMutableArray alloc] init];
        _startSucceeds = YES;
    }
    return self;
}

- (BOOL)isRunning { return _running; }
- (NSUInteger)startCount { return _startCount; }
- (NSUInteger)stopCount { return _stopCount; }
- (NSArray<NSNumber *> *)rates { return [_rates copy]; }

- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate
                tickHandler:(MobaDisplayLinkTickHandler)tickHandler {
    if (!_startSucceeds) {
        return NO;
    }
    if (_running) {
        return YES;
    }
    _running = YES;
    _startCount += 1;
    [_rates addObject:@(updateRate)];
    [_callbacks addObject:[tickHandler copy]];
    return YES;
}

- (void)stop {
    if (!_running) {
        return;
    }
    _running = NO;
    _stopCount += 1;
}

- (void)fireCurrentTick {
    MobaDisplayLinkTickHandler callback = _callbacks.lastObject;
    if (callback != nil) {
        callback();
    }
}

- (void)fireTickAtIndex:(NSUInteger)index {
    if (index < _callbacks.count) {
        MobaDisplayLinkTickHandler callback = _callbacks[index];
        callback();
    }
}

@end

@interface MobaCursorCoalescerTests : XCTestCase
@property (nonatomic, strong) MobaCoalescerFakeSink *sink;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaCoalescerFakeDriver *driver;
@property (nonatomic, strong) MobaCursorCoalescer *coalescer;
@end

@implementation MobaCursorCoalescerTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaCoalescerFakeSink alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink];
    self.driver = [[MobaCoalescerFakeDriver alloc] init];
    self.coalescer = [[MobaCursorCoalescer alloc] initWithDispatcher:self.dispatcher
                                                              driver:self.driver];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"coalescer dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)assertOnlyPoint:(CGPoint)expected {
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 1u);
    CGPoint actual = MobaCoalescerPointFromValue(self.sink.cursorPoints.firstObject);
    XCTAssertEqualWithAccuracy(actual.x, expected.x, 0.000001);
    XCTAssertEqualWithAccuracy(actual.y, expected.y, 0.000001);
}

- (void)testStartHasNoPendingPoint {
    XCTAssertTrue([self.coalescer start]);
    XCTAssertTrue(self.coalescer.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    XCTAssertEqual(self.sink.cursorPoints.count, 0u);
}

- (void)testSubmitDoesNotImmediatelyDispatchCursor {
    [self.coalescer start];
    XCTAssertTrue([self.coalescer submitLatestPoint:CGPointMake(1.0, 2.0)]);
    [self drainDispatcher];
    XCTAssertTrue(self.coalescer.hasPendingPoint);
    XCTAssertEqual(self.sink.cursorPoints.count, 0u);
}

- (void)testThreeSubmissionsBeforeTickSendOnlyLatestPoint {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(1.0, 1.0)];
    [self.coalescer submitLatestPoint:CGPointMake(2.0, 2.0)];
    [self.coalescer submitLatestPoint:CGPointMake(3.0, 3.0)];
    [self.driver fireCurrentTick];
    [self assertOnlyPoint:CGPointMake(3.0, 3.0)];
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

- (void)testMultipleTicksAfterOneSubmitSendOnlyOnce {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(4.0, 5.0)];
    [self.driver fireCurrentTick];
    [self.driver fireCurrentTick];
    [self.driver fireCurrentTick];
    [self assertOnlyPoint:CGPointMake(4.0, 5.0)];
}

- (void)testNewSubmitAfterTickSendsOnNextTick {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(1.0, 1.0)];
    [self.driver fireCurrentTick];
    [self.coalescer submitLatestPoint:CGPointMake(8.0, 9.0)];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 2u);
    CGPoint second = MobaCoalescerPointFromValue(self.sink.cursorPoints.lastObject);
    XCTAssertEqualWithAccuracy(second.x, 8.0, 0.000001);
    XCTAssertEqualWithAccuracy(second.y, 9.0, 0.000001);
}

- (void)testIdenticalPointResubmissionIsNewDirtyInput {
    CGPoint point = CGPointMake(10.0, 20.0);
    [self.coalescer start];
    [self.coalescer submitLatestPoint:point];
    [self.driver fireCurrentTick];
    [self.coalescer submitLatestPoint:point];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 2u);
}

- (void)testNonFiniteSubmissionIsRejectedAndPreservesPendingPoint {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(7.0, 8.0)];
    XCTAssertFalse([self.coalescer submitLatestPoint:CGPointMake(NAN, 1.0)]);
    XCTAssertFalse([self.coalescer submitLatestPoint:CGPointMake(1.0, INFINITY)]);
    XCTAssertTrue(self.coalescer.hasPendingPoint);
    [self.driver fireCurrentTick];
    [self assertOnlyPoint:CGPointMake(7.0, 8.0)];
}

- (void)testStopDiscardsPendingPoint {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(1.0, 2.0)];
    [self.coalescer stopAndDiscardPending];
    XCTAssertFalse(self.coalescer.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

- (void)testTickAfterStopSendsNothing {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(1.0, 2.0)];
    [self.coalescer stopAndDiscardPending];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 0u);
}

- (void)testRepeatedStopIsIdempotent {
    [self.coalescer start];
    [self.coalescer stopAndDiscardPending];
    [self.coalescer stopAndDiscardPending];
    XCTAssertEqual(self.driver.stopCount, 1u);
}

- (void)testRestartDoesNotRestoreOldPendingPoint {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(1.0, 2.0)];
    [self.coalescer stopAndDiscardPending];
    XCTAssertTrue([self.coalescer start]);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 0u);
}

- (void)testStaleGenerationCannotSendOrClearNewPendingPoint {
    [self.coalescer start];
    [self.coalescer stopAndDiscardPending];
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(30.0, 40.0)];
    [self.driver fireTickAtIndex:0];
    XCTAssertTrue(self.coalescer.hasPendingPoint);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 0u);
    [self.driver fireTickAtIndex:1];
    [self assertOnlyPoint:CGPointMake(30.0, 40.0)];
}

- (void)testSupportedRatesReachDriver {
    for (NSNumber *rateValue in @[@30, @60, @120]) {
        MobaCoalescerFakeDriver *driver = [[MobaCoalescerFakeDriver alloc] init];
        MobaCursorCoalescer *coalescer = [[MobaCursorCoalescer alloc]
            initWithDispatcher:self.dispatcher
                         driver:driver
                     updateRate:(MobaCursorUpdateRate)rateValue.unsignedIntegerValue];
        XCTAssertNotNil(coalescer);
        XCTAssertTrue([coalescer start]);
        XCTAssertEqualObjects(driver.rates, (@[rateValue]));
        [coalescer stopAndDiscardPending];
    }
}

- (void)testDefaultRateIs60Hz {
    XCTAssertEqual(self.coalescer.updateRate, MobaCursorUpdateRate60Hz);
    [self.coalescer start];
    XCTAssertEqualObjects(self.driver.rates, (@[@60]));
}

- (void)testInvalidRateFailsInitialization {
    for (NSNumber *rateValue in @[@0, @29, @31, @59, @61, @119, @121]) {
        XCTAssertNil([[MobaCursorCoalescer alloc]
            initWithDispatcher:self.dispatcher
                         driver:self.driver
                     updateRate:(MobaCursorUpdateRate)rateValue.unsignedIntegerValue]);
    }
}

- (void)testDisabledStateRejectsStartAndSubmit {
    [self.coalescer setMobaLocalInteractionEnabled:NO];
    XCTAssertFalse([self.coalescer start]);
    XCTAssertFalse([self.coalescer submitLatestPoint:CGPointMake(1.0, 2.0)]);
    XCTAssertFalse(self.coalescer.isRunning);
}

- (void)testReenableAllowsFutureStartWithoutAutomaticRestart {
    [self.coalescer start];
    [self.coalescer submitLatestPoint:CGPointMake(1.0, 2.0)];
    [self.coalescer setMobaLocalInteractionEnabled:NO];
    [self.coalescer setMobaLocalInteractionEnabled:YES];
    XCTAssertFalse(self.coalescer.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    XCTAssertEqual(self.driver.startCount, 1u);
    XCTAssertTrue([self.coalescer start]);
    XCTAssertEqual(self.driver.startCount, 2u);
}

@end
