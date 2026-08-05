//
//  MobaProfileDecoderTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Profiles/MobaProfileDecoder.h"
#import "../Limelight/Input/MOBA/Profiles/MobaProfileError.h"

#import <math.h>

typedef void (^MobaProfileJSONMutation)(NSMutableDictionary *json);

@interface MobaRepairingProfileMigrator : NSObject <MobaProfileMigrating>
@property (nonatomic) NSUInteger callCount;
@end

@implementation MobaRepairingProfileMigrator
- (NSDictionary *)migrateJSONObject:(NSDictionary *)jsonObject
                         profileKind:(MobaProfileKind)profileKind
                               error:(NSError **)error {
    self.callCount += 1;
    NSMutableDictionary *result = [jsonObject mutableCopy];
    result[@"videoMode"] = @"aspectFit";
    return result;
}
@end

@interface MobaFailingProfileMigrator : NSObject <MobaProfileMigrating>
@end

@implementation MobaFailingProfileMigrator
- (NSDictionary *)migrateJSONObject:(NSDictionary *)jsonObject
                         profileKind:(MobaProfileKind)profileKind
                               error:(NSError **)error {
    if (error != NULL) {
        *error = [NSError errorWithDomain:@"MobaFailingProfileMigrator" code:17 userInfo:nil];
    }
    return nil;
}
@end

@interface MobaWrongVersionProfileMigrator : NSObject <MobaProfileMigrating>
@end

@implementation MobaWrongVersionProfileMigrator
- (NSDictionary *)migrateJSONObject:(NSDictionary *)jsonObject
                         profileKind:(MobaProfileKind)profileKind
                               error:(NSError **)error {
    NSMutableDictionary *result = [jsonObject mutableCopy];
    result[@"schemaVersion"] = @2;
    return result;
}
@end

@interface MobaRecordingProfileValidator : NSObject <MobaProfileValidating>
@property (nonatomic) NSUInteger callCount;
@end

@implementation MobaRecordingProfileValidator
- (BOOL)validateJSONObject:(NSDictionary *)jsonObject
               profileKind:(MobaProfileKind)profileKind
                      error:(NSError **)error {
    self.callCount += 1;
    return YES;
}
@end

@interface MobaProfileDecoderTests : XCTestCase
@property (nonatomic, strong) MobaProfileDecoder *decoder;
@property (nonatomic, strong) MobaProfileValidator *validator;
@end

@implementation MobaProfileDecoderTests

- (void)setUp {
    [super setUp];
    self.decoder = [[MobaProfileDecoder alloc] init];
    self.validator = [[MobaProfileValidator alloc] init];
}

- (NSURL *)exampleURL:(NSString *)fileName {
    NSString *testDirectory = [[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent];
    NSMutableArray<NSString *> *roots = [NSMutableArray arrayWithObject:[testDirectory stringByDeletingLastPathComponent]];
    NSString *sourceRoot = NSProcessInfo.processInfo.environment[@"SRCROOT"];
    if (sourceRoot.length > 0) {
        [roots addObject:sourceRoot];
    }
    [roots addObject:NSFileManager.defaultManager.currentDirectoryPath];
    for (NSString *root in roots) {
        NSString *path = [[root stringByAppendingPathComponent:@"examples/moba"]
            stringByAppendingPathComponent:fileName];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            return [NSURL fileURLWithPath:path];
        }
    }
    XCTFail(@"Unable to locate bundled example source %@", fileName);
    return [NSURL fileURLWithPath:fileName];
}

- (NSData *)exampleData:(NSString *)fileName {
    NSData *data = [NSData dataWithContentsOfURL:[self exampleURL:fileName]];
    XCTAssertNotNil(data);
    return data;
}

- (NSMutableDictionary *)exampleJSON:(NSString *)fileName {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:[self exampleData:fileName]
                                                 options:NSJSONReadingMutableContainers
                                                   error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([object isKindOfClass:[NSMutableDictionary class]]);
    return object;
}

- (NSData *)dataForJSON:(id)object {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingFragmentsAllowed
                                                     error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    return data;
}

- (NSError *)runtimeErrorAfterMutation:(MobaProfileJSONMutation)mutation {
    NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
    mutation(json);
    NSError *error = nil;
    XCTAssertNil([self.decoder decodeRuntimeProfileData:[self dataForJSON:json] error:&error]);
    XCTAssertNotNil(error);
    return error;
}

