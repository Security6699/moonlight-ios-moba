//
//  MobaInputDispatcherTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

@interface MobaFakeInputSink : NSObject <MobaInputSink>
- (NSArray<NSString *> *)eventSnapshot;
- (void)clearEvents;
@end

@implementation MobaFakeInputSink {
    NSMutableArray<NSString *> *_events;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)recordEvent:(NSString *)event {
    @synchronized (self) {
        [_events addObject:event];
    }
}

- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down {
    [self recordEvent:[NSString stringWithFormat:@"key:%u:%@", (unsigned int)keyCode, down ? @"down" : @"up"]];
}

- (void)moveCursorToCanvasPoint:(CGPoint)point {
    [self recordEvent:[NSString stringWithFormat:@"cursor:%.0f:%.0f", point.x, point.y]];
}

- (void)sendMouseButton:(int)button down:(BOOL)down {
    [self recordEvent:[NSString stringWithFormat:@"mouse:%d:%@", button, down ? @"down" : @"up"]];
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

@interface MobaManualInputScheduler : NSObject <MobaInputScheduling>
@property (nonatomic, readonly) NSUInteger pendingCount;
- (void)runAll;
@end

@implementation MobaManualInputScheduler {
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
    (void)delayMs;
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

@interface MobaInputDispatcherTests : XCTestCase
@property (nonatomic, strong) MobaFakeInputSink *sink;
@property (nonatomic, strong) MobaManualInputScheduler *scheduler;
@property (nonatomic, strong) MobaInputDispatcher *dispatcher;
@end

@implementation MobaInputDispatcherTests

- (void)setUp {
    [super setUp];
    self.sink = [[MobaFakeInputSink alloc] init];
    self.scheduler = [[MobaManualInputScheduler alloc] init];
    self.dispatcher = [[MobaInputDispatcher alloc] initWithSink:self.sink scheduler:self.scheduler];
}

- (void)drainDispatcher {
    XCTestExpectation *idle = [self expectationWithDescription:@"dispatcher idle"];
    [self.dispatcher notifyWhenIdle:^{
        [idle fulfill];
    }];
    [self waitForExpectations:@[idle] timeout:1.0];
}

- (void)testEventsPreserveSubmissionOrder {
    [self.dispatcher setKeyCode:10 down:YES];
    [self.dispatcher moveCursorToCanvasPoint:CGPointMake(100, 200)];
    [self.dispatcher setMouseButton:1 down:YES];
    [self.dispatcher setKeyCode:10 down:NO];
    [self.dispatcher setMouseButton:1 down:NO];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"key:10:down", @"cursor:100:200", @"mouse:1:down",
                             @"key:10:up", @"mouse:1:up"]));
}

- (void)testDuplicateKeyDownIsSuppressed {
    [self.dispatcher setKeyCode:20 down:YES];
    [self.dispatcher setKeyCode:20 down:YES];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:20:down"]));
}

- (void)testInvalidKeyUpIsSuppressed {
    [self.dispatcher setKeyCode:30 down:NO];
    [self drainDispatcher];

    XCTAssertEqual(self.sink.eventSnapshot.count, 0u);
}

- (void)testDuplicateAndInvalidMouseTransitionsAreSuppressed {
    [self.dispatcher setMouseButton:2 down:NO];
    [self.dispatcher setMouseButton:2 down:YES];
    [self.dispatcher setMouseButton:2 down:YES];
    [self.dispatcher setMouseButton:2 down:NO];
    [self.dispatcher setMouseButton:2 down:NO];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"mouse:2:down", @"mouse:2:up"]));
}

- (void)testTapDoesNotWaitForScheduledKeyUp {
    [self.dispatcher tapKeyCode:40 durationMs:5000];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:40:down"]));
    XCTAssertEqual(self.scheduler.pendingCount, 1u);
}

- (void)testTapKeyDownPrecedesScheduledKeyUp {
    [self.dispatcher tapKeyCode:41 durationMs:30];
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:41:down", @"key:41:up"]));
}

