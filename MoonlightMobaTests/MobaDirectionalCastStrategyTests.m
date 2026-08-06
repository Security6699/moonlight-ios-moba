//
//  MobaDirectionalCastStrategyTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import <math.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Casting/MobaDirectionalCastStrategy.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

static const CGFloat MobaDirectionalStrategyTolerance = 0.000001;

static NSValue *MobaDirectionalValueWithPoint(CGPoint point) {
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

static CGPoint MobaDirectionalPointFromValue(NSValue *value) {
    CGPoint point;
    [value getValue:&point size:sizeof(point)];
    return point;
}

static NSValue *MobaDirectionalValueWithVector(CGVector vector) {
    return [NSValue valueWithBytes:&vector objCType:@encode(CGVector)];
}

static CGVector MobaDirectionalVectorFromValue(NSValue *value) {
    CGVector vector;
    [value getValue:&vector size:sizeof(vector)];
    return vector;
}

@interface MobaDirectionalStrategyFakeSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
@property (nonatomic, readonly) NSArray<NSValue *> *cursorPoints;
- (void)clear;
@end

@implementation MobaDirectionalStrategyFakeSink {
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
        [_recordedCursorPoints addObject:MobaDirectionalValueWithPoint(point)];
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

@interface MobaDirectionalStrategyManualScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSArray<NSNumber *> *scheduledDelays;
@property (nonatomic, readonly) NSUInteger pendingCount;
- (void)runAll;
@end

@implementation MobaDirectionalStrategyManualScheduler {
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

@interface MobaDirectionalStrategyObservingDispatcher : MobaInputDispatcher
@property (nonatomic) NSUInteger cursorMethodCallCount;
@property (nonatomic) NSUInteger keyMethodCallCount;
@property (nonatomic) NSUInteger atomicCommitCallCount;
@end

@implementation MobaDirectionalStrategyObservingDispatcher

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

@interface MobaDirectionalCastStrategyTests : XCTestCase
@property (nonatomic, strong) MobaDirectionalStrategyFakeSink *sink;
@property (nonatomic, strong) MobaDirectionalStrategyManualScheduler *scheduler;
@property (nonatomic, strong) MobaDirectionalStrategyObservingDispatcher *dispatcher;
@property (nonatomic, strong) MobaDirectionalCastStrategy *strategy;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@end

@implementation MobaDirectionalCastStrategyTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaDirectionalStrategyFakeSink alloc] init];
    self.scheduler = [[MobaDirectionalStrategyManualScheduler alloc] init];
    self.dispatcher = [[MobaDirectionalStrategyObservingDispatcher alloc] initWithSink:self.sink
                                                                             scheduler:self.scheduler];
    self.strategy = [self strategyWithSkillKeyCode:81
                                            anchor:CGPointMake(1000.0, 700.0)
                                             radii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                      cancelAction:[MobaCastCancelAction keyboardActionWithKeyCode:27 durationMs:40]];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
}

- (MobaDirectionalCastStrategy *)strategyWithSkillKeyCode:(uint16_t)skillKeyCode
                                                    anchor:(CGPoint)anchor
                                                     radii:(MobaAimRadii)radii
                                              cancelAction:(MobaCastCancelAction *)cancelAction {
    MobaDirectionalCastConfiguration *configuration =
        [MobaDirectionalCastConfiguration defaultConfigurationWithSkillKeyCode:skillKeyCode
                                                                     heroAnchor:anchor
                                                                          radii:radii
                                                                   cancelAction:cancelAction];
    XCTAssertNotNil(configuration);
    return [[MobaDirectionalCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                     configuration:configuration];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"directional dispatcher idle"];
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

- (MobaCastTransitionResult)updateCastInDirection:(CGVector)direction {
    MobaCastTransitionResult result = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:result dragDirection:direction]);
    return result;
}

- (void)assertPoint:(CGPoint)point equals:(CGPoint)expected {
    XCTAssertEqualWithAccuracy(point.x, expected.x, MobaDirectionalStrategyTolerance);
    XCTAssertEqualWithAccuracy(point.y, expected.y, MobaDirectionalStrategyTolerance);
}

- (void)resetAfterActiveCast {
    [self.session interrupt];
    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    [self drainDispatcher];
    [self.sink clear];
}