- (NSError *)inputErrorAfterMutation:(MobaProfileJSONMutation)mutation {
    NSMutableDictionary *json = [self exampleJSON:@"input.json"];
    mutation(json);
    NSError *error = nil;
    XCTAssertNil([self.decoder decodeInputProfileData:[self dataForJSON:json] error:&error]);
    XCTAssertNotNil(error);
    return error;
}

- (NSError *)layoutErrorAfterMutation:(MobaProfileJSONMutation)mutation {
    NSMutableDictionary *json = [self exampleJSON:@"ipad-pro-13-layout.json"];
    mutation(json);
    NSError *error = nil;
    XCTAssertNil([self.decoder decodeLayoutProfileData:[self dataForJSON:json] error:&error]);
    XCTAssertNotNil(error);
    return error;
}

- (NSError *)championErrorForFile:(NSString *)fileName mutation:(MobaProfileJSONMutation)mutation {
    NSMutableDictionary *json = [self exampleJSON:fileName];
    mutation(json);
    NSError *error = nil;
    XCTAssertNil([self.decoder decodeChampionProfileData:[self dataForJSON:json] error:&error]);
    XCTAssertNotNil(error);
    return error;
}

- (void)assertError:(NSError *)error
                code:(MobaProfileErrorCode)code
                kind:(MobaProfileKind)kind
                path:(NSString *)path {
    XCTAssertEqualObjects(error.domain, MobaProfileErrorDomain);
    XCTAssertEqual(error.code, code);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorProfileKindKey], kind);
    XCTAssertEqualObjects(error.userInfo[MobaProfileErrorFieldPathKey], path);
    XCTAssertNotNil(error.userInfo[MobaProfileErrorOperationKey]);
}

- (void)testAllFiveBundledExamplesDecodeAndValidate {
    NSError *error = nil;
    XCTAssertNotNil([self.decoder decodeRuntimeProfileData:[self exampleData:@"runtime.json"] error:&error]);
    XCTAssertNil(error);
    XCTAssertNotNil([self.decoder decodeInputProfileData:[self exampleData:@"input.json"] error:&error]);
    XCTAssertNil(error);
    XCTAssertNotNil([self.decoder decodeLayoutProfileData:[self exampleData:@"ipad-pro-13-layout.json"] error:&error]);
    XCTAssertNil(error);
    XCTAssertNotNil([self.decoder decodeChampionProfileData:[self exampleData:@"caitlyn.json"] error:&error]);
    XCTAssertNil(error);
    XCTAssertNotNil([self.decoder decodeChampionProfileData:[self exampleData:@"debug-instant.json"] error:&error]);
    XCTAssertNil(error);
}

- (void)testBundledModelsExposeExpectedImmutableValues {
    MobaRuntimeProfile *runtime = [self.decoder decodeRuntimeProfileData:[self exampleData:@"runtime.json"] error:nil];
    MobaInputProfile *input = [self.decoder decodeInputProfileData:[self exampleData:@"input.json"] error:nil];
    MobaLayoutProfile *layout = [self.decoder decodeLayoutProfileData:[self exampleData:@"ipad-pro-13-layout.json"] error:nil];
    MobaChampionProfile *champion = [self.decoder decodeChampionProfileData:[self exampleData:@"caitlyn.json"] error:nil];
    XCTAssertEqual(runtime.canvas.width, 2560u);
    XCTAssertEqualWithAccuracy(runtime.camera.heroAnchor.y, 720, 0.0001);
    XCTAssertEqual(input.movement.upKeyCode, 87);
    XCTAssertEqualObjects([input keyCodeForAction:@"ability2"], @69);
    XCTAssertEqual(layout.controls.count, 6u);
    XCTAssertEqualWithAccuracy(layout.controls[@"move"].wheelRadiusPt.doubleValue, 95, 0.0001);
    XCTAssertEqual(champion.skills[@"W"].targetMode, MobaProfilePointTargetModeGround);
    XCTAssertFalse([input.actions isKindOfClass:[NSMutableDictionary class]]);
    XCTAssertFalse([layout.controls isKindOfClass:[NSMutableDictionary class]]);
    XCTAssertFalse([champion.skills isKindOfClass:[NSMutableDictionary class]]);
}

