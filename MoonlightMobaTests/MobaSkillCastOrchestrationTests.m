//
//  MobaSkillCastOrchestrationTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Casting/MobaCastSession.h"
#import "../Limelight/Input/MOBA/Casting/MobaCastStrategyFactory.h"
#import "../Limelight/Input/MOBA/Casting/MobaDirectionalCastStrategy.h"
#import "../Limelight/Input/MOBA/Casting/MobaInstantCastStrategy.h"
#import "../Limelight/Input/MOBA/Casting/MobaPointCastStrategy.h"
#import "../Limelight/Input/MOBA/Controls/MobaSkillButtonView.h"
#import "../Limelight/Input/MOBA/Controls/MobaSkillCastController.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

@interface MobaSkillRuntimeDescriptor (OrchestrationTests)
- (instancetype)initWithSkillSlot:(MobaCanonicalSkillSlot)skillSlot
                     displayLabel:(NSString *)displayLabel
                layoutControlName:(NSString *)layoutControlName
                      inputAction:(NSString *)inputAction
                      hostKeyCode:(uint16_t)hostKeyCode
                         castType:(MobaProfileSkillCastType)castType
                      allowCancel:(BOOL)allowCancel
                     skillProfile:(MobaChampionSkillProfile *)skillProfile
             layoutControlProfile:(MobaLayoutControlProfile *)layoutControlProfile
                         strategy:(id<MobaCastStrategy>)strategy
                  cursorCoalescer:(nullable MobaCursorCoalescer *)cursorCoalescer
             instantConfiguration:(nullable MobaInstantCastConfiguration *)instantConfiguration
         directionalConfiguration:(nullable MobaDirectionalCastConfiguration *)directionalConfiguration
               pointConfiguration:(nullable MobaPointCastConfiguration *)pointConfiguration;
@end

@interface MobaSkillTestTouchResponse : NSObject
@property (nonatomic) double deadzoneRatio;
@end
@implementation MobaSkillTestTouchResponse
@end

@interface MobaSkillTestProfile : NSObject
@property (nonatomic) MobaProfileSkillCastType castType;
@property (nonatomic) BOOL allowCancel;
@property (nonatomic, strong, nullable) MobaSkillTestTouchResponse *touchResponse;
@end
@implementation MobaSkillTestProfile
@end

@interface MobaSkillTestLayout : NSObject
@property (nonatomic) double centerX;
@property (nonatomic) double centerY;
@property (nonatomic) double visualWidthPt;
@property (nonatomic) double visualHeightPt;
@property (nonatomic) double hitAreaScale;
@property (nonatomic, strong, nullable) NSNumber *wheelRadiusPt;
@property (nonatomic) double opacity;
@property (nonatomic) double pressedOpacity;
@property (nonatomic) double disabledOpacity;
@property (nonatomic) NSInteger zIndex;
@property (nonatomic, getter=isInteractionEnabled) BOOL interactionEnabled;
@end
@implementation MobaSkillTestLayout
@end

@interface MobaSkillTestSink : NSObject <MobaInputSink>
@property (nonatomic, readonly) NSArray<NSString *> *events;
- (void)clear;
@end

@implementation MobaSkillTestSink {
    NSMutableArray<NSString *> *_events;
}
- (instancetype)init {
    self = [super init];
    if (self) _events = [[NSMutableArray alloc] init];
    return self;
}
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    @synchronized (self) {
        [_events addObject:[NSString stringWithFormat:@"key:%u:%@", keyCode, down ? @"down" : @"up"]];
    }
}
- (void)moveCursorToCanvasPoint:(CGPoint)point {
    @synchronized (self) {
        [_events addObject:[NSString stringWithFormat:@"cursor:%.0f:%.0f", point.x, point.y]];
    }
}
- (void)sendMouseButton:(int)button down:(BOOL)down {
    @synchronized (self) {
        [_events addObject:[NSString stringWithFormat:@"mouse:%d:%@", button, down ? @"down" : @"up"]];
    }
}
- (NSArray<NSString *> *)events { @synchronized (self) { return [_events copy]; } }
- (void)clear { @synchronized (self) { [_events removeAllObjects]; } }
@end

@interface MobaSkillTestScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSUInteger pendingCount;
- (void)runAll;
@end
@implementation MobaSkillTestScheduler {
    NSMutableArray *_blocks;
}
- (instancetype)init {
    self = [super init];
    if (self) _blocks = [[NSMutableArray alloc] init];
    return self;
}
- (void)scheduleAfterMilliseconds:(NSUInteger)delayMs block:(dispatch_block_t)block {
    (void)delayMs;
    [_blocks addObject:[block copy]];
}
- (NSUInteger)pendingCount { return _blocks.count; }
- (void)runAll {
    NSArray *blocks = [_blocks copy];
    [_blocks removeAllObjects];
    for (dispatch_block_t block in blocks) block();
}
@end

