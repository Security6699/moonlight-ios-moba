//
//  MobaNativeTouchRoutingController.m
//  Moonlight
//

#import "MobaNativeTouchRoutingController.h"

@implementation MobaNativeTouchRoutingController {
    __weak id<MobaNativeTouchSequenceCancelling> _cancellationConsumer;
    BOOL _nativeTouchRoutingEnabled;
}

- (instancetype)initWithCancellationConsumer:(id<MobaNativeTouchSequenceCancelling>)consumer {
    self = [super init];
    if (self) {
        NSParameterAssert(consumer != nil);
        _cancellationConsumer = consumer;
        _nativeTouchRoutingEnabled = YES;
    }
    return self;
}

- (BOOL)isNativeTouchRoutingEnabled {
    return _nativeTouchRoutingEnabled;
}

- (void)setNativeTouchRoutingEnabled:(BOOL)enabled {
    if (_nativeTouchRoutingEnabled == enabled) {
        return;
    }

    _nativeTouchRoutingEnabled = enabled;
    if (!enabled) {
        [_cancellationConsumer cancelActiveNativeTouchSequence];
    }
}

- (BOOL)allowsTouchKind:(MobaNativeTouchKind)touchKind {
    if (touchKind == MobaNativeTouchKindIndirectPointer) {
        return YES;
    }
    return _nativeTouchRoutingEnabled;
}

- (BOOL)allowsThreeFingerKeyboardGesture {
    return _nativeTouchRoutingEnabled;
}

@end
