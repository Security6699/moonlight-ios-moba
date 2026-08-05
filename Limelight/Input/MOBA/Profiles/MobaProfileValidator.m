//
//  MobaProfileValidator.m
//  Moonlight
//

#import "MobaProfileValidator.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#include <stdint.h>

static BOOL MobaValidatorNumberIsBoolean(NSNumber *number) {
    return CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID();
}

@interface MobaProfileValidator ()
- (BOOL)validateRuntime:(NSDictionary *)json error:(NSError **)error;
- (BOOL)validateInput:(NSDictionary *)json error:(NSError **)error;
- (BOOL)validateLayout:(NSDictionary *)json error:(NSError **)error;
- (BOOL)validateChampion:(NSDictionary *)json error:(NSError **)error;
@end

@implementation MobaProfileValidator

- (BOOL)failWithCode:(MobaProfileErrorCode)code
                 kind:(MobaProfileKind)kind
                 path:(NSString *)path
          description:(NSString *)description
                error:(NSError **)error {
    if (error != NULL) {
        *error = MobaProfileMakeError(code, kind, path, @"validate", description, nil);
    }
    return NO;
}

- (id)requiredValueForKey:(NSString *)key
               dictionary:(NSDictionary *)dictionary
                     kind:(MobaProfileKind)kind
                     path:(NSString *)path
                    error:(NSError **)error {
    id value = dictionary[key];
    if (value == nil) {
        [self failWithCode:MobaProfileErrorMissingRequiredField
                      kind:kind
                      path:path
               description:@"A required profile field is missing."
                     error:error];
        return nil;
    }
    return value;
}

- (NSDictionary *)requiredDictionaryForKey:(NSString *)key
                                  dictionary:(NSDictionary *)dictionary
                                        kind:(MobaProfileKind)kind
                                        path:(NSString *)path
                                       error:(NSError **)error {
    id value = [self requiredValueForKey:key dictionary:dictionary kind:kind path:path error:error];
    if (value == nil) {
        return nil;
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        [self failWithCode:MobaProfileErrorFieldTypeMismatch
                      kind:kind
                      path:path
               description:@"The profile field must be a dictionary."
                     error:error];
        return nil;
    }
    return value;
}

- (NSString *)requiredStringForKey:(NSString *)key
                         dictionary:(NSDictionary *)dictionary
                               kind:(MobaProfileKind)kind
                               path:(NSString *)path
                              error:(NSError **)error {
    id value = [self requiredValueForKey:key dictionary:dictionary kind:kind path:path error:error];
    if (value == nil) {
        return nil;
    }
    if (![value isKindOfClass:[NSString class]]) {
        [self failWithCode:MobaProfileErrorFieldTypeMismatch
                      kind:kind
                      path:path
               description:@"The profile field must be a string."
                     error:error];
        return nil;
    }
    if ([(NSString *)value length] == 0) {
        [self failWithCode:MobaProfileErrorValueOutOfRange
                      kind:kind
                      path:path
               description:@"The profile string must not be empty."
                     error:error];
        return nil;
    }
    return value;
}

- (NSNumber *)numberForKey:(NSString *)key
                  dictionary:(NSDictionary *)dictionary
                        kind:(MobaProfileKind)kind
                        path:(NSString *)path
                    required:(BOOL)required
                       error:(NSError **)error {
    id value = dictionary[key];
    if (value == nil) {
        if (required) {
            [self failWithCode:MobaProfileErrorMissingRequiredField
                          kind:kind
                          path:path
                   description:@"A required numeric field is missing."
                         error:error];
        }
        return nil;
    }
    if (![value isKindOfClass:[NSNumber class]] || MobaValidatorNumberIsBoolean(value)) {
        [self failWithCode:MobaProfileErrorFieldTypeMismatch
                      kind:kind
                      path:path
               description:@"The profile field must be a JSON number, not a boolean."
                     error:error];
        return nil;
    }
    if (!isfinite([(NSNumber *)value doubleValue])) {
        [self failWithCode:MobaProfileErrorValueOutOfRange
                      kind:kind
                      path:path
               description:@"The numeric profile field must be finite."
                     error:error];
        return nil;
    }
    return value;
}

