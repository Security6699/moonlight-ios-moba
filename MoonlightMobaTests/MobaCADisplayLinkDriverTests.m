//
//  MobaCADisplayLinkDriverTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Core/MobaCADisplayLinkDriver.h"

@interface MobaDriverFakeLink : NSObject <MobaDisplayLinkObject>
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic, strong) id target;
@property (nonatomic) SEL selector;
@property (nonatomic) NSUInteger addCount;
@property (nonatomic) NSUInteger invalidateCount;
@property (nonatomic, strong) NSRunLoop *runLoop;
@property (nonatomic, copy) NSRunLoopMode mode;
- (void)fire;
@end

@implementation MobaDriverFakeLink

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    self.addCount += 1;
    self.runLoop = runLoop;
    self.mode = mode;
}

- (void)invalidate {
    self.invalidateCount += 1;
}

- (void)fire {
    id target = self.target;
    SEL selector = self.selector;
    if (target == nil || selector == NULL || ![target respondsToSelector:selector]) {
        return;
    }
    IMP implementation = [target methodForSelector:selector];
    void (*invoke)(id, SEL, id) = (void (*)(id, SEL, id))implementation;
    invoke(target, selector, self);
}

@end

@interface MobaDriverFakeFactory : NSObject <MobaDisplayLinkCreating>
@property (nonatomic, readonly) NSArray<MobaDriverFakeLink *> *links;
@end

@implementation MobaDriverFakeFactory {
    NSMutableArray<MobaDriverFakeLink *> *_links;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _links = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray<MobaDriverFakeLink *> *)links { return [_links copy]; }

- (id<MobaDisplayLinkObject>)displayLinkWithTarget:(id)target selector:(SEL)selector {
    MobaDriverFakeLink *link = [[MobaDriverFakeLink alloc] init];
    link.target = target;
    link.selector = selector;
    [_links addObject:link];
    return link;
}

@end

@interface MobaCADisplayLinkDriverTests : XCTestCase
@property (nonatomic, strong) MobaDriverFakeFactory *factory;
@property (nonatomic, strong) MobaCADisplayLinkDriver *driver;
@end

@implementation MobaCADisplayLinkDriverTests

- (void)setUp {
    [super setUp];
    self.factory = [[MobaDriverFakeFactory alloc] init];
    self.driver = [[MobaCADisplayLinkDriver alloc] initWithFactory:self.factory];
}

- (void)testSupportedRatesSetPreferredFramesPerSecond {
    for (NSNumber *rateValue in @[@30, @60, @120]) {
        MobaDriverFakeFactory *factory = [[MobaDriverFakeFactory alloc] init];
        MobaCADisplayLinkDriver *driver = [[MobaCADisplayLinkDriver alloc] initWithFactory:factory];
        XCTAssertTrue([driver startWithUpdateRate:(MobaCursorUpdateRate)rateValue.unsignedIntegerValue
                                      tickHandler:^{}]);
        XCTAssertEqual(factory.links.lastObject.preferredFramesPerSecond,
                       rateValue.integerValue);
        [driver stop];
    }
}

- (void)testDefaultRateMapsTo60FramesPerSecond {
    XCTAssertEqual(MobaCursorUpdateRateDefault, MobaCursorUpdateRate60Hz);
    XCTAssertTrue([self.driver startWithUpdateRate:MobaCursorUpdateRateDefault tickHandler:^{}]);
    XCTAssertEqual(self.factory.links.firstObject.preferredFramesPerSecond, 60);
}

- (void)testInvalidRateIsRejectedWithoutCreatingLink {
    for (NSNumber *rateValue in @[@0, @29, @31, @59, @61, @119, @121]) {
        XCTAssertFalse([self.driver
            startWithUpdateRate:(MobaCursorUpdateRate)rateValue.unsignedIntegerValue
                    tickHandler:^{}]);
    }
    XCTAssertFalse(self.driver.isRunning);
    XCTAssertEqual(self.factory.links.count, 0u);
}

- (void)testStartAddsLinkToMainRunLoopCommonModesAndStopInvalidatesSynchronously {
    XCTAssertTrue([self.driver startWithUpdateRate:MobaCursorUpdateRate60Hz tickHandler:^{}]);
    MobaDriverFakeLink *link = self.factory.links.firstObject;
    XCTAssertTrue(self.driver.isRunning);
    XCTAssertEqual(link.addCount, 1u);
    XCTAssertTrue(link.runLoop == NSRunLoop.mainRunLoop);
    XCTAssertEqualObjects(link.mode, NSRunLoopCommonModes);

    [self.driver stop];
    XCTAssertFalse(self.driver.isRunning);
    XCTAssertEqual(link.invalidateCount, 1u);
}

- (void)testRepeatedStartDoesNotCreateSecondActiveLink {
    __block NSUInteger tickCount = 0;
    XCTAssertTrue([self.driver startWithUpdateRate:MobaCursorUpdateRate60Hz
                                       tickHandler:^{ tickCount += 1; }]);
    XCTAssertTrue([self.driver startWithUpdateRate:MobaCursorUpdateRate120Hz tickHandler:^{}]);
    XCTAssertEqual(self.factory.links.count, 1u);
    XCTAssertEqual(self.factory.links.firstObject.preferredFramesPerSecond, 60);
    [self.factory.links.firstObject fire];
    XCTAssertEqual(tickCount, 1u);
}

- (void)testRepeatedStopIsIdempotent {
    [self.driver startWithUpdateRate:MobaCursorUpdateRate60Hz tickHandler:^{}];
    MobaDriverFakeLink *link = self.factory.links.firstObject;
    [self.driver stop];
    [self.driver stop];
    XCTAssertEqual(link.invalidateCount, 1u);
}

- (void)testStoppedAndStaleCallbacksDoNotInvokeCurrentHandler {
    __block NSUInteger firstCount = 0;
    __block NSUInteger secondCount = 0;
    [self.driver startWithUpdateRate:MobaCursorUpdateRate60Hz
                        tickHandler:^{ firstCount += 1; }];
    MobaDriverFakeLink *firstLink = self.factory.links.firstObject;
    [self.driver stop];
    [firstLink fire];
    XCTAssertEqual(firstCount, 0u);

    [self.driver startWithUpdateRate:MobaCursorUpdateRate60Hz
                        tickHandler:^{ secondCount += 1; }];
    [firstLink fire];
    XCTAssertEqual(secondCount, 0u);
    [self.factory.links.lastObject fire];
    XCTAssertEqual(secondCount, 1u);
}

- (void)testActiveDisplayLinkDoesNotRetainDriverThroughTargetCycle {
    MobaDriverFakeFactory *factory = [[MobaDriverFakeFactory alloc] init];
    __weak MobaCADisplayLinkDriver *weakDriver = nil;
    @autoreleasepool {
        MobaCADisplayLinkDriver *driver = [[MobaCADisplayLinkDriver alloc] initWithFactory:factory];
        weakDriver = driver;
        XCTAssertTrue([driver startWithUpdateRate:MobaCursorUpdateRate60Hz tickHandler:^{}]);
        XCTAssertNotNil(weakDriver);
    }
    XCTAssertNil(weakDriver);
    XCTAssertEqual(factory.links.firstObject.invalidateCount, 1u);
}

@end