- (void)testMalformedJSONFailsWithoutException {
    NSError *error = nil;
    __block MobaRuntimeProfile *profile = nil;
    XCTAssertNoThrow(profile = [self.decoder decodeRuntimeProfileData:[@"{bad" dataUsingEncoding:NSUTF8StringEncoding]
                                                                 error:&error]);
    XCTAssertNil(profile);
    [self assertError:error code:MobaProfileErrorJSONParseFailed kind:MobaProfileKindRuntime path:@"$"];
    XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
}

- (void)testArrayStringAndNullRootsReportRootPath {
    for (NSString *text in @[@"[]", @"\"runtime\"", @"null"]) {
        NSError *error = nil;
        XCTAssertNil([self.decoder decodeRuntimeProfileData:[text dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
        [self assertError:error code:MobaProfileErrorRootTypeMismatch kind:MobaProfileKindRuntime path:@"$"];
    }
}

- (void)testMissingSchemaVersionReportsExactPath {
    NSError *error = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        [json removeObjectForKey:@"schemaVersion"];
    }];
    [self assertError:error code:MobaProfileErrorMissingRequiredField kind:MobaProfileKindRuntime path:@"$.schemaVersion"];
}

- (void)testSchemaVersionRejectsBooleanFractionAndString {
    for (id value in @[@YES, @1.5, @"1"]) {
        NSError *error = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
            json[@"schemaVersion"] = value;
        }];
        [self assertError:error code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindRuntime path:@"$.schemaVersion"];
    }
}

- (void)testUnsupportedOldAndFutureSchemaVersionsFailSafely {
    for (NSNumber *value in @[@0, @2]) {
        NSError *error = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
            json[@"schemaVersion"] = value;
        }];
        [self assertError:error code:MobaProfileErrorUnsupportedSchemaVersion kind:MobaProfileKindRuntime path:@"$.schemaVersion"];
    }
}

- (void)testMigrationRunsBeforeValidation {
    NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
    [json removeObjectForKey:@"videoMode"];
    MobaRepairingProfileMigrator *migrator = [[MobaRepairingProfileMigrator alloc] init];
    MobaProfileDecoder *decoder = [[MobaProfileDecoder alloc] initWithMigrator:migrator
                                                                     validator:[[MobaProfileValidator alloc] init]];
    MobaRuntimeProfile *profile = [decoder decodeRuntimeProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertEqual(migrator.callCount, 1u);
    XCTAssertEqualObjects(profile.videoMode, @"aspectFit");
}

- (void)testIdentityMigrationPreservesUnknownRootAndNestedFields {
    NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
    json[@"futureRuntimeFlag"] = @YES;
    json[@"camera"][@"futureCameraField"] = @123;
    MobaProfileMigrator *migrator = [[MobaProfileMigrator alloc] init];
    NSDictionary *migrated = [migrator migrateJSONObject:json
                                             profileKind:MobaProfileKindRuntime
                                                   error:nil];
    XCTAssertEqualObjects(migrated[@"futureRuntimeFlag"], @YES);
    XCTAssertEqualObjects(migrated[@"camera"][@"futureCameraField"], @123);
}

- (void)testMigrationFailurePreventsValidationAndModelConstruction {
    MobaRecordingProfileValidator *validator = [[MobaRecordingProfileValidator alloc] init];
    MobaProfileDecoder *decoder = [[MobaProfileDecoder alloc] initWithMigrator:[[MobaFailingProfileMigrator alloc] init]
                                                                     validator:validator];
    NSError *error = nil;
    XCTAssertNil([decoder decodeRuntimeProfileData:[self exampleData:@"runtime.json"] error:&error]);
    XCTAssertEqual(validator.callCount, 0u);
    [self assertError:error code:MobaProfileErrorMigrationFailed kind:MobaProfileKindRuntime path:@"$.schemaVersion"];
    XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
}

- (void)testMigratedVersionIsRechecked {
    MobaProfileDecoder *decoder = [[MobaProfileDecoder alloc] initWithMigrator:[[MobaWrongVersionProfileMigrator alloc] init]
                                                                     validator:[[MobaProfileValidator alloc] init]];
    NSError *error = nil;
    XCTAssertNil([decoder decodeRuntimeProfileData:[self exampleData:@"runtime.json"] error:&error]);
    [self assertError:error code:MobaProfileErrorMigrationFailed kind:MobaProfileKindRuntime path:@"$.schemaVersion"];
}

- (void)testUnknownRootAndNestedFieldsAreTolerated {
    NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
    json[@"futureRuntimeFlag"] = @YES;
    json[@"camera"][@"futureCameraField"] = @123;
    MobaRuntimeProfile *profile = [self.decoder decodeRuntimeProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertEqualObjects(profile.camera.mode, @"locked");
}

- (void)testUnknownEnumsReportExactPaths {
    NSError *videoError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"videoMode"] = @"fill";
    }];
    [self assertError:videoError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindRuntime path:@"$.videoMode"];
    NSError *cancelError = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"cancelCastAction"][@"type"] = @"futureCancel";
    }];
    [self assertError:cancelError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindInput path:@"$.cancelCastAction.type"];
    NSError *castError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"castType"] = @"beam";
    }];
    [self assertError:castError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindChampion path:@"$.skills.Q.castType"];
}

