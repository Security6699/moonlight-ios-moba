//
//  MobaModeToolbarView.m
//  Moonlight
//

#import "MobaModeToolbarView.h"

@implementation MobaModeToolbarView {
    UISegmentedControl *_modeControl;
    UIButton *_profilesButton;
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

    _profilesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_profilesButton setTitle:@"Profiles" forState:UIControlStateNormal];
    [_profilesButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_profilesButton addTarget:self action:@selector(profilesTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_profilesButton];

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
    return CGSizeMake(438.0, 42.0);
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

- (void)profilesTapped {
    if ([_delegate respondsToSelector:@selector(mobaModeToolbarViewDidRequestProfileTransfer:)]) {
        [_delegate mobaModeToolbarViewDidRequestProfileTransfer:self];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect content = CGRectInset(self.bounds, 5.0, 5.0);
    CGFloat buttonWidth = 80.0;
    _profilesButton.frame = CGRectMake(CGRectGetMaxX(content) - buttonWidth,
                                       CGRectGetMinY(content), buttonWidth,
                                       CGRectGetHeight(content));
    _modeControl.frame = CGRectMake(CGRectGetMinX(content), CGRectGetMinY(content),
                                    MAX(0.0, CGRectGetWidth(content) - buttonWidth - 5.0),
                                    CGRectGetHeight(content));
}

@end
