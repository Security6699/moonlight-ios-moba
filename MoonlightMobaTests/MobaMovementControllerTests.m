//
//  MobaMovementControllerTests.m
//  MoonlightMobaTests
//


#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Controls/MobaMovementController.h"
#import "../Limelight/Input/MOBA/Controls/MoveJoystickView.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Core/MobaOverlayLifecycle.h"

@interface MoveJoystickView (MobaTesting)
- (BOOL)beginInteractionWithToken:(id)token displacement:(CGVector)displacement;
- (BOOL)updateInteractionWithToken:(id)token displacement:(CGVector)displacement;
- (BOOL)endInteractionWithToken:(id)token;
- (BOOL)cancelInteractionWithToken:(id)token;
@end

@interface MobaMovementFakeSink : NSObject <MobaInputSink>
- (NSArray<NSString *> *)eventSnapshot;
- (void)clearEvents;
@end

@implementation MobaMovementFakeSink {
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

@interface MobaMovementLifecycleEnvironment : NSObject <MobaOverlayLifecycleEnvironment>
@property (nonatomic, getter=isMobaBattleModeSupported) BOOL mobaBattleModeSupported;
@end

@implementation MobaMovementLifecycleEnvironment

- (void)setTraditionalOnScreenControlsSuppressed:(BOOL)suppressed {
    (void)suppressed;
}

@end

@interface MobaMovementCancellationDelegate : NSObject <MobaMovementControllerDelegate>
@property (nonatomic, strong) MobaOverlayLifecycle *lifecycle;
@property (nonatomic) NSUInteger cancellationCount;
@end

@implementation MobaMovementCancellationDelegate

- (void)movementControllerDidRequestTouchCancellation:(MobaMovementController *)controller {
    (void)controller;
    self.cancellationCount++;
    [self.lifecycle touchesCancelled];
}

@end

@interface MobaMovementControllerTests : XCTestCase
@property (nonatomic, strong) MobaMovementFakeSink *sink;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaMovementController *controller;
@end

@implementation MobaMovementControllerTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaMovementFakeSink alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink];
    self.controller = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher
                     keyMapping:MobaDefaultMovementKeyMapping()
                    wheelRadius:100.0
                  deadZoneRatio:0.16
     directionHysteresisDegrees:8.0];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"movement dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)moveUp {
    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(0.0, -100.0)]);
}

- (void)moveUpRight {
    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(100.0, -100.0)]);
}

- (void)moveRight {
    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(100.0, 0.0)]);
}

- (void)moveDownRight {
    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(100.0, 100.0)]);
}

- (void)testNeutralToUpSendsOnlyWDown {
    [self moveUp];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:down"]));
}

- (void)testUpToUpRightSendsOnlyDDown {
    [self moveUp];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self moveUpRight];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:68:down"]));
}

- (void)testUpRightToRightSendsOnlyWUp {
    [self moveUpRight];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self moveRight];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up"]));
}

- (void)testRightToDownRightSendsOnlySDown {
    [self moveRight];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self moveDownRight];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:83:down"]));
}

- (void)testUpToDownReleasesWBeforePressingS {
    [self moveUp];
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(0.0, 100.0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"key:83:down"]));
}

- (void)testMultiKeyTransitionUsesWASDReleaseThenPressOrder {
    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(-100.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    [self moveDownRight];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"key:87:up", @"key:65:up",
                             @"key:83:down", @"key:68:down"]));
}

- (void)testUnchangedStateProducesNoEvents {
    [self moveRight];
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.controller updateDisplacement:CGVectorMake(200.0, 0.0)]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
}

- (void)testNormalEndReleasesEveryActiveMovementKeyOnce {
    NSObject *token = [[NSObject alloc] init];
    XCTAssertTrue([self.controller beginInteractionWithToken:token
                                                displacement:CGVectorMake(100.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.controller endInteractionWithToken:token]);
    XCTAssertFalse([self.controller endInteractionWithToken:token]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"key:68:up"]));
    XCTAssertEqual(self.controller.state, MobaJoystickStateNeutral);
    XCTAssertNil(self.controller.activeTouchToken);
}