- (void)testFinalCursorPrecedesSkillKeyUpWithoutInterleaving {
    [self.dispatcher setKeyCode:50 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.dispatcher commitFinalCursorPoint:CGPointMake(500, 600) releasingKeyCode:50];
    [self.dispatcher setKeyCode:51 down:YES];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"cursor:500:600", @"key:50:up", @"key:51:down"]));
}

- (void)testKeyboardCancelPrecedesSkillKeyUp {
    [self.dispatcher setKeyCode:60 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.dispatcher cancelWithKeyCode:27 durationMs:30 releasingSkillKeyCode:60];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:27:down", @"key:60:up"]));
}

- (void)testMouseCancelPrecedesSkillKeyUp {
    [self.dispatcher setKeyCode:61 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.dispatcher cancelWithMouseButton:2 releasingSkillKeyCode:61];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"mouse:2:down", @"mouse:2:up", @"key:61:up"]));
}

- (void)testPublicMethodsCanBeCalledOffMainThread {
    XCTestExpectation *submitted = [self expectationWithDescription:@"submitted off main thread"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.dispatcher setKeyCode:62 down:YES];
        [self.dispatcher setMouseButton:3 down:YES];
        [submitted fulfill];
    });
    [self waitForExpectations:@[submitted] timeout:1.0];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:62:down", @"mouse:3:down"]));
}

- (void)testDifferentCallerThreadsPreserveControlledSubmissionOrder {
    dispatch_queue_t keyQueue = dispatch_queue_create("MobaInputDispatcherTests.key", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t pointerQueue = dispatch_queue_create("MobaInputDispatcherTests.pointer", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t keySubmitted = dispatch_semaphore_create(0);
    XCTestExpectation *submitted = [self expectationWithDescription:@"submitted from different caller threads"];

    dispatch_async(keyQueue, ^{
        [self.dispatcher setKeyCode:63 down:YES];
        dispatch_semaphore_signal(keySubmitted);
    });
    dispatch_async(pointerQueue, ^{
        dispatch_semaphore_wait(keySubmitted, DISPATCH_TIME_FOREVER);
        [self.dispatcher moveCursorToCanvasPoint:CGPointMake(300, 400)];
        [self.dispatcher setMouseButton:4 down:YES];
        [submitted fulfill];
    });

    [self waitForExpectations:@[submitted] timeout:1.0];
    [self drainDispatcher];
    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"key:63:down", @"cursor:300:400", @"mouse:4:down"]));
}

- (void)testReleaseAllInputsReleasesEveryStateExactlyOnce {
    [self.dispatcher setKeyCode:72 down:YES];
    [self.dispatcher setKeyCode:71 down:YES];
    [self.dispatcher setMouseButton:2 down:YES];
    [self.dispatcher setMouseButton:1 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.dispatcher releaseAllInputs];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot,
                          (@[@"key:71:up", @"key:72:up", @"mouse:1:up",
                             @"mouse:2:up"]));
}

- (void)testRepeatedReleaseAllInputsIsIdempotent {
    [self.dispatcher setKeyCode:80 down:YES];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.dispatcher releaseAllInputs];
    [self.dispatcher releaseAllInputs];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:80:up"]));
}

- (void)testReleaseAllPreventsDelayedTapKeyUpFromRepeatingRelease {
    [self.dispatcher tapKeyCode:90 durationMs:30];
    [self drainDispatcher];
    [self.sink clearEvents];

    [self.dispatcher releaseAllInputs];
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:90:up"]));
}

- (void)testManualKeyUpPreventsDelayedTapKeyUpFromRepeatingRelease {
    [self.dispatcher tapKeyCode:91 durationMs:30];
    [self drainDispatcher];

    [self.dispatcher setKeyCode:91 down:NO];
    [self drainDispatcher];
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:91:down", @"key:91:up"]));
}

- (void)testRepeatedTapWhileKeyIsDownDoesNotScheduleAnotherRelease {
    [self.dispatcher tapKeyCode:92 durationMs:30];
    [self.dispatcher tapKeyCode:92 durationMs:30];
    [self drainDispatcher];

    XCTAssertEqual(self.scheduler.pendingCount, 1u);
    [self.scheduler runAll];
    [self drainDispatcher];

    XCTAssertEqualObjects(self.sink.eventSnapshot, (@[@"key:92:down", @"key:92:up"]));
}

@end
