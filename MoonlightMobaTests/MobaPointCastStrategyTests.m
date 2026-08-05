//
//  MobaPointCastStrategyTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Casting/MobaPointCastStrategy.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Geometry/MobaPointCastGeometry.h"

static const CGFloat MobaPointCastStrategyTolerance = 0.000001;

static NSValue *MobaPointStrategyValueWithPoint(CGPoint point) {
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

static CGPoint MobaPointStrategyPointFromValue(NSValue *value) {
    CGPoint point;
    [value getValue:&point size:sizeof(point)];
    return point;
}

@interface MobaPointStrategyFakeSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
@property (nonatomic, readonly) NSArray<NSValue *> *cursorPoints;
- (void)clear;
@end


@implementation MobaPointStrategyFakeSink {
    NSMutableArray<NSString *> *_recordedEvents;
    NSMutableArray<NSValue *> *_recordedCursorPoints;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordedEvents = [[NSMutableArray alloc] init];
        _recordedCursorPoints = [[NSMutableArray alloc] init];
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
        [_recordedEvents addObject:@"cursor"];
        [_recordedCursorPoints addObject:MobaPointStrategyValueWithPoint(point)];
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

- (NSArray<NSValue *> *)cursorPoints {
    @synchronized (self) {
        return [_recordedCursorPoints copy];
    }
}

- (void)clear {
    @synchronized (self) {
        [_recordedEvents removeAllObjects];
        [_recordedCursorPoints removeAllObjects];
    }
}

@end

@interface MobaPointStrategyManualScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSArray<NSNumber *> *scheduledDelays;
- (void)runAll;
@end

@implementation MobaPointStrategyManualScheduler {
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

@interface MobaPointStrategyObservingDispatcher : MobaInputDispatcher
@property (nonatomic) NSUInteger cursorMethodCallCount;
@property (nonatomic) NSUInteger keyMethodCallCount;
@property (nonatomic) NSUInteger atomicCommitCallCount;
@end

@implementation MobaPointStrategyObservingDispatcher

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    self.cursorMethodCallCount += 1;
    [super moveCursorToCanvasPoint:point];
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    self.keyMethodCallCount += 1;
    [super setKeyCode:keyCode down:down];
}

- (void)commitFinalCursorPoint:(CGPoint)point releasingKeyCode:(uint16_t)keyCode {
    self.atomicCommitCallCount += 1;
    [super commitFinalCursorPoint:point releasingKeyCode:keyCode];
}

@end

@interface MobaPointCastStrategyTests : XCTestCase
@property (nonatomic, strong) MobaPointStrategyFakeSink *sink;
@property (nonatomic, strong) MobaPointStrategyManualScheduler *scheduler;
@property (nonatomic, strong) MobaPointStrategyObservingDispatcher *dispatcher;
@property (nonatomic, strong) MobaPointCastStrategy *strategy;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@end

@implementation MobaPointCastStrategyTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaPointStrategyFakeSink alloc] init];
    self.scheduler = [[MobaPointStrategyManualScheduler alloc] init];
    self.dispatcher = [[MobaPointStrategyObservingDispatcher alloc] initWithSink:self.sink
                                                                       scheduler:self.scheduler];
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeGround
                                    anchor:CGPointMake(1000.0, 700.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                              cancelAction:[MobaCastCancelAction keyboardActionWithKeyCode:27 durationMs:40]];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
}

- (MobaPointCastConfiguration *)configurationWithMode:(MobaPointCastTargetMode)mode
                                               anchor:(CGPoint)anchor
                                     defaultDirection:(CGVector)defaultDirection
                                 defaultDistanceRatio:(CGFloat)defaultDistanceRatio
                                          wheelRadius:(CGFloat)wheelRadius
                                        deadzoneRatio:(CGFloat)deadzoneRatio
                                       fullRangeRatio:(CGFloat)fullRangeRatio
                                        curveExponent:(CGFloat)curveExponent
                                         minimumRadii:(MobaAimRadii)minimumRadii
                                         maximumRadii:(MobaAimRadii)maximumRadii
                                          cancelAction:(MobaCastCancelAction *)cancelAction {
    return [[MobaPointCastConfiguration alloc] initWithTargetMode:mode
                                                     skillKeyCode:69
                                                       heroAnchor:anchor
                                                 defaultDirection:defaultDirection
                                             defaultDistanceRatio:defaultDistanceRatio
                                                      wheelRadius:wheelRadius
                                                    deadzoneRatio:deadzoneRatio
                                                   fullRangeRatio:fullRangeRatio
                                                    curveExponent:curveExponent
                                                     minimumRadii:minimumRadii
                                                     maximumRadii:maximumRadii
                                                      cancelAction:cancelAction];
}

