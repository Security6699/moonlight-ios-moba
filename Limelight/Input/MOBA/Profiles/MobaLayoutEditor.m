//
//  MobaLayoutEditor.m
//  Moonlight
//

#import "MobaLayoutEditor.h"

#import <math.h>

NSString *const MobaLayoutEditorControlMove = @"move";
NSString *const MobaLayoutEditorControlAttack = @"attack";
NSString *const MobaLayoutEditorControlCancelZone = @"cancelZone";

static NSArray<NSString *> *MobaManagedLayoutControlNames(void) {
    return @[@"move", @"abilityQ", @"abilityW", @"abilityE", @"abilityR", @"attack"];
}

static id MobaDeepMutableJSONCopy(id value) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
            (void)stop;
            copy[[key copy]] = MobaDeepMutableJSONCopy(object);
        }];
        return copy;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *copy = [NSMutableArray arrayWithCapacity:[value count]];
        for (id object in value) {
            [copy addObject:MobaDeepMutableJSONCopy(object)];
        }
        return copy;
    }
    return [value copy];
}

static NSMutableDictionary *MobaMutableJSONObjectFromData(NSData *data, NSError **error) {
    id object = [NSJSONSerialization JSONObjectWithData:data
                                                options:NSJSONReadingMutableContainers
                                                  error:error];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return MobaDeepMutableJSONCopy(object);
}

@interface MobaLayoutEditorControlDraft ()
@property (nonatomic, copy, readwrite) NSString *controlName;
@property (nonatomic, readwrite) double centerX;
@property (nonatomic, readwrite) double centerY;
@property (nonatomic, readwrite) double visualWidthPt;
@property (nonatomic, readwrite) double visualHeightPt;
@property (nonatomic, readwrite) double hitAreaScale;
@property (nonatomic, strong, readwrite, nullable) NSNumber *wheelRadiusPt;
@property (nonatomic, readwrite, getter=isWheelRadiusEditable) BOOL wheelRadiusEditable;
@property (nonatomic, readwrite) double opacity;
@property (nonatomic, readwrite) double pressedOpacity;
@property (nonatomic, readwrite) double disabledOpacity;
@property (nonatomic, readwrite) NSInteger zIndex;
@property (nonatomic, readwrite, getter=isInteractionEnabled) BOOL interactionEnabled;
- (instancetype)initWithName:(NSString *)name
                      profile:(MobaLayoutControlProfile *)profile
          wheelRadiusEditable:(BOOL)wheelRadiusEditable;
@end

@implementation MobaLayoutEditorControlDraft

- (instancetype)initWithName:(NSString *)name
                      profile:(MobaLayoutControlProfile *)profile
          wheelRadiusEditable:(BOOL)wheelRadiusEditable {
    self = [super init];
    if (self) {
        _controlName = [name copy];
        _centerX = profile.centerX;
        _centerY = profile.centerY;
        _visualWidthPt = profile.visualWidthPt;
        _visualHeightPt = profile.visualHeightPt;
        _hitAreaScale = profile.hitAreaScale;
        _wheelRadiusPt = [profile.wheelRadiusPt copy];
        _wheelRadiusEditable = wheelRadiusEditable;
        _opacity = profile.opacity;
        _pressedOpacity = profile.pressedOpacity;
        _disabledOpacity = profile.disabledOpacity;
        _zIndex = profile.zIndex;
        _interactionEnabled = profile.isInteractionEnabled;
    }
    return self;
}

