//
//  MobaProfileError.m
//  Moonlight
//

#import "MobaProfileError.h"

NSErrorDomain const MobaProfileErrorDomain = @"MobaProfileErrorDomain";
NSString *const MobaProfileErrorProfileKindKey = @"MobaProfileKind";
NSString *const MobaProfileErrorFieldPathKey = @"MobaProfileFieldPath";
NSString *const MobaProfileErrorOperationKey = @"MobaProfileOperation";

MobaProfileKind const MobaProfileKindRuntime = @"runtime";
MobaProfileKind const MobaProfileKindInput = @"input";
MobaProfileKind const MobaProfileKindLayout = @"layout";
MobaProfileKind const MobaProfileKindChampion = @"champion";

NSError *MobaProfileMakeError(MobaProfileErrorCode code,
                              MobaProfileKind profileKind,
                              NSString *fieldPath,
                              NSString *operation,
                              NSString *description,
                              NSError *underlyingError) {
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey: [description copy],
        MobaProfileErrorProfileKindKey: [profileKind copy],
        MobaProfileErrorFieldPathKey: [fieldPath copy],
        MobaProfileErrorOperationKey: [operation copy],
    } mutableCopy];
    if (underlyingError != nil) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:MobaProfileErrorDomain code:code userInfo:userInfo];
}
