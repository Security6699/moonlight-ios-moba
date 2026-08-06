//
//  MobaSkillTuning.m
//  Moonlight
//

#import "MobaSkillTuning.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

NSErrorDomain const MobaSkillTuningErrorDomain = @"MobaSkillTuningErrorDomain";

static NSError *MobaSkillTuningError(MobaSkillTuningErrorCode code,
                                     NSString *description,
                                     NSString *fieldPath,
                                     NSError *underlying) {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:description
                                                                    forKey:NSLocalizedDescriptionKey];
    if (fieldPath.length > 0) info[@"fieldPath"] = fieldPath;
    if (underlying != nil) info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:MobaSkillTuningErrorDomain code:code userInfo:info];
}

static id MobaSkillTuningDeepMutableCopy(id object) {
    if ([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *copy = [NSMutableDictionary dictionary];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            copy[key] = MobaSkillTuningDeepMutableCopy(value);
        }];
        return copy;
    }
    if ([object isKindOfClass:NSArray.class]) {
        NSMutableArray *copy = [NSMutableArray array];
        for (id value in (NSArray *)object) [copy addObject:MobaSkillTuningDeepMutableCopy(value)];
        return copy;
    }
    return [object copy];
}

static NSMutableDictionary *MobaSkillTuningJSONObject(NSData *data, NSError **error) {
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    return MobaSkillTuningDeepMutableCopy(object);
}

static NSData *MobaSkillTuningJSONData(NSDictionary *json, NSError **error) {
    if (![NSJSONSerialization isValidJSONObject:json]) {
        if (error != NULL) {
            *error = MobaSkillTuningError(MobaSkillTuningErrorSerializationFailed,
                                          @"The skill tuning draft is not valid JSON.", @"$", nil);
        }
        return nil;
    }
    return [NSJSONSerialization dataWithJSONObject:json
                                           options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                             error:error];
}

@interface MobaSkillTuningSkillValue ()
- (instancetype)initWithSlot:(MobaCanonicalSkillSlot)slot json:(NSDictionary *)json;
@end

@implementation MobaSkillTuningSkillValue
- (instancetype)initWithSlot:(MobaCanonicalSkillSlot)slot json:(NSDictionary *)json {
    self = [super init];
    if (self) {
        _skillSlot = [slot copy];
        NSString *castType = json[@"castType"];
        _castType = [castType isEqualToString:@"instant"] ? MobaProfileSkillCastTypeInstant
            : [castType isEqualToString:@"directional"] ? MobaProfileSkillCastTypeDirectional
            : MobaProfileSkillCastTypePoint;
        _allowCancel = [json[@"allowCancel"] boolValue];
        NSDictionary *defaultAim = json[@"defaultAim"];
        _defaultAngleDegrees = defaultAim[@"angleDeg"];
        _defaultDistanceRatio = defaultAim[@"distanceRatio"];
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        NSDictionary *range = json[@"range"];
        NSDictionary *response = json[@"touchResponse"];
        NSArray *fields = @[
            @(MobaSkillTuningFieldDirectionalLeftPx), @(MobaSkillTuningFieldDirectionalRightPx),
            @(MobaSkillTuningFieldDirectionalUpPx), @(MobaSkillTuningFieldDirectionalDownPx),
            @(MobaSkillTuningFieldPointMinLeftPx), @(MobaSkillTuningFieldPointMinRightPx),
            @(MobaSkillTuningFieldPointMinUpPx), @(MobaSkillTuningFieldPointMinDownPx),
            @(MobaSkillTuningFieldPointMaxLeftPx), @(MobaSkillTuningFieldPointMaxRightPx),
            @(MobaSkillTuningFieldPointMaxUpPx), @(MobaSkillTuningFieldPointMaxDownPx),
            @(MobaSkillTuningFieldTouchDeadzoneRatio), @(MobaSkillTuningFieldTouchFullRangeRatio),
            @(MobaSkillTuningFieldTouchCurveExponent),
        ];
        NSDictionary *keys = @{
            @(MobaSkillTuningFieldDirectionalLeftPx): @"leftPx",
            @(MobaSkillTuningFieldDirectionalRightPx): @"rightPx",
            @(MobaSkillTuningFieldDirectionalUpPx): @"upPx",
            @(MobaSkillTuningFieldDirectionalDownPx): @"downPx",
            @(MobaSkillTuningFieldPointMinLeftPx): @"minLeftPx",
            @(MobaSkillTuningFieldPointMinRightPx): @"minRightPx",
            @(MobaSkillTuningFieldPointMinUpPx): @"minUpPx",
            @(MobaSkillTuningFieldPointMinDownPx): @"minDownPx",
            @(MobaSkillTuningFieldPointMaxLeftPx): @"maxLeftPx",
            @(MobaSkillTuningFieldPointMaxRightPx): @"maxRightPx",
            @(MobaSkillTuningFieldPointMaxUpPx): @"maxUpPx",
            @(MobaSkillTuningFieldPointMaxDownPx): @"maxDownPx",
            @(MobaSkillTuningFieldTouchDeadzoneRatio): @"deadzoneRatio",
            @(MobaSkillTuningFieldTouchFullRangeRatio): @"fullRangeRatio",
            @(MobaSkillTuningFieldTouchCurveExponent): @"curveExponent",
        };
        for (NSNumber *field in fields) {
            NSDictionary *source = field.integerValue >= MobaSkillTuningFieldTouchDeadzoneRatio ? response : range;
            NSNumber *number = source[keys[field]];
            if (number != nil) values[field] = number;
        }
        _numericValues = [values copy];
    }
    return self;
}
@end