@interface MobaSkillEndpointDriver : NSObject <MobaDisplayLinkDriving>
@property (nonatomic, getter=isRunning) BOOL running;
@property (nonatomic, copy, nullable) MobaDisplayLinkTickHandler tickHandler;
- (void)tick;
@end
@implementation MobaSkillEndpointDriver
- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate
                tickHandler:(MobaDisplayLinkTickHandler)tickHandler {
    (void)updateRate;
    self.running = YES;
    self.tickHandler = tickHandler;
    return YES;
}
- (void)stop { self.running = NO; }
- (void)tick { if (self.tickHandler != nil) self.tickHandler(); }
@end

@interface MobaSkillTestGate : NSObject <MobaBattleInputGate>
@property (nonatomic, getter=isBattleInputAllowed) BOOL battleInputAllowed;
@end
@implementation MobaSkillTestGate
@end

@interface MobaSkillTestZoneRouter : NSObject <MobaSkillCancelZoneRouting>
@property (nonatomic) BOOL beginAllowed;
@property (nonatomic) BOOL evaluateAllowed;
@property (nonatomic) BOOL applyAllowed;
@property (nonatomic) BOOL endAllowed;
@property (nonatomic) BOOL inside;
@property (nonatomic, strong, nullable) id activeToken;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end
@implementation MobaSkillTestZoneRouter
- (instancetype)init {
    self = [super init];
    if (self) {
        _beginAllowed = _evaluateAllowed = _applyAllowed = _endAllowed = YES;
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}
- (BOOL)beginCancelZonePresentationForCastToken:(id)token {
    [self.events addObject:@"zone-begin"];
    if (!self.beginAllowed || self.activeToken != nil) return NO;
    self.activeToken = token;
    return YES;
}
- (BOOL)evaluateCancelZoneAtStreamViewPoint:(CGPoint)point
                                forCastToken:(id)token
                           insideCancelZone:(BOOL *)insideCancelZone {
    (void)point;
    [self.events addObject:@"zone-evaluate"];
    if (!self.evaluateAllowed || token != self.activeToken || insideCancelZone == NULL) return NO;
    *insideCancelZone = self.inside;
    return YES;
}
- (BOOL)applyCancelZoneTransitionResult:(MobaCastTransitionResult)result forCastToken:(id)token {
    (void)result;
    [self.events addObject:@"zone-apply"];
    return self.applyAllowed && token == self.activeToken;
}
- (BOOL)endCancelZonePresentationForCastToken:(id)token {
    [self.events addObject:@"zone-end"];
    if (!self.endAllowed || token != self.activeToken) return NO;
    self.activeToken = nil;
    return YES;
}
@end

@interface MobaSkillTestStrategy : NSObject <MobaCastStrategy>
@property (nonatomic) BOOL beginAllowed;
@property (nonatomic) BOOL updateAllowed;
@property (nonatomic) BOOL commitAllowed;
@property (nonatomic) BOOL cancelAllowed;
@property (nonatomic) NSUInteger silentResetCount;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result;
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result dragDirection:(CGVector)direction;
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result dragDisplacement:(CGVector)displacement;
@end
@implementation MobaSkillTestStrategy
- (instancetype)init {
    self = [super init];
    if (self) {
        _beginAllowed = _updateAllowed = _commitAllowed = _cancelAllowed = YES;
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}
- (BOOL)beginWithTransitionResult:(MobaCastTransitionResult)result {
    [self.events addObject:@"strategy-begin"];
    return self.beginAllowed && result.accepted;
}
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result {
    [self.events addObject:@"strategy-update"];
    return self.updateAllowed && result.accepted;
}
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result dragDirection:(CGVector)direction {
    (void)direction;
    return [self updateWithTransitionResult:result];
}
- (BOOL)updateWithTransitionResult:(MobaCastTransitionResult)result dragDisplacement:(CGVector)displacement {
    (void)displacement;
    return [self updateWithTransitionResult:result];
}
- (BOOL)commitWithTransitionResult:(MobaCastTransitionResult)result {
    [self.events addObject:@"strategy-commit"];
    return self.commitAllowed && result.terminalOutcome == MobaCastTerminalOutcomeCommitted;
}
- (BOOL)cancelWithTransitionResult:(MobaCastTransitionResult)result {
    [self.events addObject:@"strategy-cancel"];
    return self.cancelAllowed && result.terminalOutcome == MobaCastTerminalOutcomeCancelled;
}
- (void)silentReset { self.silentResetCount += 1; [self.events addObject:@"strategy-reset"]; }
@end

@interface MobaSkillTestCancellationDelegate : NSObject <MobaSkillCastControllerDelegate>
@property (nonatomic) NSUInteger cancellationCount;
@property (nonatomic, copy, nullable) void (^handler)(MobaSkillCastController *controller);
@end
@implementation MobaSkillTestCancellationDelegate
- (void)skillCastControllerDidRequestTouchCancellation:(MobaSkillCastController *)controller {
    self.cancellationCount += 1;
    if (self.handler != nil) self.handler(controller);
}
@end

@interface MobaSkillCastOrchestrationTests : XCTestCase
@property (nonatomic, strong) MobaSkillTestSink *sink;
@property (nonatomic, strong) MobaSkillTestScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaSkillTestGate *gate;
@property (nonatomic, strong) MobaSkillTestZoneRouter *zone;
@property (nonatomic, strong) MobaSkillTestCancellationDelegate *cancellationDelegate;
- (MobaSkillCastController *)directionalControllerAllowCancel:(BOOL)allowCancel
                                              cursorCoalescer:(nullable id<MobaCursorCoalescing>)cursorCoalescer;
@end

@implementation MobaSkillCastOrchestrationTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaSkillTestSink alloc] init];
    self.scheduler = [[MobaSkillTestScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
    self.gate = [[MobaSkillTestGate alloc] init];
    self.gate.battleInputAllowed = YES;
    self.zone = [[MobaSkillTestZoneRouter alloc] init];
    self.cancellationDelegate = [[MobaSkillTestCancellationDelegate alloc] init];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"skill dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{ [idle fulfill]; }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (MobaSkillTestLayout *)layoutWithOpacity:(double)opacity interactionEnabled:(BOOL)interactionEnabled {
    MobaSkillTestLayout *layout = [[MobaSkillTestLayout alloc] init];
    layout.centerX = 0.72;
    layout.centerY = 0.87;
    layout.visualWidthPt = 92;
    layout.visualHeightPt = 88;
    layout.hitAreaScale = 1.2;
    layout.wheelRadiusPt = @100;
    layout.opacity = opacity;
    layout.pressedOpacity = 0.88;
    layout.disabledOpacity = 0.30;
    layout.zIndex = 20;
    layout.interactionEnabled = interactionEnabled;
    return layout;
}

- (MobaSkillRuntimeDescriptor *)descriptorWithType:(MobaProfileSkillCastType)type
                                       allowCancel:(BOOL)allowCancel
                                          strategy:(id<MobaCastStrategy>)strategy
                                             label:(NSString *)label
                                           opacity:(double)opacity
                                interactionEnabled:(BOOL)interactionEnabled {
    MobaSkillTestTouchResponse *response = [[MobaSkillTestTouchResponse alloc] init];
    response.deadzoneRatio = 0.10;
    MobaSkillTestProfile *skill = [[MobaSkillTestProfile alloc] init];
    skill.castType = type;
    skill.allowCancel = allowCancel;
    skill.touchResponse = response;
    MobaSkillTestLayout *layout = [self layoutWithOpacity:opacity interactionEnabled:interactionEnabled];
    return [[MobaSkillRuntimeDescriptor alloc]
        initWithSkillSlot:label
             displayLabel:label
        layoutControlName:[@"ability" stringByAppendingString:label]
              inputAction:[@"ability" stringByAppendingString:label]
              hostKeyCode:81
                 castType:type
              allowCancel:allowCancel
             skillProfile:(MobaChampionSkillProfile *)skill
     layoutControlProfile:(MobaLayoutControlProfile *)layout
                 strategy:strategy
          cursorCoalescer:nil
     instantConfiguration:nil
 directionalConfiguration:nil
       pointConfiguration:nil];
}

- (MobaSkillCastController *)controllerForDescriptor:(MobaSkillRuntimeDescriptor *)descriptor {
    MobaSkillCastController *controller = [[MobaSkillCastController alloc]
        initWithDescriptor:descriptor inputGate:self.gate cancelZoneRouter:self.zone];
    controller.delegate = self.cancellationDelegate;
    return controller;
}

- (void)prepareSkillViewForHitTesting:(MobaSkillButtonView *)view {
    CGSize size = view.intrinsicContentSize;
    view.frame = CGRectMake(0.0, 0.0, size.width, size.height);
    [view setNeedsLayout];
    [view layoutIfNeeded];
}

- (UIView *)centerHitForSkillView:(MobaSkillButtonView *)view {
    return [view hitTest:CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds))
               withEvent:nil];
}

