//
//  MobaCADisplayLinkDriver.m
//  Moonlight
//

#import "MobaCADisplayLinkDriver.h"

@class MobaCADisplayLinkDriver;

@interface MobaCADisplayLinkWeakTarget : NSObject

@property (nonatomic, weak) MobaCADisplayLinkDriver *driver;
@property (nonatomic) NSUInteger generation;

- (void)displayLinkDidTick:(id)sender;

@end

@interface MobaCADisplayLinkFactory : NSObject <MobaDisplayLinkCreating>
@end

@interface MobaCADisplayLinkDriver ()

- (void)handleTickForGeneration:(NSUInteger)generation;

@end


@implementation MobaCADisplayLinkWeakTarget

- (void)displayLinkDidTick:(id)sender {
    (void)sender;
    [self.driver handleTickForGeneration:self.generation];
}

@end

@implementation MobaCADisplayLinkFactory

- (id<MobaDisplayLinkObject>)displayLinkWithTarget:(id)target selector:(SEL)selector {
    return (id<MobaDisplayLinkObject>)[CADisplayLink displayLinkWithTarget:target selector:selector];
}

@end

@implementation MobaCADisplayLinkDriver {
    id<MobaDisplayLinkCreating> _factory;
    id<MobaDisplayLinkObject> _displayLink;
    MobaDisplayLinkTickHandler _tickHandler;
    NSUInteger _generation;
    BOOL _running;
}

- (instancetype)init {
    return [self initWithFactory:[[MobaCADisplayLinkFactory alloc] init]];
}

- (instancetype)initWithFactory:(id<MobaDisplayLinkCreating>)factory {
    NSParameterAssert(factory != nil);
    self = [super init];
    if (self) {
        _factory = factory;
    }
    return self;
}

- (BOOL)isRunning {
    return _running;
}

- (BOOL)startWithUpdateRate:(MobaCursorUpdateRate)updateRate
                tickHandler:(MobaDisplayLinkTickHandler)tickHandler {
    NSAssert([NSThread isMainThread], @"MobaCADisplayLinkDriver must start on the main thread");
    if (!MobaCursorUpdateRateIsValid(updateRate) || tickHandler == nil) {
        return NO;
    }
    if (_running) {
        return YES;
    }

    _generation += 1;
    MobaCADisplayLinkWeakTarget *target = [[MobaCADisplayLinkWeakTarget alloc] init];
    target.driver = self;
    target.generation = _generation;
    id<MobaDisplayLinkObject> displayLink =
        [_factory displayLinkWithTarget:target selector:@selector(displayLinkDidTick:)];
    if (displayLink == nil) {
        return NO;
    }

    displayLink.preferredFramesPerSecond = (NSInteger)updateRate;
    _tickHandler = [tickHandler copy];
    _displayLink = displayLink;
    _running = YES;
    [displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}

- (void)stop {
    NSAssert([NSThread isMainThread], @"MobaCADisplayLinkDriver must stop on the main thread");
    if (!_running && _displayLink == nil && _tickHandler == nil) {
        return;
    }

    _running = NO;
    _generation += 1;
    _tickHandler = nil;
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)handleTickForGeneration:(NSUInteger)generation {
    NSAssert([NSThread isMainThread], @"MobaCADisplayLinkDriver ticks on the main thread");
    if (!_running || generation != _generation) {
        return;
    }

    MobaDisplayLinkTickHandler handler = _tickHandler;
    if (handler != nil) {
        handler();
    }
}

- (void)dealloc {
    [_displayLink invalidate];
}

@end
