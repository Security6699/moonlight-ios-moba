//
//  MobaCursorCoalescingStrategyTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Casting/MobaDirectionalCastStrategy.h"
#import "../Limelight/Input/MOBA/Casting/MobaPointCastStrategy.h"
#import "../Limelight/Input/MOBA/Core/MobaCursorCoalescer.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

static NSValue *MobaStrategyCoalescingValueWithPoint(CGPoint point) {
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

static CGPoint MobaStrategyCoalescingPointFromValue(NSValue *value) {
    CGPoint point;
    [value getValue:&point size:sizeof(point)];
    return point;
}

@interface MobaStrategyCoalescingSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
@property (nonatomic, readonly) NSArray<NSValue *> *cursorPoints;
- (void)clear;
@end

@implementation MobaStrategyCoalescingSink {
    NSMutableArray<NSString *> *_events;
    NSMutableArray<NSValue *> *_cursorPoints;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [[NSMutableArray alloc] init];
        _cursorPoints = [[NSMutableArray alloc] init];
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
    @synchronized (self) {
        [_events addObject:@"cursor"];
        [_cursorPoints addObject:MobaStrategyCoalescingValueWithPoint(point)];
    }
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    @synchronized (self) {
        [_events addObject:[NSString stringWithFormat:@"mouse:%d:%@",
                            button,
                            down ? @"down" : @"up"]];
    }
}

- (NSArray<NSString *> *)events {
    @synchronized (self) { return [_events copy]; }
}

- (NSArray<NSValue *> *)cursorPoints {
    @synchronized (self) { return [_cursorPoints copy]; }
}

- (void)clear {
    @synchronized (self) {
        [_events removeAllObjects];
        [_cursorPoints removeAllObjects];
    }
}

@end

@interface MobaStrategyCoalescingDriver : NSObject <MobaDisplayLinkDriving>
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic) BOOL startSucceeds;
@property (nonatomic, readonly) NSUInteger startCount;
@property (nonatomic, readonly) NSUInteger stopCount;
- (void)fireCurrentTick;
- (void)fireTickAtIndex:(NSUInteger)index;
@end

@implementation MobaStrategyCoalescingDriver {
    NSMutableArray *_callbacks;
    BOOL _running;
    NSUInteger _startCount;
    NSUInteger _stopCount;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _callbacks = [[NSMutableArray alloc] init];
        _startSucceeds = YES;
    }
    return self;
}

- (BOOL)isRunning { return _running; }
- (NSUInteger)startCount { return _startCount; }
- (NSUInteger)stopCount { return _stopCount; }

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
    [_callbacks addObject:[tickHandler copy]];
    return YES;
}

- (void)stop {
    if (_running) {
        _running = NO;
        _stopCount += 1;
    }
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

@interface MobaStrategyCoalescingDispatcher : MobaInputDispatcher
@property (nonatomic) NSUInteger cursorMethodCallCount;
@property (nonatomic) NSUInteger atomicCommitCallCount;
@end

@implementation MobaStrategyCoalescingDispatcher

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    self.cursorMethodCallCount += 1;
    [super moveCursorToCanvasPoint:point];
}

- (void)commitFinalCursorPoint:(CGPoint)point releasingKeyCode:(uint16_t)keyCode {
    self.atomicCommitCallCount += 1;
    [super commitFinalCursorPoint:point releasingKeyCode:keyCode];
}

@end

@interface MobaCursorCoalescingStrategyTests : XCTestCase
@property (nonatomic, strong) MobaStrategyCoalescingSink *sink;
@property (nonatomic, strong) MobaStrategyCoalescingDispatcher *dispatcher;
@property (nonatomic, strong) MobaStrategyCoalescingDriver *driver;
@property (nonatomic, strong) MobaCursorCoalescer *coalescer;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@end

@implementation MobaCursorCoalescingStrategyTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaStrategyCoalescingSink alloc] init];
    self.dispatcher = [[MobaStrategyCoalescingDispatcher alloc] initWithSink:self.sink];
    self.driver = [[MobaStrategyCoalescingDriver alloc] init];
    self.coalescer = [[MobaCursorCoalescer alloc] initWithDispatcher:self.dispatcher
                                                              driver:self.driver];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
}

- (MobaDirectionalCastStrategy *)directionalStrategy {
    MobaDirectionalCastConfiguration *configuration =
        [MobaDirectionalCastConfiguration defaultConfigurationWithSkillKeyCode:81
                                                                     heroAnchor:CGPointMake(1000.0, 700.0)
                                                                          radii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                                                   cancelAction:[MobaCastCancelAction rightMouseAction]];
    return [[MobaDirectionalCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                     configuration:configuration
                                                   cursorCoalescer:self.coalescer];
}

- (MobaPointCastStrategy *)pointStrategyWithMode:(MobaPointCastTargetMode)mode
                                       coalescer:(id<MobaCursorCoalescing>)coalescer {
    MobaPointCastConfiguration *configuration =
        [MobaPointCastConfiguration defaultConfigurationWithTargetMode:mode
                                                           skillKeyCode:69
                                                             heroAnchor:CGPointMake(1000.0, 700.0)
                                                            wheelRadius:100.0
                                                          deadzoneRatio:0.2
                                                         fullRangeRatio:0.8
                                                          curveExponent:1.0
                                                           minimumRadii:MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0)
                                                           maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                                            cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    return [[MobaPointCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                configuration:configuration
                                              cursorCoalescer:coalescer];
}

- (MobaPointCastStrategy *)pointStrategy {
    return [self pointStrategyWithMode:MobaPointCastTargetModeGround coalescer:self.coalescer];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"strategy coalescing dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)beginStrategy:(id<MobaCastStrategy>)strategy {
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([strategy beginWithTransitionResult:begin]);
}

- (MobaCastTransitionResult)directionalUpdate:(MobaDirectionalCastStrategy *)strategy
                                    direction:(CGVector)direction
                              insideCancelZone:(BOOL)insideCancelZone {
    MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:insideCancelZone];
    XCTAssertTrue([strategy updateWithTransitionResult:update dragDirection:direction]);
    return update;
}

- (MobaCastTransitionResult)pointUpdate:(MobaPointCastStrategy *)strategy
                           displacement:(CGVector)displacement
                         meaningfulDrag:(BOOL)meaningfulDrag
                       insideCancelZone:(BOOL)insideCancelZone {
    MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:meaningfulDrag
                                                               insideCancelZone:insideCancelZone];
    XCTAssertTrue([strategy updateWithTransitionResult:update dragDisplacement:displacement]);
    return update;
}

- (void)assertLastPoint:(CGPoint)expected {
    CGPoint actual = MobaStrategyCoalescingPointFromValue(self.sink.cursorPoints.lastObject);
    XCTAssertEqualWithAccuracy(actual.x, expected.x, 0.000001);
    XCTAssertEqualWithAccuracy(actual.y, expected.y, 0.000001);
}