- (MobaSkillCastController *)fakeControllerWithType:(MobaProfileSkillCastType)type
                                        allowCancel:(BOOL)allowCancel
                                           strategy:(MobaSkillTestStrategy *)strategy {
    return [self controllerForDescriptor:[self descriptorWithType:type
                                                        allowCancel:allowCancel
                                                           strategy:strategy
                                                              label:@"Q"
                                                            opacity:0.72
                                                 interactionEnabled:YES]];
}

- (MobaSkillCastController *)directionalControllerAllowCancel:(BOOL)allowCancel {
    return [self directionalControllerAllowCancel:allowCancel cursorCoalescer:nil];
}

- (MobaSkillCastController *)directionalControllerAllowCancel:(BOOL)allowCancel
                                              cursorCoalescer:(id<MobaCursorCoalescing>)cursorCoalescer {
    MobaDirectionalCastConfiguration *configuration =
        [MobaDirectionalCastConfiguration defaultConfigurationWithSkillKeyCode:81
                                                                     heroAnchor:CGPointMake(1000, 700)
                                                                          radii:MobaAimRadiiMake(100, 100, 100, 100)
                                                                   cancelAction:[MobaCastCancelAction keyboardActionWithKeyCode:27 durationMs:30]];
    MobaDirectionalCastStrategy *strategy = [[MobaDirectionalCastStrategy alloc]
        initWithDispatcher:self.dispatcher
              configuration:configuration
            cursorCoalescer:cursorCoalescer];
    MobaSkillTestTouchResponse *response = [[MobaSkillTestTouchResponse alloc] init];
    response.deadzoneRatio = 0.10;
    MobaSkillTestProfile *skill = [[MobaSkillTestProfile alloc] init];
    skill.castType = MobaProfileSkillCastTypeDirectional;
    skill.allowCancel = allowCancel;
    skill.touchResponse = response;
    MobaSkillRuntimeDescriptor *descriptor = [[MobaSkillRuntimeDescriptor alloc]
        initWithSkillSlot:@"Q"
             displayLabel:@"Q"
        layoutControlName:@"abilityQ"
              inputAction:@"abilityQ"
              hostKeyCode:81
                 castType:MobaProfileSkillCastTypeDirectional
              allowCancel:allowCancel
             skillProfile:(MobaChampionSkillProfile *)skill
     layoutControlProfile:(MobaLayoutControlProfile *)[self layoutWithOpacity:0.72 interactionEnabled:YES]
                 strategy:strategy
          cursorCoalescer:(MobaCursorCoalescer *)cursorCoalescer
     instantConfiguration:nil
 directionalConfiguration:configuration
       pointConfiguration:nil];
    return [self controllerForDescriptor:descriptor];
}