@implementation MobaSkillTuningDraft {
    NSMutableDictionary *_runtimeJSON;
    NSMutableDictionary *_championJSON;
    NSData *_baselineRuntimeData;
    NSData *_baselineChampionData;
}

- (instancetype)initWithRuntimeData:(NSData *)runtimeData
                       championData:(NSData *)championData
                            decoder:(MobaProfileDecoder *)decoder
                              error:(NSError **)error {
    self = [super init];
    if (self) {
        if ([decoder decodeRuntimeProfileData:runtimeData error:error] == nil ||
            [decoder decodeChampionProfileData:championData error:error] == nil) return nil;
        _runtimeJSON = MobaSkillTuningJSONObject(runtimeData, error);
        _championJSON = MobaSkillTuningJSONObject(championData, error);
        if (_runtimeJSON == nil || _championJSON == nil) return nil;
        _baselineRuntimeData = [runtimeData copy];
        _baselineChampionData = [championData copy];
    }
    return self;
}

- (double)heroAnchorX { return [_runtimeJSON[@"camera"][@"heroAnchorPx"][@"x"] doubleValue]; }
- (double)heroAnchorY { return [_runtimeJSON[@"camera"][@"heroAnchorPx"][@"y"] doubleValue]; }
- (NSUInteger)mouseUpdateRateHz { return [_runtimeJSON[@"mouseUpdateRateHz"] unsignedIntegerValue]; }

- (BOOL)isDirty {
    NSData *runtime = [self runtimeDataWithError:nil];
    NSData *champion = [self championDataWithError:nil];
    NSDictionary *currentRuntime = runtime == nil ? nil : [NSJSONSerialization JSONObjectWithData:runtime options:0 error:nil];
    NSDictionary *baseRuntime = [NSJSONSerialization JSONObjectWithData:_baselineRuntimeData options:0 error:nil];
    NSDictionary *currentChampion = champion == nil ? nil : [NSJSONSerialization JSONObjectWithData:champion options:0 error:nil];
    NSDictionary *baseChampion = [NSJSONSerialization JSONObjectWithData:_baselineChampionData options:0 error:nil];
    return ![currentRuntime isEqual:baseRuntime] || ![currentChampion isEqual:baseChampion];
}

- (NSMutableDictionary *)skillJSONForSlot:(MobaCanonicalSkillSlot)slot {
    id skill = _championJSON[@"skills"][slot];
    return [skill isKindOfClass:NSMutableDictionary.class] ? skill : nil;
}

- (MobaSkillTuningSkillValue *)skillValueForSlot:(MobaCanonicalSkillSlot)slot {
    NSDictionary *skill = [self skillJSONForSlot:slot];
    return skill == nil ? nil : [[MobaSkillTuningSkillValue alloc] initWithSlot:slot json:skill];
}

- (BOOL)validFiniteNumber:(id)value fieldPath:(NSString *)path error:(NSError **)error {
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() ||
        !isfinite([value doubleValue])) {
        if (error != NULL) {
            *error = MobaSkillTuningError(MobaSkillTuningErrorInvalidField,
                                          @"Skill tuning values must be finite JSON numbers.", path, nil);
        }
        return NO;
    }
    return YES;
}

- (BOOL)setHeroAnchorX:(double)x y:(double)y error:(NSError **)error {
    if (![self validFiniteNumber:@(x) fieldPath:@"$.camera.heroAnchorPx.x" error:error] ||
        ![self validFiniteNumber:@(y) fieldPath:@"$.camera.heroAnchorPx.y" error:error]) return NO;
    _runtimeJSON[@"camera"][@"heroAnchorPx"][@"x"] = @(x);
    _runtimeJSON[@"camera"][@"heroAnchorPx"][@"y"] = @(y);
    return YES;
}

