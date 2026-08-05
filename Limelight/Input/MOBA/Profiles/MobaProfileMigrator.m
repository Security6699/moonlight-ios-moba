//
//  MobaProfileMigrator.m
//  Moonlight
//

#import "MobaProfileMigrator.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

const NSUInteger MobaProfileCurrentSchemaVersion = 1;

static BOOL MobaProfileNumberIsBoolean(NSNumber *number) {
    return CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID();
}

@implementation MobaProfileMigrator

- (NSDictionary *)migrateJSONObject:(NSDictionary *)jsonObject
                         profileKind:(MobaProfileKind)profileKind
                               error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    id versionValue = jsonObject[@"schemaVersion"];
    if (versionValue == nil) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorMissingRequiredField,
                                          profileKind,
                                          @"$.schemaVersion",
                                          @"migrate",
                                          @"schemaVersion is required.",
                                          nil);
        }
        return nil;
    }
    if (![versionValue isKindOfClass:[NSNumber class]] ||
        MobaProfileNumberIsBoolean(versionValue)) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorFieldTypeMismatch,
                                          profileKind,
                                          @"$.schemaVersion",
                                          @"migrate",
                                          @"schemaVersion must be an integer.",
                                          nil);
        }
        return nil;
    }

    double versionNumber = [versionValue doubleValue];
    if (!isfinite(versionNumber) || trunc(versionNumber) != versionNumber) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorFieldTypeMismatch,
                                          profileKind,
                                          @"$.schemaVersion",
                                          @"migrate",
                                          @"schemaVersion must be a finite integer.",
                                          nil);
        }
        return nil;
    }
    if (versionNumber != MobaProfileCurrentSchemaVersion) {
        if (error != NULL) {
            *error = MobaProfileMakeError(MobaProfileErrorUnsupportedSchemaVersion,
                                          profileKind,
                                          @"$.schemaVersion",
                                          @"migrate",
                                          @"The profile schema version is not supported.",
                                          nil);
        }
        return nil;
    }

    // Identity migration deliberately keeps every unknown field.
    return [jsonObject copy];
}

@end