- (MobaSkillCastController *)instantController {
    MobaInstantCastConfiguration *configuration = [[MobaInstantCastConfiguration alloc]
        initWithSkillKeyCode:82 tapDurationMs:30];
    MobaInstantCastStrategy *strategy = [[MobaInstantCastStrategy alloc]
        initWithDispatcher:self.dispatcher configuration:configuration];
    return [self controllerForDescriptor:[self descriptorWithType:MobaProfileSkillCastTypeInstant
                                                        allowCancel:NO
                                                           strategy:strategy
                                                              label:@"R"
                                                            opacity:0.72
                                                 interactionEnabled:YES]];
}

- (MobaSkillCastController *)pointController {
    MobaPointCastConfiguration *configuration =
        [MobaPointCastConfiguration defaultConfigurationWithTargetMode:MobaPointCastTargetModeGround
                                                           skillKeyCode:69
                                                             heroAnchor:CGPointMake(1000, 700)
                                                            wheelRadius:100
                                                          deadzoneRatio:0.10
                                                         fullRangeRatio:1.0
                                                          curveExponent:1.0
                                                           minimumRadii:MobaAimRadiiMake(0, 0, 0, 0)
                                                           maximumRadii:MobaAimRadiiMake(200, 200, 200, 200)
                                                            cancelAction:[MobaCastCancelAction releaseOnlyAction]];
    MobaPointCastStrategy *strategy = [[MobaPointCastStrategy alloc]
        initWithDispatcher:self.dispatcher configuration:configuration];
    return [self controllerForDescriptor:[self descriptorWithType:MobaProfileSkillCastTypePoint
                                                        allowCancel:YES
                                                           strategy:strategy
                                                              label:@"W"
                                                            opacity:0.72
                                                 interactionEnabled:YES]];
}

