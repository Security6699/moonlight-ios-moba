//
//  MobaCursorDiagnostics.m
//  Moonlight
//

#import "MobaCursorDiagnostics.h"
#import "MobaInputDispatcher.h"

const NSUInteger MobaCursorDiagnosticPointCount = 9;

static const CGPoint MobaFixedCursorDiagnosticPoints[] = {
    { 0, 0 }, { 1280, 0 }, { 2559, 0 },
    { 0, 720 }, { 1280, 720 }, { 2559, 720 },
    { 0, 1439 }, { 1280, 1439 }, { 2559, 1439 },
};

BOOL MobaCursorDiagnosticPointAtIndex(NSUInteger index, CGPoint *point) {
    if (index >= MobaCursorDiagnosticPointCount || point == NULL) {
        return NO;
    }

    *point = MobaFixedCursorDiagnosticPoints[index];
    return YES;
}

@implementation MobaCursorDiagnostics {
    MobaInputDispatcher *_dispatcher;
    __weak id<MobaBattleInputGate> _inputGate;
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                          inputGate:(id<MobaBattleInputGate>)inputGate {
    self = [super init];
    if (self) {
        NSParameterAssert(dispatcher != nil);
        NSParameterAssert(inputGate != nil);
        _dispatcher = dispatcher;
        _inputGate = inputGate;
    }
    return self;
}

- (BOOL)sendPointAtIndex:(NSUInteger)index {
    CGPoint point;
    if (!MobaCursorDiagnosticPointAtIndex(index, &point) || ![_inputGate isBattleInputAllowed]) {
        return NO;
    }

    [_dispatcher moveCursorToCanvasPoint:point];
    return YES;
}

@end