- (NSNumber *)integerForKey:(NSString *)key
                   dictionary:(NSDictionary *)dictionary
                         kind:(MobaProfileKind)kind
                         path:(NSString *)path
                     required:(BOOL)required
                      minimum:(NSNumber *)minimum
                      maximum:(NSNumber *)maximum
                        error:(NSError **)error {
    NSNumber *number = [self numberForKey:key
                               dictionary:dictionary
                                     kind:kind
                                     path:path
                                 required:required
                                    error:error];
    if (number == nil) {
        return nil;
    }
    double value = number.doubleValue;
    if (trunc(value) != value) {
        [self failWithCode:MobaProfileErrorFieldTypeMismatch
                      kind:kind
                      path:path
               description:@"The profile field must be an integer without a fractional part."
                     error:error];
        return nil;
    }
    if ([number compare:minimum] == NSOrderedAscending ||
        [number compare:maximum] == NSOrderedDescending) {
        [self failWithCode:MobaProfileErrorValueOutOfRange
                      kind:kind
                      path:path
               description:@"The integer profile field is outside its supported range."
                     error:error];
        return nil;
    }
    return number;
}

- (NSNumber *)requiredBooleanForKey:(NSString *)key
                          dictionary:(NSDictionary *)dictionary
                                kind:(MobaProfileKind)kind
                                path:(NSString *)path
                               error:(NSError **)error {
    id value = [self requiredValueForKey:key dictionary:dictionary kind:kind path:path error:error];
    if (value == nil) {
        return nil;
    }
    if (![value isKindOfClass:[NSNumber class]] || !MobaValidatorNumberIsBoolean(value)) {
        [self failWithCode:MobaProfileErrorFieldTypeMismatch
                      kind:kind
                      path:path
               description:@"The profile field must be a JSON boolean."
                     error:error];
        return nil;
    }
    return value;
}

- (BOOL)number:(NSNumber *)number
       inRange:(double)minimum
       maximum:(double)maximum
           kind:(MobaProfileKind)kind
           path:(NSString *)path
          error:(NSError **)error {
    double value = number.doubleValue;
    if (value < minimum || value > maximum) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:path
                      description:@"The numeric profile field is outside its supported range."
                            error:error];
    }
    return YES;
}

- (BOOL)validateSchemaVersion:(NSDictionary *)json
                          kind:(MobaProfileKind)kind
                         error:(NSError **)error {
    NSNumber *version = [self integerForKey:@"schemaVersion"
                                  dictionary:json
                                        kind:kind
                                        path:@"$.schemaVersion"
                                    required:YES
                                     minimum:@0
                                     maximum:@(NSUIntegerMax)
                                       error:error];
    if (version == nil) {
        return NO;
    }
    if (version.unsignedIntegerValue != 1) {
        return [self failWithCode:MobaProfileErrorUnsupportedSchemaVersion
                             kind:kind
                             path:@"$.schemaVersion"
                      description:@"The profile schema version is not supported."
                            error:error];
    }
    return YES;
}

- (BOOL)validateJSONObject:(NSDictionary *)jsonObject
               profileKind:(MobaProfileKind)profileKind
                      error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (![self validateSchemaVersion:jsonObject kind:profileKind error:error]) {
        return NO;
    }
    if ([profileKind isEqualToString:MobaProfileKindRuntime]) {
        return [self validateRuntime:jsonObject error:error];
    }
    if ([profileKind isEqualToString:MobaProfileKindInput]) {
        return [self validateInput:jsonObject error:error];
    }
    if ([profileKind isEqualToString:MobaProfileKindLayout]) {
        return [self validateLayout:jsonObject error:error];
    }
    if ([profileKind isEqualToString:MobaProfileKindChampion]) {
        return [self validateChampion:jsonObject error:error];
    }
    return [self failWithCode:MobaProfileErrorFieldTypeMismatch
                         kind:profileKind
                         path:@"$"
                  description:@"The requested profile kind is not supported."
                        error:error];
}

- (BOOL)validateFixedSize:(NSDictionary *)size
                     kind:(MobaProfileKind)kind
                     path:(NSString *)path
                    error:(NSError **)error {
    NSNumber *width = [self integerForKey:@"width"
                                dictionary:size
                                      kind:kind
                                      path:[path stringByAppendingString:@".width"]
                                  required:YES
                                   minimum:@0
                                   maximum:@(NSUIntegerMax)
                                     error:error];
    if (width == nil) {
        return NO;
    }
    NSNumber *height = [self integerForKey:@"height"
                                 dictionary:size
                                       kind:kind
                                       path:[path stringByAppendingString:@".height"]
                                   required:YES
                                    minimum:@0
                                    maximum:@(NSUIntegerMax)
                                      error:error];
    if (height == nil) {
        return NO;
    }
    if (width.unsignedIntegerValue != 2560) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:[path stringByAppendingString:@".width"]
                      description:@"Schema v1 requires a width of 2560."
                            error:error];
    }
    if (height.unsignedIntegerValue != 1440) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:[path stringByAppendingString:@".height"]
                      description:@"Schema v1 requires a height of 1440."
                            error:error];
    }
    return YES;
}

