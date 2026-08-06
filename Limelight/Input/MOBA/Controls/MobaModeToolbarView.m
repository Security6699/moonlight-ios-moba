//
//  MobaModeToolbarView.m
//  Moonlight
//

#import "MobaModeToolbarView.h"

@implementation MobaModeToolbarView {
    UISegmentedControl *_modeControl;
    MobaOverlayMode _selectedMode;
}

- (void)initializeToolbar {
    self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.72];
    self.layer.cornerRadius = 9.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    self.layer.borderWidth = 1.0;

    _modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Battle", @"UI", @"Layout", @"Tuning"]];
    [_modeControl addTarget:self action:@selector(modeControlChanged:)
          forControlEvents:UIControlEventValueChanged];
    [self addSubview:_modeControl];

    _battleModeAvailable = YES;
    [self setSelectedMode:MobaOverlayModeBattle];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeToolbar];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initializeToolbar];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(348.0, 42.0);
}

- (MobaOverlayMode)selectedMode {
    return _selectedMode;
}

- (void)setBattleModeAvailable:(BOOL)battleModeAvailable {
    _battleModeAvailable = battleModeAvailable;
    [_modeControl setEnabled:battleModeAvailable forSegmentAtIndex:0];
}

- (void)setSelectedMode:(MobaOverlayMode)mode {
    _selectedMode = mode;
    switch (mode) {
        case MobaOverlayModeBattle:
            _modeControl.selectedSegmentIndex = 0;
            break;
        case MobaOverlayModeUI:
            _modeControl.selectedSegmentIndex = 1;
            break;
        case MobaOverlayModeLayoutEdit:
            _modeControl.selectedSegmentIndex = 2;
            break;
        case MobaOverlayModeSkillTuning:
            _modeControl.selectedSegmentIndex = 3;
            break;
    }
}

- (BOOL)requestMode:(MobaOverlayMode)mode {
    if (mode == MobaOverlayModeBattle && !_battleModeAvailable) {
        [self setSelectedMode:_selectedMode];
        return NO;
    }
    if (_selectedMode == mode) {
        return YES;
    }

    MobaOverlayMode previousMode = _selectedMode;
    BOOL accepted = [_delegate mobaModeToolbarView:self requestMode:mode];
    [self setSelectedMode:accepted ? mode : previousMode];
    return accepted;
}

- (void)modeControlChanged:(UISegmentedControl *)sender {
    MobaOverlayMode modes[] = {MobaOverlayModeBattle, MobaOverlayModeUI,
                              MobaOverlayModeLayoutEdit, MobaOverlayModeSkillTuning};
    MobaOverlayMode mode = modes[MAX(0, MIN(3, sender.selectedSegmentIndex))];
    [self requestMode:mode];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _modeControl.frame = CGRectInset(self.bounds, 5.0, 5.0);
}

@end
