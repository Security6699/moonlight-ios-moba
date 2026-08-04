//
//  MobaCursorDiagnostics.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class MobaInputDispatcher;

@protocol MobaBattleInputGate <NSObject>
@property (nonatomic, readonly, getter=isBattleInputAllowed) BOOL battleInputAllowed;
@end

FOUNDATION_EXPORT const NSUInteger MobaCursorDiagnosticPointCount;
FOUNDATION_EXPORT BOOL MobaCursorDiagnosticPointAtIndex(NSUInteger index, CGPoint *point);

@interface MobaCursorDiagnostics : NSObject

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                          inputGate:(id<MobaBattleInputGate>)inputGate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Returns YES only when a fixed diagnostic point was accepted by the battle gate
// and submitted to the serialized dispatcher.
- (BOOL)sendPointAtIndex:(NSUInteger)index;

@end