- (BOOL)validateRuntime:(NSDictionary *)json error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindRuntime;
    NSDictionary *canvas = [self requiredDictionaryForKey:@"canvas"
                                                dictionary:json
                                                      kind:kind
                                                      path:@"$.canvas"
                                                     error:error];
    if (canvas == nil || ![self validateFixedSize:canvas kind:kind path:@"$.canvas" error:error]) {
        return NO;
    }
    NSDictionary *stream = [self requiredDictionaryForKey:@"requiredStreamResolution"
                                                dictionary:json
                                                      kind:kind
                                                      path:@"$.requiredStreamResolution"
                                                     error:error];
    if (stream == nil || ![self validateFixedSize:stream kind:kind path:@"$.requiredStreamResolution" error:error]) {
        return NO;
    }
    NSString *videoMode = [self requiredStringForKey:@"videoMode"
                                           dictionary:json
                                                 kind:kind
                                                 path:@"$.videoMode"
                                                error:error];
    if (videoMode == nil) {
        return NO;
    }
    if (![videoMode isEqualToString:@"aspectFit"]) {
        return [self failWithCode:MobaProfileErrorUnknownEnumValue
                             kind:kind
                             path:@"$.videoMode"
                      description:@"videoMode must be aspectFit in schema v1."
                            error:error];
    }
    NSDictionary *camera = [self requiredDictionaryForKey:@"camera"
                                                dictionary:json
                                                      kind:kind
                                                      path:@"$.camera"
                                                     error:error];
    if (camera == nil) {
        return NO;
    }
    NSString *cameraMode = [self requiredStringForKey:@"mode"
                                            dictionary:camera
                                                  kind:kind
                                                  path:@"$.camera.mode"
                                                 error:error];
    if (cameraMode == nil) {
        return NO;
    }
    if (![cameraMode isEqualToString:@"locked"]) {
        return [self failWithCode:MobaProfileErrorUnknownEnumValue
                             kind:kind
                             path:@"$.camera.mode"
                      description:@"camera.mode must be locked in schema v1."
                            error:error];
    }
    NSDictionary *anchor = [self requiredDictionaryForKey:@"heroAnchorPx"
                                                dictionary:camera
                                                      kind:kind
                                                      path:@"$.camera.heroAnchorPx"
                                                     error:error];
    if (anchor == nil) {
        return NO;
    }
    NSNumber *anchorX = [self numberForKey:@"x"
                                dictionary:anchor
                                      kind:kind
                                      path:@"$.camera.heroAnchorPx.x"
                                  required:YES
                                     error:error];
    if (anchorX == nil || ![self number:anchorX inRange:0 maximum:2559 kind:kind path:@"$.camera.heroAnchorPx.x" error:error]) {
        return NO;
    }
    NSNumber *anchorY = [self numberForKey:@"y"
                                dictionary:anchor
                                      kind:kind
                                      path:@"$.camera.heroAnchorPx.y"
                                  required:YES
                                     error:error];
    if (anchorY == nil || ![self number:anchorY inRange:0 maximum:1439 kind:kind path:@"$.camera.heroAnchorPx.y" error:error]) {
        return NO;
    }
    NSNumber *rate = [self integerForKey:@"mouseUpdateRateHz"
                               dictionary:json
                                     kind:kind
                                     path:@"$.mouseUpdateRateHz"
                                 required:YES
                                  minimum:@0
                                  maximum:@(NSUIntegerMax)
                                    error:error];
    if (rate == nil) {
        return NO;
    }
    NSSet *rates = [NSSet setWithObjects:@30, @60, @120, nil];
    if (![rates containsObject:rate]) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:@"$.mouseUpdateRateHz"
                      description:@"mouseUpdateRateHz must be 30, 60, or 120."
                            error:error];
    }
    NSNumber *opacity = [self numberForKey:@"globalOpacityMultiplier"
                                 dictionary:json
                                       kind:kind
                                       path:@"$.globalOpacityMultiplier"
                                   required:YES
                                      error:error];
    return opacity != nil && [self number:opacity inRange:0 maximum:1 kind:kind path:@"$.globalOpacityMultiplier" error:error];
}