- (void)testBattleGatePrecedesSessionAndRejectedBeginOwnsNothing {
    self.gate.battleInputAllowed = NO;
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    XCTAssertFalse([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(controller.session.state, MobaCastStateIdle);
    XCTAssertNil(controller.activeTouchToken);
    XCTAssertEqual(strategy.events.count, 0u);
}

- (void)testBeginOrdersCancelZoneBeforeStrategyAndThenMarksPressed {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    strategy.events = self.zone.events;
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    XCTAssertTrue([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointMake(10, 20)]);
    XCTAssertEqualObjects(self.zone.events, (@[@"zone-begin", @"strategy-begin"]));
    XCTAssertTrue(controller.isPressed);
    XCTAssertEqual(controller.session.state, MobaCastStateAimingDefault);
}

- (void)testInstantBeginDoesNotUseCancelZone {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:YES strategy:strategy];
    XCTAssertTrue([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(self.zone.events.count, 0u);
}

- (void)testAimedAllowCancelFalseDoesNotUseCancelZone {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:NO strategy:strategy];
    XCTAssertTrue([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(self.zone.events.count, 0u);
}

- (void)testSecondTokenCannotTakeOwnership {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    NSObject *owner = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:owner streamViewPoint:CGPointZero]);
    XCTAssertFalse([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(controller.activeTouchToken, owner);
}

- (void)testBeginStrategyFailureRollsBackAndRequestsLifecycleCancellation {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    strategy.beginAllowed = NO;
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    XCTAssertFalse([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(self.cancellationDelegate.cancellationCount, 1u);
    XCTAssertNil(controller.activeTouchToken);
    XCTAssertEqual(controller.session.state, MobaCastStateIdle);
    XCTAssertNil(self.zone.activeToken);
    XCTAssertTrue([strategy.events containsObject:@"strategy-reset"]);
}

- (void)testCancelZoneBeginFailureRollsBackBeforeStrategyBegin {
    self.zone.beginAllowed = NO;
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    XCTAssertFalse([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertFalse([strategy.events containsObject:@"strategy-begin"]);
    XCTAssertEqual(controller.session.state, MobaCastStateIdle);
    XCTAssertEqual(self.cancellationDelegate.cancellationCount, 1u);
}

- (void)testUpdateUsesCurrentMinusInitialDisplacementForDirectional {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointMake(40, 50)]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(90, 50)]);
    MobaDirectionalCastStrategy *strategy = (MobaDirectionalCastStrategy *)controller.descriptor.strategy;
    XCTAssertEqualWithAccuracy(strategy.latestTarget.x, 1100, 0.001);
    XCTAssertEqualWithAccuracy(strategy.latestTarget.y, 700, 0.001);
}

- (void)testPointUsesSameDisplacementForDirectionAndDistance {
    MobaSkillCastController *controller = [self pointController];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointMake(10, 10)]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(60, 10)]);
    MobaPointCastStrategy *strategy = (MobaPointCastStrategy *)controller.descriptor.strategy;
    XCTAssertEqualWithAccuracy(strategy.latestTarget.x, 1088.888, 0.01);
    XCTAssertEqualWithAccuracy(strategy.latestTarget.y, 700, 0.01);
}

- (void)testUpdateDoesNotDirectlySendCursorWithoutCoalescer {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testAcceptedSessionUpdateRejectedByStrategyRequestsLifecycleCancellation {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    strategy.updateAllowed = NO;
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:NO strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertFalse([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(30, 0)]);
    XCTAssertEqual(self.cancellationDelegate.cancellationCount, 1u);
    XCTAssertEqual(controller.session.state, MobaCastStateIdle);
    XCTAssertNil(controller.activeTouchToken);
}

- (void)testCancelZoneApplyFailureRequestsLifecycleCancellation {
    self.zone.applyAllowed = NO;
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertFalse([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(30, 0)]);
    XCTAssertEqual(self.cancellationDelegate.cancellationCount, 1u);
}

- (void)testIntentionalCancelReleaseAloneCallsStrategyCancel {
    self.zone.inside = YES;
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    XCTAssertTrue([strategy.events containsObject:@"strategy-cancel"]);
    XCTAssertFalse([strategy.events containsObject:@"strategy-commit"]);
}

- (void)testExitCancelZoneThenReleaseCommits {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    self.zone.inside = YES;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    self.zone.inside = NO;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertTrue([strategy.events containsObject:@"strategy-commit"]);
}

- (void)testNormalDirectionalReleaseAtomicallySendsFinalCursorBeforeKeyUp {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1100:700", @"key:81:up"]));
}

- (void)testDirectionalEndedEndpointWithoutMoveCommitsEndpointTarget {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1100:700", @"key:81:up"]));
}

- (void)testPointEndedEndpointWithoutMoveUsesFinalDirectionAndDistance {
    MobaSkillCastController *controller = [self pointController];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointMake(10, 10)]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(60, 10)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1089:700", @"key:69:up"]));
}

- (void)testEndedEndpointEnteringCancelZoneOverridesEarlierOutsideMove {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    self.zone.inside = NO;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    self.zone.inside = YES;
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertEqual([[strategy.events filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"SELF == 'strategy-cancel'"]] count], 1u);
    XCTAssertFalse([strategy.events containsObject:@"strategy-commit"]);
}

- (void)testEndedEndpointLeavingCancelZoneCommitsCurrentState {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    self.zone.inside = YES;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    self.zone.inside = NO;
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertEqual([[strategy.events filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"SELF == 'strategy-commit'"]] count], 1u);
    XCTAssertFalse([strategy.events containsObject:@"strategy-cancel"]);
}

- (void)testEndedEndpointReenteringAfterEnterExitCancels {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    self.zone.inside = YES;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    self.zone.inside = NO;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    self.zone.inside = YES;
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(60, 0)]);
    XCTAssertEqual([[strategy.events filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"SELF == 'strategy-cancel'"]] count], 1u);
}

- (void)testDirectionalEndedEndpointInsideMeaningfulThresholdRestoresDefaultTarget {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(5, 0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1000:600", @"key:81:up"]));
}

- (void)testFinalEndpointSemanticFailureRequestsLifecycleCancellationWithoutStaleCommit {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:YES];
    __weak MobaInputDispatcher *dispatcher = self.dispatcher;
    self.cancellationDelegate.handler = ^(MobaSkillCastController *cancelledController) {
        [dispatcher releaseAllInputs];
        [cancelledController silentReset];
    };
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    [self drainDispatcher];
    [self.sink clear];
    self.zone.applyAllowed = NO;
    XCTAssertFalse([controller endInteractionWithToken:token streamViewPoint:CGPointMake(60, 0)]);
    [self drainDispatcher];
    XCTAssertEqual(self.cancellationDelegate.cancellationCount, 1u);
    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
    XCTAssertNil(controller.activeTouchToken);
}