- (MobaPointCastStrategy *)strategyWithMode:(MobaPointCastTargetMode)mode
                                      anchor:(CGPoint)anchor
                                    exponent:(CGFloat)exponent
                                maximumRadii:(MobaAimRadii)maximumRadii
                                cancelAction:(MobaCastCancelAction *)cancelAction {
    MobaPointCastConfiguration *configuration =
        [MobaPointCastConfiguration defaultConfigurationWithTargetMode:mode
                                                           skillKeyCode:69
                                                             heroAnchor:anchor
                                                            wheelRadius:100.0
                                                          deadzoneRatio:0.2
                                                         fullRangeRatio:0.8
                                                          curveExponent:exponent
                                                           minimumRadii:MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0)
                                                           maximumRadii:maximumRadii
                                                            cancelAction:cancelAction];
    XCTAssertNotNil(configuration);
    return [[MobaPointCastStrategy alloc] initWithDispatcher:self.dispatcher
                                               configuration:configuration];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"point dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)assertPoint:(CGPoint)point equals:(CGPoint)expected {
    XCTAssertEqualWithAccuracy(point.x, expected.x, MobaPointCastStrategyTolerance);
    XCTAssertEqualWithAccuracy(point.y, expected.y, MobaPointCastStrategyTolerance);
}

- (MobaCastTransitionResult)beginCast {
    MobaCastTransitionResult result = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy beginWithTransitionResult:result]);
    return result;
}

- (MobaCastTransitionResult)sessionUpdateWithMeaningfulDrag:(BOOL)meaningful
                                           insideCancelZone:(BOOL)insideCancelZone {
    return [self.session updateInteractionWithToken:self.token
                                     meaningfulDrag:meaningful
                                    insideCancelZone:insideCancelZone];
}

- (MobaCastTransitionResult)sessionUpdateWithMeaningfulDrag:(BOOL)meaningful {
    return [self sessionUpdateWithMeaningfulDrag:meaningful insideCancelZone:NO];
}

- (void)resetAfterActiveCast {
    [self.session interrupt];
    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    [self drainDispatcher];
    [self.sink clear];
}

- (void)testGroundBeginSendsDefaultCursorBeforeSkillKeyDown {
    [self beginCast];
    [self drainDispatcher];
    XCTAssertEqual(self.strategy.targetMode, MobaPointCastTargetModeGround);
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:down"]));
    [self assertPoint:MobaPointStrategyPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 400.0)];
}

- (void)testNoDragCommitUsesDefaultUpMaximumTarget {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
    [self assertPoint:MobaPointStrategyPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 400.0)];
}

- (void)testDefaultDistanceRatioUsesGeometryClamp {
    MobaPointCastConfiguration *aboveMaximum =
        [self configurationWithMode:MobaPointCastTargetModeGround
                             anchor:CGPointMake(1000.0, 700.0)
                   defaultDirection:CGVectorMake(1.0, 0.0)
               defaultDistanceRatio:2.0
                        wheelRadius:100.0
                      deadzoneRatio:0.2
                     fullRangeRatio:0.8
                      curveExponent:1.0
                       minimumRadii:MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0)
                       maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                        cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    self.strategy = [[MobaPointCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                        configuration:aboveMaximum];
    [self beginCast];
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
    [self resetAfterActiveCast];

    MobaPointCastConfiguration *belowMinimum =
        [self configurationWithMode:MobaPointCastTargetModeGround
                             anchor:CGPointMake(1000.0, 700.0)
                   defaultDirection:CGVectorMake(1.0, 0.0)
               defaultDistanceRatio:-2.0
                        wheelRadius:100.0
                      deadzoneRatio:0.2
                     fullRangeRatio:0.8
                      curveExponent:1.0
                       minimumRadii:MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0)
                       maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                        cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    self.strategy = [[MobaPointCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                        configuration:belowMinimum];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
    [self beginCast];
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 700.0)];
}