- (void)testDirectionalBeginKeepsDefaultCursorThenSkillDownOrder {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:down"]));
    [self assertLastPoint:CGPointMake(1000.0, 400.0)];
    XCTAssertTrue(self.driver.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

- (void)testBeginFailureToStartCoalescerSendsNoInput {
    self.driver.startSucceeds = NO;
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertFalse([strategy beginWithTransitionResult:begin]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testDirectionalUpdateWithoutTickSendsNoCursor {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertTrue(self.coalescer.hasPendingPoint);
}

- (void)testMultipleDirectionalUpdatesOneTickSendLastTarget {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    [self directionalUpdate:strategy direction:CGVectorMake(0.0, 1.0) insideCancelZone:NO];
    [self directionalUpdate:strategy direction:CGVectorMake(-1.0, 0.0) insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor"]));
    [self assertLastPoint:CGPointMake(900.0, 700.0)];
}

- (void)testDirectionalUpdateAfterTickCanSendNextTarget {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self directionalUpdate:strategy direction:CGVectorMake(0.0, 1.0) insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 2u);
    [self assertLastPoint:CGPointMake(1000.0, 1100.0)];
}

- (void)testDirectionalCommitDiscardsPendingAndOrdersFinalBeforeSkillUp {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    XCTAssertTrue([strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:up"]));
    [self assertLastPoint:CGPointMake(1200.0, 700.0)];
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    XCTAssertFalse(self.driver.isRunning);
}

- (void)testDirectionalCommitUsesOnlyDispatcherAtomicAPI {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    NSUInteger cursorCallsBeforeCommit = self.dispatcher.cursorMethodCallCount;
    XCTAssertTrue([strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 1u);
    XCTAssertEqual(self.dispatcher.cursorMethodCallCount, cursorCallsBeforeCommit);
}

- (void)testDirectionalCommitAfterTickOrdersIntermediateThenFinalThenSkillUp {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self directionalUpdate:strategy direction:CGVectorMake(0.0, 1.0) insideCancelZone:NO];
    XCTAssertTrue([strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"cursor", @"key:81:up"]));
    CGPoint intermediate = MobaStrategyCoalescingPointFromValue(self.sink.cursorPoints.firstObject);
    XCTAssertEqualWithAccuracy(intermediate.x, 1200.0, 0.000001);
    [self assertLastPoint:CGPointMake(1000.0, 1100.0)];
}

- (void)testDirectionalCommitMakesStaleTickNoOp {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    [self drainDispatcher];
    [self.sink clear];
    [strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]];
    [self drainDispatcher];
    NSArray *eventsAfterCommit = self.sink.events;
    [self.driver fireTickAtIndex:0];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, eventsAfterCommit);
}

- (void)testDirectionalCancelDiscardsPendingWithoutFinalCursor {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:YES];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([strategy cancelWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events,
                          (@[@"mouse:3:down", @"mouse:3:up", @"key:81:up"]));
    XCTAssertFalse([self.sink.events containsObject:@"cursor"]);
}

- (void)testDirectionalSilentResetStopsDriverAndDiscardsPending {
    MobaDirectionalCastStrategy *strategy = [self directionalStrategy];
    [self beginStrategy:strategy];
    [self directionalUpdate:strategy direction:CGVectorMake(1.0, 0.0) insideCancelZone:NO];
    [strategy silentReset];
    XCTAssertFalse(self.driver.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    [self.driver fireTickAtIndex:0];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 1u);
}

- (void)testPointDraggedUpdatesAreCoalesced {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self pointUpdate:strategy displacement:CGVectorMake(-80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorPoints.count, 1u);
    [self assertLastPoint:CGPointMake(900.0, 700.0)];
}

- (void)testPointBeginFailureToStartCoalescerSendsNoInput {
    self.driver.startSucceeds = NO;
    MobaPointCastStrategy *strategy = [self pointStrategy];
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertFalse([strategy beginWithTransitionResult:begin]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testPointAimingDefaultFallbackSubmitsDefaultOnNextTick {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    [self.sink clear];
    [self pointUpdate:strategy displacement:CGVectorMake(NAN, INFINITY) meaningfulDrag:NO insideCancelZone:NO];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    [self assertLastPoint:CGPointMake(1000.0, 400.0)];
}

- (void)testPointZeroResponseFallbackSubmitsDefaultOnNextTick {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    [self.sink clear];
    [self pointUpdate:strategy displacement:CGVectorMake(10.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    [self assertLastPoint:CGPointMake(1000.0, 400.0)];
}

- (void)testPointCancelArmedUpdateCreatesNoPendingPoint {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self.driver fireCurrentTick];
    XCTAssertFalse(self.coalescer.hasPendingPoint);
    MobaCastTransitionResult armed = [self pointUpdate:strategy
                                         displacement:CGVectorMake(-80.0, 0.0)
                                       meaningfulDrag:YES
                                     insideCancelZone:YES];
    XCTAssertEqual(armed.currentState, MobaCastStateCancelArmed);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

- (void)testPointExitCancelArmedToDraggedSubmitsRecomputedTarget {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:YES];
    MobaCastTransitionResult dragged = [self pointUpdate:strategy
                                           displacement:CGVectorMake(-80.0, 0.0)
                                         meaningfulDrag:YES
                                       insideCancelZone:NO];
    XCTAssertEqual(dragged.currentState, MobaCastStateAimingDragged);
    XCTAssertTrue(self.coalescer.hasPendingPoint);
    [self.driver fireCurrentTick];
    [self drainDispatcher];
    [self assertLastPoint:CGPointMake(900.0, 700.0)];
}

- (void)testPointCommitBypassesPendingWithFinalTargetAndAtomicKeyUp {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    XCTAssertTrue([strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
    [self assertLastPoint:CGPointMake(1200.0, 700.0)];
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 1u);
}

- (void)testPointCancelDiscardsPendingWithoutCursorFlush {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:YES];
    XCTAssertTrue(self.coalescer.hasPendingPoint);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([strategy cancelWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:69:up"]));
    XCTAssertFalse(self.driver.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

- (void)testPointSilentResetStopsDriverAndDiscardsPending {
    MobaPointCastStrategy *strategy = [self pointStrategy];
    [self beginStrategy:strategy];
    [self pointUpdate:strategy displacement:CGVectorMake(80.0, 0.0) meaningfulDrag:YES insideCancelZone:NO];
    [strategy silentReset];
    XCTAssertFalse(self.driver.isRunning);
    XCTAssertFalse(self.coalescer.hasPendingPoint);
}

- (void)testPointGroundAndUnitShareCoalescedDirectMapping {
    NSMutableArray<NSValue *> *targets = [[NSMutableArray alloc] init];
    for (NSNumber *modeValue in @[@(MobaPointCastTargetModeGround), @(MobaPointCastTargetModeUnit)]) {
        MobaStrategyCoalescingDriver *driver = [[MobaStrategyCoalescingDriver alloc] init];
        MobaCursorCoalescer *coalescer = [[MobaCursorCoalescer alloc]
            initWithDispatcher:self.dispatcher driver:driver];
        MobaPointCastStrategy *strategy = [self pointStrategyWithMode:modeValue.integerValue
                                                            coalescer:coalescer];
        MobaCastSession *session = [[MobaCastSession alloc] init];
        NSObject *token = [[NSObject alloc] init];
        XCTAssertTrue([strategy beginWithTransitionResult:[session beginInteractionWithToken:token]]);
        MobaCastTransitionResult update = [session updateInteractionWithToken:token
                                                               meaningfulDrag:YES
                                                              insideCancelZone:NO];
        XCTAssertTrue([strategy updateWithTransitionResult:update
                                          dragDisplacement:CGVectorMake(80.0, 0.0)]);
        [driver fireCurrentTick];
        [self drainDispatcher];
        [targets addObject:self.sink.cursorPoints.lastObject];
        [strategy silentReset];
    }
    CGPoint ground = MobaStrategyCoalescingPointFromValue(targets[0]);
    CGPoint unit = MobaStrategyCoalescingPointFromValue(targets[1]);
    XCTAssertEqualWithAccuracy(ground.x, unit.x, 0.000001);
    XCTAssertEqualWithAccuracy(ground.y, unit.y, 0.000001);
    XCTAssertEqualWithAccuracy(unit.x, 1200.0, 0.000001);
    XCTAssertEqualWithAccuracy(unit.y, 700.0, 0.000001);
}

@end
