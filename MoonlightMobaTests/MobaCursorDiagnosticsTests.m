//
//  MobaCursorDiagnosticsTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Core/MobaCursorDiagnostics.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"
#import "../Limelight/Input/MOBA/Geometry/MobaVideoGeometry.h"

@interface MobaFakeBattleInputGate : NSObject <MobaBattleInputGate>
@property (nonatomic, getter=isBattleInputAllowed) BOOL battleInputAllowed;
@end

@implementation MobaFakeBattleInputGate
@end

@interface MobaCursorRecordingSink : NSObject <MobaInputSink>
- (NSArray<NSValue *> *)cursorSnapshot;
@end

static NSValue *MobaTestValueWithPoint(CGPoint point) {
    return [NSValue value:&point withObjCType:@encode(CGPoint)];
}

@implementation MobaCursorRecordingSink {
    NSMutableArray<NSValue *> *_cursorPoints;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cursorPoints = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    (void)keyCode;
    (void)down;
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    @synchronized (self) {
        [_cursorPoints addObject:MobaTestValueWithPoint(point)];
    }
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    (void)button;
    (void)down;
}

- (NSArray<NSValue *> *)cursorSnapshot {
    @synchronized (self) {
        return [_cursorPoints copy];
    }
}

@end

@interface MobaCursorDiagnosticsTests : XCTestCase
@property (nonatomic, strong) MobaFakeBattleInputGate *gate;
@property (nonatomic, strong) MobaCursorRecordingSink *sink;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@property (nonatomic, strong) MobaCursorDiagnostics *diagnostics;
@end

@implementation MobaCursorDiagnosticsTests

- (void)setUp {
    [super setUp];
    self.gate = [[MobaFakeBattleInputGate alloc] init];
    self.sink = [[MobaCursorRecordingSink alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink];
    self.diagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:self.dispatcher
                                                               inputGate:self.gate];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)testDiagnosticListContainsTheNineFixedCanvasPoints {
    CGPoint expected[] = {
        CGPointMake(0, 0), CGPointMake(1280, 0), CGPointMake(2559, 0),
        CGPointMake(0, 720), CGPointMake(1280, 720), CGPointMake(2559, 720),
        CGPointMake(0, 1439), CGPointMake(1280, 1439), CGPointMake(2559, 1439),
    };

    XCTAssertEqual(MobaCursorDiagnosticPointCount, 9u);
    for (NSUInteger index = 0; index < MobaCursorDiagnosticPointCount; index++) {
        CGPoint actual;
        XCTAssertTrue(MobaCursorDiagnosticPointAtIndex(index, &actual));
        XCTAssertEqual(actual.x, expected[index].x);
        XCTAssertEqual(actual.y, expected[index].y);
    }
}

- (void)testResolutionMismatchRejectsDiagnosticInput {
    self.gate.battleInputAllowed = MobaStreamResolutionAllowsBattleMode(CGSizeMake(1920, 1080));

    XCTAssertFalse([self.diagnostics sendPointAtIndex:4]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorSnapshot.count, 0u);
}

- (void)testNonBattleModeRejectsDiagnosticInput {
    self.gate.battleInputAllowed = NO;

    XCTAssertFalse([self.diagnostics sendPointAtIndex:0]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorSnapshot.count, 0u);
}

- (void)testInvalidDiagnosticIndexIsRejected {
    self.gate.battleInputAllowed = YES;

    XCTAssertFalse([self.diagnostics sendPointAtIndex:MobaCursorDiagnosticPointCount]);
    [self drainDispatcher];
    XCTAssertEqual(self.sink.cursorSnapshot.count, 0u);
}

- (void)testEachDiagnosticActionSendsOneCursorEvent {
    self.gate.battleInputAllowed = YES;

    for (NSUInteger index = 0; index < MobaCursorDiagnosticPointCount; index++) {
        XCTAssertTrue([self.diagnostics sendPointAtIndex:index]);
    }
    [self drainDispatcher];

    NSMutableArray<NSValue *> *expected = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < MobaCursorDiagnosticPointCount; index++) {
        CGPoint point;
        MobaCursorDiagnosticPointAtIndex(index, &point);
        [expected addObject:MobaTestValueWithPoint(point)];
    }
    XCTAssertEqualObjects(self.sink.cursorSnapshot, expected);
}

- (void)testDiagnosticCursorEventWaitsForDispatcherQueue {
    self.gate.battleInputAllowed = YES;
    dispatch_semaphore_t queueStarted = dispatch_semaphore_create(0);
    dispatch_semaphore_t releaseQueue = dispatch_semaphore_create(0);

    [self.dispatcher notifyWhenIdle:^{
        dispatch_semaphore_signal(queueStarted);
        dispatch_semaphore_wait(releaseQueue, DISPATCH_TIME_FOREVER);
    }];
    XCTAssertEqual(dispatch_semaphore_wait(queueStarted,
                                           dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0);

    XCTAssertTrue([self.diagnostics sendPointAtIndex:4]);
    XCTAssertEqual(self.sink.cursorSnapshot.count, 0u);

    dispatch_semaphore_signal(releaseQueue);
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.cursorSnapshot,
                          (@[MobaTestValueWithPoint(CGPointMake(1280, 720))]));
}

@end
