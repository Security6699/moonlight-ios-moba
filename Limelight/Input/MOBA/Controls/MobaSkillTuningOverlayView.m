//
//  MobaSkillTuningOverlayView.m
//  Moonlight
//

#import "MobaSkillTuningOverlayView.h"

#import "MobaAimPreviewView.h"
#import "../Geometry/MobaAimPreviewGeometry.h"

@implementation MobaSkillTuningOverlayView {
    UIView *_inspectorPanel;
    UILabel *_championLabel;
    UILabel *_castTypeLabel;
    UILabel *_statusLabel;
    UISegmentedControl *_skillControl;
    UISegmentedControl *_castModeControl;
    UISegmentedControl *_rateControl;
    UITextField *_anchorXField;
    UITextField *_anchorYField;
    UIStackView *_fieldStack;
    NSMutableDictionary<NSNumber *, UITextField *> *_numericFields;
    UISwitch *_allowCancelSwitch;
    UIButton *_saveButton;
    NSMutableArray<UIButton *> *_actionButtons;
    BOOL _editingEnabled;
    id _previewToken;
    CGPoint _previewInitialPoint;
    CGVector _previewDisplacement;
}

- (instancetype)initWithTuningController:(MobaSkillTuningController *)tuningController
                             championName:(NSString *)championName {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _tuningController = tuningController;
        _castMode = MobaSkillTuningCastModePreviewOnly;
        _editingEnabled = YES;
        _numericFields = [NSMutableDictionary dictionary];
        _actionButtons = [NSMutableArray array];
        self.backgroundColor = UIColor.clearColor;
        _aimPreviewView = [[MobaAimPreviewView alloc] initWithFrame:CGRectZero];
        [self addSubview:_aimPreviewView];
        _inspectorPanel = [[UIView alloc] initWithFrame:CGRectZero];
        _inspectorPanel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.92];
        _inspectorPanel.layer.cornerRadius = 10.0;
        [self addSubview:_inspectorPanel];

        _championLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _championLabel.text = championName;
        _championLabel.textColor = UIColor.whiteColor;
        _championLabel.font = [UIFont boldSystemFontOfSize:18.0];
        [_inspectorPanel addSubview:_championLabel];
        _skillControl = [[UISegmentedControl alloc] initWithItems:@[@"Q", @"W", @"E", @"R"]];
        _skillControl.selectedSegmentIndex = 0;
        [_skillControl addTarget:self action:@selector(skillChanged:) forControlEvents:UIControlEventValueChanged];
        [_inspectorPanel addSubview:_skillControl];
        _castTypeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _castTypeLabel.textColor = UIColor.lightGrayColor;
        [_inspectorPanel addSubview:_castTypeLabel];
        _castModeControl = [[UISegmentedControl alloc] initWithItems:@[@"Preview Only", @"Live Cast"]];
        _castModeControl.selectedSegmentIndex = 0;
        [_castModeControl addTarget:self action:@selector(castModeChanged:) forControlEvents:UIControlEventValueChanged];
        [_inspectorPanel addSubview:_castModeControl];

        _anchorXField = [self textFieldWithPlaceholder:@"Anchor X"];
        _anchorYField = [self textFieldWithPlaceholder:@"Anchor Y"];
        [_anchorXField addTarget:self action:@selector(runtimeFieldEnded:) forControlEvents:UIControlEventEditingDidEnd];
        [_anchorYField addTarget:self action:@selector(runtimeFieldEnded:) forControlEvents:UIControlEventEditingDidEnd];
        [_inspectorPanel addSubview:_anchorXField];
        [_inspectorPanel addSubview:_anchorYField];
        _rateControl = [[UISegmentedControl alloc] initWithItems:@[@"30", @"60", @"120"]];
        [_rateControl addTarget:self action:@selector(rateChanged:) forControlEvents:UIControlEventValueChanged];
        [_inspectorPanel addSubview:_rateControl];

        _fieldStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        _fieldStack.axis = UILayoutConstraintAxisVertical;
        _fieldStack.spacing = 5.0;
        [_inspectorPanel addSubview:_fieldStack];
        _allowCancelSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_allowCancelSwitch addTarget:self action:@selector(allowCancelChanged:) forControlEvents:UIControlEventValueChanged];
        [_inspectorPanel addSubview:_allowCancelSwitch];

        NSArray *titles = @[@"Save", @"Revert", @"Defaults"];
        for (NSUInteger index = 0; index < titles.count; index++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            [button setTitle:titles[index] forState:UIControlStateNormal];
            button.tag = index;
            [button addTarget:self action:@selector(actionPressed:) forControlEvents:UIControlEventTouchUpInside];
            button.frame = CGRectMake(12.0 + index * 94.0, 610.0, 88.0, 34.0);
            [_inspectorPanel addSubview:button];
            [_actionButtons addObject:button];
            if (index == 0) _saveButton = button;
        }
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _statusLabel.numberOfLines = 2;
        _statusLabel.font = [UIFont systemFontOfSize:12.0];
        [_inspectorPanel addSubview:_statusLabel];
        [self refreshFromDraft];
    }
    return self;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
    field.placeholder = placeholder;
    field.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    field.textColor = UIColor.whiteColor;
    field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    field.layer.cornerRadius = 5.0;
    return field;
}

