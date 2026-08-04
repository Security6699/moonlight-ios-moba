//
//  MoonlightMobaInputAdapterTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>
#import <math.h>
#include <Limelight.h>

#import "../Limelight/Input/MOBA/Core/MoonlightMobaInputAdapter.h"

@interface MobaFakeMoonlightInputSender : NSObject <MoonlightMobaInputSending>
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *events;
@end

@implementation MobaFakeMoonlightInputSender

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (int)sendKeyboardEventWithKeyCode:(int16_t)keyCode
                             action:(int8_t)action
                          modifiers:(int8_t)modifiers {
    [self.events addObject:@{
        @"type": @1,
        @"keyCode": @(keyCode),
        @"action": @(action),
        @"modifiers": @(modifiers),
    }];
    return 0;
}

- (int)sendMousePositionX:(int16_t)x
                        y:(int16_t)y
           referenceWidth:(int16_t)referenceWidth
          referenceHeight:(int16_t)referenceHeight {
    [self.events addObject:@{
        @"type": @2,
        @"x": @(x),
        @"y": @(y),
        @"referenceWidth": @(referenceWidth),
        @"referenceHeight": @(referenceHeight),
    }];
    return 0;
}

- (int)sendMouseButton:(int)button action:(int8_t)action {
    [self.events addObject:@{
        @"type": @3,
        @"button": @(button),
        @"action": @(action),
    }];
    return 0;
}

@end

@interface MoonlightMobaInputAdapterTests : XCTestCase
@property (nonatomic, strong) MobaFakeMoonlightInputSender *sender;
@property (nonatomic, strong) MoonlightMobaInputAdapter *adapter;
@end

@implementation MoonlightMobaInputAdapterTests

- (void)setUp {
    [super setUp];
    self.sender = [[MobaFakeMoonlightInputSender alloc] init];
    self.adapter = [[MoonlightMobaInputAdapter alloc] initWithSender:self.sender];
}

- (void)testCursorUsesFixedCanvasReferenceDimensions {
    [self.adapter moveCursorToCanvasPoint:CGPointMake(1280, 720)];

    XCTAssertEqualObjects(self.sender.events,
                          (@[@{
                              @"type": @2,
                              @"x": @1280,
                              @"y": @720,
                              @"referenceWidth": @2560,
                              @"referenceHeight": @1440,
                          }]));
}

- (void)testCursorCoordinatesAreClampedBeforeSending {
    [self.adapter moveCursorToCanvasPoint:CGPointMake(-10, 2000)];

    NSDictionary *event = self.sender.events.firstObject;
    XCTAssertEqualObjects(event[@"x"], @0);
    XCTAssertEqualObjects(event[@"y"], @1439);
}

- (void)testNonFiniteCursorCoordinatesAreNotSent {
    [self.adapter moveCursorToCanvasPoint:CGPointMake(NAN, 720)];
    [self.adapter moveCursorToCanvasPoint:CGPointMake(1280, -INFINITY)];

    XCTAssertEqual(self.sender.events.count, 0u);
}

- (void)testKeyboardDownAndUpUseMoonlightVirtualKeySemantics {
    [self.adapter setKeyCode:0x51 down:YES];
    [self.adapter setKeyCode:0x51 down:NO];

    int16_t expectedKeyCode = (int16_t)(0x8000u | 0x51u);
    XCTAssertEqualObjects(self.sender.events,
                          (@[
                              @{
                                  @"type": @1,
                                  @"keyCode": @(expectedKeyCode),
                                  @"action": @(KEY_ACTION_DOWN),
                                  @"modifiers": @0,
                              },
                              @{
                                  @"type": @1,
                                  @"keyCode": @(expectedKeyCode),
                                  @"action": @(KEY_ACTION_UP),
                                  @"modifiers": @0,
                              },
                          ]));
}

- (void)testMouseButtonDownAndUpUseMoonlightButtonSemantics {
    [self.adapter sendMouseButton:BUTTON_RIGHT down:YES];
    [self.adapter sendMouseButton:BUTTON_RIGHT down:NO];

    XCTAssertEqualObjects(self.sender.events,
                          (@[
                              @{
                                  @"type": @3,
                                  @"button": @(BUTTON_RIGHT),
                                  @"action": @(BUTTON_ACTION_PRESS),
                              },
                              @{
                                  @"type": @3,
                                  @"button": @(BUTTON_RIGHT),
                                  @"action": @(BUTTON_ACTION_RELEASE),
                              },
                          ]));
}

@end
