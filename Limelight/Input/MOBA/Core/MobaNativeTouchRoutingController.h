//
//  MobaNativeTouchRoutingController.h
//  Moonlight
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MobaNativeTouchKind) {
    MobaNativeTouchKindDirect,
    MobaNativeTouchKindPencil,
    MobaNativeTouchKindIndirectPointer,
};

@protocol MobaNativeTouchSequenceCancelling <NSObject>

- (void)cancelActiveNativeTouchSequence;

@end

// Foundation-only routing state used by StreamView. The default is enabled so
// a StreamView without a MOBA Coordinator preserves upstream touch behavior.
@interface MobaNativeTouchRoutingController : NSObject

@property (nonatomic, readonly, getter=isNativeTouchRoutingEnabled) BOOL nativeTouchRoutingEnabled;

- (instancetype)initWithCancellationConsumer:(id<MobaNativeTouchSequenceCancelling>)consumer NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)setNativeTouchRoutingEnabled:(BOOL)enabled;
- (BOOL)allowsTouchKind:(MobaNativeTouchKind)touchKind;
- (BOOL)allowsThreeFingerKeyboardGesture;

@end

NS_ASSUME_NONNULL_END