- (NSString *)slotForIndex:(NSInteger)index { return MobaCanonicalSkillSlots()[(NSUInteger)MAX(0, MIN(3, index))]; }

- (NSArray<NSNumber *> *)fieldsForValue:(MobaSkillTuningSkillValue *)value {
    NSMutableArray *fields = [NSMutableArray array];
    if (value.castType != MobaProfileSkillCastTypeInstant) {
        [fields addObjectsFromArray:@[@(MobaSkillTuningFieldDefaultAngleDegrees),
                                      @(MobaSkillTuningFieldDefaultDistanceRatio)]];
    }
    if (value.castType == MobaProfileSkillCastTypeDirectional) {
        [fields addObjectsFromArray:@[@(MobaSkillTuningFieldDirectionalLeftPx),
                                      @(MobaSkillTuningFieldDirectionalRightPx),
                                      @(MobaSkillTuningFieldDirectionalUpPx),
                                      @(MobaSkillTuningFieldDirectionalDownPx),
                                      @(MobaSkillTuningFieldTouchDeadzoneRatio)]];
    }
    else if (value.castType == MobaProfileSkillCastTypePoint) {
        for (NSInteger field = MobaSkillTuningFieldPointMinLeftPx;
             field <= MobaSkillTuningFieldTouchCurveExponent; field++) [fields addObject:@(field)];
    }
    return fields;
}

- (NSString *)titleForField:(MobaSkillTuningField)field {
    NSArray *titles = @[@"Default angle", @"Default distance", @"Left", @"Right", @"Up", @"Down",
        @"Min left", @"Min right", @"Min up", @"Min down", @"Max left", @"Max right", @"Max up",
        @"Max down", @"Deadzone", @"Full range", @"Curve"];
    return titles[field];
}