- (void)testNumberFieldsRejectJSONBooleans {
    NSError *error = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"camera"][@"heroAnchorPx"][@"x"] = @YES;
    }];
    [self assertError:error code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindRuntime path:@"$.camera.heroAnchorPx.x"];
}

- (void)testBooleanFieldsRejectJSONNumbers {
    NSError *inputError = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"cancelCastAction"][@"cancelBeforeSkillKeyUp"] = @1;
    }];
    [self assertError:inputError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindInput path:@"$.cancelCastAction.cancelBeforeSkillKeyUp"];
    NSError *layoutError = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"controls"][@"move"][@"interactionEnabled"] = @0;
    }];
    [self assertError:layoutError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindLayout path:@"$.controls.move.interactionEnabled"];
}

- (void)testIntegerFieldsRejectFractionsWithoutTruncation {
    NSError *inputError = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"movement"][@"up"] = @87.5;
    }];
    [self assertError:inputError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindInput path:@"$.movement.up"];
    NSError *layoutError = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"controls"][@"move"][@"zIndex"] = @10.5;
    }];
    [self assertError:layoutError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindLayout path:@"$.controls.move.zIndex"];
}

- (void)testRuntimeCanvasAndStreamResolutionAreExact {
    NSError *canvasError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"canvas"][@"width"] = @2559;
    }];
    [self assertError:canvasError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindRuntime path:@"$.canvas.width"];
    NSError *streamError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"requiredStreamResolution"][@"height"] = @1439;
    }];
    [self assertError:streamError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindRuntime path:@"$.requiredStreamResolution.height"];
}

- (void)testRuntimeVideoAndCameraModesAreStrictEnums {
    NSError *videoError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"videoMode"] = @"aspectFill";
    }];
    [self assertError:videoError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindRuntime path:@"$.videoMode"];
    NSError *cameraError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"camera"][@"mode"] = @"unlocked";
    }];
    [self assertError:cameraError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindRuntime path:@"$.camera.mode"];
}

- (void)testRuntimeAnchorAcceptsCanvasEdgesAndRejectsOutside {
    NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
    json[@"camera"][@"heroAnchorPx"][@"x"] = @2559;
    json[@"camera"][@"heroAnchorPx"][@"y"] = @1439;
    XCTAssertNotNil([self.decoder decodeRuntimeProfileData:[self dataForJSON:json] error:nil]);
    NSError *error = [self runtimeErrorAfterMutation:^(NSMutableDictionary *invalid) {
        invalid[@"camera"][@"heroAnchorPx"][@"x"] = @2560;
    }];
    [self assertError:error code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindRuntime path:@"$.camera.heroAnchorPx.x"];
}

- (void)testRuntimeRejectsNonFiniteAnchorAtValidatorBoundary {
    NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
    json[@"camera"][@"heroAnchorPx"][@"y"] = @(INFINITY);
    NSError *error = nil;
    XCTAssertFalse([self.validator validateJSONObject:json profileKind:MobaProfileKindRuntime error:&error]);
    [self assertError:error code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindRuntime path:@"$.camera.heroAnchorPx.y"];
}

