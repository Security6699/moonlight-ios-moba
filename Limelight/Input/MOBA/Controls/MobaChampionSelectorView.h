//
//  MobaChampionSelectorView.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "../Core/MobaOverlayLifecycle.h"
#import "../Profiles/MobaChampionSelectionController.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaChampionSelectorView;

@protocol MobaChampionSelectorViewDelegate <NSObject>
- (BOOL)mobaChampionSelectorView:(MobaChampionSelectorView *)selectorView
               requestChampionID:(NSString *)championID
                            error:(NSError **)error;
@end

// Compact manual shell. It owns presentation only and delegates every
// selection request without accessing profiles, strategies, or remote input.
@interface MobaChampionSelectorView : UIView

@property (nonatomic, weak, nullable) id<MobaChampionSelectorViewDelegate> delegate;
@property (nonatomic, copy, readonly) NSArray<MobaChampionCatalogEntry *> *catalogEntries;
@property (nonatomic, copy, readonly) NSArray<NSString *> *displayedChampionNames;
@property (nonatomic, copy, nullable) NSString *selectedChampionID;
@property (nonatomic, readonly) MobaOverlayMode mode;

- (instancetype)initWithCatalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)setMode:(MobaOverlayMode)mode;
- (void)setCatalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries;

// Deterministic semantic seam shared by the segmented-control action and tests.
- (BOOL)requestSelectionAtIndex:(NSUInteger)index error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