- (void)testNonMeaningfulMicroMovementDoesNotReplaceDefaultTarget {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(5.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
    XCTAssertTrue([self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    [self assertPoint:MobaPointStrategyPointFromValue(self.sink.cursorPoints.lastObject)
               equals:CGPointMake(1000.0, 400.0)];
}

- (void)testDeadzoneResponseDoesNotReplaceDefaultTarget {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(10.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
}

- (void)testDeadzoneBoundaryDoesNotReplaceDefaultTarget {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(20.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
}

- (void)testMeaningfulDragReturningToAimingDefaultCommitsDefaultTarget {
    [self beginCast];
    MobaCastTransitionResult dragged = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
    [self drainDispatcher];
    [self.sink clear];

    MobaCastTransitionResult returnedToDefault = [self sessionUpdateWithMeaningfulDrag:NO];
    XCTAssertEqual(returnedToDefault.currentState, MobaCastStateAimingDefault);
    XCTAssertTrue([self.strategy updateWithTransitionResult:returnedToDefault
                                           dragDisplacement:CGVectorMake(NAN, INFINITY)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);

    XCTAssertTrue([self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
    [self assertPoint:MobaPointStrategyPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 400.0)];
}

- (void)testMeaningfulDragWhoseResponseReturnsToDeadzoneRestoresDefaultTarget {
    [self beginCast];
    MobaCastTransitionResult dragged = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];

    MobaCastTransitionResult stillDragged = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertEqual(stillDragged.currentState, MobaCastStateAimingDragged);
    XCTAssertTrue([self.strategy updateWithTransitionResult:stillDragged
                                           dragDisplacement:CGVectorMake(10.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
}

- (void)testCancelArmedExitToAimingDefaultRestoresDefaultTarget {
    [self beginCast];
    MobaCastTransitionResult dragged = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);

    MobaCastTransitionResult cancelArmed =
        [self sessionUpdateWithMeaningfulDrag:YES insideCancelZone:YES];
    XCTAssertEqual(cancelArmed.currentState, MobaCastStateCancelArmed);
    XCTAssertTrue([self.strategy updateWithTransitionResult:cancelArmed
                                           dragDisplacement:CGVectorMake(-80.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];

    MobaCastTransitionResult returnedToDefault =
        [self sessionUpdateWithMeaningfulDrag:NO insideCancelZone:NO];
    XCTAssertEqual(returnedToDefault.currentState, MobaCastStateAimingDefault);
    XCTAssertTrue([self.strategy updateWithTransitionResult:returnedToDefault
                                           dragDisplacement:CGVectorMake(-80.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
}

- (void)testCancelArmedExitToAimingDraggedUsesCurrentDisplacementWithoutInput {
    [self beginCast];
    MobaCastTransitionResult dragged = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);
    [self drainDispatcher];
    [self.sink clear];

    MobaCastTransitionResult cancelArmed =
        [self sessionUpdateWithMeaningfulDrag:YES insideCancelZone:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:cancelArmed
                                           dragDisplacement:CGVectorMake(0.0, 80.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];

    MobaCastTransitionResult returnedToDragged =
        [self sessionUpdateWithMeaningfulDrag:YES insideCancelZone:NO];
    XCTAssertEqual(returnedToDragged.currentState, MobaCastStateAimingDragged);
    XCTAssertTrue([self.strategy updateWithTransitionResult:returnedToDragged
                                           dragDisplacement:CGVectorMake(-80.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(900.0, 700.0)];
    XCTAssertTrue(self.session.activeInteractionToken == self.token);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testGroundAndUnitModesShareDefaultFallbackSemantics {
    NSArray<NSNumber *> *modes = @[@(MobaPointCastTargetModeGround),
                                    @(MobaPointCastTargetModeUnit)];
    for (NSNumber *modeValue in modes) {
        self.strategy = [self strategyWithMode:modeValue.integerValue
                                        anchor:CGPointMake(500.0, 600.0)
                                      exponent:1.0
                                  maximumRadii:MobaAimRadiiMake(50.0, 150.0, 100.0, 200.0)
                                  cancelAction:[MobaCastCancelAction releaseOnlyAction]];
        self.session = [[MobaCastSession alloc] init];
        self.token = [[NSObject alloc] init];
        [self beginCast];
        MobaCastTransitionResult dragged = [self sessionUpdateWithMeaningfulDrag:YES];
        XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                               dragDisplacement:CGVectorMake(80.0, 0.0)]);
        [self assertPoint:self.strategy.latestTarget equals:CGPointMake(650.0, 600.0)];
        MobaCastTransitionResult returnedToDefault = [self sessionUpdateWithMeaningfulDrag:NO];
        XCTAssertTrue([self.strategy updateWithTransitionResult:returnedToDefault
                                               dragDisplacement:CGVectorMake(0.0, 0.0)]);
        [self assertPoint:self.strategy.latestTarget equals:CGPointMake(500.0, 500.0)];
        [self resetAfterActiveCast];
    }
}

- (void)testDefaultAndDeadzoneFallbackUpdatesDoNotCallDispatcher {
    [self beginCast];
    MobaCastTransitionResult dragged = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);
    NSUInteger cursorCallsAfterBegin = self.dispatcher.cursorMethodCallCount;
    NSUInteger keyCallsAfterBegin = self.dispatcher.keyMethodCallCount;

    MobaCastTransitionResult deadzone = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:deadzone
                                           dragDisplacement:CGVectorMake(10.0, 0.0)]);
    MobaCastTransitionResult defaultState = [self sessionUpdateWithMeaningfulDrag:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:defaultState
                                           dragDisplacement:CGVectorMake(0.0, 0.0)]);
    XCTAssertEqual(self.dispatcher.cursorMethodCallCount, cursorCallsAfterBegin);
    XCTAssertEqual(self.dispatcher.keyMethodCallCount, keyCallsAfterBegin);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 0u);
}

- (void)testFullRangeThresholdProducesMaximumTarget {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
}

- (void)testBeyondFullRangeRemainsAtMaximumTarget {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(150.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
}

- (void)testResponseExponentsProduceLinearSlowerAndFasterTargets {
    NSArray<NSNumber *> *exponents = @[@1.0, @2.0, @0.5];
    NSArray<NSNumber *> *expectedX = @[@1100.0, @1050.0, @(1000.0 + 200.0 * sqrt(0.5))];
    for (NSUInteger index = 0; index < exponents.count; index++) {
        self.strategy = [self strategyWithMode:MobaPointCastTargetModeGround
                                        anchor:CGPointMake(1000.0, 700.0)
                                      exponent:exponents[index].doubleValue
                                  maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                  cancelAction:[MobaCastCancelAction releaseOnlyAction]];
        self.session = [[MobaCastSession alloc] init];
        self.token = [[NSObject alloc] init];
        [self beginCast];
        MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
        XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                               dragDisplacement:CGVectorMake(50.0, 0.0)]);
        XCTAssertEqualWithAccuracy(self.strategy.latestTarget.x,
                                   expectedX[index].doubleValue,
                                   MobaPointCastStrategyTolerance);
        [self resetAfterActiveCast];
    }
}

- (void)testUpdateOnlyChangesLatestTargetWithoutSendingCursor {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(-80.0, 0.0)]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(900.0, 700.0)];
}

- (void)testCommitUsesLastValidTargetWithStrictCursorThenKeyUpOrder {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    [self.strategy updateWithTransitionResult:update dragDisplacement:CGVectorMake(0.0, 80.0)];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
    [self assertPoint:MobaPointStrategyPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 1100.0)];
}

- (void)testCommitUsesOnlyAtomicDispatcherAPI {
    [self beginCast];
    XCTAssertEqual(self.dispatcher.cursorMethodCallCount, 1u);
    XCTAssertEqual(self.dispatcher.keyMethodCallCount, 1u);
    XCTAssertTrue([self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 1u);
    XCTAssertEqual(self.dispatcher.cursorMethodCallCount, 1u);
    XCTAssertEqual(self.dispatcher.keyMethodCallCount, 1u);
}

- (void)testInvalidDisplacementsAreRejectedAndPreserveLatestTarget {
    [self beginCast];
    CGVector invalid[] = {
        CGVectorMake(0.0, 0.0),
        CGVectorMake(NAN, 1.0),
        CGVectorMake(1.0, INFINITY),
    };
    for (NSUInteger index = 0; index < 3; index++) {
        MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
        XCTAssertFalse([self.strategy updateWithTransitionResult:update dragDisplacement:invalid[index]]);
        [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1000.0, 400.0)];
    }
}

- (MobaCastTransitionResult)cancelArmedReleaseResult {
    [self.session updateInteractionWithToken:self.token
                              meaningfulDrag:YES
                             insideCancelZone:YES];
    return [self.session releaseInteractionWithToken:self.token];
}

- (void)testKeyboardCancellationPrecedesSkillUpAndScheduledCancelUp {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:27:down", @"key:69:up"]));
    XCTAssertEqualObjects(self.scheduler.scheduledDelays, (@[@40]));
    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events,
                          (@[@"key:27:down", @"key:69:up", @"key:27:up"]));
}

- (void)testRightMouseCancellationPrecedesSkillUp {
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeGround
                                    anchor:CGPointMake(1000.0, 700.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                              cancelAction:[MobaCastCancelAction rightMouseAction]];
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events,
                          (@[@"mouse:3:down", @"mouse:3:up", @"key:69:up"]));
}

- (void)testReleaseOnlyCancellationSendsOnlySkillUp {
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeGround
                                    anchor:CGPointMake(1000.0, 700.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                              cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:69:up"]));
}

- (void)testCancellationDoesNotSubmitFinalCursor {
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    [self.strategy updateWithTransitionResult:update dragDisplacement:CGVectorMake(80.0, 0.0)];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];
    XCTAssertFalse([self.sink.events containsObject:@"cursor"]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 0u);
}

- (void)testLifecycleReleaseAllReleasesSkillOnceAndSilentResetsDoNotRepeat {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    [self.session interrupt];
    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    [self drainDispatcher];
    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:69:up"]));
    XCTAssertFalse(self.strategy.hasLatestTarget);
}

- (void)testUnitModeUsesDirectConfiguredCursorMapping {
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeUnit
                                    anchor:CGPointMake(500.0, 600.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(50.0, 150.0, 100.0, 200.0)
                              cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(0.0, 80.0)]);
    XCTAssertEqual(self.strategy.targetMode, MobaPointCastTargetModeUnit);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(500.0, 800.0)];
}

- (void)testUnitBeginUpdateCommitOrderingMatchesGround {
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeUnit
                                    anchor:CGPointMake(500.0, 600.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(50.0, 150.0, 100.0, 200.0)
                              cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginCast];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:down"]));
    [self.sink clear];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    [self.strategy updateWithTransitionResult:update dragDisplacement:CGVectorMake(80.0, 0.0)];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    [self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
}

- (void)testUnitModeDoesNotSnapAndEqualsPureGeometryResult {
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeUnit
                                    anchor:CGPointMake(500.0, 600.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(50.0, 150.0, 100.0, 200.0)
                              cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginCast];
    CGVector displacement = CGVectorMake(60.0, -45.0);
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update dragDisplacement:displacement]);
    CGPoint expected = CGPointZero;
    XCTAssertTrue(MobaPointCastTargetForDirection(CGPointMake(500.0, 600.0), displacement,
                                                  MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0),
                                                  MobaAimRadiiMake(50.0, 150.0, 100.0, 200.0),
                                                  (75.0 / 100.0 - 0.2) / 0.6,
                                                  &expected));
    [self assertPoint:self.strategy.latestTarget equals:expected];
}

