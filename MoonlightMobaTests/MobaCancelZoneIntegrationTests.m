//
//  MobaCancelZoneIntegrationTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Casting/MobaDirectionalCastStrategy.h"
#import "../Limelight/Input/MOBA/Casting/MobaPointCastStrategy.h"
#import "../Limelight/Input/MOBA/Controls/MobaCancelZoneController.h"
#import "../Limelight/Input/MOBA/Controls/MobaCancelZoneView.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"

@interface MobaCancelIntegrationFakeSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
- (void)clear;
@end

@implementation MobaCancelIntegrationFakeSink {
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
    @synchronized (self) {
        [_events addObject:@"cursor"];
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
    @synchronized (self) {
        return [_events copy];
    }
}

- (void)clear {
    @synchronized (self) {
        [_events removeAllObjects];
    }
}

@end

@interface MobaCancelIntegrationScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSUInteger pendingCount;
- (void)runAll;
@end

@implementation MobaCancelIntegrationScheduler {
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
    @synchronized (self) {
        [_blocks addObject:[block copy]];
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

@interface MobaCancelIntegrationPresentation : NSObject <MobaCancelZonePresenting>
@property (nonatomic) BOOL visible;
@property (nonatomic) BOOL armed;
@property (nonatomic) NSUInteger resetCount;
@end

@implementation MobaCancelIntegrationPresentation

- (void)setCancelZoneCastingVisible:(BOOL)visible {
    self.visible = visible;
}

- (void)setCancelZoneArmed:(BOOL)armed {
    self.armed = armed;
}

- (void)resetCancelZonePresentation {
    self.visible = NO;
    self.armed = NO;
    self.resetCount += 1;
}

@end

@interface MobaCancelIntegrationEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic) BOOL supported;
@end

@implementation MobaCancelIntegrationEnvironment
- (BOOL)isMobaBattleModeSupported { return self.supported; }
- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed {}
- (void)setMobaNativeTouchRoutingEnabled:(BOOL)enabled {}
@end

@interface MobaCancelZoneIntegrationTests : XCTestCase
@property (nonatomic, strong) MobaCancelIntegrationFakeSink *sink;
@property (nonatomic, strong) MobaCancelIntegrationScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaCastSession *session;
@property (nonatomic, strong) NSObject *token;
@property (nonatomic, strong) MobaCancelIntegrationPresentation *presentation;
@property (nonatomic, strong) MobaCancelZoneController *zone;
@end

@implementation MobaCancelZoneIntegrationTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaCancelIntegrationFakeSink alloc] init];
    self.scheduler = [[MobaCancelIntegrationScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
    self.session = [[MobaCastSession alloc] init];
    self.token = [[NSObject alloc] init];
    self.presentation = [[MobaCancelIntegrationPresentation alloc] init];
    self.zone = [[MobaCancelZoneController alloc]
        initWithGeometry:MobaCancelZoneGeometryMake(CGPointMake(50.0, 50.0), 40.0, 0.0)
             presentation:self.presentation];
}

- (MobaDirectionalCastStrategy *)directionalStrategyWithCancelAction:(MobaCastCancelAction *)action {
    MobaDirectionalCastConfiguration *configuration =
        [MobaDirectionalCastConfiguration defaultConfigurationWithSkillKeyCode:81
                                                                     heroAnchor:CGPointMake(1000.0, 700.0)
                                                                          radii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                                                   cancelAction:action];
    XCTAssertNotNil(configuration);
    return [[MobaDirectionalCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                     configuration:configuration];
}

- (MobaPointCastStrategy *)pointStrategyWithCancelAction:(MobaCastCancelAction *)action {
    MobaPointCastConfiguration *configuration =
        [MobaPointCastConfiguration defaultConfigurationWithTargetMode:MobaPointCastTargetModeGround
                                                           skillKeyCode:69
                                                             heroAnchor:CGPointMake(1000.0, 700.0)
                                                            wheelRadius:100.0
                                                          deadzoneRatio:0.2
                                                         fullRangeRatio:0.8
                                                          curveExponent:1.0
                                                           minimumRadii:MobaAimRadiiMake(0.0, 0.0, 0.0, 0.0)
                                                           maximumRadii:MobaAimRadiiMake(100.0, 200.0, 300.0, 400.0)
                                                            cancelAction:action];
    XCTAssertNotNil(configuration);
    return [[MobaPointCastStrategy alloc] initWithDispatcher:self.dispatcher
                                                configuration:configuration];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"cancel integration dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (MobaCastTransitionResult)beginStrategy:(id<MobaCastStrategy>)strategy {
    MobaCastTransitionResult begin = [self.session beginInteractionWithToken:self.token];
    XCTAssertTrue(begin.accepted);
    XCTAssertTrue([strategy beginWithTransitionResult:begin]);
    XCTAssertTrue([self.zone beginCastingWithToken:self.token]);
    return begin;
}

- (MobaCastTransitionResult)updateStrategy:(id<MobaCastStrategy>)strategy
                                     point:(CGPoint)point
                            meaningfulDrag:(BOOL)meaningfulDrag {
    BOOL inside = NO;
    XCTAssertTrue([self.zone evaluatePoint:point
                                  forToken:self.token
                          insideCancelZone:&inside]);
    MobaCastTransitionResult update = [self.session updateInteractionWithToken:self.token
                                                                meaningfulDrag:meaningfulDrag
                                                               insideCancelZone:inside];
    XCTAssertTrue(update.accepted);
    if ([strategy isKindOfClass:[MobaDirectionalCastStrategy class]]) {
        XCTAssertTrue([(MobaDirectionalCastStrategy *)strategy updateWithTransitionResult:update
                                                                        dragDirection:CGVectorMake(1.0, 0.0)]);
    }
    else {
        XCTAssertTrue([(MobaPointCastStrategy *)strategy updateWithTransitionResult:update
                                                                 dragDisplacement:CGVectorMake(80.0, 0.0)]);
    }
    XCTAssertTrue([self.zone applyAcceptedTransitionResult:update forToken:self.token]);
    return update;
}

- (MobaCastTransitionResult)releaseStrategy:(id<MobaCastStrategy>)strategy {
    MobaCastTransitionResult terminal = [self.session releaseInteractionWithToken:self.token];
    BOOL consumed = terminal.terminalOutcome == MobaCastTerminalOutcomeCancelled
        ? [strategy cancelWithTransitionResult:terminal]
        : [strategy commitWithTransitionResult:terminal];
    XCTAssertTrue(consumed);
    [self.session silentReset];
    [strategy silentReset];
    XCTAssertTrue([self.zone endCastingWithToken:self.token]);
    return terminal;
}

- (void)testDirectionalCancelUsesSessionArmedResultAndKeyboardBeforeSkillUp {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction keyboardActionWithKeyCode:27 durationMs:40]];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];

    XCTAssertEqual([self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES].currentState,
                   MobaCastStateCancelArmed);
    XCTAssertTrue(self.presentation.armed);
    XCTAssertEqual([self releaseStrategy:strategy].terminalOutcome, MobaCastTerminalOutcomeCancelled);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:27:down", @"key:81:up"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
}