- (void)testBeginSendsDefaultUpCursorBeforeSkillKeyDown {
    [self beginCast];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:down"]));
    XCTAssertEqual(self.sink.cursorPoints.count, 1u);
    [self assertPoint:MobaDirectionalPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 400.0)];
    XCTAssertTrue(self.strategy.hasDefaultTarget);
    [self assertPoint:self.strategy.defaultTarget equals:CGPointMake(1000.0, 400.0)];
    XCTAssertTrue(self.strategy.hasLatestTarget);
    [self assertPoint:self.strategy.latestTarget equals:self.strategy.defaultTarget];
}

- (void)testNoDragCommitUsesDefaultUpTarget {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];

    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:up"]));
    [self assertPoint:MobaDirectionalPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 400.0)];
    XCTAssertFalse(self.strategy.hasLatestTarget);
}

- (void)testCardinalDirectionsSelectRightDownLeftAndUpRadii {
    NSArray<NSValue *> *directions = @[
        MobaDirectionalValueWithVector(CGVectorMake(1.0, 0.0)),
        MobaDirectionalValueWithVector(CGVectorMake(0.0, 1.0)),
        MobaDirectionalValueWithVector(CGVectorMake(-1.0, 0.0)),
        MobaDirectionalValueWithVector(CGVectorMake(0.0, -1.0)),
    ];
    NSArray<NSValue *> *expected = @[
        MobaDirectionalValueWithPoint(CGPointMake(1200.0, 700.0)),
        MobaDirectionalValueWithPoint(CGPointMake(1000.0, 1100.0)),
        MobaDirectionalValueWithPoint(CGPointMake(900.0, 700.0)),
        MobaDirectionalValueWithPoint(CGPointMake(1000.0, 400.0)),
    ];

    for (NSUInteger index = 0; index < directions.count; index++) {
        [self beginCast];
        [self updateCastInDirection:MobaDirectionalVectorFromValue(directions[index])];
        [self assertPoint:self.strategy.latestTarget
                   equals:MobaDirectionalPointFromValue(expected[index])];
        [self resetAfterActiveCast];
    }
}

- (void)testDiagonalDirectionsUseTheirAsymmetricQuadrantRadii {
    NSArray<NSValue *> *directions = @[
        MobaDirectionalValueWithVector(CGVectorMake(1.0, 1.0)),
        MobaDirectionalValueWithVector(CGVectorMake(-1.0, 1.0)),
        MobaDirectionalValueWithVector(CGVectorMake(-1.0, -1.0)),
        MobaDirectionalValueWithVector(CGVectorMake(1.0, -1.0)),
    ];

    for (NSValue *directionValue in directions) {
        [self beginCast];
        CGVector direction = MobaDirectionalVectorFromValue(directionValue);
        CGPoint expected = CGPointZero;
        XCTAssertTrue(MobaAimTargetForDirection(CGPointMake(1000.0, 700.0),
                                                direction,
                                                MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0),
                                                1.0,
                                                &expected));
        [self updateCastInDirection:direction];
        [self assertPoint:self.strategy.latestTarget equals:expected];
        [self resetAfterActiveCast];
    }
}

- (void)testAsymmetricUpdateTargetRemainsCollinearWithDragDirection {
    [self beginCast];
    CGVector direction = CGVectorMake(2.0, -5.0);
    [self updateCastInDirection:direction];
    CGPoint delta = CGPointMake(self.strategy.latestTarget.x - 1000.0,
                                self.strategy.latestTarget.y - 700.0);
    XCTAssertEqualWithAccuracy(delta.x * direction.dy - delta.y * direction.dx,
                               0.0,
                               MobaDirectionalStrategyTolerance);
    XCTAssertGreaterThan(delta.x * direction.dx + delta.y * direction.dy, 0.0);
}

- (void)testNonUnitAndNormalizedDirectionsProduceSameLatestTarget {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(3.0, -4.0)];
    CGPoint nonUnitTarget = self.strategy.latestTarget;
    MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update
                                              dragDirection:CGVectorMake(0.6, -0.8)]);
    [self assertPoint:self.strategy.latestTarget equals:nonUnitTarget];
}

- (void)testUpdateOnlyChangesLatestTargetWithoutSendingCursor {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];

    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
}