- (void)testUnitModeAddsNoLegalityCheckOrFallbackInput {
    self.strategy = [self strategyWithMode:MobaPointCastTargetModeUnit
                                    anchor:CGPointMake(2500.0, 1400.0)
                                  exponent:1.0
                              maximumRadii:MobaAimRadiiMake(100.0, 200.0, 100.0, 200.0)
                              cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginCast];
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    [self.strategy updateWithTransitionResult:update dragDisplacement:CGVectorMake(80.0, 0.0)];
    [self drainDispatcher];
    [self.sink clear];
    [self.strategy commitWithTransitionResult:[self.session releaseInteractionWithToken:self.token]];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
    [self assertPoint:MobaPointStrategyPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(2700.0, 1400.0)];
}

- (void)testAcceptedSessionPhasesDriveOnceAndExplicitResetAllowsNextToken {
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy beginWithTransitionResult:begin]);
    MobaCastTransitionResult update = [self sessionUpdateWithMeaningfulDrag:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                           dragDisplacement:CGVectorMake(80.0, 0.0)]);
    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    XCTAssertFalse([self.strategy commitWithTransitionResult:committed]);

    NSObject *nextToken = [[NSObject alloc] init];
    XCTAssertFalse([self.session beginInteractionWithToken:nextToken].accepted);
    [self.session silentReset];
    MobaCastTransitionResult nextBegin = [self.session beginInteractionWithToken:nextToken];
    XCTAssertTrue(nextBegin.accepted);
    XCTAssertTrue([self.strategy beginWithTransitionResult:nextBegin]);
}