- (NSNumber *)keyCodeForKey:(NSString *)key
                  dictionary:(NSDictionary *)dictionary
                        kind:(MobaProfileKind)kind
                        path:(NSString *)path
                       error:(NSError **)error {
    return [self integerForKey:key
                    dictionary:dictionary
                          kind:kind
                          path:path
                      required:YES
                       minimum:@0
                       maximum:@(UINT16_MAX)
                         error:error];
}

- (BOOL)validateInput:(NSDictionary *)json error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindInput;
    if ([self requiredStringForKey:@"profileId" dictionary:json kind:kind path:@"$.profileId" error:error] == nil) {
        return NO;
    }
    NSDictionary *movement = [self requiredDictionaryForKey:@"movement"
                                                  dictionary:json
                                                        kind:kind
                                                        path:@"$.movement"
                                                       error:error];
    if (movement == nil) {
        return NO;
    }
    for (NSString *name in @[@"up", @"left", @"down", @"right"]) {
        if ([self keyCodeForKey:name
                     dictionary:movement
                           kind:kind
                           path:[@"$.movement." stringByAppendingString:name]
                          error:error] == nil) {
            return NO;
        }
    }
    NSDictionary *actions = [self requiredDictionaryForKey:@"actions"
                                                 dictionary:json
                                                       kind:kind
                                                       path:@"$.actions"
                                                      error:error];
    if (actions == nil) {
        return NO;
    }
    for (NSString *name in @[@"ability1", @"ability2", @"ability3", @"ability4", @"attack"]) {
        if ([self keyCodeForKey:name
                     dictionary:actions
                           kind:kind
                           path:[@"$.actions." stringByAppendingString:name]
                          error:error] == nil) {
            return NO;
        }
    }
    for (id name in actions) {
        NSString *path = [NSString stringWithFormat:@"$.actions.%@", name];
        if (![name isKindOfClass:[NSString class]] || [(NSString *)name length] == 0) {
            return [self failWithCode:MobaProfileErrorFieldTypeMismatch
                                 kind:kind
                                 path:@"$.actions"
                          description:@"Action names must be non-empty strings."
                                error:error];
        }
        if ([self keyCodeForKey:name dictionary:actions kind:kind path:path error:error] == nil) {
            return NO;
        }
    }
    if ([self integerForKey:@"attackTapDurationMs"
                 dictionary:json
                       kind:kind
                       path:@"$.attackTapDurationMs"
                   required:YES
                    minimum:@0
                    maximum:@(NSUIntegerMax)
                      error:error] == nil) {
        return NO;
    }
    NSDictionary *cancel = [self requiredDictionaryForKey:@"cancelCastAction"
                                                dictionary:json
                                                      kind:kind
                                                      path:@"$.cancelCastAction"
                                                     error:error];
    if (cancel == nil) {
        return NO;
    }
    NSString *type = [self requiredStringForKey:@"type"
                                      dictionary:cancel
                                            kind:kind
                                            path:@"$.cancelCastAction.type"
                                           error:error];
    if (type == nil) {
        return NO;
    }
    NSSet *types = [NSSet setWithObjects:@"keyboard", @"rightMouse", @"releaseOnly", nil];
    if (![types containsObject:type]) {
        return [self failWithCode:MobaProfileErrorUnknownEnumValue
                             kind:kind
                             path:@"$.cancelCastAction.type"
                      description:@"The cancel action type is not supported."
                            error:error];
    }
    if ([type isEqualToString:@"keyboard"] &&
        [self keyCodeForKey:@"keyCode"
                 dictionary:cancel
                       kind:kind
                       path:@"$.cancelCastAction.keyCode"
                      error:error] == nil) {
        return NO;
    }
    return [self requiredBooleanForKey:@"cancelBeforeSkillKeyUp"
                            dictionary:cancel
                                  kind:kind
                                  path:@"$.cancelCastAction.cancelBeforeSkillKeyUp"
                                 error:error] != nil;
}