- (void)testDraggedThenAimingDefaultRestoresDefaultWithoutValidDirection {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
    [self drainDispatcher];
    [self.sink clear];

    MobaCastTransitionResult fallback = [self.session updateInteractionWithToken:self.token
                                                                    meaningfulDrag:NO
                                                                   insideCancelZone:NO];
    XCTAssertEqual(fallback.currentState, MobaCastStateAimingDefault);
    XCTAssertTrue([self.strategy updateWithTransitionResult:fallback
                                              dragDirection:CGVectorMake(NAN, INFINITY)]);
    [self assertPoint:self.strategy.latestTarget equals:self.strategy.defaultTarget];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testCommitAfterAimingDefaultFallbackUsesDefaultBeforeSkillUp {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    MobaCastTransitionResult fallback = [self.session updateInteractionWithToken:self.token
                                                                    meaningfulDrag:NO
                                                                   insideCancelZone:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:fallback
                                              dragDirection:CGVectorMake(0.0, 0.0)]);
    [self drainDispatcher];
    [self.sink clear];

    XCTAssertTrue([self.strategy commitWithTransitionResult:
        [self.session releaseInteractionWithToken:self.token]]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:up"]));
    [self assertPoint:MobaDirectionalPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(1000.0, 400.0)];
}

- (void)testCancelArmedPreservesLatestAndExitToDefaultRestoresDefault {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    CGPoint draggedTarget = self.strategy.latestTarget;

    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                 meaningfulDrag:YES
                                                                insideCancelZone:YES];
    XCTAssertEqual(armed.currentState, MobaCastStateCancelArmed);
    XCTAssertTrue([self.strategy updateWithTransitionResult:armed
                                              dragDirection:CGVectorMake(NAN, INFINITY)]);
    [self assertPoint:self.strategy.latestTarget equals:draggedTarget];

    MobaCastTransitionResult fallback = [self.session updateInteractionWithToken:self.token
                                                                    meaningfulDrag:NO
                                                                   insideCancelZone:NO];
    XCTAssertEqual(fallback.currentState, MobaCastStateAimingDefault);
    XCTAssertTrue([self.strategy updateWithTransitionResult:fallback
                                              dragDirection:CGVectorMake(0.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:self.strategy.defaultTarget];
}

- (void)testCancelArmedExitToDraggedUsesCurrentDirection {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    MobaCastTransitionResult armed = [self.session updateInteractionWithToken:self.token
                                                                 meaningfulDrag:YES
                                                                insideCancelZone:YES];
    XCTAssertTrue([self.strategy updateWithTransitionResult:armed
                                              dragDirection:CGVectorMake(-1.0, 0.0)]);

    MobaCastTransitionResult dragged = [self.session updateInteractionWithToken:self.token
                                                                   meaningfulDrag:YES
                                                                  insideCancelZone:NO];
    XCTAssertEqual(dragged.currentState, MobaCastStateAimingDragged);
    XCTAssertTrue([self.strategy updateWithTransitionResult:dragged
                                              dragDirection:CGVectorMake(-1.0, 0.0)]);
    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(900.0, 700.0)];
}

- (void)testCommitUsesLastValidTargetAndPreservesAtomicEventOrder {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(-1.0, 0.0)];
    [self drainDispatcher];
    [self.sink clear];

    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:up"]));
    [self assertPoint:MobaDirectionalPointFromValue(self.sink.cursorPoints.firstObject)
               equals:CGPointMake(900.0, 700.0)];
}

- (void)testCommitCallsAtomicDispatcherAPIInsteadOfSeparateCursorAndKeyMethods {
    [self beginCast];
    XCTAssertEqual(self.dispatcher.cursorMethodCallCount, 1u);
    XCTAssertEqual(self.dispatcher.keyMethodCallCount, 1u);

    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 1u);
    XCTAssertEqual(self.dispatcher.cursorMethodCallCount, 1u);
    XCTAssertEqual(self.dispatcher.keyMethodCallCount, 1u);
}

- (void)testInvalidDirectionsAreRejectedAndPreserveLastValidTarget {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    CGPoint validTarget = self.strategy.latestTarget;

    NSArray<NSValue *> *invalidDirections = @[
        MobaDirectionalValueWithVector(CGVectorMake(0.0, 0.0)),
        MobaDirectionalValueWithVector(CGVectorMake(NAN, 1.0)),
        MobaDirectionalValueWithVector(CGVectorMake(1.0, INFINITY)),
    ];
    for (NSValue *value in invalidDirections) {
        MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                    meaningfulDrag:YES
                                                                   insideCancelZone:NO];
        XCTAssertFalse([self.strategy updateWithTransitionResult:update
                                                   dragDirection:MobaDirectionalVectorFromValue(value)]);
        [self assertPoint:self.strategy.latestTarget equals:validTarget];
    }

    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    [self drainDispatcher];
    [self assertPoint:MobaDirectionalPointFromValue(self.sink.cursorPoints.lastObject)
               equals:validTarget];
}