- (void)testCancelledAndCommittedTerminalResultsCannotUseWrongPath {
    [self beginCast];
    MobaCastTransitionResult cancelled = [self cancelArmedReleaseResult];
    XCTAssertFalse([self.strategy commitWithTransitionResult:cancelled]);
    XCTAssertTrue([self.strategy cancelWithTransitionResult:cancelled]);
    [self.session silentReset];

    NSObject *next = [[NSObject alloc] init];
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:next];
    XCTAssertTrue([self.strategy beginWithTransitionResult:begin]);
    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:next];
    XCTAssertFalse([self.strategy cancelWithTransitionResult:committed]);
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
}

- (void)testDuplicateBeginAndRepeatedTerminalDoNotDuplicateInput {
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy beginWithTransitionResult:begin]);
    MobaCastTransitionResult duplicate = [self.session beginInteractionWithToken:[[NSObject alloc] init]];
    XCTAssertFalse([self.strategy beginWithTransitionResult:duplicate]);
    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    XCTAssertFalse([self.strategy commitWithTransitionResult:committed]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events,
                          (@[@"cursor", @"key:69:down", @"cursor", @"key:69:up"]));
}

- (void)testTwoPointStrategiesDoNotShareModeConfigurationOrLatestTarget {
    MobaPointCastStrategy *unit = [self strategyWithMode:MobaPointCastTargetModeUnit
                                                  anchor:CGPointMake(300.0, 400.0)
                                                exponent:1.0
                                            maximumRadii:MobaAimRadiiMake(10.0, 20.0, 30.0, 40.0)
                                            cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    MobaCastSession *unitSession = [[MobaCastSession alloc] init];
    NSObject *unitToken = [[NSObject alloc] init];
    [self beginCast];
    XCTAssertTrue([unit beginWithTransitionResult:[unitSession beginInteractionWithToken:unitToken]]);
    MobaCastTransitionResult groundUpdate = [self sessionUpdateWithMeaningfulDrag:YES];
    [self.strategy updateWithTransitionResult:groundUpdate dragDisplacement:CGVectorMake(80.0, 0.0)];
    MobaCastTransitionResult unitUpdate = [unitSession updateInteractionWithToken:unitToken
                                                                    meaningfulDrag:YES
                                                                   insideCancelZone:NO];
    [unit updateWithTransitionResult:unitUpdate dragDisplacement:CGVectorMake(-80.0, 0.0)];

    XCTAssertEqual(self.strategy.targetMode, MobaPointCastTargetModeGround);
    XCTAssertEqual(unit.targetMode, MobaPointCastTargetModeUnit);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
    [self assertPoint:unit.latestTarget equals:CGPointMake(290.0, 400.0)];
}

- (void)testInvalidPointConfigurationsFailInitialization {
    MobaAimRadii minimum = MobaAimRadiiMake(0.0, 1.0, 2.0, 3.0);
    MobaAimRadii maximum = MobaAimRadiiMake(10.0, 20.0, 30.0, 40.0);
    MobaCastCancelAction *cancel = [MobaCastCancelAction releaseOnlyAction];

    XCTAssertNil([self configurationWithMode:(MobaPointCastTargetMode)99 anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointMake(NAN, 0.0)
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, 0.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(INFINITY, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:NAN
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:0.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:-0.1 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.8 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:0.0
                                 minimumRadii:minimum maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:MobaAimRadiiMake(-1.0, 1.0, 2.0, 3.0)
                                 maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum
                                 maximumRadii:MobaAimRadiiMake(10.0, 0.0, 30.0, 40.0) cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                  minimumRadii:MobaAimRadiiMake(0.0, 21.0, 2.0, 3.0)
                                  maximumRadii:maximum cancelAction:cancel]);
    XCTAssertNil([self configurationWithMode:MobaPointCastTargetModeGround anchor:CGPointZero
                             defaultDirection:CGVectorMake(0.0, -1.0) defaultDistanceRatio:1.0
                                  wheelRadius:100.0 deadzoneRatio:0.2 fullRangeRatio:0.8 curveExponent:1.0
                                 minimumRadii:minimum maximumRadii:maximum
                                  cancelAction:(MobaCastCancelAction *)nil]);
}

@end