- (BOOL)setMouseUpdateRateHz:(NSUInteger)rate error:(NSError **)error {
    if (rate != 30 && rate != 60 && rate != 120) {
        if (error != NULL) *error = MobaSkillTuningError(MobaSkillTuningErrorInvalidField,
            @"mouseUpdateRateHz must be 30, 60, or 120.", @"$.mouseUpdateRateHz", nil);
        return NO;
    }
    _runtimeJSON[@"mouseUpdateRateHz"] = @(rate);
    return YES;
}

- (BOOL)setValue:(id)value forField:(MobaSkillTuningField)field
       skillSlot:(MobaCanonicalSkillSlot)slot error:(NSError **)error {
    NSMutableDictionary *skill = [self skillJSONForSlot:slot];
    if (skill == nil) return NO;
    NSString *path = [NSString stringWithFormat:@"$.skills.%@", slot];
    if (![self validFiniteNumber:value fieldPath:path error:error]) return NO;
    NSString *castType = skill[@"castType"];
    NSMutableDictionary *target = nil;
    NSString *key = nil;
    switch (field) {
        case MobaSkillTuningFieldDefaultAngleDegrees: target = skill[@"defaultAim"]; key = @"angleDeg"; break;
        case MobaSkillTuningFieldDefaultDistanceRatio: target = skill[@"defaultAim"]; key = @"distanceRatio"; break;
        case MobaSkillTuningFieldDirectionalLeftPx: key = @"leftPx"; break;
        case MobaSkillTuningFieldDirectionalRightPx: key = @"rightPx"; break;
        case MobaSkillTuningFieldDirectionalUpPx: key = @"upPx"; break;
        case MobaSkillTuningFieldDirectionalDownPx: key = @"downPx"; break;
        case MobaSkillTuningFieldPointMinLeftPx: key = @"minLeftPx"; break;
        case MobaSkillTuningFieldPointMinRightPx: key = @"minRightPx"; break;
        case MobaSkillTuningFieldPointMinUpPx: key = @"minUpPx"; break;
        case MobaSkillTuningFieldPointMinDownPx: key = @"minDownPx"; break;
        case MobaSkillTuningFieldPointMaxLeftPx: key = @"maxLeftPx"; break;
        case MobaSkillTuningFieldPointMaxRightPx: key = @"maxRightPx"; break;
        case MobaSkillTuningFieldPointMaxUpPx: key = @"maxUpPx"; break;
        case MobaSkillTuningFieldPointMaxDownPx: key = @"maxDownPx"; break;
        case MobaSkillTuningFieldTouchDeadzoneRatio: key = @"deadzoneRatio"; break;
        case MobaSkillTuningFieldTouchFullRangeRatio: key = @"fullRangeRatio"; break;
        case MobaSkillTuningFieldTouchCurveExponent: key = @"curveExponent"; break;
    }
    if (field >= MobaSkillTuningFieldDirectionalLeftPx && field <= MobaSkillTuningFieldDirectionalDownPx) {
        if (![castType isEqualToString:@"directional"]) target = nil; else target = skill[@"range"];
    }
    else if (field >= MobaSkillTuningFieldPointMinLeftPx && field <= MobaSkillTuningFieldPointMaxDownPx) {
        if (![castType isEqualToString:@"point"]) target = nil; else target = skill[@"range"];
    }
    else if (field >= MobaSkillTuningFieldTouchDeadzoneRatio) {
        if ([castType isEqualToString:@"instant"]) target = nil; else target = skill[@"touchResponse"];
    }
    if (![target isKindOfClass:NSMutableDictionary.class] || key == nil) {
        if (error != NULL) *error = MobaSkillTuningError(MobaSkillTuningErrorInvalidField,
            @"The selected field does not apply to this skill cast type.", path, nil);
        return NO;
    }
    target[key] = value;
    return YES;
}

- (BOOL)setAllowCancel:(BOOL)allowCancel skillSlot:(MobaCanonicalSkillSlot)slot error:(NSError **)error {
    NSMutableDictionary *skill = [self skillJSONForSlot:slot];
    if (skill == nil) {
        if (error != NULL) *error = MobaSkillTuningError(MobaSkillTuningErrorInvalidField,
            @"The selected skill does not exist.", [NSString stringWithFormat:@"$.skills.%@", slot], nil);
        return NO;
    }
    skill[@"allowCancel"] = @(allowCancel);
    return YES;
}

- (NSData *)runtimeDataWithError:(NSError **)error { return MobaSkillTuningJSONData(_runtimeJSON, error); }
- (NSData *)championDataWithError:(NSError **)error { return MobaSkillTuningJSONData(_championJSON, error); }