- (void)testInvalidDirectionalConfigurationsFailInitialization {
    MobaAimRadii validRadii = MobaAimRadiiMake(1.0, 2.0, 3.0, 4.0);
    MobaCastCancelAction *cancel = [MobaCastCancelAction releaseOnlyAction];

    XCTAssertNil([[MobaDirectionalCastConfiguration alloc] initWithSkillKeyCode:81
                                                                     heroAnchor:CGPointMake(NAN, 0.0)
                                                                          radii:validRadii
                                                               defaultDirection:CGVectorMake(0.0, -1.0)
                                                           defaultDistanceRatio:1.0
                                                                   cancelAction:cancel]);
    MobaAimRadii invalidLeft = MobaAimRadiiMake(0.0, 2.0, 3.0, 4.0);
    MobaAimRadii invalidRight = MobaAimRadiiMake(1.0, -1.0, 3.0, 4.0);
    MobaAimRadii invalidUp = MobaAimRadiiMake(1.0, 2.0, INFINITY, 4.0);
    MobaAimRadii invalidDown = MobaAimRadiiMake(1.0, 2.0, 3.0, NAN);
    NSArray<NSValue *> *invalidRadii = @[
        [NSValue valueWithBytes:&invalidLeft objCType:@encode(MobaAimRadii)],
        [NSValue valueWithBytes:&invalidRight objCType:@encode(MobaAimRadii)],
        [NSValue valueWithBytes:&invalidUp objCType:@encode(MobaAimRadii)],
        [NSValue valueWithBytes:&invalidDown objCType:@encode(MobaAimRadii)],
    ];
    for (NSValue *value in invalidRadii) {
        MobaAimRadii radii;
        [value getValue:&radii size:sizeof(radii)];
        XCTAssertNil([[MobaDirectionalCastConfiguration alloc] initWithSkillKeyCode:81
                                                                         heroAnchor:CGPointZero
                                                                              radii:radii
                                                                   defaultDirection:CGVectorMake(0.0, -1.0)
                                                               defaultDistanceRatio:1.0
                                                                       cancelAction:cancel]);
    }
    XCTAssertNil([[MobaDirectionalCastConfiguration alloc] initWithSkillKeyCode:81
                                                                     heroAnchor:CGPointZero
                                                                          radii:validRadii
                                                               defaultDirection:CGVectorMake(0.0, 0.0)
                                                           defaultDistanceRatio:1.0
                                                                   cancelAction:cancel]);
    XCTAssertNil([[MobaDirectionalCastConfiguration alloc] initWithSkillKeyCode:81
                                                                     heroAnchor:CGPointZero
                                                                          radii:validRadii
                                                               defaultDirection:CGVectorMake(INFINITY, -1.0)
                                                           defaultDistanceRatio:1.0
                                                                   cancelAction:cancel]);
    XCTAssertNil([[MobaDirectionalCastConfiguration alloc] initWithSkillKeyCode:81
                                                                     heroAnchor:CGPointZero
                                                                          radii:validRadii
                                                               defaultDirection:CGVectorMake(0.0, -1.0)
                                                           defaultDistanceRatio:NAN
                                                                   cancelAction:cancel]);
}

- (MobaCastTransitionResult)cancelArmedReleaseResult {
    [self.session updateInteractionWithToken:self.token
                              meaningfulDrag:YES
                             insideCancelZone:YES];
    return [self.session releaseInteractionWithToken:self.token];
}

- (void)testKeyboardCancelPrecedesSkillUpAndUsesConfiguredSchedule {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:27:down", @"key:81:up"]));
    XCTAssertEqualObjects(self.scheduler.scheduledDelays, (@[@40]));
    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events,
                          (@[@"key:27:down", @"key:81:up", @"key:27:up"]));
}

- (void)testRightMouseCancelPrecedesSkillUp {
    self.strategy = [self strategyWithSkillKeyCode:81
                                            anchor:CGPointMake(1000.0, 700.0)
                                             radii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                      cancelAction:[MobaCastCancelAction rightMouseAction]];
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events,
                          (@[@"mouse:3:down", @"mouse:3:up", @"key:81:up"]));
}