- (BOOL)validateControl:(NSDictionary *)control
                   path:(NSString *)path
                  error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindLayout;
    NSDictionary<NSString *, NSArray<NSNumber *> *> *ranges = @{
        @"centerX": @[@0.0, @1.0],
        @"centerY": @[@0.0, @1.0],
        @"visualWidthPt": @[@24.0, @600.0],
        @"visualHeightPt": @[@24.0, @600.0],
        @"hitAreaScale": @[@0.5, @3.0],
        @"opacity": @[@0.0, @1.0],
        @"pressedOpacity": @[@0.0, @1.0],
        @"disabledOpacity": @[@0.0, @1.0],
    };
    for (NSString *field in ranges) {
        NSString *fieldPath = [path stringByAppendingFormat:@".%@", field];
        NSNumber *value = [self numberForKey:field
                                  dictionary:control
                                        kind:kind
                                        path:fieldPath
                                    required:YES
                                       error:error];
        NSArray<NSNumber *> *range = ranges[field];
        if (value == nil || ![self number:value
                                  inRange:range[0].doubleValue
                                  maximum:range[1].doubleValue
                                      kind:kind
                                      path:fieldPath
                                     error:error]) {
            return NO;
        }
    }
    if (control[@"wheelRadiusPt"] != nil) {
        NSString *wheelPath = [path stringByAppendingString:@".wheelRadiusPt"];
        NSNumber *wheel = [self numberForKey:@"wheelRadiusPt"
                                  dictionary:control
                                        kind:kind
                                        path:wheelPath
                                    required:NO
                                       error:error];
        if (wheel == nil || ![self number:wheel inRange:40 maximum:400 kind:kind path:wheelPath error:error]) {
            return NO;
        }
    }
    if ([self integerForKey:@"zIndex"
                 dictionary:control
                       kind:kind
                       path:[path stringByAppendingString:@".zIndex"]
                   required:YES
                    minimum:@(NSIntegerMin)
                    maximum:@(NSIntegerMax)
                      error:error] == nil) {
        return NO;
    }
    return [self requiredBooleanForKey:@"interactionEnabled"
                            dictionary:control
                                  kind:kind
                                  path:[path stringByAppendingString:@".interactionEnabled"]
                                 error:error] != nil;
}

- (BOOL)validateLayout:(NSDictionary *)json error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindLayout;
    if ([self requiredStringForKey:@"layoutId" dictionary:json kind:kind path:@"$.layoutId" error:error] == nil ||
        [self requiredStringForKey:@"deviceClass" dictionary:json kind:kind path:@"$.deviceClass" error:error] == nil) {
        return NO;
    }
    NSDictionary *controls = [self requiredDictionaryForKey:@"controls"
                                                  dictionary:json
                                                        kind:kind
                                                        path:@"$.controls"
                                                       error:error];
    if (controls == nil) {
        return NO;
    }
    if (controls.count == 0) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:@"$.controls"
                      description:@"A layout must contain at least one control."
                            error:error];
    }
    for (id name in controls) {
        if (![name isKindOfClass:[NSString class]] || [(NSString *)name length] == 0) {
            return [self failWithCode:MobaProfileErrorFieldTypeMismatch
                                 kind:kind
                                 path:@"$.controls"
                          description:@"Control names must be non-empty strings."
                                error:error];
        }
        NSString *path = [NSString stringWithFormat:@"$.controls.%@", name];
        id control = controls[name];
        if (![control isKindOfClass:[NSDictionary class]]) {
            return [self failWithCode:MobaProfileErrorFieldTypeMismatch
                                 kind:kind
                                 path:path
                          description:@"Each layout control must be a dictionary."
                                error:error];
        }
        if (![self validateControl:control path:path error:error]) {
            return NO;
        }
    }
    NSDictionary *cancelZone = [self requiredDictionaryForKey:@"cancelZone"
                                                    dictionary:json
                                                          kind:kind
                                                          path:@"$.cancelZone"
                                                         error:error];
    if (cancelZone == nil) {
        return NO;
    }
    NSDictionary<NSString *, NSArray<NSNumber *> *> *ranges = @{
        @"centerX": @[@0.0, @1.0],
        @"centerY": @[@0.0, @1.0],
        @"diameterPt": @[@24.0, @600.0],
        @"opacity": @[@0.0, @1.0],
    };
    for (NSString *field in ranges) {
        NSString *path = [@"$.cancelZone." stringByAppendingString:field];
        NSNumber *value = [self numberForKey:field
                                  dictionary:cancelZone
                                        kind:kind
                                        path:path
                                    required:YES
                                       error:error];
        NSArray<NSNumber *> *range = ranges[field];
        if (value == nil || ![self number:value
                                  inRange:range[0].doubleValue
                                  maximum:range[1].doubleValue
                                      kind:kind
                                      path:path
                                     error:error]) {
            return NO;
        }
    }
    NSNumber *inset = [self numberForKey:@"activationInsetPt"
                               dictionary:cancelZone
                                     kind:kind
                                     path:@"$.cancelZone.activationInsetPt"
                                 required:YES
                                    error:error];
    if (inset == nil || inset.doubleValue < 0) {
        if (inset != nil) {
            [self failWithCode:MobaProfileErrorValueOutOfRange
                          kind:kind
                          path:@"$.cancelZone.activationInsetPt"
                   description:@"Cancel-zone activation inset must be non-negative."
                         error:error];
        }
        return NO;
    }
    double diameter = [cancelZone[@"diameterPt"] doubleValue];
    if (inset.doubleValue > diameter / 2.0) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:@"$.cancelZone.activationInsetPt"
                      description:@"Cancel-zone activation inset exceeds its radius."
                            error:error];
    }
    return [self requiredBooleanForKey:@"visibleOnlyWhileCasting"
                            dictionary:cancelZone
                                  kind:kind
                                  path:@"$.cancelZone.visibleOnlyWhileCasting"
                                 error:error] != nil;
}

