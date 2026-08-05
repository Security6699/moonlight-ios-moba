//
//  MobaProfileModels.m
//  Moonlight
//

#import "MobaProfileModelsInternal.h"

@interface MobaProfileSize ()
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height;
@end

@implementation MobaProfileSize
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height {
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
    }
    return self;
}
@end

@interface MobaProfilePoint ()
- (instancetype)initWithX:(double)x y:(double)y;
@end

@implementation MobaProfilePoint
- (instancetype)initWithX:(double)x y:(double)y {
    self = [super init];
    if (self) {
        _x = x;
        _y = y;
    }
    return self;
}
@end

@interface MobaCameraProfile ()
- (instancetype)initWithMode:(NSString *)mode heroAnchor:(MobaProfilePoint *)heroAnchor;
@end

@implementation MobaCameraProfile
- (instancetype)initWithMode:(NSString *)mode heroAnchor:(MobaProfilePoint *)heroAnchor {
    self = [super init];
    if (self) {
        _mode = [mode copy];
        _heroAnchor = heroAnchor;
    }
    return self;
}
@end

@interface MobaRuntimeProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaRuntimeProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        NSDictionary *canvas = json[@"canvas"];
        NSDictionary *stream = json[@"requiredStreamResolution"];
        NSDictionary *camera = json[@"camera"];
        NSDictionary *anchor = camera[@"heroAnchorPx"];
        _schemaVersion = [json[@"schemaVersion"] unsignedIntegerValue];
        _canvas = [[MobaProfileSize alloc] initWithWidth:[canvas[@"width"] unsignedIntegerValue]
                                                  height:[canvas[@"height"] unsignedIntegerValue]];
        _requiredStreamResolution = [[MobaProfileSize alloc]
            initWithWidth:[stream[@"width"] unsignedIntegerValue]
                    height:[stream[@"height"] unsignedIntegerValue]];
        _videoMode = [json[@"videoMode"] copy];
        MobaProfilePoint *heroAnchor = [[MobaProfilePoint alloc] initWithX:[anchor[@"x"] doubleValue]
                                                                        y:[anchor[@"y"] doubleValue]];
        _camera = [[MobaCameraProfile alloc] initWithMode:camera[@"mode"] heroAnchor:heroAnchor];
        _mouseUpdateRateHz = [json[@"mouseUpdateRateHz"] unsignedIntegerValue];
        _globalOpacityMultiplier = [json[@"globalOpacityMultiplier"] doubleValue];
    }
    return self;
}
@end

@interface MobaMovementProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaMovementProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _upKeyCode = [json[@"up"] unsignedShortValue];
        _leftKeyCode = [json[@"left"] unsignedShortValue];
        _downKeyCode = [json[@"down"] unsignedShortValue];
        _rightKeyCode = [json[@"right"] unsignedShortValue];
    }
    return self;
}
@end

@interface MobaCancelCastActionProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaCancelCastActionProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        NSString *type = json[@"type"];
        if ([type isEqualToString:@"keyboard"]) {
            _type = MobaProfileCancelTypeKeyboard;
            _hasKeyCode = YES;
            _keyCode = [json[@"keyCode"] unsignedShortValue];
        }
        else if ([type isEqualToString:@"rightMouse"]) {
            _type = MobaProfileCancelTypeRightMouse;
        }
        else {
            _type = MobaProfileCancelTypeReleaseOnly;
        }
        _cancelBeforeSkillKeyUp = [json[@"cancelBeforeSkillKeyUp"] boolValue];
    }
    return self;
}
@end

@interface MobaInputProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaInputProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _schemaVersion = [json[@"schemaVersion"] unsignedIntegerValue];
        _profileID = [json[@"profileId"] copy];
        _movement = [[MobaMovementProfile alloc] initWithJSON:json[@"movement"]];
        _actions = [json[@"actions"] copy];
        _attackTapDurationMs = [json[@"attackTapDurationMs"] unsignedIntegerValue];
        _cancelCastAction = [[MobaCancelCastActionProfile alloc] initWithJSON:json[@"cancelCastAction"]];
    }
    return self;
}
- (NSNumber *)keyCodeForAction:(NSString *)actionName {
    return self.actions[actionName];
}
@end