- (void)testReleaseOnlyCancelSendsOnlySkillKeyUp {
    self.strategy = [self strategyWithSkillKeyCode:81
                                            anchor:CGPointMake(1000.0, 700.0)
                                             radii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                      cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
}

- (void)testCancellationDoesNotSubmitFinalCursor {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([self.strategy cancelWithTransitionResult:[self cancelArmedReleaseResult]]);
    [self drainDispatcher];

    XCTAssertFalse([self.sink.events containsObject:@"cursor"]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 0u);
}

- (void)testLifecycleReleaseAllReleasesSkillOnceAndResetsStaySilent {
    [self beginCast];
    [self drainDispatcher];
    [self.sink clear];
    MobaCastTransitionResult interrupted = [self.session interrupt];
    XCTAssertEqual(interrupted.terminalOutcome, MobaCastTerminalOutcomeCancelled);

    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    [self drainDispatcher];
    [self.dispatcher releaseAllInputs];
    [self.strategy silentReset];
    [self.session silentReset];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
    XCTAssertFalse(self.strategy.hasDefaultTarget);
    XCTAssertFalse(self.strategy.hasLatestTarget);
}

- (void)testNewCastDoesNotInheritPreviousDefaultOrLatestState {
    [self beginCast];
    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    XCTAssertTrue([self.strategy commitWithTransitionResult:
        [self.session releaseInteractionWithToken:self.token]]);
    XCTAssertFalse(self.strategy.hasDefaultTarget);
    XCTAssertFalse(self.strategy.hasLatestTarget);

    [self.session silentReset];
    self.token = [[NSObject alloc] init];
    [self beginCast];
    XCTAssertTrue(self.strategy.hasDefaultTarget);
    XCTAssertTrue(self.strategy.hasLatestTarget);
    [self assertPoint:self.strategy.defaultTarget equals:CGPointMake(1000.0, 400.0)];
    [self assertPoint:self.strategy.latestTarget equals:self.strategy.defaultTarget];
}

- (void)testTwoStrategyInstancesKeepIndependentConfigurationsAndLatestTargets {
    MobaDirectionalCastStrategy *second = [self strategyWithSkillKeyCode:82
                                                                  anchor:CGPointMake(300.0, 400.0)
                                                                   radii:MobaAimRadiiMake(10.0, 20.0, 30.0, 40.0)
                                                            cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    MobaCastSession *secondSession = [[MobaCastSession alloc] init];
    NSObject *secondToken = [[NSObject alloc] init];
    [self beginCast];
    XCTAssertTrue([second beginWithTransitionResult:[secondSession beginInteractionWithToken:secondToken]]);

    [self updateCastInDirection:CGVectorMake(1.0, 0.0)];
    MobaCastTransitionResult secondUpdate = [secondSession updateInteractionWithToken:secondToken
                                                                        meaningfulDrag:YES
                                                                       insideCancelZone:NO];
    XCTAssertTrue([second updateWithTransitionResult:secondUpdate dragDirection:CGVectorMake(-1.0, 0.0)]);

    [self assertPoint:self.strategy.latestTarget equals:CGPointMake(1200.0, 700.0)];
    [self assertPoint:second.latestTarget equals:CGPointMake(290.0, 400.0)];
}

- (void)testSessionResultsDriveEachStrategyPhaseOnceAndExplicitResetAllowsNextToken {
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy beginWithTransitionResult:begin]);
    MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:YES
                                                               insideCancelZone:NO];
    XCTAssertTrue([self.strategy updateWithTransitionResult:update dragDirection:CGVectorMake(1.0, 0.0)]);
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

- (void)testRejectedDuplicateBeginCannotSendSecondCursorOrKeyDown {
    MobaCastTransitionResult first = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue([self.strategy beginWithTransitionResult:first]);
    MobaCastTransitionResult duplicate = [self.session beginInteractionWithToken:[[NSObject alloc] init]];
    XCTAssertFalse(duplicate.accepted);
    XCTAssertFalse([self.strategy beginWithTransitionResult:duplicate]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:down"]));
}

- (void)testCancelledTerminalCannotBeConsumedAsCommit {
    [self beginCast];
    MobaCastTransitionResult cancelled = [self cancelArmedReleaseResult];
    XCTAssertFalse([self.strategy commitWithTransitionResult:cancelled]);
    XCTAssertTrue([self.strategy cancelWithTransitionResult:cancelled]);
    XCTAssertFalse([self.strategy cancelWithTransitionResult:cancelled]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 0u);
}

- (void)testCommittedTerminalCannotBeConsumedAsCancel {
    [self beginCast];
    MobaCastTransitionResult committed = [self.session releaseInteractionWithToken:self.token];
    XCTAssertFalse([self.strategy cancelWithTransitionResult:committed]);
    XCTAssertTrue([self.strategy commitWithTransitionResult:committed]);
    XCTAssertFalse([self.strategy commitWithTransitionResult:committed]);
    XCTAssertEqual(self.dispatcher.atomicCommitCallCount, 1u);
}

@end
