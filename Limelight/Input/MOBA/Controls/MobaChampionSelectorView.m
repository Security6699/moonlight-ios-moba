//
//  MobaChampionSelectorView.m
//  Moonlight
//

#import "MobaChampionSelectorView.h"

@implementation MobaChampionSelectorView {
    NSArray<MobaChampionCatalogEntry *> *_catalogEntries;
    NSArray<NSString *> *_displayedChampionNames;
    UISegmentedControl *_segmentedControl;
    NSString *_selectedChampionID;
    MobaOverlayMode _mode;
}

- (instancetype)initWithCatalogEntries:(NSArray<MobaChampionCatalogEntry *> *)catalogEntries {
    if (catalogEntries.count == 0) {
        return nil;
    }
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _catalogEntries = [catalogEntries copy];
        NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:catalogEntries.count];
        for (MobaChampionCatalogEntry *entry in catalogEntries) {
            [names addObject:entry.displayName];
        }
        _displayedChampionNames = [names copy];

        _segmentedControl = [[UISegmentedControl alloc] initWithItems:_displayedChampionNames];
        [_segmentedControl addTarget:self
                              action:@selector(selectionControlChanged:)
                    forControlEvents:UIControlEventValueChanged];
        _segmentedControl.accessibilityLabel = @"MOBA champion";
        _segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_segmentedControl];

        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.82];
        self.layer.cornerRadius = 10.0;
        self.layer.masksToBounds = YES;
        _mode = MobaOverlayModeBattle;
        [self updateModePresentation];
    }
    return self;
}

- (NSArray<MobaChampionCatalogEntry *> *)catalogEntries {
    return _catalogEntries;
}

- (NSArray<NSString *> *)displayedChampionNames {
    return _displayedChampionNames;
}

- (CGSize)intrinsicContentSize {
    CGSize controlSize = _segmentedControl.intrinsicContentSize;
    return CGSizeMake(MAX(260.0, controlSize.width + 20.0), MAX(44.0, controlSize.height + 12.0));
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _segmentedControl.frame = CGRectInset(self.bounds, 8.0, 6.0);
}

- (NSString *)selectedChampionID {
    return _selectedChampionID;
}

- (void)setSelectedChampionID:(NSString *)selectedChampionID {
    _selectedChampionID = [selectedChampionID copy];
    NSInteger selectedIndex = UISegmentedControlNoSegment;
    for (NSUInteger index = 0; index < _catalogEntries.count; index++) {
        if ([_catalogEntries[index].championID isEqualToString:selectedChampionID]) {
            selectedIndex = (NSInteger)index;
            break;
        }
    }
    _segmentedControl.selectedSegmentIndex = selectedIndex;
}

- (MobaOverlayMode)mode {
    return _mode;
}

- (void)setMode:(MobaOverlayMode)mode {
    _mode = mode;
    [self updateModePresentation];
}

- (void)updateModePresentation {
    BOOL enabled = _mode == MobaOverlayModeUI;
    self.hidden = !enabled;
    self.userInteractionEnabled = enabled;
    _segmentedControl.enabled = enabled;
}

- (BOOL)requestSelectionAtIndex:(NSUInteger)index error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (index >= _catalogEntries.count || _mode != MobaOverlayModeUI || self.delegate == nil) {
        return NO;
    }
    NSString *previousChampionID = [self.selectedChampionID copy];
    MobaChampionCatalogEntry *entry = _catalogEntries[index];
    BOOL accepted = [self.delegate mobaChampionSelectorView:self
                                         requestChampionID:entry.championID
                                                      error:error];
    if (accepted) {
        self.selectedChampionID = entry.championID;
    }
    else {
        self.selectedChampionID = previousChampionID;
    }
    return accepted;
}

- (void)selectionControlChanged:(UISegmentedControl *)sender {
    NSInteger requestedIndex = sender.selectedSegmentIndex;
    if (requestedIndex < 0) {
        return;
    }
    NSError *error = nil;
    if (![self requestSelectionAtIndex:(NSUInteger)requestedIndex error:&error] && error != nil) {
        NSLog(@"MOBA champion selection failed: %@", error);
    }
}

@end