- (void)testRuntimeUpdateRatesAndOpacityBoundaries {
    for (NSNumber *rate in @[@30, @60, @120]) {
        NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
        json[@"mouseUpdateRateHz"] = rate;
        XCTAssertNotNil([self.decoder decodeRuntimeProfileData:[self dataForJSON:json] error:nil]);
    }
    for (NSNumber *opacity in @[@0, @1]) {
        NSMutableDictionary *json = [self exampleJSON:@"runtime.json"];
        json[@"globalOpacityMultiplier"] = opacity;
        XCTAssertNotNil([self.decoder decodeRuntimeProfileData:[self dataForJSON:json] error:nil]);
    }
    NSError *rateError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"mouseUpdateRateHz"] = @59;
    }];
    [self assertError:rateError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindRuntime path:@"$.mouseUpdateRateHz"];
    NSError *opacityError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"globalOpacityMultiplier"] = @1.01;
    }];
    [self assertError:opacityError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindRuntime path:@"$.globalOpacityMultiplier"];
}

- (void)testInputRequiredMovementAndActionsReportExactPaths {
    NSError *movementError = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        [json[@"movement"] removeObjectForKey:@"left"];
    }];
    [self assertError:movementError code:MobaProfileErrorMissingRequiredField kind:MobaProfileKindInput path:@"$.movement.left"];
    NSError *actionError = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        [json[@"actions"] removeObjectForKey:@"attack"];
    }];
    [self assertError:actionError code:MobaProfileErrorMissingRequiredField kind:MobaProfileKindInput path:@"$.actions.attack"];
}

- (void)testInputKeyCodesUseUint16RangeWithoutUniquenessRule {
    NSMutableDictionary *json = [self exampleJSON:@"input.json"];
    json[@"movement"][@"up"] = @0;
    json[@"movement"][@"left"] = @0;
    json[@"actions"][@"ability1"] = @(UINT16_MAX);
    MobaInputProfile *profile = [self.decoder decodeInputProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertEqual(profile.movement.upKeyCode, 0);
    XCTAssertEqualObjects(profile.actions[@"ability1"], @(UINT16_MAX));
    NSError *error = [self inputErrorAfterMutation:^(NSMutableDictionary *invalid) {
        invalid[@"actions"][@"ability1"] = @(UINT16_MAX + 1U);
    }];
    [self assertError:error code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindInput path:@"$.actions.ability1"];
}

- (void)testInputCancelTypesAndKeyboardRequirements {
    for (NSString *type in @[@"rightMouse", @"releaseOnly"]) {
        NSMutableDictionary *json = [self exampleJSON:@"input.json"];
        json[@"cancelCastAction"][@"type"] = type;
        [json[@"cancelCastAction"] removeObjectForKey:@"keyCode"];
        XCTAssertNotNil([self.decoder decodeInputProfileData:[self dataForJSON:json] error:nil]);
    }
    NSError *missingKey = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        [json[@"cancelCastAction"] removeObjectForKey:@"keyCode"];
    }];
    [self assertError:missingKey code:MobaProfileErrorMissingRequiredField kind:MobaProfileKindInput path:@"$.cancelCastAction.keyCode"];
}

- (void)testAttackTapDurationIsNonnegativeInteger {
    NSError *negative = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"attackTapDurationMs"] = @-1;
    }];
    [self assertError:negative code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindInput path:@"$.attackTapDurationMs"];
    NSError *fraction = [self inputErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"attackTapDurationMs"] = @30.5;
    }];
    [self assertError:fraction code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindInput path:@"$.attackTapDurationMs"];
}

