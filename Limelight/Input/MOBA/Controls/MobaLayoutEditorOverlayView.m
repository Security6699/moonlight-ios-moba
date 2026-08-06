//
//  MobaLayoutEditorOverlayView.m
//  Moonlight
//

#import "MobaLayoutEditorOverlayView.h"

static const CGFloat MobaLayoutEditorPanelWidth = 286.0;

@interface MobaLayoutEditorSliderRow : UIView
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic) NSInteger fieldTag;
@end

@implementation MobaLayoutEditorSliderRow
- (instancetype)initWithTitle:(NSString *)title minimum:(float)minimum maximum:(float)maximum {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.text = title;
        _label.textColor = UIColor.whiteColor;
        _label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        [self addSubview:_label];
        _slider = [[UISlider alloc] initWithFrame:CGRectZero];
        _slider.minimumValue = minimum;
        _slider.maximumValue = maximum;
        [self addSubview:_slider];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.label.frame = CGRectMake(0.0, 0.0, 82.0, CGRectGetHeight(self.bounds));
    self.slider.frame = CGRectMake(86.0, 0.0, MAX(0.0, CGRectGetWidth(self.bounds) - 86.0), CGRectGetHeight(self.bounds));
}
@end

@implementation MobaLayoutEditorOverlayView {
    UIView *_panel;
    UILabel *_selectionLabel;
    UILabel *_statusLabel;
    CAShapeLayer *_selectionLayer;
    NSMutableDictionary<NSNumber *, MobaLayoutEditorSliderRow *> *_controlRows;
    NSMutableDictionary<NSNumber *, MobaLayoutEditorSliderRow *> *_cancelRows;
    MobaLayoutEditorSliderRow *_globalOpacityRow;
    UISwitch *_interactionSwitch;
    UISwitch *_cancelVisibilitySwitch;
    UIButton *_zDownButton;
    UIButton *_zUpButton;
    id _activeDragToken;
}

- (instancetype)initWithEditorController:(MobaLayoutEditorController *)editorController {
    if (editorController == nil) return nil;
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _editorController = editorController;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.08];
        self.multipleTouchEnabled = YES;

        _selectionLayer = [CAShapeLayer layer];
        _selectionLayer.fillColor = UIColor.clearColor.CGColor;
        _selectionLayer.strokeColor = [UIColor colorWithRed:0.20 green:0.82 blue:1.0 alpha:1.0].CGColor;
        _selectionLayer.lineWidth = 3.0;
        _selectionLayer.lineDashPattern = @[@8, @5];
        [self.layer addSublayer:_selectionLayer];

        _panel = [[UIView alloc] initWithFrame:CGRectZero];
        _panel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.92];
        _panel.layer.cornerRadius = 12.0;
        [self addSubview:_panel];

        _selectionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _selectionLabel.textColor = UIColor.whiteColor;
        _selectionLabel.font = [UIFont boldSystemFontOfSize:16.0];
        [_panel addSubview:_selectionLabel];

        _controlRows = [NSMutableDictionary dictionary];
        [self addControlRow:@"Center X" field:MobaLayoutEditorControlFieldCenterX min:0 max:1];
        [self addControlRow:@"Center Y" field:MobaLayoutEditorControlFieldCenterY min:0 max:1];
        [self addControlRow:@"Width" field:MobaLayoutEditorControlFieldVisualWidth min:24 max:600];
        [self addControlRow:@"Height" field:MobaLayoutEditorControlFieldVisualHeight min:24 max:600];
        [self addControlRow:@"Hit Area" field:MobaLayoutEditorControlFieldHitAreaScale min:0.5 max:3];
        [self addControlRow:@"Wheel" field:MobaLayoutEditorControlFieldWheelRadius min:40 max:400];
        [self addControlRow:@"Normal" field:MobaLayoutEditorControlFieldNormalOpacity min:0 max:1];
        [self addControlRow:@"Pressed" field:MobaLayoutEditorControlFieldPressedOpacity min:0 max:1];
        [self addControlRow:@"Disabled" field:MobaLayoutEditorControlFieldDisabledOpacity min:0 max:1];

        _cancelRows = [NSMutableDictionary dictionary];
        [self addCancelRow:@"Center X" field:MobaLayoutEditorCancelZoneFieldCenterX min:0 max:1];
        [self addCancelRow:@"Center Y" field:MobaLayoutEditorCancelZoneFieldCenterY min:0 max:1];
        [self addCancelRow:@"Diameter" field:MobaLayoutEditorCancelZoneFieldDiameter min:24 max:600];
        [self addCancelRow:@"Inset" field:MobaLayoutEditorCancelZoneFieldActivationInset min:0 max:299];
        [self addCancelRow:@"Opacity" field:MobaLayoutEditorCancelZoneFieldOpacity min:0 max:1];

        _globalOpacityRow = [[MobaLayoutEditorSliderRow alloc] initWithTitle:@"Global" minimum:0 maximum:1];
        [_globalOpacityRow.slider addTarget:self action:@selector(globalOpacityChanged:) forControlEvents:UIControlEventValueChanged];
        [_panel addSubview:_globalOpacityRow];

        _interactionSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        _interactionSwitch.accessibilityLabel = @"Interaction Enabled";
        [_interactionSwitch addTarget:self action:@selector(interactionSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [_panel addSubview:_interactionSwitch];
        _cancelVisibilitySwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        _cancelVisibilitySwitch.accessibilityLabel = @"Visible Only While Casting";
        [_cancelVisibilitySwitch addTarget:self action:@selector(cancelVisibilityChanged:) forControlEvents:UIControlEventValueChanged];
        [_panel addSubview:_cancelVisibilitySwitch];

        _zDownButton = [self buttonWithTitle:@"Z −" action:@selector(zDown:)];
        _zUpButton = [self buttonWithTitle:@"Z +" action:@selector(zUp:)];
        UISegmentedControl *preview = [[UISegmentedControl alloc] initWithItems:@[@"Normal", @"Pressed", @"Disabled"]];
        preview.selectedSegmentIndex = 0;
        preview.tag = 9001;
        [preview addTarget:self action:@selector(previewChanged:) forControlEvents:UIControlEventValueChanged];
        [_panel addSubview:preview];

        UIButton *save = [self buttonWithTitle:@"Save" action:@selector(save:)];
        save.tag = 9002;
        UIButton *revert = [self buttonWithTitle:@"Revert" action:@selector(revert:)];
        revert.tag = 9003;
        UIButton *defaults = [self buttonWithTitle:@"Defaults" action:@selector(defaults:)];
        defaults.tag = 9004;

        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _statusLabel.font = [UIFont systemFontOfSize:11.0];
        _statusLabel.numberOfLines = 2;
        [_panel addSubview:_statusLabel];
        [self refreshFromDraft];
    }
    return self;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    button.layer.cornerRadius = 6.0;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:button];
    return button;
}