- (void)rebuildNumericFieldsForValue:(MobaSkillTuningSkillValue *)value {
    for (UIView *view in _fieldStack.arrangedSubviews.copy) {
        [_fieldStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [_numericFields removeAllObjects];
    for (NSNumber *fieldNumber in [self fieldsForValue:value]) {
        MobaSkillTuningField field = fieldNumber.integerValue;
        UITextField *textField = [self textFieldWithPlaceholder:[self titleForField:field]];
        textField.tag = field;
        NSNumber *number = field == MobaSkillTuningFieldDefaultAngleDegrees ? value.defaultAngleDegrees
            : field == MobaSkillTuningFieldDefaultDistanceRatio ? value.defaultDistanceRatio
            : value.numericValues[fieldNumber];
        textField.text = number.stringValue;
        [textField addTarget:self action:@selector(skillFieldEnded:) forControlEvents:UIControlEventEditingDidEnd];
        [textField.heightAnchor constraintEqualToConstant:28.0].active = YES;
        [_fieldStack addArrangedSubview:textField];
        _numericFields[fieldNumber] = textField;
    }
}

- (void)refreshPreview {
    MobaSkillRuntimeDescriptor *descriptor = [_tuningController.lastValidRuntime
        descriptorForSkillSlot:_tuningController.selectedSkillSlot];
    MobaAimPreviewResult result;
    BOOL valid = MobaAimPreviewResultForDescriptor(descriptor, _previewDisplacement, &result);
    [_aimPreviewView setPreviewResult:result valid:valid];
}

- (void)refreshFromDraft {
    MobaSkillTuningSkillValue *value = [_tuningController.draft
        skillValueForSlot:_tuningController.selectedSkillSlot];
    _anchorXField.text = [NSString stringWithFormat:@"%.3g", _tuningController.draft.heroAnchorX];
    _anchorYField.text = [NSString stringWithFormat:@"%.3g", _tuningController.draft.heroAnchorY];
    _rateControl.selectedSegmentIndex = _tuningController.draft.mouseUpdateRateHz == 30 ? 0
        : _tuningController.draft.mouseUpdateRateHz == 60 ? 1 : 2;
    _castTypeLabel.text = value.castType == MobaProfileSkillCastTypeInstant ? @"Cast type: Instant"
        : value.castType == MobaProfileSkillCastTypeDirectional ? @"Cast type: Directional"
        : @"Cast type: Point";
    _allowCancelSwitch.on = value.allowCancel;
    _allowCancelSwitch.enabled = value.castType != MobaProfileSkillCastTypeInstant && _editingEnabled;
    [self rebuildNumericFieldsForValue:value];
    _saveButton.enabled = _tuningController.draft.isDirty && _tuningController.validationError == nil;
    if (_tuningController.validationError != nil) {
        [self showStatusMessage:_tuningController.validationError.localizedDescription error:YES];
    }
    else {
        [self showStatusMessage:_tuningController.draft.isDirty ? @"Unsaved changes" : @"Saved baseline" error:NO];
    }
    [self setEditingEnabled:_editingEnabled];
    [self refreshPreview];
}

- (void)setVideoRect:(CGRect)videoRect { _aimPreviewView.videoRect = videoRect; }
- (void)setCastMode:(MobaSkillTuningCastMode)castMode {
    _castMode = castMode;
    _castModeControl.selectedSegmentIndex = castMode;
    if (castMode == MobaSkillTuningCastModeLiveCast) [self cancelPreview];
}
- (void)setEditingEnabled:(BOOL)enabled {
    _editingEnabled = enabled;
    _skillControl.enabled = enabled;
    _anchorXField.enabled = enabled;
    _anchorYField.enabled = enabled;
    _rateControl.enabled = enabled;
    for (UITextField *field in _numericFields.allValues) field.enabled = enabled;
    MobaSkillTuningSkillValue *value = [_tuningController.draft skillValueForSlot:_tuningController.selectedSkillSlot];
    _allowCancelSwitch.enabled = enabled && value.castType != MobaProfileSkillCastTypeInstant;
}

- (void)showStatusMessage:(NSString *)message error:(BOOL)isError {
    _statusLabel.text = message;
    _statusLabel.textColor = isError ? UIColor.systemRedColor : UIColor.systemGreenColor;
}

- (void)skillChanged:(UISegmentedControl *)sender {
    MobaCanonicalSkillSlot slot = [self slotForIndex:sender.selectedSegmentIndex];
    _tuningController.selectedSkillSlot = slot;
    [_delegate skillTuningOverlay:self didSelectSkill:slot];
    [self refreshFromDraft];
}
- (void)castModeChanged:(UISegmentedControl *)sender {
    MobaSkillTuningCastMode requested = sender.selectedSegmentIndex == 1
        ? MobaSkillTuningCastModeLiveCast : MobaSkillTuningCastModePreviewOnly;
    [_delegate skillTuningOverlay:self didRequestCastMode:requested];
}
- (void)runtimeFieldEnded:(UITextField *)sender {
    (void)sender;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *x = [formatter numberFromString:_anchorXField.text ?: @""];
    NSNumber *y = [formatter numberFromString:_anchorYField.text ?: @""];
    NSError *error = nil;
    if (x == nil || y == nil) {
        error = [NSError errorWithDomain:MobaSkillTuningErrorDomain
            code:MobaSkillTuningErrorInvalidField
            userInfo:@{NSLocalizedDescriptionKey: @"Hero anchor requires finite numeric X and Y values."}];
    }
    else if (![_tuningController.draft setHeroAnchorX:x.doubleValue y:y.doubleValue error:&error] ||
        ![_tuningController refreshCandidateWithError:&error]) {
    }
    [_delegate skillTuningOverlayDidChangeDraft:self];
    [self refreshFromDraft];
    if (error != nil) [self showStatusMessage:error.localizedDescription error:YES];
}
- (void)rateChanged:(UISegmentedControl *)sender {
    NSUInteger rates[] = {30, 60, 120};
    NSError *error = nil;
    [_tuningController.draft setMouseUpdateRateHz:rates[sender.selectedSegmentIndex] error:&error];
    [_tuningController refreshCandidateWithError:&error];
    [_delegate skillTuningOverlayDidChangeDraft:self];
    [self refreshFromDraft];
}
- (void)skillFieldEnded:(UITextField *)sender {
    NSError *error = nil;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *number = [formatter numberFromString:sender.text ?: @""];
    if (![_tuningController.draft setValue:number ?: (id)NSNull.null
                                     forField:(MobaSkillTuningField)sender.tag
                                    skillSlot:_tuningController.selectedSkillSlot error:&error] ||
        ![_tuningController refreshCandidateWithError:&error]) {
    }
    [_delegate skillTuningOverlayDidChangeDraft:self];
    [self refreshFromDraft];
    if (error != nil) [self showStatusMessage:error.localizedDescription error:YES];
}
- (void)allowCancelChanged:(UISwitch *)sender {
    NSError *error = nil;
    [_tuningController.draft setAllowCancel:sender.isOn skillSlot:_tuningController.selectedSkillSlot error:&error];
    [_tuningController refreshCandidateWithError:&error];
    [_delegate skillTuningOverlayDidChangeDraft:self];
    [self refreshFromDraft];
}
- (void)actionPressed:(UIButton *)sender {
    if (sender.tag == 0) [_delegate skillTuningOverlayDidRequestSave:self];
    else if (sender.tag == 1) [_delegate skillTuningOverlayDidRequestRevert:self];
    else [_delegate skillTuningOverlayDidRequestRestoreDefaults:self];
}

- (BOOL)beginPreviewWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (_castMode != MobaSkillTuningCastModePreviewOnly || token == nil || _previewToken != nil) return NO;
    _previewToken = token;
    _previewInitialPoint = point;
    _previewDisplacement = CGVectorMake(0, 0);
    [self refreshPreview];
    return YES;
}
- (BOOL)updatePreviewWithToken:(id)token streamViewPoint:(CGPoint)point {
    if (token == nil || token != _previewToken) return NO;
    _previewDisplacement = CGVectorMake(point.x - _previewInitialPoint.x, point.y - _previewInitialPoint.y);
    [self refreshPreview];
    return YES;
}
- (BOOL)endPreviewWithToken:(id)token {
    if (token == nil || token != _previewToken) return NO;
    _previewToken = nil;
    return YES;
}
- (void)cancelPreview { _previewToken = nil; _previewDisplacement = CGVectorMake(0, 0); [self refreshPreview]; }

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) if ([self beginPreviewWithToken:touch streamViewPoint:[touch locationInView:self]]) break;
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) [self updatePreviewWithToken:touch streamViewPoint:[touch locationInView:self]];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)event;
    for (UITouch *touch in touches) if ([self endPreviewWithToken:touch]) break;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { (void)touches; (void)event; [self cancelPreview]; }

