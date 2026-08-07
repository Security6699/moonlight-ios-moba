//
//  MobaProfileError.h
//  Moonlight
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaProfileErrorDomain;
FOUNDATION_EXPORT NSString *const MobaProfileErrorProfileKindKey;
FOUNDATION_EXPORT NSString *const MobaProfileErrorFieldPathKey;
FOUNDATION_EXPORT NSString *const MobaProfileErrorOperationKey;

typedef NSString *MobaProfileKind NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT MobaProfileKind const MobaProfileKindRuntime;
FOUNDATION_EXPORT MobaProfileKind const MobaProfileKindInput;
FOUNDATION_EXPORT MobaProfileKind const MobaProfileKindLayout;
FOUNDATION_EXPORT MobaProfileKind const MobaProfileKindChampion;

typedef NS_ERROR_ENUM(MobaProfileErrorDomain, MobaProfileErrorCode) {
    MobaProfileErrorJSONParseFailed = 1,
    MobaProfileErrorRootTypeMismatch,
    MobaProfileErrorMissingRequiredField,
    MobaProfileErrorFieldTypeMismatch,
    MobaProfileErrorUnsupportedSchemaVersion,
    MobaProfileErrorMigrationFailed,
    MobaProfileErrorUnknownEnumValue,
    MobaProfileErrorValueOutOfRange,
    MobaProfileErrorCrossProfileReferenceInvalid,
    MobaProfileErrorStorageReadFailed,
    MobaProfileErrorStorageWriteFailed,
    MobaProfileErrorUnknownProfileType,
    MobaProfileErrorAmbiguousProfileType,
};

FOUNDATION_EXPORT NSError *MobaProfileMakeError(MobaProfileErrorCode code,
                                                MobaProfileKind profileKind,
                                                NSString *fieldPath,
                                                NSString *operation,
                                                NSString *description,
                                                NSError *_Nullable underlyingError);

NS_ASSUME_NONNULL_END