- (void)addControlRow:(NSString *)title field:(MobaLayoutEditorControlField)field min:(float)min max:(float)max {
    MobaLayoutEditorSliderRow *row = [[MobaLayoutEditorSliderRow alloc] initWithTitle:title minimum:min maximum:max];
    row.fieldTag = field;
    [row.slider addTarget:self action:@selector(controlSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_panel addSubview:row];
    _controlRows[@(field)] = row;
}

- (void)addCancelRow:(NSString *)title field:(MobaLayoutEditorCancelZoneField)field min:(float)min max:(float)max {
    MobaLayoutEditorSliderRow *row = [[MobaLayoutEditorSliderRow alloc] initWithTitle:title minimum:min maximum:max];
    row.fieldTag = field;
    [row.slider addTarget:self action:@selector(cancelSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_panel addSubview:row];
    _cancelRows[@(field)] = row;
}

- (id)activeDragToken { return _activeDragToken; }

- (CGRect)safeFrame {
    return self.safeAreaLayoutGuide.layoutFrame;
}

- (BOOL)beginEditingWithToken:(id)token point:(CGPoint)point {
    if (token == nil || _activeDragToken != nil || CGRectContainsPoint(_panel.frame, point)) return NO;
    NSString *selected = [_editorController selectTopmostControlAtPoint:point safeAreaFrame:self.safeFrame];
    if (selected == nil) return NO;
    _activeDragToken = token;
    [_editorController moveSelectedControlToPoint:point safeAreaFrame:self.safeFrame];
    [self refreshFromDraft];
    return YES;
}

- (BOOL)updateEditingWithToken:(id)token point:(CGPoint)point {
    if (token == nil || token != _activeDragToken) return NO;
    BOOL changed = [_editorController moveSelectedControlToPoint:point safeAreaFrame:self.safeFrame];
    [self refreshFromDraft];
    return changed;
}

- (BOOL)endEditingWithToken:(id)token {
    if (token == nil || token != _activeDragToken) return NO;
    _activeDragToken = nil;
    return YES;
}

- (BOOL)cancelEditingWithToken:(id)token {
    return [self endEditingWithToken:token];
}

- (void)cancelEditingInteraction { _activeDragToken = nil; }

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) {
        if ([self beginEditingWithToken:touch point:[touch locationInView:self]]) break;
    }
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) [self updateEditingWithToken:touch point:[touch locationInView:self]];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) if ([self endEditingWithToken:touch]) break;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) if ([self cancelEditingWithToken:touch]) break;
}