@interface MobaLayoutControlProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaLayoutControlProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _centerX = [json[@"centerX"] doubleValue];
        _centerY = [json[@"centerY"] doubleValue];
        _visualWidthPt = [json[@"visualWidthPt"] doubleValue];
        _visualHeightPt = [json[@"visualHeightPt"] doubleValue];
        _hitAreaScale = [json[@"hitAreaScale"] doubleValue];
        _wheelRadiusPt = [json[@"wheelRadiusPt"] copy];
        _opacity = [json[@"opacity"] doubleValue];
        _pressedOpacity = [json[@"pressedOpacity"] doubleValue];
        _disabledOpacity = [json[@"disabledOpacity"] doubleValue];
        _zIndex = [json[@"zIndex"] integerValue];
        _interactionEnabled = [json[@"interactionEnabled"] boolValue];
    }
    return self;
}
@end

@interface MobaCancelZoneProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaCancelZoneProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _centerX = [json[@"centerX"] doubleValue];
        _centerY = [json[@"centerY"] doubleValue];
        _diameterPt = [json[@"diameterPt"] doubleValue];
        _activationInsetPt = [json[@"activationInsetPt"] doubleValue];
        _opacity = [json[@"opacity"] doubleValue];
        _visibleOnlyWhileCasting = [json[@"visibleOnlyWhileCasting"] boolValue];
    }
    return self;
}
@end

@interface MobaLayoutProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaLayoutProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _schemaVersion = [json[@"schemaVersion"] unsignedIntegerValue];
        _layoutID = [json[@"layoutId"] copy];
        _deviceClass = [json[@"deviceClass"] copy];
        NSMutableDictionary *controls = [NSMutableDictionary dictionary];
        NSDictionary<NSString *, NSDictionary *> *controlJSON = json[@"controls"];
        [controlJSON enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *value, BOOL *stop) {
            controls[[name copy]] = [[MobaLayoutControlProfile alloc] initWithJSON:value];
        }];
        _controls = [controls copy];
        _cancelZone = [[MobaCancelZoneProfile alloc] initWithJSON:json[@"cancelZone"]];
    }
    return self;
}
@end

@interface MobaDefaultAimProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaDefaultAimProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _angleDegrees = [json[@"angleDeg"] doubleValue];
        _distanceRatio = [json[@"distanceRatio"] doubleValue];
    }
    return self;
}
@end

@interface MobaDirectionalRangeProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaDirectionalRangeProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _model = MobaProfileRangeModelAsymmetricEllipse;
        _leftPx = [json[@"leftPx"] doubleValue];
        _rightPx = [json[@"rightPx"] doubleValue];
        _upPx = [json[@"upPx"] doubleValue];
        _downPx = [json[@"downPx"] doubleValue];
    }
    return self;
}
@end

@interface MobaPointRangeProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaPointRangeProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _model = MobaProfileRangeModelAsymmetricEllipse;
        _minLeftPx = [json[@"minLeftPx"] doubleValue];
        _minRightPx = [json[@"minRightPx"] doubleValue];
        _minUpPx = [json[@"minUpPx"] doubleValue];
        _minDownPx = [json[@"minDownPx"] doubleValue];
        _maxLeftPx = [json[@"maxLeftPx"] doubleValue];
        _maxRightPx = [json[@"maxRightPx"] doubleValue];
        _maxUpPx = [json[@"maxUpPx"] doubleValue];
        _maxDownPx = [json[@"maxDownPx"] doubleValue];
    }
    return self;
}
@end

@interface MobaTouchResponseProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaTouchResponseProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _deadzoneRatio = [json[@"deadzoneRatio"] doubleValue];
        _fullRangeRatio = [json[@"fullRangeRatio"] copy];
        _curveExponent = [json[@"curveExponent"] copy];
    }
    return self;
}
@end