- (BOOL)validateDefaultAim:(NSDictionary *)aim path:(NSString *)path error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindChampion;
    NSNumber *angle = [self numberForKey:@"angleDeg"
                               dictionary:aim
                                     kind:kind
                                     path:[path stringByAppendingString:@".angleDeg"]
                                 required:YES
                                    error:error];
    if (angle == nil) {
        return NO;
    }
    NSNumber *ratio = [self numberForKey:@"distanceRatio"
                               dictionary:aim
                                     kind:kind
                                     path:[path stringByAppendingString:@".distanceRatio"]
                                 required:YES
                                    error:error];
    return ratio != nil && [self number:ratio
                                inRange:0
                                maximum:1
                                    kind:kind
                                    path:[path stringByAppendingString:@".distanceRatio"]
                                   error:error];
}

- (BOOL)validateRangeModel:(NSDictionary *)range path:(NSString *)path error:(NSError **)error {
    NSString *model = [self requiredStringForKey:@"model"
                                       dictionary:range
                                             kind:MobaProfileKindChampion
                                             path:[path stringByAppendingString:@".model"]
                                            error:error];
    if (model == nil) {
        return NO;
    }
    if (![model isEqualToString:@"asymmetricEllipse"]) {
        return [self failWithCode:MobaProfileErrorUnknownEnumValue
                             kind:MobaProfileKindChampion
                             path:[path stringByAppendingString:@".model"]
                      description:@"The skill range model is not supported."
                            error:error];
    }
    return YES;
}

- (BOOL)validateDirectionalRange:(NSDictionary *)range path:(NSString *)path error:(NSError **)error {
    if (![self validateRangeModel:range path:path error:error]) {
        return NO;
    }
    for (NSString *field in @[@"leftPx", @"rightPx", @"upPx", @"downPx"]) {
        NSString *fieldPath = [path stringByAppendingFormat:@".%@", field];
        NSNumber *value = [self numberForKey:field
                                  dictionary:range
                                        kind:MobaProfileKindChampion
                                        path:fieldPath
                                    required:YES
                                       error:error];
        if (value == nil) {
            return NO;
        }
        if (value.doubleValue <= 0) {
            return [self failWithCode:MobaProfileErrorValueOutOfRange
                                 kind:MobaProfileKindChampion
                                 path:fieldPath
                          description:@"Directional ellipse radii must be greater than zero."
                                error:error];
        }
    }
    return YES;
}

