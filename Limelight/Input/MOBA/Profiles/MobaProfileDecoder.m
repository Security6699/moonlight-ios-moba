//
//  MobaProfileDecoder.m
//  Moonlight
//

#import "MobaProfileDecoder.h"

#import "MobaProfileModelsInternal.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

static BOOL MobaDecoderNumberIsBoolean(NSNumber *number) {
    return CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID();
}

@implementation MobaProfileDecoder {
    id<MobaProfileMigrating> _migrator;
    id<MobaProfileValidating> _validator;
}

- (instancetype)init {
    return [self initWithMigrator:[[MobaProfileMigrator alloc] init]
                        validator:[[MobaProfileValidator alloc] init]];
}

- (instancetype)initWithMigrator:(id<MobaProfileMigrating>)migrator
                         validator:(id<MobaProfileValidating>)validator {
    self = [super init];
    if (self) {
        _migrator = migrator;
        _validator = validator;
    }
    return self;
}

- (NSError *)normalizedError:(NSError *)candidate
                         code:(MobaProfileErrorCode)code
                         kind:(MobaProfileKind)kind
                         path:(NSString *)path
                    operation:(NSString *)operation
                  description:(NSString *)description {
    if ([candidate.domain isEqualToString:MobaProfileErrorDomain] &&
        candidate.userInfo[MobaProfileErrorProfileKindKey] != nil &&
        candidate.userInfo[MobaProfileErrorFieldPathKey] != nil &&
        candidate.userInfo[MobaProfileErrorOperationKey] != nil) {
        return candidate;
    }
    return MobaProfileMakeError(code, kind, path, operation, description, candidate);
}

- (BOOL)extractSchemaVersionFromJSON:(NSDictionary *)json
                                kind:(MobaProfileKind)kind
                           operation:(NSString *)operation
                               error:(NSError **)error {
    id value = json[@"schemaVersion"];
    if (value == nil) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorMissingRequiredField,
                                          kind,
                                          @"$.schemaVersion",
                                          operation,
                                          @"schemaVersion is required.",
                                          nil);
        }
        return NO;
    }
    if (![value isKindOfClass:[NSNumber class]] || MobaDecoderNumberIsBoolean(value)) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorFieldTypeMismatch,
                                          kind,
                                          @"$.schemaVersion",
                                          operation,
                                          @"schemaVersion must be a JSON integer.",
                                          nil);
        }
        return NO;
    }
    double number = [value doubleValue];
    if (!isfinite(number) || trunc(number) != number) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorFieldTypeMismatch,
                                          kind,
                                          @"$.schemaVersion",
                                          operation,
                                          @"schemaVersion must be a finite integer.",
                                          nil);
        }
        return NO;
    }
    return YES;
}

- (NSDictionary *)JSONObjectFromData:(NSData *)data
                                 kind:(MobaProfileKind)kind
                                error:(NSError **)error {
    if (![data isKindOfClass:[NSData class]]) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorJSONParseFailed,
                                          kind,
                                          @"$",
                                          @"parse-json",
                                          @"Profile data must be NSData.",
                                          nil);
        }
        return nil;
    }
    NSError *parseError = nil;
    id root = nil;
    @try {
        root = [NSJSONSerialization JSONObjectWithData:data
                                               options:NSJSONReadingFragmentsAllowed
                                                 error:&parseError];
    }
    @catch (NSException *exception) {
        NSDictionary *details = @{NSLocalizedDescriptionKey: exception.reason ?: @"JSON parsing raised an exception."};
        parseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:details];
    }
    if (root == nil) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorJSONParseFailed,
                                          kind,
                                          @"$",
                                          @"parse-json",
                                          @"The profile is not valid JSON.",
                                          parseError);
        }
        return nil;
    }
    if (![root isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorRootTypeMismatch,
                                          kind,
                                          @"$",
                                          @"check-root",
                                          @"The JSON root must be a dictionary.",
                                          nil);
        }
        return nil;
    }
    return root;
}

- (id)decodeData:(NSData *)data profileKind:(MobaProfileKind)kind error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSDictionary *root = [self JSONObjectFromData:data kind:kind error:error];
    if (root == nil || ![self extractSchemaVersionFromJSON:root kind:kind operation:@"extract-schema-version" error:error]) {
        return nil;
    }

    NSError *migrationError = nil;
    NSDictionary *migrated = nil;
    @try {
        migrated = [_migrator migrateJSONObject:root profileKind:kind error:&migrationError];
    }
    @catch (NSException *exception) {
        NSDictionary *details = @{NSLocalizedDescriptionKey: exception.reason ?: @"Migration raised an exception."};
        migrationError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:details];
    }
    if (![migrated isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) {
            *error = [self normalizedError:migrationError
                                      code:MobaProfileErrorMigrationFailed
                                      kind:kind
                                      path:@"$.schemaVersion"
                                 operation:@"migrate"
                               description:@"Profile migration failed."];
        }
        return nil;
    }
    NSError *versionError = nil;
    if (![self extractSchemaVersionFromJSON:migrated
                                       kind:kind
                                  operation:@"verify-migrated-schema-version"
                                      error:&versionError] ||
        [migrated[@"schemaVersion"] unsignedIntegerValue] != MobaProfileCurrentSchemaVersion) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorMigrationFailed,
                                          kind,
                                          @"$.schemaVersion",
                                          @"verify-migrated-schema-version",
                                          @"Migration did not produce the current schema version.",
                                          versionError);
        }
        return nil;
    }

    NSError *validationError = nil;
    BOOL valid = NO;
    @try {
        valid = [_validator validateJSONObject:migrated profileKind:kind error:&validationError];
    }
    @catch (NSException *exception) {
        NSDictionary *details = @{NSLocalizedDescriptionKey: exception.reason ?: @"Validation raised an exception."};
        validationError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:details];
    }
    if (!valid) {
        if (error != NULL) {
            *error = [self normalizedError:validationError
                                      code:MobaProfileErrorFieldTypeMismatch
                                      kind:kind
                                      path:@"$"
                                 operation:@"validate"
                               description:@"Profile validation failed."];
        }
        return nil;
    }

    if ([kind isEqualToString:MobaProfileKindRuntime]) {
        return MobaRuntimeProfileFromValidatedJSON(migrated);
    }
    if ([kind isEqualToString:MobaProfileKindInput]) {
        return MobaInputProfileFromValidatedJSON(migrated);
    }
    if ([kind isEqualToString:MobaProfileKindLayout]) {
        return MobaLayoutProfileFromValidatedJSON(migrated);
    }
    return MobaChampionProfileFromValidatedJSON(migrated);
}

- (MobaRuntimeProfile *)decodeRuntimeProfileData:(NSData *)data error:(NSError **)error {
    return [self decodeData:data profileKind:MobaProfileKindRuntime error:error];
}

- (MobaInputProfile *)decodeInputProfileData:(NSData *)data error:(NSError **)error {
    return [self decodeData:data profileKind:MobaProfileKindInput error:error];
}

- (MobaLayoutProfile *)decodeLayoutProfileData:(NSData *)data error:(NSError **)error {
    return [self decodeData:data profileKind:MobaProfileKindLayout error:error];
}

- (MobaChampionProfile *)decodeChampionProfileData:(NSData *)data error:(NSError **)error {
    return [self decodeData:data profileKind:MobaProfileKindChampion error:error];
}

@end