- (BOOL)replaceWithRuntimeData:(NSData *)runtimeData championData:(NSData *)championData
                       decoder:(MobaProfileDecoder *)decoder error:(NSError **)error {
    if ([decoder decodeRuntimeProfileData:runtimeData error:error] == nil ||
        [decoder decodeChampionProfileData:championData error:error] == nil) return NO;
    NSMutableDictionary *runtimeJSON = MobaSkillTuningJSONObject(runtimeData, error);
    NSMutableDictionary *championJSON = MobaSkillTuningJSONObject(championData, error);
    if (runtimeJSON == nil || championJSON == nil) return NO;
    _runtimeJSON = runtimeJSON;
    _championJSON = championJSON;
    return YES;
}

- (void)revert {
    _runtimeJSON = MobaSkillTuningJSONObject(_baselineRuntimeData, nil);
    _championJSON = MobaSkillTuningJSONObject(_baselineChampionData, nil);
}

- (BOOL)acceptCurrentValuesAsBaselineWithError:(NSError **)error {
    NSData *runtime = [self runtimeDataWithError:error];
    NSData *champion = [self championDataWithError:error];
    if (runtime == nil || champion == nil) return NO;
    _baselineRuntimeData = runtime;
    _baselineChampionData = champion;
    return YES;
}
@end

@implementation MobaSkillTuningController {
    MobaProfileDecoder *_decoder;
    MobaProfileRepository *_repository;
    id<MobaChampionRuntimeBuilding> _runtimeBuilder;
    id<MobaSkillControlPackageBuilding> _controlPackageBuilder;
}

- (instancetype)initWithRuntimeData:(NSData *)runtimeData championData:(NSData *)championData
                            decoder:(MobaProfileDecoder *)decoder repository:(MobaProfileRepository *)repository
                     runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
              controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder
                              error:(NSError **)error {
    self = [super init];
    if (self) {
        _decoder = decoder;
        _repository = repository;
        _runtimeBuilder = runtimeBuilder;
        _controlPackageBuilder = controlPackageBuilder;
        _draft = [[MobaSkillTuningDraft alloc] initWithRuntimeData:runtimeData championData:championData
                                                           decoder:decoder error:error];
        if (_draft == nil) return nil;
        _selectedSkillSlot = MobaCanonicalSkillSlotQ;
        if (![self refreshCandidateWithError:error]) return nil;
    }
    return self;
}

- (BOOL)refreshCandidateWithError:(NSError **)error {
    NSData *runtimeData = [_draft runtimeDataWithError:error];
    NSData *championData = [_draft championDataWithError:error];
    if (runtimeData == nil || championData == nil) return NO;
    NSError *candidateError = nil;
    MobaProfileRepositoryCandidate *candidate = [_repository
        prepareSkillTuningCandidateWithRuntimeData:runtimeData championData:championData error:&candidateError];
    MobaChampionRuntime *runtime = candidate == nil ? nil
        : [_runtimeBuilder runtimeFromSnapshot:candidate.snapshot error:&candidateError];
    MobaSkillControlPackage *package = runtime == nil ? nil
        : [_controlPackageBuilder controlPackageForRuntime:runtime error:&candidateError];
    if (candidate == nil || runtime == nil || !package.isComplete) {
        _validationError = candidateError ?: MobaSkillTuningError(MobaSkillTuningErrorCandidateRejected,
            @"The complete skill tuning candidate was rejected.", @"$", nil);
        if (error != NULL) *error = _validationError;
        return NO;
    }
    _lastValidCandidate = candidate;
    _lastValidRuntime = runtime;
    _lastValidControlPackage = package;
    _validationError = nil;
    return YES;
}

- (BOOL)restoreDefaultsFromRuntimeData:(NSData *)runtimeData championData:(NSData *)championData
                                 error:(NSError **)error {
    NSData *oldRuntime = [_draft runtimeDataWithError:nil];
    NSData *oldChampion = [_draft championDataWithError:nil];
    if (![_draft replaceWithRuntimeData:runtimeData championData:championData decoder:_decoder error:error] ||
        ![self refreshCandidateWithError:error]) {
        [_draft replaceWithRuntimeData:oldRuntime championData:oldChampion decoder:_decoder error:nil];
        return NO;
    }
    return YES;
}

- (BOOL)revertWithError:(NSError **)error {
    [_draft revert];
    return [self refreshCandidateWithError:error];
}

- (BOOL)acceptSavedRuntimeData:(NSData *)runtimeData championData:(NSData *)championData
                         error:(NSError **)error {
    if (![_draft replaceWithRuntimeData:runtimeData championData:championData decoder:_decoder error:error] ||
        ![_draft acceptCurrentValuesAsBaselineWithError:error]) return NO;
    return [self refreshCandidateWithError:error];
}
@end