- (instancetype)initWithControl:(MobaLayoutEditorControlDraft *)control {
    self = [super init];
    if (self) {
        _controlName = [control.controlName copy];
        _centerX = control.centerX;
        _centerY = control.centerY;
        _visualWidthPt = control.visualWidthPt;
        _visualHeightPt = control.visualHeightPt;
        _hitAreaScale = control.hitAreaScale;
        _wheelRadiusPt = [control.wheelRadiusPt copy];
        _wheelRadiusEditable = control.isWheelRadiusEditable;
        _opacity = control.opacity;
        _pressedOpacity = control.pressedOpacity;
        _disabledOpacity = control.disabledOpacity;
        _zIndex = control.zIndex;
        _interactionEnabled = control.isInteractionEnabled;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return [[MobaLayoutEditorControlDraft alloc] initWithControl:self];
}

- (MobaControlLayoutPresentation *)presentation {
    return [[MobaControlLayoutPresentation alloc]
        initWithCenterX:self.centerX
        centerY:self.centerY
        visualSize:CGSizeMake(self.visualWidthPt, self.visualHeightPt)
        hitAreaScale:self.hitAreaScale
        wheelRadiusPt:self.wheelRadiusPt
        normalOpacity:self.opacity
        pressedOpacity:self.pressedOpacity
        disabledOpacity:self.disabledOpacity
        zIndex:self.zIndex
        interactionEnabled:self.isInteractionEnabled];
}

@end

@interface MobaLayoutEditorCancelZoneDraft ()
@property (nonatomic, readwrite) double centerX;
@property (nonatomic, readwrite) double centerY;
@property (nonatomic, readwrite) double diameterPt;
@property (nonatomic, readwrite) double activationInsetPt;
@property (nonatomic, readwrite) double opacity;
@property (nonatomic, readwrite) BOOL visibleOnlyWhileCasting;
- (instancetype)initWithProfile:(MobaCancelZoneProfile *)profile;
@end

@implementation MobaLayoutEditorCancelZoneDraft

- (instancetype)initWithProfile:(MobaCancelZoneProfile *)profile {
    self = [super init];
    if (self) {
        _centerX = profile.centerX;
        _centerY = profile.centerY;
        _diameterPt = profile.diameterPt;
        _activationInsetPt = profile.activationInsetPt;
        _opacity = profile.opacity;
        _visibleOnlyWhileCasting = profile.visibleOnlyWhileCasting;
    }
    return self;
}

- (instancetype)initWithCancelZone:(MobaLayoutEditorCancelZoneDraft *)cancelZone {
    self = [super init];
    if (self) {
        _centerX = cancelZone.centerX;
        _centerY = cancelZone.centerY;
        _diameterPt = cancelZone.diameterPt;
        _activationInsetPt = cancelZone.activationInsetPt;
        _opacity = cancelZone.opacity;
        _visibleOnlyWhileCasting = cancelZone.visibleOnlyWhileCasting;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return [[MobaLayoutEditorCancelZoneDraft alloc] initWithCancelZone:self];
}

- (MobaCancelZoneLayoutPresentation *)presentation {
    return [[MobaCancelZoneLayoutPresentation alloc]
        initWithCenterX:self.centerX
        centerY:self.centerY
        diameterPt:self.diameterPt
        activationInsetPt:self.activationInsetPt
        opacity:self.opacity
        visibleOnlyWhileCasting:self.visibleOnlyWhileCasting];
}

@end

@interface MobaLayoutEditorDraft ()
@property (nonatomic, readwrite) double globalOpacityMultiplier;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *controlNames;
@property (nonatomic, strong, readwrite) MobaLayoutEditorCancelZoneDraft *cancelZone;
@property (nonatomic, strong) NSMutableDictionary *rawRuntimeJSON;
@property (nonatomic, strong) NSMutableDictionary *rawLayoutJSON;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MobaLayoutEditorControlDraft *> *controls;
- (void)replaceManagedValuesFromDraft:(MobaLayoutEditorDraft *)source;
@end

@implementation MobaLayoutEditorDraft

- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                      runtimeData:(NSData *)runtimeData
                       layoutData:(NSData *)layoutData
                            error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSError *parseError = nil;
    NSMutableDictionary *runtime = MobaMutableJSONObjectFromData(runtimeData, &parseError);
    NSMutableDictionary *layout = MobaMutableJSONObjectFromData(layoutData, &parseError);
    if (snapshot == nil || runtime == nil || layout == nil) {
        if (error != NULL) {
            *error = parseError ?: [NSError errorWithDomain:NSCocoaErrorDomain
                                                        code:NSPropertyListReadCorruptError
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Layout editor source JSON is invalid."}];
        }
        return nil;
    }
    self = [super init];
    if (self) {
        _rawRuntimeJSON = runtime;
        _rawLayoutJSON = layout;
        _globalOpacityMultiplier = snapshot.runtimeProfile.globalOpacityMultiplier;
        _controls = [NSMutableDictionary dictionary];
        NSMutableArray *names = [NSMutableArray array];
        for (NSString *name in MobaManagedLayoutControlNames()) {
            MobaLayoutControlProfile *profile = snapshot.layoutProfile.controls[name];
            if (profile != nil) {
                BOOL wheelEditable = [name isEqualToString:MobaLayoutEditorControlMove];
                NSDictionary *skillSlots = @{
                    @"abilityQ": @"Q", @"abilityW": @"W", @"abilityE": @"E", @"abilityR": @"R",
                };
                NSString *skillSlot = skillSlots[name];
                MobaChampionSkillProfile *skill = skillSlot != nil
                    ? snapshot.championProfile.skills[skillSlot] : nil;
                if (skill != nil && skill.castType != MobaProfileSkillCastTypeInstant) {
                    wheelEditable = YES;
                }
                _controls[name] = [[MobaLayoutEditorControlDraft alloc]
                    initWithName:name profile:profile wheelRadiusEditable:wheelEditable];
                [names addObject:name];
            }
        }
        _controlNames = [names copy];
        _cancelZone = [[MobaLayoutEditorCancelZoneDraft alloc] initWithProfile:snapshot.layoutProfile.cancelZone];
    }
    return self;
}

- (instancetype)initWithDraft:(MobaLayoutEditorDraft *)draft {
    self = [super init];
    if (self) {
        _rawRuntimeJSON = MobaDeepMutableJSONCopy(draft.rawRuntimeJSON);
        _rawLayoutJSON = MobaDeepMutableJSONCopy(draft.rawLayoutJSON);
        _globalOpacityMultiplier = draft.globalOpacityMultiplier;
        _controlNames = [draft.controlNames copy];
        _controls = [NSMutableDictionary dictionary];
        for (NSString *name in _controlNames) {
            _controls[name] = [draft.controls[name] copy];
        }
        _cancelZone = [draft.cancelZone copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return [[MobaLayoutEditorDraft alloc] initWithDraft:self];
}

- (MobaLayoutEditorControlDraft *)controlNamed:(NSString *)controlName {
    return self.controls[controlName];
}

- (NSMutableDictionary *)patchedRuntimeJSON {
    NSMutableDictionary *json = MobaDeepMutableJSONCopy(self.rawRuntimeJSON);
    json[@"globalOpacityMultiplier"] = @(self.globalOpacityMultiplier);
    return json;
}

- (NSMutableDictionary *)patchedLayoutJSON {
    NSMutableDictionary *json = MobaDeepMutableJSONCopy(self.rawLayoutJSON);
    NSMutableDictionary *controlsJSON = json[@"controls"];
    for (NSString *name in self.controlNames) {
        MobaLayoutEditorControlDraft *control = self.controls[name];
        NSMutableDictionary *controlJSON = controlsJSON[name];
        controlJSON[@"centerX"] = @(control.centerX);
        controlJSON[@"centerY"] = @(control.centerY);
        controlJSON[@"visualWidthPt"] = @(control.visualWidthPt);
        controlJSON[@"visualHeightPt"] = @(control.visualHeightPt);
        controlJSON[@"hitAreaScale"] = @(control.hitAreaScale);
        if (control.wheelRadiusPt != nil || controlJSON[@"wheelRadiusPt"] != nil) {
            if (control.wheelRadiusPt != nil) {
                controlJSON[@"wheelRadiusPt"] = control.wheelRadiusPt;
            }
            else {
                [controlJSON removeObjectForKey:@"wheelRadiusPt"];
            }
        }
        controlJSON[@"opacity"] = @(control.opacity);
        controlJSON[@"pressedOpacity"] = @(control.pressedOpacity);
        controlJSON[@"disabledOpacity"] = @(control.disabledOpacity);
        controlJSON[@"zIndex"] = @(control.zIndex);
        controlJSON[@"interactionEnabled"] = @(control.isInteractionEnabled);
    }
    NSMutableDictionary *cancelJSON = json[@"cancelZone"];
    cancelJSON[@"centerX"] = @(self.cancelZone.centerX);
    cancelJSON[@"centerY"] = @(self.cancelZone.centerY);
    cancelJSON[@"diameterPt"] = @(self.cancelZone.diameterPt);
    cancelJSON[@"activationInsetPt"] = @(self.cancelZone.activationInsetPt);
    cancelJSON[@"opacity"] = @(self.cancelZone.opacity);
    cancelJSON[@"visibleOnlyWhileCasting"] = @(self.cancelZone.visibleOnlyWhileCasting);
    return json;
}

- (NSData *)candidateRuntimeDataWithError:(NSError **)error {
    return [NSJSONSerialization dataWithJSONObject:[self patchedRuntimeJSON]
                                           options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                             error:error];
}

- (NSData *)candidateLayoutDataWithError:(NSError **)error {
    return [NSJSONSerialization dataWithJSONObject:[self patchedLayoutJSON]
                                           options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                             error:error];
}

- (void)replaceManagedValuesFromDraft:(MobaLayoutEditorDraft *)source {
    self.globalOpacityMultiplier = source.globalOpacityMultiplier;
    for (NSString *name in self.controlNames) {
        MobaLayoutEditorControlDraft *candidate = source.controls[name];
        if (candidate != nil) {
            self.controls[name] = [candidate copy];
        }
    }
    self.cancelZone = [source.cancelZone copy];
}

@end

@implementation MobaLayoutEditorController {
    MobaProfileDecoder *_decoder;
    MobaProfileSnapshot *_sourceSnapshot;
    MobaLayoutEditorDraft *_baseline;
    MobaLayoutEditorDraft *_draft;
    NSString *_selectedControlName;
}

- (instancetype)initWithSnapshot:(MobaProfileSnapshot *)snapshot
                      runtimeData:(NSData *)runtimeData
                       layoutData:(NSData *)layoutData
                          decoder:(MobaProfileDecoder *)decoder
                            error:(NSError **)error {
    MobaLayoutEditorDraft *draft = [[MobaLayoutEditorDraft alloc] initWithSnapshot:snapshot
                                                                       runtimeData:runtimeData
                                                                        layoutData:layoutData
                                                                             error:error];
    if (draft == nil || decoder == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        _decoder = decoder;
        _sourceSnapshot = snapshot;
        _baseline = [draft copy];
        _draft = draft;
        _opacityPreviewState = MobaControlOpacityPreviewStateNormal;
    }
    return self;
}

- (MobaLayoutEditorDraft *)draft { return _draft; }
- (NSString *)selectedControlName { return _selectedControlName; }

- (void)assertMainThread {
    NSAssert(NSThread.isMainThread, @"Layout editor operations require the main thread.");
}

- (void)notifyChange {
    [self.delegate layoutEditorControllerDidChangeDraft:self];
}

- (BOOL)isDirty {
    NSData *draftRuntime = [_draft candidateRuntimeDataWithError:nil];
    NSData *baselineRuntime = [_baseline candidateRuntimeDataWithError:nil];
    NSData *draftLayout = [_draft candidateLayoutDataWithError:nil];
    NSData *baselineLayout = [_baseline candidateLayoutDataWithError:nil];
    return ![draftRuntime isEqualToData:baselineRuntime] || ![draftLayout isEqualToData:baselineLayout];
}

- (void)setOpacityPreviewState:(MobaControlOpacityPreviewState)opacityPreviewState {
    [self assertMainThread];
    if (opacityPreviewState == MobaControlOpacityPreviewStateAutomatic) {
        opacityPreviewState = MobaControlOpacityPreviewStateNormal;
    }
    _opacityPreviewState = opacityPreviewState;
    [self notifyChange];
}

- (BOOL)selectControlNamed:(NSString *)controlName {
    [self assertMainThread];
    if (controlName != nil &&
        ![controlName isEqualToString:MobaLayoutEditorControlCancelZone] &&
        [_draft controlNamed:controlName] == nil) {
        return NO;
    }
    _selectedControlName = [controlName copy];
    [self notifyChange];
    return YES;
}

- (NSString *)selectTopmostControlAtPoint:(CGPoint)point safeAreaFrame:(CGRect)safeAreaFrame {
    [self assertMainThread];
    if (!isfinite(point.x) || !isfinite(point.y) ||
        !isfinite(safeAreaFrame.origin.x) || !isfinite(safeAreaFrame.origin.y) ||
        safeAreaFrame.size.width <= 0.0 || safeAreaFrame.size.height <= 0.0) {
        return nil;
    }
    NSString *winner = nil;
    NSInteger winnerZ = NSIntegerMin;
    for (NSString *name in _draft.controlNames) {
        MobaLayoutEditorControlDraft *control = [_draft controlNamed:name];
        CGPoint center = CGPointMake(CGRectGetMinX(safeAreaFrame) + control.centerX * CGRectGetWidth(safeAreaFrame),
                                     CGRectGetMinY(safeAreaFrame) + control.centerY * CGRectGetHeight(safeAreaFrame));
        CGSize hitSize = CGSizeMake(control.visualWidthPt * control.hitAreaScale,
                                    control.visualHeightPt * control.hitAreaScale);
        CGRect hitRect = CGRectMake(center.x - hitSize.width * 0.5,
                                    center.y - hitSize.height * 0.5,
                                    hitSize.width,
                                    hitSize.height);
        if (CGRectContainsPoint(hitRect, point) &&
            (winner == nil || control.zIndex >= winnerZ)) {
            winner = name;
            winnerZ = control.zIndex;
        }
    }
    MobaLayoutEditorCancelZoneDraft *cancel = _draft.cancelZone;
    CGPoint cancelCenter = CGPointMake(CGRectGetMinX(safeAreaFrame) + cancel.centerX * CGRectGetWidth(safeAreaFrame),
                                       CGRectGetMinY(safeAreaFrame) + cancel.centerY * CGRectGetHeight(safeAreaFrame));
    CGRect cancelRect = CGRectMake(cancelCenter.x - cancel.diameterPt * 0.5,
                                   cancelCenter.y - cancel.diameterPt * 0.5,
                                   cancel.diameterPt,
                                   cancel.diameterPt);
    if (winner == nil && CGRectContainsPoint(cancelRect, point)) {
        winner = MobaLayoutEditorControlCancelZone;
    }
    [self selectControlNamed:winner];
    return winner;
}

- (BOOL)moveSelectedControlToPoint:(CGPoint)point safeAreaFrame:(CGRect)safeAreaFrame {
    [self assertMainThread];
    if (_selectedControlName == nil || !isfinite(point.x) || !isfinite(point.y) ||
        safeAreaFrame.size.width <= 0.0 || safeAreaFrame.size.height <= 0.0) {
        return NO;
    }
    double x = (point.x - CGRectGetMinX(safeAreaFrame)) / CGRectGetWidth(safeAreaFrame);
    double y = (point.y - CGRectGetMinY(safeAreaFrame)) / CGRectGetHeight(safeAreaFrame);
    x = fmin(fmax(x, 0.0), 1.0);
    y = fmin(fmax(y, 0.0), 1.0);
    if ([_selectedControlName isEqualToString:MobaLayoutEditorControlCancelZone]) {
        _draft.cancelZone.centerX = x;
        _draft.cancelZone.centerY = y;
    }
    else {
        MobaLayoutEditorControlDraft *control = [_draft controlNamed:_selectedControlName];
        if (control == nil) {
            return NO;
        }
        control.centerX = x;
        control.centerY = y;
    }
    [self notifyChange];
    return YES;
}

- (BOOL)setSelectedControlValue:(double)value forField:(MobaLayoutEditorControlField)field {
    [self assertMainThread];
    if (!isfinite(value)) {
        return NO;
    }
    MobaLayoutEditorControlDraft *control = [_draft controlNamed:_selectedControlName];
    if (control == nil) {
        return NO;
    }
    switch (field) {
        case MobaLayoutEditorControlFieldCenterX: control.centerX = value; break;
        case MobaLayoutEditorControlFieldCenterY: control.centerY = value; break;
        case MobaLayoutEditorControlFieldVisualWidth: control.visualWidthPt = value; break;
        case MobaLayoutEditorControlFieldVisualHeight: control.visualHeightPt = value; break;
        case MobaLayoutEditorControlFieldHitAreaScale: control.hitAreaScale = value; break;
        case MobaLayoutEditorControlFieldWheelRadius:
            if (!control.isWheelRadiusEditable || control.wheelRadiusPt == nil) return NO;
            control.wheelRadiusPt = @(value);
            break;
        case MobaLayoutEditorControlFieldNormalOpacity: control.opacity = value; break;
        case MobaLayoutEditorControlFieldPressedOpacity: control.pressedOpacity = value; break;
        case MobaLayoutEditorControlFieldDisabledOpacity: control.disabledOpacity = value; break;
    }
    [self notifyChange];
    return YES;
}

- (BOOL)setSelectedControlInteractionEnabled:(BOOL)enabled {
    [self assertMainThread];
    MobaLayoutEditorControlDraft *control = [_draft controlNamed:_selectedControlName];
    if (control == nil) return NO;
    control.interactionEnabled = enabled;
    [self notifyChange];
    return YES;
}

- (BOOL)adjustSelectedControlZIndexBy:(NSInteger)delta {
    [self assertMainThread];
    MobaLayoutEditorControlDraft *control = [_draft controlNamed:_selectedControlName];
    if (control == nil || (delta != 1 && delta != -1) ||
        (delta == 1 && control.zIndex == NSIntegerMax) ||
        (delta == -1 && control.zIndex == NSIntegerMin)) {
        return NO;
    }
    control.zIndex += delta;
    [self notifyChange];
    return YES;
}

- (BOOL)setCancelZoneValue:(double)value forField:(MobaLayoutEditorCancelZoneField)field {
    [self assertMainThread];
    if (!isfinite(value)) return NO;
    switch (field) {
        case MobaLayoutEditorCancelZoneFieldCenterX: _draft.cancelZone.centerX = value; break;
        case MobaLayoutEditorCancelZoneFieldCenterY: _draft.cancelZone.centerY = value; break;
        case MobaLayoutEditorCancelZoneFieldDiameter: _draft.cancelZone.diameterPt = value; break;
        case MobaLayoutEditorCancelZoneFieldActivationInset: _draft.cancelZone.activationInsetPt = value; break;
        case MobaLayoutEditorCancelZoneFieldOpacity: _draft.cancelZone.opacity = value; break;
    }
    [self notifyChange];
    return YES;
}

- (void)setCancelZoneVisibleOnlyWhileCasting:(BOOL)visibleOnlyWhileCasting {
    [self assertMainThread];
    _draft.cancelZone.visibleOnlyWhileCasting = visibleOnlyWhileCasting;
    [self notifyChange];
}

- (BOOL)setGlobalOpacityMultiplierValue:(double)value {
    [self assertMainThread];
    if (!isfinite(value)) return NO;
    _draft.globalOpacityMultiplier = value;
    [self notifyChange];
    return YES;
}

- (void)revert {
    [self assertMainThread];
    _draft = [_baseline copy];
    _selectedControlName = nil;
    [self notifyChange];
}

- (BOOL)restoreDefaultsFromRuntimeData:(NSData *)runtimeData
                            layoutData:(NSData *)layoutData
                                 error:(NSError **)error {
    [self assertMainThread];
    MobaRuntimeProfile *runtime = [_decoder decodeRuntimeProfileData:runtimeData error:error];
    if (runtime == nil) return NO;
    MobaLayoutProfile *layout = [_decoder decodeLayoutProfileData:layoutData error:error];
    if (layout == nil) return NO;
    MobaProfileSnapshot *current = [[MobaProfileSnapshot alloc]
        initWithRuntimeProfile:runtime
        inputProfile:_sourceSnapshot.inputProfile
        layoutProfile:layout
        championProfile:_sourceSnapshot.championProfile];
    MobaLayoutEditorDraft *defaults = [[MobaLayoutEditorDraft alloc]
        initWithSnapshot:current runtimeData:runtimeData layoutData:layoutData error:error];
    if (defaults == nil) return NO;
    [_draft replaceManagedValuesFromDraft:defaults];
    [self notifyChange];
    return YES;
}

- (BOOL)acceptSavedSnapshot:(MobaProfileSnapshot *)snapshot
                runtimeData:(NSData *)runtimeData
                 layoutData:(NSData *)layoutData
                      error:(NSError **)error {
    [self assertMainThread];
    MobaLayoutEditorDraft *saved = [[MobaLayoutEditorDraft alloc] initWithSnapshot:snapshot
                                                                        runtimeData:runtimeData
                                                                         layoutData:layoutData
                                                                              error:error];
    if (saved == nil) return NO;
    _baseline = [saved copy];
    _draft = saved;
    _sourceSnapshot = snapshot;
    [self notifyChange];
    return YES;
}

@end