- (void)testLayoutLoadsAllCurrentControlsAndUnknownControlNames {
    NSMutableDictionary *json = [self exampleJSON:@"ipad-pro-13-layout.json"];
    json[@"controls"][@"futureControl"] = [json[@"controls"][@"attack"] mutableCopy];
    MobaLayoutProfile *profile = [self.decoder decodeLayoutProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertNotNil(profile.controls[@"move"]);
    XCTAssertNotNil(profile.controls[@"abilityQ"]);
    XCTAssertNotNil(profile.controls[@"abilityW"]);
    XCTAssertNotNil(profile.controls[@"abilityE"]);
    XCTAssertNotNil(profile.controls[@"abilityR"]);
    XCTAssertNotNil(profile.controls[@"attack"]);
    XCTAssertNotNil(profile.controls[@"futureControl"]);
}

- (void)testLayoutDocumentedControlRangeBoundariesAreAccepted {
    NSMutableDictionary *json = [self exampleJSON:@"ipad-pro-13-layout.json"];
    NSMutableDictionary *move = json[@"controls"][@"move"];
    move[@"centerX"] = @0;
    move[@"centerY"] = @1;
    move[@"visualWidthPt"] = @24;
    move[@"visualHeightPt"] = @600;
    move[@"hitAreaScale"] = @0.5;
    move[@"wheelRadiusPt"] = @400;
    move[@"opacity"] = @0;
    move[@"pressedOpacity"] = @1;
    move[@"disabledOpacity"] = @0;
    MobaLayoutProfile *profile = [self.decoder decodeLayoutProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertTrue(profile.controls[@"move"].isInteractionEnabled);
    XCTAssertEqualWithAccuracy(profile.controls[@"move"].opacity, 0, 0.0001);
}

- (void)testLayoutRejectsEveryDocumentedControlRangeOutsideBoundary {
    NSArray<NSArray *> *cases = @[
        @[@"centerX", @-0.01],
        @[@"centerY", @1.01],
        @[@"visualWidthPt", @23.9],
        @[@"visualHeightPt", @600.1],
        @[@"hitAreaScale", @3.01],
        @[@"wheelRadiusPt", @39.9],
        @[@"opacity", @-0.01],
        @[@"pressedOpacity", @1.01],
        @[@"disabledOpacity", @1.01],
    ];
    for (NSArray *entry in cases) {
        NSString *field = entry[0];
        NSNumber *value = entry[1];
        NSError *error = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
            json[@"controls"][@"move"][field] = value;
        }];
        [self assertError:error
                     code:MobaProfileErrorValueOutOfRange
                     kind:MobaProfileKindLayout
                     path:[@"$.controls.move." stringByAppendingString:field]];
    }
}

- (void)testLayoutMissingControlFieldReportsMostSpecificPath {
    NSError *error = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
        [json[@"controls"][@"abilityQ"] removeObjectForKey:@"pressedOpacity"];
    }];
    [self assertError:error
                 code:MobaProfileErrorMissingRequiredField
                 kind:MobaProfileKindLayout
                 path:@"$.controls.abilityQ.pressedOpacity"];
}

- (void)testNestedDictionaryTypeMismatchReportsContainerPath {
    NSError *runtimeError = [self runtimeErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"camera"] = @[];
    }];
    [self assertError:runtimeError
                 code:MobaProfileErrorFieldTypeMismatch
                 kind:MobaProfileKindRuntime
                 path:@"$.camera"];
    NSError *championError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"range"] = @"far";
    }];
    [self assertError:championError
                 code:MobaProfileErrorFieldTypeMismatch
                 kind:MobaProfileKindChampion
                 path:@"$.skills.Q.range"];
}

- (void)testOpacityZeroDoesNotChangeInteractionEnabled {
    NSMutableDictionary *json = [self exampleJSON:@"ipad-pro-13-layout.json"];
    json[@"controls"][@"attack"][@"opacity"] = @0;
    json[@"controls"][@"attack"][@"interactionEnabled"] = @YES;
    MobaLayoutProfile *profile = [self.decoder decodeLayoutProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertEqualWithAccuracy(profile.controls[@"attack"].opacity, 0, 0.0001);
    XCTAssertTrue(profile.controls[@"attack"].isInteractionEnabled);
}

- (void)testOptionalWheelRadiusMayBeAbsentButMustValidateWhenPresent {
    NSMutableDictionary *json = [self exampleJSON:@"ipad-pro-13-layout.json"];
    XCTAssertNil(json[@"controls"][@"attack"][@"wheelRadiusPt"]);
    XCTAssertNotNil([self.decoder decodeLayoutProfileData:[self dataForJSON:json] error:nil]);
    NSError *error = [self layoutErrorAfterMutation:^(NSMutableDictionary *invalid) {
        invalid[@"controls"][@"attack"][@"wheelRadiusPt"] = @401;
    }];
    [self assertError:error code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindLayout path:@"$.controls.attack.wheelRadiusPt"];
}

- (void)testCancelZoneValidatesTypeOpacityAndGeometry {
    NSError *typeError = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"cancelZone"][@"visibleOnlyWhileCasting"] = @1;
    }];
    [self assertError:typeError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindLayout path:@"$.cancelZone.visibleOnlyWhileCasting"];
    NSError *opacityError = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"cancelZone"][@"opacity"] = @1.1;
    }];
    [self assertError:opacityError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindLayout path:@"$.cancelZone.opacity"];
    NSError *geometryError = [self layoutErrorAfterMutation:^(NSMutableDictionary *json) {
        json[@"cancelZone"][@"activationInsetPt"] = @57;
    }];
    [self assertError:geometryError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindLayout path:@"$.cancelZone.activationInsetPt"];
}