- (void)testEndpointProcessingStillConsumesTerminalOutcomeOnlyOnce {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:NO strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    XCTAssertFalse([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertEqual([[strategy.events filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"SELF == 'strategy-commit'"]] count], 1u);
}

- (void)testFinalEndpointCommitDiscardsPendingCoalescedPointBeforeAtomicFinalInput {
    MobaSkillEndpointDriver *driver = [[MobaSkillEndpointDriver alloc] init];
    MobaCursorCoalescer *coalescer = [[MobaCursorCoalescer alloc]
        initWithDispatcher:self.dispatcher driver:driver];
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO
                                                                  cursorCoalescer:coalescer];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(30, 0)]);
    XCTAssertTrue(coalescer.hasPendingPoint);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertFalse(coalescer.hasPendingPoint);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1100:700", @"key:81:up"]));
}

- (void)testStaleCoalescerTickAfterEndpointCommitSendsNoInput {
    MobaSkillEndpointDriver *driver = [[MobaSkillEndpointDriver alloc] init];
    MobaCursorCoalescer *coalescer = [[MobaCursorCoalescer alloc]
        initWithDispatcher:self.dispatcher driver:driver];
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO
                                                                  cursorCoalescer:coalescer];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(30, 0)]);
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    [self drainDispatcher];
    [self.sink clear];
    [driver tick];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testTouchCancellationUsesLifecycleReleaseAndNeverConfiguredCancel {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:YES];
    __weak MobaInputDispatcher *dispatcher = self.dispatcher;
    self.cancellationDelegate.handler = ^(MobaSkillCastController *cancelledController) {
        [dispatcher releaseAllInputs];
        [cancelledController silentReset];
    };
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller cancelInteractionWithToken:token]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
    XCTAssertNil(controller.activeTouchToken);
}

- (void)testSilentResetIsIdempotentAndSendsNoInput {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:YES];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    [self.sink clear];
    [controller silentReset];
    [controller silentReset];
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(controller.session.state, MobaCastStateIdle);
}