- (BOOL)validatePointRange:(NSDictionary *)range path:(NSString *)path error:(NSError **)error {
    if (![self validateRangeModel:range path:path error:error]) {
        return NO;
    }
    NSArray<NSString *> *directions = @[@"Left", @"Right", @"Up", @"Down"];
    for (NSString *direction in directions) {
        NSString *minField = [@"min" stringByAppendingString:direction];
        minField = [minField stringByAppendingString:@"Px"];
        NSString *maxField = [@"max" stringByAppendingString:direction];
        maxField = [maxField stringByAppendingString:@"Px"];
        NSString *minPath = [path stringByAppendingFormat:@".%@", minField];
        NSString *maxPath = [path stringByAppendingFormat:@".%@", maxField];
        NSNumber *minimum = [self numberForKey:minField
                                    dictionary:range
                                          kind:MobaProfileKindChampion
                                          path:minPath
                                      required:YES
                                         error:error];
        if (minimum == nil || ![self number:minimum inRange:0 maximum:2560 kind:MobaProfileKindChampion path:minPath error:error]) {
            return NO;
        }
        NSNumber *maximum = [self numberForKey:maxField
                                    dictionary:range
                                          kind:MobaProfileKindChampion
                                          path:maxPath
                                      required:YES
                                         error:error];
        if (maximum == nil || ![self number:maximum inRange:0 maximum:2560 kind:MobaProfileKindChampion path:maxPath error:error]) {
            return NO;
        }
        if (minimum.doubleValue > maximum.doubleValue) {
            return [self failWithCode:MobaProfileErrorValueOutOfRange
                                 kind:MobaProfileKindChampion
                                 path:minPath
                          description:@"A point-range minimum cannot exceed its matching maximum."
                                error:error];
        }
    }
    return YES;
}

- (BOOL)validateTouchResponse:(NSDictionary *)response
                          path:(NSString *)path
                         point:(BOOL)point
                         error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindChampion;
    NSString *deadzonePath = [path stringByAppendingString:@".deadzoneRatio"];
    NSNumber *deadzone = [self numberForKey:@"deadzoneRatio"
                                  dictionary:response
                                        kind:kind
                                        path:deadzonePath
                                    required:YES
                                       error:error];
    if (deadzone == nil || ![self number:deadzone inRange:0 maximum:0.5 kind:kind path:deadzonePath error:error]) {
        return NO;
    }
    if (!point) {
        return YES;
    }
    NSString *fullPath = [path stringByAppendingString:@".fullRangeRatio"];
    NSNumber *full = [self numberForKey:@"fullRangeRatio"
                              dictionary:response
                                    kind:kind
                                    path:fullPath
                                required:YES
                                   error:error];
    if (full == nil || ![self number:full inRange:0.5 maximum:1.5 kind:kind path:fullPath error:error]) {
        return NO;
    }
    if (full.doubleValue <= deadzone.doubleValue) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:fullPath
                      description:@"fullRangeRatio must be greater than deadzoneRatio."
                            error:error];
    }
    NSString *curvePath = [path stringByAppendingString:@".curveExponent"];
    NSNumber *curve = [self numberForKey:@"curveExponent"
                               dictionary:response
                                     kind:kind
                                     path:curvePath
                                 required:YES
                                    error:error];
    return curve != nil && [self number:curve inRange:0.25 maximum:4 kind:kind path:curvePath error:error];
}