- (void)controlSliderChanged:(UISlider *)slider {
    MobaLayoutEditorSliderRow *row = (id)slider.superview;
    [_editorController setSelectedControlValue:slider.value forField:row.fieldTag];
    [self refreshFromDraft];
}
- (void)cancelSliderChanged:(UISlider *)slider {
    MobaLayoutEditorSliderRow *row = (id)slider.superview;
    [_editorController setCancelZoneValue:slider.value forField:row.fieldTag];
    [self refreshFromDraft];
}
- (void)globalOpacityChanged:(UISlider *)slider {
    [_editorController setGlobalOpacityMultiplierValue:slider.value];
    [self refreshFromDraft];
}
- (void)interactionSwitchChanged:(UISwitch *)sender {
    [_editorController setSelectedControlInteractionEnabled:sender.isOn];
    [self refreshFromDraft];
}
- (void)cancelVisibilityChanged:(UISwitch *)sender {
    [_editorController setCancelZoneVisibleOnlyWhileCasting:sender.isOn];
    [self refreshFromDraft];
}
- (void)zDown:(id)sender { (void)sender; [_editorController adjustSelectedControlZIndexBy:-1]; [self refreshFromDraft]; }
- (void)zUp:(id)sender { (void)sender; [_editorController adjustSelectedControlZIndexBy:1]; [self refreshFromDraft]; }
- (void)previewChanged:(UISegmentedControl *)sender {
    _editorController.opacityPreviewState = (MobaControlOpacityPreviewState)(sender.selectedSegmentIndex + 1);
}
- (void)save:(id)sender { (void)sender; [self.delegate layoutEditorOverlayDidRequestSave:self]; }
- (void)revert:(id)sender { (void)sender; [_editorController revert]; [self refreshFromDraft]; }
- (void)defaults:(id)sender { (void)sender; [self.delegate layoutEditorOverlayDidRequestRestoreDefaults:self]; }

- (void)showStatusMessage:(NSString *)message error:(BOOL)isError {
    _statusLabel.text = message;
    _statusLabel.textColor = isError ? UIColor.systemRedColor : UIColor.systemGreenColor;
}