- (void)layoutSubviews {
    [super layoutSubviews];
    _aimPreviewView.frame = self.bounds;
    CGFloat width = MIN(320.0, CGRectGetWidth(self.bounds) * 0.34);
    _inspectorPanel.frame = CGRectMake(CGRectGetMaxX(self.bounds) - width - 12.0, 62.0,
                                       width, CGRectGetHeight(self.bounds) - 74.0);
    CGFloat contentWidth = width - 24.0;
    _championLabel.frame = CGRectMake(12, 10, contentWidth, 24);
    _skillControl.frame = CGRectMake(12, 40, contentWidth, 32);
    _castTypeLabel.frame = CGRectMake(12, 76, contentWidth, 24);
    _castModeControl.frame = CGRectMake(12, 104, contentWidth, 32);
    _anchorXField.frame = CGRectMake(12, 142, contentWidth * 0.48, 32);
    _anchorYField.frame = CGRectMake(18 + contentWidth * 0.48, 142, contentWidth * 0.48, 32);
    _rateControl.frame = CGRectMake(12, 180, contentWidth, 32);
    _fieldStack.frame = CGRectMake(12, 218, contentWidth, _fieldStack.arrangedSubviews.count * 33.0);
    _allowCancelSwitch.frame = CGRectMake(12, CGRectGetMaxY(_fieldStack.frame) + 5, 60, 32);
    CGFloat actionsY = MIN(CGRectGetMaxY(_allowCancelSwitch.frame) + 5,
                           CGRectGetHeight(_inspectorPanel.bounds) - 92.0);
    for (NSUInteger index = 0; index < _actionButtons.count; index++) {
        _actionButtons[index].frame = CGRectMake(12.0 + index * 94.0, actionsY, 88.0, 34.0);
    }
    _statusLabel.frame = CGRectMake(12, CGRectGetHeight(_inspectorPanel.bounds) - 50, contentWidth, 42);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.userInteractionEnabled || self.alpha < 0.01) return nil;
    if (_castMode == MobaSkillTuningCastModeLiveCast) {
        CGPoint inspectorPoint = [self convertPoint:point toView:_inspectorPanel];
        if (![_inspectorPanel pointInside:inspectorPoint withEvent:event]) return nil;
    }
    return [super hitTest:point withEvent:event];
}
@end