- (void)testPointGroundCancelUsesRightMouseBeforeSkillUp {
    MobaPointCastStrategy *strategy =
        [self pointStrategyWithCancelAction:[MobaCastCancelAction rightMouseAction]];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES];
    [self releaseStrategy:strategy];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events,
                          (@[@"mouse:3:down", @"mouse:3:up", @"key:69:up"]));
}

- (void)testReleaseOnlyCancelProducesOnlySkillUpAndNoFinalCursor {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES];
    [self releaseStrategy:strategy];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
}

- (void)testCancelReleaseNeverSubmitsFinalCursor {
    MobaPointCastStrategy *strategy =
        [self pointStrategyWithCancelAction:[MobaCastCancelAction rightMouseAction]];
    [self beginStrategy:strategy];
    [self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES];
    [self drainDispatcher];
    [self.sink clear];
    [self releaseStrategy:strategy];
    [self drainDispatcher];

    XCTAssertFalse([self.sink.events containsObject:@"cursor"]);
    XCTAssertEqualObjects(self.sink.events,
                          (@[@"mouse:3:down", @"mouse:3:up", @"key:69:up"]));
}

- (void)testReleaseOutsideZoneCommitsFinalCursorWithoutCancelAction {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction keyboardActionWithKeyCode:27 durationMs:40]];
    [self beginStrategy:strategy];
    [self drainDispatcher];
    [self.sink clear];
    [self updateStrategy:strategy point:CGPointMake(100.0, 100.0) meaningfulDrag:YES];
    XCTAssertEqual([self releaseStrategy:strategy].terminalOutcome, MobaCastTerminalOutcomeCommitted);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:81:up"]));
    XCTAssertEqual(self.scheduler.pendingCount, 0u);
}

- (void)testEnterThenExitZoneRestoresNormalAndReleaseCommits {
    MobaPointCastStrategy *strategy =
        [self pointStrategyWithCancelAction:[MobaCastCancelAction rightMouseAction]];
    [self beginStrategy:strategy];
    [self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES];
    XCTAssertTrue(self.presentation.armed);
    [self updateStrategy:strategy point:CGPointMake(100.0, 100.0) meaningfulDrag:YES];
    XCTAssertFalse(self.presentation.armed);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertEqual([self releaseStrategy:strategy].terminalOutcome, MobaCastTerminalOutcomeCommitted);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"cursor", @"key:69:up"]));
}

