//
//  MobaCADisplayLinkDriver.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "MobaDisplayLinkDriving.h"

NS_ASSUME_NONNULL_BEGIN

// Public test seam over the small CADisplayLink surface used by the driver.
// Production uses a private factory backed by CADisplayLink.
@protocol MobaDisplayLinkObject <NSObject>

@property (nonatomic) NSInteger preferredFramesPerSecond;

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode;
- (void)invalidate;

@end

@protocol MobaDisplayLinkCreating <NSObject>

- (id<MobaDisplayLinkObject>)displayLinkWithTarget:(id)target selector:(SEL)selector;

@end

@interface MobaCADisplayLinkDriver : NSObject <MobaDisplayLinkDriving>

- (instancetype)init;
- (instancetype)initWithFactory:(id<MobaDisplayLinkCreating>)factory NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