- (void)testViewOwnsFirstTokenAndRejectsSecondWithoutPrivateUITouch {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    UIView *streamView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1000, 600)];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc] initWithController:controller
                                                          streamCoordinateView:streamView];
    [view setMobaLocalInteractionEnabled:YES];
    NSObject *owner = [NSObject new];
    XCTAssertTrue([view beginInteractionWithToken:owner streamViewPoint:CGPointMake(10, 20)]);
    XCTAssertFalse([view beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(view.activeTouchToken, owner);
    XCTAssertTrue(view.isPressed);
}

- (void)testNonOwnerUpdateEndAndCancelAreIgnored {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:controller streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    NSObject *owner = [NSObject new];
    NSObject *other = [NSObject new];
    XCTAssertTrue([view beginInteractionWithToken:owner streamViewPoint:CGPointZero]);
    XCTAssertFalse([view updateInteractionWithToken:other streamViewPoint:CGPointMake(1, 1)]);
    XCTAssertFalse([view endInteractionWithToken:other streamViewPoint:CGPointMake(1, 1)]);
    XCTAssertFalse([view cancelInteractionWithToken:other]);
    XCTAssertEqual(view.activeTouchToken, owner);
}

- (void)testViewNormalEndClearsOwnershipAndPressedExactlyOnce {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:controller streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    NSObject *token = [NSObject new];
    XCTAssertTrue([view beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([view endInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertFalse([view endInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertNil(view.activeTouchToken);
    XCTAssertFalse(view.isPressed);
}

- (void)testUIHiddenAndNonBattleModesNeverAcceptGameplayInput {
    for (NSNumber *modeValue in @[@(MobaOverlayModeUI), @(MobaOverlayModeLayoutEdit), @(MobaOverlayModeSkillTuning)]) {
        MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
        MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                               allowCancel:NO strategy:strategy];
        MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
            initWithController:controller streamCoordinateView:[[UIView alloc] init]];
        [view setMobaLocalInteractionEnabled:YES];
        [view setMode:modeValue.integerValue];
        [self prepareSkillViewForHitTesting:view];
        XCTAssertEqual(view.hidden, modeValue.integerValue == MobaOverlayModeUI);
        XCTAssertFalse(view.userInteractionEnabled);
        XCTAssertNil([self centerHitForSkillView:view]);
        XCTAssertFalse([view beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
        XCTAssertEqual(strategy.events.count, 0u);
    }
}

- (void)testSkillTuningRequiresExplicitPerCandidateInteractionOptIn {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:controller streamCoordinateView:[[UIView alloc] init]];
    [view setMode:MobaOverlayModeSkillTuning];
    [view setMobaLocalInteractionEnabled:YES];
    [self prepareSkillViewForHitTesting:view];
    XCTAssertNil([self centerHitForSkillView:view]);
    view.skillTuningInteractionEnabled = YES;
    XCTAssertEqual([self centerHitForSkillView:view], view);
    XCTAssertTrue([view beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqual(strategy.events.count, 1u);
}

- (void)testLayoutProfileControlsHitSizeLabelOpacityAndZIndex {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillRuntimeDescriptor *descriptor = [self descriptorWithType:MobaProfileSkillCastTypeInstant
                                                          allowCancel:NO strategy:strategy label:@"R"
                                                              opacity:0.42 interactionEnabled:YES];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:[self controllerForDescriptor:descriptor]
        streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    XCTAssertEqualWithAccuracy(view.intrinsicContentSize.width, 110.4, 0.001);
    XCTAssertEqualWithAccuracy(view.intrinsicContentSize.height, 105.6, 0.001);
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.42, 0.001);
    XCTAssertEqualWithAccuracy(view.layer.zPosition, 20, 0.001);
    XCTAssertEqualObjects(view.descriptor.displayLabel, @"R");
    XCTAssertEqualObjects(view.displayLabel, @"R");
}

- (void)testZeroNormalOpacityDoesNotDisableInteraction {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillRuntimeDescriptor *descriptor = [self descriptorWithType:MobaProfileSkillCastTypeInstant
                                                          allowCancel:NO strategy:strategy label:@"Q"
                                                              opacity:0 interactionEnabled:YES];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:[self controllerForDescriptor:descriptor]
        streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    [self prepareSkillViewForHitTesting:view];
    XCTAssertEqualWithAccuracy(view.alpha, 1, 0.001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0, 0.001);
    XCTAssertTrue(view.userInteractionEnabled);
    XCTAssertEqual([self centerHitForSkillView:view], view);
    XCTAssertEqualObjects(view.displayLabel, @"Q");
    XCTAssertEqual(view.descriptor.hostKeyCode, 81);
    XCTAssertTrue([view beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
}

- (void)testZeroGlobalOpacityDoesNotDisableSkillHitTesting {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillRuntimeDescriptor *descriptor = [self descriptorWithType:MobaProfileSkillCastTypeInstant
                                                          allowCancel:NO strategy:strategy label:@"W"
                                                              opacity:0.7 interactionEnabled:YES];
    MobaSkillCastController *controller = [self controllerForDescriptor:descriptor];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:controller streamCoordinateView:[[UIView alloc] init]];
    MobaControlLayoutPresentation *presentation = [[MobaControlLayoutPresentation alloc]
        initWithCenterX:0.5 centerY:0.5 visualSize:CGSizeMake(92, 88)
        hitAreaScale:1.2 wheelRadiusPt:@100 normalOpacity:0.7 pressedOpacity:0.8
        disabledOpacity:0.3 zIndex:20 interactionEnabled:YES];
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:0
                            previewState:MobaControlOpacityPreviewStateAutomatic];
    [view setMobaLocalInteractionEnabled:YES];
    [self prepareSkillViewForHitTesting:view];
    XCTAssertEqual(view.alpha, 1.0);
    XCTAssertEqual(view.effectiveVisualOpacity, 0.0);
    XCTAssertEqual([self centerHitForSkillView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
}

- (void)testProfileInteractionDisabledUsesDisabledOpacityAndRejectsInput {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillRuntimeDescriptor *descriptor = [self descriptorWithType:MobaProfileSkillCastTypeInstant
                                                          allowCancel:NO strategy:strategy label:@"Q"
                                                              opacity:0.7 interactionEnabled:NO];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:[self controllerForDescriptor:descriptor]
        streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    [self prepareSkillViewForHitTesting:view];
    XCTAssertFalse(view.userInteractionEnabled);
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.30, 0.001);
    XCTAssertNil([self centerHitForSkillView:view]);
    XCTAssertFalse([view beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
}

- (void)testLifecycleDisableThenReleaseAllAndResetDoesNotDuplicateSkillUpOrCancelAction {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:YES];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:controller streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    NSObject *token = [NSObject new];
    XCTAssertTrue([view beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    [self.sink clear];
    [view setMobaLocalInteractionEnabled:NO];
    [self.dispatcher releaseAllInputs];
    [view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonApplicationDidEnterBackground];
    [view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonApplicationDidEnterBackground];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:81:up"]));
    XCTAssertNil(view.activeTouchToken);
    XCTAssertFalse(view.isPressed);
}

- (void)testFourViewsHaveIndependentSessionsAndOwners {
    NSMutableArray<MobaSkillButtonView *> *views = [[NSMutableArray alloc] init];
    NSMutableSet<MobaCastSession *> *sessions = [[NSMutableSet alloc] init];
    for (NSString *label in @[@"Q", @"W", @"E", @"R"]) {
        MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
        MobaSkillRuntimeDescriptor *descriptor = [self descriptorWithType:MobaProfileSkillCastTypeInstant
                                                              allowCancel:NO strategy:strategy label:label
                                                                  opacity:0.7 interactionEnabled:YES];
        MobaSkillCastController *controller = [self controllerForDescriptor:descriptor];
        [sessions addObject:controller.session];
        MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
            initWithController:controller streamCoordinateView:[[UIView alloc] init]];
        [view setMobaLocalInteractionEnabled:YES];
        [views addObject:view];
    }
    XCTAssertEqual(sessions.count, 4u);
    [views enumerateObjectsUsingBlock:^(MobaSkillButtonView *view, NSUInteger index, BOOL *stop) {
        XCTAssertTrue([view beginInteractionWithToken:[[NSObject alloc] init]
                                      streamViewPoint:CGPointMake(index, index)]);
    }];
    XCTAssertEqual([[NSSet setWithArray:[views valueForKey:@"activeTouchToken"]] count], 4u);
}

- (void)testInstantReleaseSubmitsExactlyOneTimedTap {
    MobaSkillCastController *controller = [self instantController];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:82:down"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
    [self.scheduler runAll];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:82:down", @"key:82:up"]));
}

- (void)testInstantMoveNeverSubmitsInputBeforeRelease {
    MobaSkillCastController *controller = [self instantController];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(100, 100)]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
    XCTAssertEqual(self.scheduler.pendingCount, 0u);
}

- (void)testDirectionalNoDragReleaseCommitsDefaultUpTarget {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointMake(20, 20)]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(20, 20)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1000:600", @"key:81:up"]));
}

- (void)testPointNoDragReleaseCommitsDefaultUpTarget {
    MobaSkillCastController *controller = [self pointController];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointMake(20, 20)]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(20, 20)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1000:500", @"key:69:up"]));
}

- (void)testEnterExitAndReenterCancelZoneCancelsOnRelease {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    self.zone.inside = YES;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    self.zone.inside = NO;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    self.zone.inside = YES;
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(60, 0)]);
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(60, 0)]);
    XCTAssertEqual([[strategy.events filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"SELF == 'strategy-cancel'"]] count], 1u);
}

- (void)testIntentionalConfiguredCancelOrdersEscapeBeforeSkillUpWithoutCursor {
    self.zone.inside = YES;
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:YES];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertTrue([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointMake(40, 0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"key:27:down", @"key:81:up"]));
    XCTAssertFalse([[self.sink.events componentsJoinedByString:@","] containsString:@"cursor"]);
}

- (void)testRepeatedReleaseCannotRepeatTerminalInput {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    [self.sink clear];
    XCTAssertTrue([controller endInteractionWithToken:token streamViewPoint:CGPointZero]);
    XCTAssertFalse([controller endInteractionWithToken:token streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.events, (@[@"cursor:1000:600", @"key:81:up"]));
}

- (void)testStaleTokenCannotUpdateAfterSilentReset {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:YES strategy:strategy];
    NSObject *token = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:token streamViewPoint:CGPointZero]);
    [controller silentReset];
    XCTAssertFalse([controller updateInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertFalse([controller endInteractionWithToken:token streamViewPoint:CGPointMake(50, 0)]);
    XCTAssertFalse([controller cancelInteractionWithToken:token]);
}

- (void)testSilentInteractionDisableRejectsNewCastWithoutInput {
    MobaSkillCastController *controller = [self directionalControllerAllowCancel:NO];
    [controller setInteractionEnabled:NO];
    XCTAssertFalse([controller beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.events.count, 0u);
}

- (void)testBattlePressedAppearanceUsesProfilePressedOpacity {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeInstant
                                                           allowCancel:NO strategy:strategy];
    MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
        initWithController:controller streamCoordinateView:[[UIView alloc] init]];
    [view setMobaLocalInteractionEnabled:YES];
    XCTAssertTrue([view beginInteractionWithToken:[NSObject new] streamViewPoint:CGPointZero]);
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.88, 0.001);
}

- (void)testNewCastAfterResetDoesNotInheritPriorOwnerOrPoints {
    MobaSkillTestStrategy *strategy = [[MobaSkillTestStrategy alloc] init];
    MobaSkillCastController *controller = [self fakeControllerWithType:MobaProfileSkillCastTypeDirectional
                                                           allowCancel:NO strategy:strategy];
    NSObject *first = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:first streamViewPoint:CGPointMake(100, 200)]);
    [controller silentReset];
    NSObject *second = [NSObject new];
    XCTAssertTrue([controller beginInteractionWithToken:second streamViewPoint:CGPointMake(7, 9)]);
    XCTAssertEqual(controller.activeTouchToken, second);
    XCTAssertTrue(CGPointEqualToPoint(controller.initialStreamViewPoint, CGPointMake(7, 9)));
    XCTAssertTrue(CGPointEqualToPoint(controller.latestStreamViewPoint, CGPointMake(7, 9)));
}

@end