- (void)testInstantSkillsDoNotRequireAimOrRange {
    MobaChampionProfile *profile = [self.decoder decodeChampionProfileData:[self exampleData:@"debug-instant.json"] error:nil];
    XCTAssertNotNil(profile);
    MobaChampionSkillProfile *skill = profile.skills[@"Q"];
    XCTAssertEqual(skill.castType, MobaProfileSkillCastTypeInstant);
    XCTAssertNil(skill.defaultAim);
    XCTAssertNil(skill.directionalRange);
    XCTAssertNil(skill.pointRange);
    XCTAssertEqual(skill.tapDurationMs, 30u);
}

- (void)testInstantActivationAndTapDurationAreStrict {
    NSError *activationError = [self championErrorForFile:@"debug-instant.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"activation"] = @"onPress";
    }];
    [self assertError:activationError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindChampion path:@"$.skills.Q.activation"];
    NSError *durationError = [self championErrorForFile:@"debug-instant.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"tapDurationMs"] = @30.5;
    }];
    [self assertError:durationError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindChampion path:@"$.skills.Q.tapDurationMs"];
}

- (void)testDirectionalSkillsRequireAimRangeAndResponse {
    NSArray<NSArray *> *cases = @[
        @[@"defaultAim", @"$.skills.Q.defaultAim"],
        @[@"range", @"$.skills.Q.range"],
        @[@"touchResponse", @"$.skills.Q.touchResponse"],
    ];
    for (NSArray *entry in cases) {
        NSError *error = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
            [json[@"skills"][@"Q"] removeObjectForKey:entry[0]];
        }];
        [self assertError:error code:MobaProfileErrorMissingRequiredField kind:MobaProfileKindChampion path:entry[1]];
    }
}

- (void)testDirectionalRadiiMustBeFiniteAndPositiveWithoutCaitlynHardCoding {
    NSMutableDictionary *json = [self exampleJSON:@"caitlyn.json"];
    json[@"skills"][@"Q"][@"range"][@"leftPx"] = @701.25;
    MobaChampionProfile *profile = [self.decoder decodeChampionProfileData:[self dataForJSON:json] error:nil];
    XCTAssertNotNil(profile);
    XCTAssertEqualWithAccuracy(profile.skills[@"Q"].directionalRange.leftPx, 701.25, 0.0001);
    NSError *error = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *invalid) {
        invalid[@"skills"][@"Q"][@"range"][@"upPx"] = @0;
    }];
    [self assertError:error code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindChampion path:@"$.skills.Q.range.upPx"];
}

- (void)testPointGroundAndUnitModesDecode {
    MobaChampionProfile *profile = [self.decoder decodeChampionProfileData:[self exampleData:@"caitlyn.json"] error:nil];
    XCTAssertEqual(profile.skills[@"W"].targetMode, MobaProfilePointTargetModeGround);
    XCTAssertEqual(profile.skills[@"R"].targetMode, MobaProfilePointTargetModeUnit);
}

- (void)testPointTargetModeAndRangeModelRejectUnknownEnums {
    NSError *targetError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"W"][@"targetMode"] = @"nearest";
    }];
    [self assertError:targetError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindChampion path:@"$.skills.W.targetMode"];
    NSError *modelError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"W"][@"range"][@"model"] = @"circle";
    }];
    [self assertError:modelError code:MobaProfileErrorUnknownEnumValue kind:MobaProfileKindChampion path:@"$.skills.W.range.model"];
}