- (void)refreshFromDraft {
    NSString *name = _editorController.selectedControlName;
    BOOL cancelSelected = [name isEqualToString:MobaLayoutEditorControlCancelZone];
    MobaLayoutEditorControlDraft *control = [_editorController.draft controlNamed:name];
    _selectionLabel.text = name.length > 0
        ? [NSString stringWithFormat:@"%@%@", name, _editorController.isDirty ? @"  •" : @""]
        : @"Select a control";
    _globalOpacityRow.slider.value = _editorController.draft.globalOpacityMultiplier;
    for (NSNumber *key in _controlRows) _controlRows[key].hidden = control == nil;
    for (NSNumber *key in _cancelRows) _cancelRows[key].hidden = !cancelSelected;
    _interactionSwitch.hidden = control == nil;
    _zDownButton.hidden = control == nil;
    _zUpButton.hidden = control == nil;
    _cancelVisibilitySwitch.hidden = !cancelSelected;
    if (control != nil) {
        _controlRows[@(MobaLayoutEditorControlFieldCenterX)].slider.value = control.centerX;
        _controlRows[@(MobaLayoutEditorControlFieldCenterY)].slider.value = control.centerY;
        _controlRows[@(MobaLayoutEditorControlFieldVisualWidth)].slider.value = control.visualWidthPt;
        _controlRows[@(MobaLayoutEditorControlFieldVisualHeight)].slider.value = control.visualHeightPt;
        _controlRows[@(MobaLayoutEditorControlFieldHitAreaScale)].slider.value = control.hitAreaScale;
        MobaLayoutEditorSliderRow *wheel = _controlRows[@(MobaLayoutEditorControlFieldWheelRadius)];
        wheel.hidden = !control.isWheelRadiusEditable;
        wheel.slider.value = control.wheelRadiusPt.floatValue;
        _controlRows[@(MobaLayoutEditorControlFieldNormalOpacity)].slider.value = control.opacity;
        _controlRows[@(MobaLayoutEditorControlFieldPressedOpacity)].slider.value = control.pressedOpacity;
        _controlRows[@(MobaLayoutEditorControlFieldDisabledOpacity)].slider.value = control.disabledOpacity;
        _interactionSwitch.on = control.isInteractionEnabled;
    }
    if (cancelSelected) {
        MobaLayoutEditorCancelZoneDraft *cancel = _editorController.draft.cancelZone;
        _cancelRows[@(MobaLayoutEditorCancelZoneFieldCenterX)].slider.value = cancel.centerX;
        _cancelRows[@(MobaLayoutEditorCancelZoneFieldCenterY)].slider.value = cancel.centerY;
        _cancelRows[@(MobaLayoutEditorCancelZoneFieldDiameter)].slider.value = cancel.diameterPt;
        MobaLayoutEditorSliderRow *inset = _cancelRows[@(MobaLayoutEditorCancelZoneFieldActivationInset)];
        inset.slider.maximumValue = MAX(0.0, cancel.diameterPt * 0.5 - 0.001);
        inset.slider.value = cancel.activationInsetPt;
        _cancelRows[@(MobaLayoutEditorCancelZoneFieldOpacity)].slider.value = cancel.opacity;
        _cancelVisibilitySwitch.on = cancel.visibleOnlyWhileCasting;
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect safeFrame = self.safeFrame;
    CGFloat panelHeight = MIN(CGRectGetHeight(safeFrame) - 16.0, 612.0);
    _panel.frame = CGRectMake(CGRectGetMaxX(safeFrame) - MobaLayoutEditorPanelWidth - 8.0,
                              CGRectGetMinY(safeFrame) + 8.0,
                              MobaLayoutEditorPanelWidth,
                              panelHeight);
    CGFloat y = 10.0;
    _selectionLabel.frame = CGRectMake(12.0, y, MobaLayoutEditorPanelWidth - 24.0, 24.0);
    y += 28.0;
    for (NSNumber *key in @[@0, @1, @2, @3, @4, @5, @6, @7, @8]) {
        MobaLayoutEditorSliderRow *row = _controlRows[key];
        if (!row.hidden) { row.frame = CGRectMake(12.0, y, MobaLayoutEditorPanelWidth - 24.0, 28.0); y += 30.0; }
    }
    for (NSNumber *key in @[@0, @1, @2, @3, @4]) {
        MobaLayoutEditorSliderRow *row = _cancelRows[key];
        if (!row.hidden) { row.frame = CGRectMake(12.0, y, MobaLayoutEditorPanelWidth - 24.0, 28.0); y += 30.0; }
    }
    _globalOpacityRow.frame = CGRectMake(12.0, y, MobaLayoutEditorPanelWidth - 24.0, 28.0); y += 30.0;
    if (!_interactionSwitch.hidden) { _interactionSwitch.frame = CGRectMake(12.0, y, 52.0, 31.0); y += 34.0; }
    if (!_cancelVisibilitySwitch.hidden) { _cancelVisibilitySwitch.frame = CGRectMake(12.0, y, 52.0, 31.0); y += 34.0; }
    if (!_zDownButton.hidden) {
        _zDownButton.frame = CGRectMake(12.0, y, 70.0, 30.0);
        _zUpButton.frame = CGRectMake(88.0, y, 70.0, 30.0);
        y += 34.0;
    }
    UISegmentedControl *preview = [_panel viewWithTag:9001];
    preview.frame = CGRectMake(12.0, y, MobaLayoutEditorPanelWidth - 24.0, 30.0); y += 36.0;
    UIButton *save = [_panel viewWithTag:9002];
    UIButton *revert = [_panel viewWithTag:9003];
    UIButton *defaults = [_panel viewWithTag:9004];
    save.frame = CGRectMake(12.0, y, 76.0, 32.0);
    revert.frame = CGRectMake(94.0, y, 76.0, 32.0);
    defaults.frame = CGRectMake(176.0, y, 98.0, 32.0); y += 36.0;
    _statusLabel.frame = CGRectMake(12.0, y, MobaLayoutEditorPanelWidth - 24.0, 34.0);

    NSString *name = _editorController.selectedControlName;
    CGRect selectionRect = CGRectZero;
    if ([name isEqualToString:MobaLayoutEditorControlCancelZone]) {
        MobaLayoutEditorCancelZoneDraft *cancel = _editorController.draft.cancelZone;
        CGPoint center = CGPointMake(CGRectGetMinX(safeFrame) + cancel.centerX * CGRectGetWidth(safeFrame),
                                     CGRectGetMinY(safeFrame) + cancel.centerY * CGRectGetHeight(safeFrame));
        selectionRect = CGRectMake(center.x - cancel.diameterPt * 0.5, center.y - cancel.diameterPt * 0.5,
                                   cancel.diameterPt, cancel.diameterPt);
    }
    else {
        MobaLayoutEditorControlDraft *control = [_editorController.draft controlNamed:name];
        if (control != nil) {
            CGPoint center = CGPointMake(CGRectGetMinX(safeFrame) + control.centerX * CGRectGetWidth(safeFrame),
                                         CGRectGetMinY(safeFrame) + control.centerY * CGRectGetHeight(safeFrame));
            CGSize hit = CGSizeMake(control.visualWidthPt * control.hitAreaScale,
                                    control.visualHeightPt * control.hitAreaScale);
            selectionRect = CGRectMake(center.x - hit.width * 0.5, center.y - hit.height * 0.5, hit.width, hit.height);
        }
    }
    _selectionLayer.path = CGRectIsEmpty(selectionRect) ? nil : [UIBezierPath bezierPathWithRect:selectionRect].CGPath;
}

@end