- (void)testCustomKeyMappingIsUsedWithoutProfileStorage {
    MobaMovementController *customController = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher
                     keyMapping:MobaMovementKeyMappingMake(1, 2, 3, 4)
                    wheelRadius:100.0
                  deadZoneRatio:0.16
     directionHysteresisDegrees:8.0];

    XCTAssertTrue([customController updateDisplacement:CGVectorMake(100.0, -100.0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:1:down", @"key:4:down"]));
}

- (void)testFirstTouchTokenOwnsInteractionAndSecondIsRejected {
    NSObject *owner = [[NSObject alloc] init];
    NSObject *other = [[NSObject alloc] init];

    XCTAssertTrue([self.controller beginInteractionWithToken:owner
                                                displacement:CGVectorMake(0.0, -100.0)]);
    XCTAssertFalse([self.controller beginInteractionWithToken:other
                                                 displacement:CGVectorMake(100.0, 0.0)]);
    XCTAssertEqual(self.controller.activeTouchToken, owner);
    XCTAssertEqual(self.controller.state, MobaJoystickStateUp);
}

- (void)testNonOwnerMoveAndEndDoNotChangeInteraction {
    NSObject *owner = [[NSObject alloc] init];
    NSObject *other = [[NSObject alloc] init];
    XCTAssertTrue([self.controller beginInteractionWithToken:owner
                                                displacement:CGVectorMake(0.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertFalse([self.controller updateInteractionWithToken:other
                                                  displacement:CGVectorMake(100.0, 0.0)]);
    XCTAssertFalse([self.controller endInteractionWithToken:other]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertEqual(self.controller.activeTouchToken, owner);
    XCTAssertEqual(self.controller.state, MobaJoystickStateUp);
}

- (void)testLifecycleDisableAndResetAreSilentLocally {
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:self.controller
                        visualSize:MoveJoystickDefaultVisualSize
                       wheelRadius:100.0
                      hitAreaScale:MoveJoystickDefaultHitAreaScale];
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.controller beginInteractionWithToken:owner
                                                displacement:CGVectorMake(0.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    [view setMobaLocalInteractionEnabled:NO];
    [view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonApplicationWillResignActive];
    [self drainDispatcher];

    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
    XCTAssertEqual(self.controller.state, MobaJoystickStateNeutral);
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(self.controller.isInteractionEnabled);
    XCTAssertFalse(view.isPressed);
    XCTAssertEqualWithAccuracy(view.knobDisplacement.dx, 0.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.knobDisplacement.dy, 0.0, 0.000001);
    XCTAssertFalse([self.controller beginInteractionWithToken:[[NSObject alloc] init]
                                                 displacement:CGVectorMake(100.0, 0.0)]);
}

- (void)testOwnerCancellationUsesUnifiedLifecycleReleaseAndInvalidatesOldToken {
    MobaMovementLifecycleEnvironment *environment = [[MobaMovementLifecycleEnvironment alloc] init];
    environment.mobaBattleModeSupported = YES;
    MobaOverlayLifecycle *lifecycle = [[MobaOverlayLifecycle alloc]
        initWithEnvironment:environment
             inputDispatcher:self.dispatcher];
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:self.controller
                        visualSize:MoveJoystickDefaultVisualSize
                       wheelRadius:100.0
                      hitAreaScale:MoveJoystickDefaultHitAreaScale];
    [lifecycle registerLocalInteractionResetParticipant:view];
    [lifecycle start];

    MobaMovementCancellationDelegate *delegate = [[MobaMovementCancellationDelegate alloc] init];
    delegate.lifecycle = lifecycle;
    self.controller.delegate = delegate;

    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.controller beginInteractionWithToken:owner
                                                displacement:CGVectorMake(0.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    XCTAssertTrue([self.controller cancelInteractionWithToken:owner]);
    [self drainDispatcher];

    XCTAssertEqual(delegate.cancellationCount, 1u);
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up"]));
    XCTAssertEqual(self.controller.state, MobaJoystickStateNeutral);
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertTrue(lifecycle.isBattleInputAllowed);
    XCTAssertFalse([self.controller updateInteractionWithToken:owner
                                                  displacement:CGVectorMake(100.0, 0.0)]);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up"]));
}

- (void)testReleaseAllThenResetDoesNotSendDuplicateMovementKeyUp {
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:self.controller
                        visualSize:MoveJoystickDefaultVisualSize
                       wheelRadius:100.0
                      hitAreaScale:MoveJoystickDefaultHitAreaScale];
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([self.controller beginInteractionWithToken:owner
                                                displacement:CGVectorMake(100.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    [view setMobaLocalInteractionEnabled:NO];
    [self.dispatcher releaseAllInputs];
    [view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonTouchCancellation];
    [view resetMobaLocalInteractionForReason:MobaInputInterruptionReasonTouchCancellation];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:68:up", @"key:87:up"]));
}

- (void)testViewDefaultsAndZeroOpacityDoNotDisableInteraction {
    MobaMovementController *defaultController = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher
                     keyMapping:MobaDefaultMovementKeyMapping()
                    wheelRadius:MoveJoystickDefaultWheelRadius
                  deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
     directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
    MoveJoystickView *view = [[MoveJoystickView alloc] initWithMovementController:defaultController];

    XCTAssertTrue(CGSizeEqualToSize(view.visualSize, CGSizeMake(190.0, 190.0)));
    XCTAssertEqualWithAccuracy(view.wheelRadius, 95.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.hitAreaScale, 1.20, 0.000001);
    XCTAssertEqualWithAccuracy(view.normalOpacity, 0.66, 0.000001);
    XCTAssertEqualWithAccuracy(view.pressedOpacity, 0.82, 0.000001);
    XCTAssertEqualWithAccuracy(view.disabledOpacity, 0.30, 0.000001);

    view.normalOpacity = 0.0;
    XCTAssertEqualWithAccuracy(view.alpha, 0.0, 0.000001);
    XCTAssertTrue(view.userInteractionEnabled);
    XCTAssertTrue(view.isInteractionEnabled);
}

- (void)testViewSupportsCustomGeometryAndIndependentDisable {
    MobaMovementController *customController = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher
                     keyMapping:MobaDefaultMovementKeyMapping()
                    wheelRadius:80.0
                  deadZoneRatio:0.16
     directionHysteresisDegrees:8.0];
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:customController
                        visualSize:CGSizeMake(160.0, 170.0)
                       wheelRadius:80.0
                      hitAreaScale:1.5];

    XCTAssertTrue(CGSizeEqualToSize(view.intrinsicContentSize, CGSizeMake(240.0, 255.0)));
    view.interactionEnabled = NO;
    XCTAssertFalse(view.userInteractionEnabled);
    XCTAssertFalse(customController.isInteractionEnabled);
    XCTAssertEqualWithAccuracy(view.alpha, 0.30, 0.000001);
}

- (void)testConfigurationDisableReleasesMovementAndClearsLocalInteraction {
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:self.controller
                        visualSize:MoveJoystickDefaultVisualSize
                       wheelRadius:100.0
                      hitAreaScale:MoveJoystickDefaultHitAreaScale];
    view.frame = CGRectMake(0.0, 0.0, 228.0, 228.0);
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([view beginInteractionWithToken:owner
                                     displacement:CGVectorMake(100.0, -100.0)]);
    [view layoutIfNeeded];
    XCTAssertTrue(view.isPressed);
    XCTAssertNotEqualWithAccuracy(view.knobDisplacement.dx, 0.0, 0.000001);
    XCTAssertNotEqualWithAccuracy(view.knobDisplacement.dy, 0.0, 0.000001);
    [self drainDispatcher];
    [self.sink clearEvents];

    view.interactionEnabled = NO;
    [view layoutIfNeeded];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"key:68:up"]));
    XCTAssertEqual(self.controller.state, MobaJoystickStateNeutral);
    XCTAssertNil(self.controller.activeTouchToken);
    XCTAssertFalse(view.isPressed);
    XCTAssertEqualWithAccuracy(view.knobDisplacement.dx, 0.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.knobDisplacement.dy, 0.0, 0.000001);
    XCTAssertFalse(view.userInteractionEnabled);
    XCTAssertFalse(view.isInteractionEnabled);
    XCTAssertFalse(self.controller.isInteractionEnabled);
    XCTAssertEqualWithAccuracy(view.alpha, view.disabledOpacity, 0.000001);
}

- (void)testRepeatedConfigurationDisableDoesNotReleaseMovementTwice {
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:self.controller
                        visualSize:MoveJoystickDefaultVisualSize
                       wheelRadius:100.0
                      hitAreaScale:MoveJoystickDefaultHitAreaScale];
    NSObject *owner = [[NSObject alloc] init];
    XCTAssertTrue([view beginInteractionWithToken:owner
                                     displacement:CGVectorMake(100.0, -100.0)]);
    [self drainDispatcher];
    [self.sink clearEvents];

    view.interactionEnabled = NO;
    view.interactionEnabled = NO;
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:87:up", @"key:68:up"]));
}

- (void)testConfigurationReenableRejectsOldTokenAndAllowsNewOwnership {
    MoveJoystickView *view = [[MoveJoystickView alloc]
        initWithMovementController:self.controller
                        visualSize:MoveJoystickDefaultVisualSize
                       wheelRadius:100.0
                      hitAreaScale:MoveJoystickDefaultHitAreaScale];
    NSObject *oldToken = [[NSObject alloc] init];
    NSObject *newToken = [[NSObject alloc] init];
    XCTAssertTrue([view beginInteractionWithToken:oldToken
                                     displacement:CGVectorMake(0.0, -100.0)]);
    [self drainDispatcher];

    view.interactionEnabled = NO;
    [self drainDispatcher];
    [self.sink clearEvents];
    view.interactionEnabled = YES;

    XCTAssertFalse([view updateInteractionWithToken:oldToken
                                       displacement:CGVectorMake(100.0, 0.0)]);
    XCTAssertFalse([view endInteractionWithToken:oldToken]);
    XCTAssertFalse([view cancelInteractionWithToken:oldToken]);
    XCTAssertTrue([view beginInteractionWithToken:newToken
                                     displacement:CGVectorMake(100.0, 0.0)]);
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:68:down"]));
    XCTAssertEqual(self.controller.activeTouchToken, newToken);
    XCTAssertEqual(self.controller.state, MobaJoystickStateRight);
    XCTAssertTrue(view.isPressed);
    XCTAssertTrue(view.userInteractionEnabled);
    XCTAssertTrue(view.isInteractionEnabled);
    XCTAssertTrue(self.controller.isInteractionEnabled);
}

@end