- (BOOL)validateSkill:(NSDictionary *)skill name:(NSString *)name error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindChampion;
    NSString *path = [NSString stringWithFormat:@"$.skills.%@", name];
    if ([self requiredStringForKey:@"inputAction"
                        dictionary:skill
                              kind:kind
                              path:[path stringByAppendingString:@".inputAction"]
                             error:error] == nil) {
        return NO;
    }
    NSString *castType = [self requiredStringForKey:@"castType"
                                          dictionary:skill
                                                kind:kind
                                                path:[path stringByAppendingString:@".castType"]
                                               error:error];
    if (castType == nil) {
        return NO;
    }
    if ([self requiredBooleanForKey:@"allowCancel"
                         dictionary:skill
                               kind:kind
                               path:[path stringByAppendingString:@".allowCancel"]
                              error:error] == nil) {
        return NO;
    }
    if ([castType isEqualToString:@"instant"]) {
        NSString *activation = [self requiredStringForKey:@"activation"
                                                dictionary:skill
                                                      kind:kind
                                                      path:[path stringByAppendingString:@".activation"]
                                                     error:error];
        if (activation == nil) {
            return NO;
        }
        if (![activation isEqualToString:@"onRelease"]) {
            return [self failWithCode:MobaProfileErrorUnknownEnumValue
                                 kind:kind
                                 path:[path stringByAppendingString:@".activation"]
                          description:@"The instant-skill activation value is not supported."
                                error:error];
        }
        return [self integerForKey:@"tapDurationMs"
                        dictionary:skill
                              kind:kind
                              path:[path stringByAppendingString:@".tapDurationMs"]
                          required:YES
                           minimum:@0
                           maximum:@(NSUIntegerMax)
                             error:error] != nil;
    }
    if (![castType isEqualToString:@"directional"] && ![castType isEqualToString:@"point"]) {
        return [self failWithCode:MobaProfileErrorUnknownEnumValue
                             kind:kind
                             path:[path stringByAppendingString:@".castType"]
                      description:@"The skill cast type is not supported."
                            error:error];
    }
    NSDictionary *aim = [self requiredDictionaryForKey:@"defaultAim"
                                             dictionary:skill
                                                   kind:kind
                                                   path:[path stringByAppendingString:@".defaultAim"]
                                                  error:error];
    if (aim == nil || ![self validateDefaultAim:aim path:[path stringByAppendingString:@".defaultAim"] error:error]) {
        return NO;
    }
    NSDictionary *range = [self requiredDictionaryForKey:@"range"
                                               dictionary:skill
                                                     kind:kind
                                                     path:[path stringByAppendingString:@".range"]
                                                    error:error];
    NSDictionary *response = [self requiredDictionaryForKey:@"touchResponse"
                                                  dictionary:skill
                                                        kind:kind
                                                        path:[path stringByAppendingString:@".touchResponse"]
                                                       error:error];
    if (range == nil || response == nil) {
        return NO;
    }
    if ([castType isEqualToString:@"directional"]) {
        return [self validateDirectionalRange:range path:[path stringByAppendingString:@".range"] error:error] &&
            [self validateTouchResponse:response path:[path stringByAppendingString:@".touchResponse"] point:NO error:error];
    }
    NSString *targetMode = [self requiredStringForKey:@"targetMode"
                                            dictionary:skill
                                                  kind:kind
                                                  path:[path stringByAppendingString:@".targetMode"]
                                                 error:error];
    if (targetMode == nil) {
        return NO;
    }
    if (![targetMode isEqualToString:@"ground"] && ![targetMode isEqualToString:@"unit"]) {
        return [self failWithCode:MobaProfileErrorUnknownEnumValue
                             kind:kind
                             path:[path stringByAppendingString:@".targetMode"]
                      description:@"The point target mode is not supported."
                            error:error];
    }
    return [self validatePointRange:range path:[path stringByAppendingString:@".range"] error:error] &&
        [self validateTouchResponse:response path:[path stringByAppendingString:@".touchResponse"] point:YES error:error];
}

- (BOOL)validateChampion:(NSDictionary *)json error:(NSError **)error {
    MobaProfileKind kind = MobaProfileKindChampion;
    for (NSString *field in @[@"championId", @"displayName"]) {
        NSString *path = [@"$." stringByAppendingString:field];
        if ([self requiredStringForKey:field dictionary:json kind:kind path:path error:error] == nil) {
            return NO;
        }
    }
    if (json[@"displayNameZhCN"] != nil &&
        [self requiredStringForKey:@"displayNameZhCN"
                        dictionary:json
                              kind:kind
                              path:@"$.displayNameZhCN"
                             error:error] == nil) {
        return NO;
    }
    if (json[@"calibrationStatus"] != nil &&
        [self requiredStringForKey:@"calibrationStatus"
                        dictionary:json
                              kind:kind
                              path:@"$.calibrationStatus"
                             error:error] == nil) {
        return NO;
    }
    NSDictionary *skills = [self requiredDictionaryForKey:@"skills"
                                                dictionary:json
                                                      kind:kind
                                                      path:@"$.skills"
                                                     error:error];
    if (skills == nil) {
        return NO;
    }
    if (skills.count == 0) {
        return [self failWithCode:MobaProfileErrorValueOutOfRange
                             kind:kind
                             path:@"$.skills"
                      description:@"A champion profile must contain at least one skill."
                            error:error];
    }
    for (id name in skills) {
        if (![name isKindOfClass:[NSString class]] || [(NSString *)name length] == 0) {
            return [self failWithCode:MobaProfileErrorFieldTypeMismatch
                                 kind:kind
                                 path:@"$.skills"
                          description:@"Skill names must be non-empty strings."
                                error:error];
        }
        NSString *path = [NSString stringWithFormat:@"$.skills.%@", name];
        id skill = skills[name];
        if (![skill isKindOfClass:[NSDictionary class]]) {
            return [self failWithCode:MobaProfileErrorFieldTypeMismatch
                                 kind:kind
                                 path:path
                          description:@"Each skill must be a dictionary."
                                error:error];
        }
        if (![self validateSkill:skill name:name error:error]) {
            return NO;
        }
    }
    return YES;
}

@end