- (void)testPointRangeBoundsAndMinimumMaximumRelationship {
    NSMutableDictionary *json = [self exampleJSON:@"caitlyn.json"];
    json[@"skills"][@"W"][@"range"][@"maxLeftPx"] = @2560;
    XCTAssertNotNil([self.decoder decodeChampionProfileData:[self dataForJSON:json] error:nil]);
    NSError *outside = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *invalid) {
        invalid[@"skills"][@"W"][@"range"][@"maxRightPx"] = @2560.1;
    }];
    [self assertError:outside code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindChampion path:@"$.skills.W.range.maxRightPx"];
    NSError *relationship = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *invalid) {
        invalid[@"skills"][@"W"][@"range"][@"minUpPx"] = @451;
    }];
    [self assertError:relationship code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindChampion path:@"$.skills.W.range.minUpPx"];
}

- (void)testPointResponseDocumentedBoundariesAndRelationships {
    NSMutableDictionary *json = [self exampleJSON:@"caitlyn.json"];
    NSMutableDictionary *response = json[@"skills"][@"W"][@"touchResponse"];
    response[@"deadzoneRatio"] = @0;
    response[@"fullRangeRatio"] = @1.5;
    response[@"curveExponent"] = @4;
    XCTAssertNotNil([self.decoder decodeChampionProfileData:[self dataForJSON:json] error:nil]);
    NSArray<NSArray *> *cases = @[
        @[@"deadzoneRatio", @0.51],
        @[@"fullRangeRatio", @0.49],
        @[@"curveExponent", @0.24],
    ];
    for (NSArray *entry in cases) {
        NSError *error = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *invalid) {
            invalid[@"skills"][@"W"][@"touchResponse"][entry[0]] = entry[1];
        }];
        [self assertError:error
                     code:MobaProfileErrorValueOutOfRange
                     kind:MobaProfileKindChampion
                     path:[@"$.skills.W.touchResponse." stringByAppendingString:entry[0]]];
    }
    NSError *relationship = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *invalid) {
        invalid[@"skills"][@"W"][@"touchResponse"][@"deadzoneRatio"] = @0.5;
        invalid[@"skills"][@"W"][@"touchResponse"][@"fullRangeRatio"] = @0.5;
    }];
    [self assertError:relationship code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindChampion path:@"$.skills.W.touchResponse.fullRangeRatio"];
}

- (void)testDefaultAimRatioBoundariesAndFiniteAngle {
    NSMutableDictionary *json = [self exampleJSON:@"caitlyn.json"];
    json[@"skills"][@"Q"][@"defaultAim"][@"distanceRatio"] = @0;
    XCTAssertNotNil([self.decoder decodeChampionProfileData:[self dataForJSON:json] error:nil]);
    NSError *ratioError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *invalid) {
        invalid[@"skills"][@"Q"][@"defaultAim"][@"distanceRatio"] = @1.01;
    }];
    [self assertError:ratioError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindChampion path:@"$.skills.Q.defaultAim.distanceRatio"];
    NSMutableDictionary *nonfinite = [self exampleJSON:@"caitlyn.json"];
    nonfinite[@"skills"][@"Q"][@"defaultAim"][@"angleDeg"] = @(NAN);
    NSError *angleError = nil;
    XCTAssertFalse([self.validator validateJSONObject:nonfinite profileKind:MobaProfileKindChampion error:&angleError]);
    [self assertError:angleError code:MobaProfileErrorValueOutOfRange kind:MobaProfileKindChampion path:@"$.skills.Q.defaultAim.angleDeg"];
}

- (void)testChampionRequiredStringsAndSkillBooleanUseStrictTypes {
    NSError *stringError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"displayName"] = @123;
    }];
    [self assertError:stringError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindChampion path:@"$.displayName"];
    NSError *boolError = [self championErrorForFile:@"caitlyn.json" mutation:^(NSMutableDictionary *json) {
        json[@"skills"][@"Q"][@"allowCancel"] = @1;
    }];
    [self assertError:boolError code:MobaProfileErrorFieldTypeMismatch kind:MobaProfileKindChampion path:@"$.skills.Q.allowCancel"];
}

- (void)testUnknownChampionFieldsAreIgnoredButKnownFieldsStillValidate {
    NSMutableDictionary *json = [self exampleJSON:@"caitlyn.json"];
    json[@"futureChampionField"] = @[@1, @2];
    json[@"skills"][@"Q"][@"futureSkillField"] = @{ @"enabled": @YES };
    json[@"skills"][@"Q"][@"range"][@"futureRangeField"] = @123;
    XCTAssertNotNil([self.decoder decodeChampionProfileData:[self dataForJSON:json] error:nil]);
}

@end