- (void)testRepeatedTerminalResultCannotRepeatConfiguredCancel {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginStrategy:strategy];
    [self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES];
    MobaCastTransitionResult terminal = [self.session releaseInteractionWithToken:self.token];
    XCTAssertTrue([strategy cancelWithTransitionResult:terminal]);
    XCTAssertFalse([strategy cancelWithTransitionResult:terminal]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events,
                          (@[@"cursor", @"key:81:down", @"key:81:up"]));
}

- (void)testRejectedNonOwnerUpdateCannotChangeArmedPresentation {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginStrategy:strategy];
    NSObject *other = [[NSObject alloc] init];
    BOOL inside = NO;
    XCTAssertFalse([self.zone evaluatePoint:CGPointMake(50.0, 50.0)
                                   forToken:other
                           insideCancelZone:&inside]);
    MobaCastTransitionResult rejected = [self.session updateInteractionWithToken:other
                                                                   meaningfulDrag:YES
                                                                  insideCancelZone:YES];
    XCTAssertFalse(rejected.accepted);
    XCTAssertFalse([self.zone applyAcceptedTransitionResult:rejected forToken:other]);
    XCTAssertFalse(self.presentation.armed);
}

- (void)testLifecycleInterruptionReleasesSkillWithoutConfiguredCancel {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction keyboardActionWithKeyCode:27 durationMs:40]];
    [self beginStrategy:strategy];
    [self updateStrategy:strategy point:CGPointMake(50.0, 50.0) meaningfulDrag:YES];
    [self drainDispatcher];
    [self.sink clear];

    [self.dispatcher releaseAllInputs];
    [strategy silentReset];
    [self.session silentReset];
    [self.zone silentReset];
    [self drainDispatcher];
    [self.dispatcher releaseAllInputs];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
    XCTAssertFalse(self.presentation.visible);
    XCTAssertFalse(self.presentation.armed);
}

- (void)testStaleTokenAfterInterruptionCannotUpdateArmOrEndZone {
    MobaDirectionalCastStrategy *strategy =
        [self directionalStrategyWithCancelAction:[MobaCastCancelAction releaseOnlyAction]];
    [self beginStrategy:strategy];
    [self.zone silentReset];
    MobaCastTransitionResult acceptedElsewhere = [self.session updateInteractionWithToken:self.token
                                                                            meaningfulDrag:YES
                                                                           insideCancelZone:YES];
    BOOL inside = NO;
    XCTAssertFalse([self.zone evaluatePoint:CGPointMake(50.0, 50.0)
                                   forToken:self.token
                           insideCancelZone:&inside]);
    XCTAssertFalse([self.zone applyAcceptedTransitionResult:acceptedElsewhere forToken:self.token]);
    XCTAssertFalse([self.zone endCastingWithToken:self.token]);
    XCTAssertFalse(self.presentation.visible);
    XCTAssertFalse(self.presentation.armed);
}

- (void)testUIAndLayoutModeInterruptionResetAndHideZone {
    for (NSNumber *modeValue in @[@(MobaOverlayModeUI), @(MobaOverlayModeLayoutEdit)]) {
        MobaCancelIntegrationEnvironment *environment = [[MobaCancelIntegrationEnvironment alloc] init];
        environment.supported = YES;
        MobaOverlayLifecycle *lifecycle = [[MobaOverlayLifecycle alloc]
            initWithEnvironment:environment inputDispatcher:self.dispatcher];
        MobaCancelZoneView *view = [[MobaCancelZoneView alloc]
            initWithVisualDiameter:MobaCancelZoneDefaultVisualDiameter];
        MobaCancelZoneController *controller = [[MobaCancelZoneController alloc]
            initWithGeometry:MobaCancelZoneGeometryMake(CGPointMake(50.0, 50.0), 40.0, 0.0)
                 presentation:view];
        view.controller = controller;
        [lifecycle registerLocalInteractionResetParticipant:view];
        [lifecycle start];
        NSObject *token = [[NSObject alloc] init];
        XCTAssertTrue([controller beginCastingWithToken:token]);
        XCTAssertFalse(view.hidden);

        XCTAssertTrue([lifecycle transitionToMode:modeValue.integerValue]);
        XCTAssertTrue(view.hidden);
        XCTAssertFalse(controller.castingActive);
        XCTAssertNil(controller.activeCastToken);
        [lifecycle stop];
    }
}

@end