@interface MobaChampionSkillProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaChampionSkillProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _inputAction = [json[@"inputAction"] copy];
        NSString *castType = json[@"castType"];
        if ([castType isEqualToString:@"instant"]) {
            _castType = MobaProfileSkillCastTypeInstant;
            _activation = MobaProfileSkillActivationOnRelease;
            _hasTapDuration = YES;
            _tapDurationMs = [json[@"tapDurationMs"] unsignedIntegerValue];
        }
        else if ([castType isEqualToString:@"directional"]) {
            _castType = MobaProfileSkillCastTypeDirectional;
            _defaultAim = [[MobaDefaultAimProfile alloc] initWithJSON:json[@"defaultAim"]];
            _directionalRange = [[MobaDirectionalRangeProfile alloc] initWithJSON:json[@"range"]];
            _touchResponse = [[MobaTouchResponseProfile alloc] initWithJSON:json[@"touchResponse"]];
        }
        else {
            _castType = MobaProfileSkillCastTypePoint;
            _targetMode = [json[@"targetMode"] isEqualToString:@"ground"]
                ? MobaProfilePointTargetModeGround : MobaProfilePointTargetModeUnit;
            _defaultAim = [[MobaDefaultAimProfile alloc] initWithJSON:json[@"defaultAim"]];
            _pointRange = [[MobaPointRangeProfile alloc] initWithJSON:json[@"range"]];
            _touchResponse = [[MobaTouchResponseProfile alloc] initWithJSON:json[@"touchResponse"]];
        }
        _allowCancel = [json[@"allowCancel"] boolValue];
    }
    return self;
}
@end

@interface MobaChampionProfile ()
- (instancetype)initWithJSON:(NSDictionary *)json;
@end

@implementation MobaChampionProfile
- (instancetype)initWithJSON:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _schemaVersion = [json[@"schemaVersion"] unsignedIntegerValue];
        _championID = [json[@"championId"] copy];
        _displayName = [json[@"displayName"] copy];
        _displayNameZhCN = [json[@"displayNameZhCN"] copy];
        _calibrationStatus = [json[@"calibrationStatus"] copy];
        NSMutableDictionary *skills = [NSMutableDictionary dictionary];
        NSDictionary<NSString *, NSDictionary *> *skillJSON = json[@"skills"];
        [skillJSON enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSDictionary *value, BOOL *stop) {
            skills[[name copy]] = [[MobaChampionSkillProfile alloc] initWithJSON:value];
        }];
        _skills = [skills copy];
    }
    return self;
}
@end

@implementation MobaProfileSnapshot
- (instancetype)initWithRuntimeProfile:(MobaRuntimeProfile *)runtimeProfile
                           inputProfile:(MobaInputProfile *)inputProfile
                          layoutProfile:(MobaLayoutProfile *)layoutProfile
                        championProfile:(MobaChampionProfile *)championProfile {
    self = [super init];
    if (self) {
        _runtimeProfile = runtimeProfile;
        _inputProfile = inputProfile;
        _layoutProfile = layoutProfile;
        _championProfile = championProfile;
    }
    return self;
}
@end

MobaRuntimeProfile *MobaRuntimeProfileFromValidatedJSON(NSDictionary *json) {
    return [[MobaRuntimeProfile alloc] initWithJSON:json];
}

MobaInputProfile *MobaInputProfileFromValidatedJSON(NSDictionary *json) {
    return [[MobaInputProfile alloc] initWithJSON:json];
}

MobaLayoutProfile *MobaLayoutProfileFromValidatedJSON(NSDictionary *json) {
    return [[MobaLayoutProfile alloc] initWithJSON:json];
}

MobaChampionProfile *MobaChampionProfileFromValidatedJSON(NSDictionary *json) {
    return [[MobaChampionProfile alloc] initWithJSON:json];
}
