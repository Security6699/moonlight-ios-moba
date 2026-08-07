//
//  MobaProfileTransferService.m
//  Moonlight
//

#import "MobaProfileTransferService.h"

#import "MobaProfileError.h"

@interface MobaProfileExportPayload ()
- (instancetype)initWithData:(NSData *)data fileName:(NSString *)fileName
                  profileKind:(MobaProfileKind)profileKind;
@end

@implementation MobaProfileExportPayload
- (instancetype)initWithData:(NSData *)data fileName:(NSString *)fileName
                  profileKind:(MobaProfileKind)profileKind {
    self = [super init];
    if (self) {
        _data = [data copy];
        _fileName = [fileName copy];
        _profileKind = [profileKind copy];
    }
    return self;
}
@end

@interface MobaProfileImportPlan ()
- (instancetype)initWithProfileKind:(MobaProfileKind)profileKind
                          importData:(NSData *)importData
                       schemaVersion:(NSUInteger)schemaVersion
                   profileIdentifier:(NSString *)profileIdentifier
                         displayName:(nullable NSString *)displayName
                  targetRelativePath:(NSString *)targetRelativePath
          activeChampionRelativePath:(NSString *)activeChampionRelativePath
           replacedProfileIdentifier:(NSString *)replacedProfileIdentifier
              switchesActiveChampion:(BOOL)switchesActiveChampion
      destinationPreviouslyExisted:(BOOL)destinationPreviouslyExisted
             previousDestinationData:(nullable NSData *)previousDestinationData
 activeProfileDataByRelativePath:(NSDictionary<NSString *, NSData *> *)activeProfileDataByRelativePath
                        summaryLines:(NSArray<NSString *> *)summaryLines
                        baseSnapshot:(MobaProfileSnapshot *)baseSnapshot
                 repositoryCandidate:(MobaProfileRepositoryCandidate *)repositoryCandidate
                             runtime:(MobaChampionRuntime *)runtime
                 skillControlPackage:(MobaSkillControlPackage *)skillControlPackage;
@end

@implementation MobaProfileImportPlan
- (instancetype)initWithProfileKind:(MobaProfileKind)profileKind
                          importData:(NSData *)importData
                       schemaVersion:(NSUInteger)schemaVersion
                   profileIdentifier:(NSString *)profileIdentifier
                         displayName:(NSString *)displayName
                  targetRelativePath:(NSString *)targetRelativePath
          activeChampionRelativePath:(NSString *)activeChampionRelativePath
           replacedProfileIdentifier:(NSString *)replacedProfileIdentifier
              switchesActiveChampion:(BOOL)switchesActiveChampion
      destinationPreviouslyExisted:(BOOL)destinationPreviouslyExisted
             previousDestinationData:(NSData *)previousDestinationData
 activeProfileDataByRelativePath:(NSDictionary<NSString *, NSData *> *)activeProfileDataByRelativePath
                        summaryLines:(NSArray<NSString *> *)summaryLines
                        baseSnapshot:(MobaProfileSnapshot *)baseSnapshot
                 repositoryCandidate:(MobaProfileRepositoryCandidate *)repositoryCandidate
                             runtime:(MobaChampionRuntime *)runtime
                 skillControlPackage:(MobaSkillControlPackage *)skillControlPackage {
    self = [super init];
    if (self) {
        _profileKind = [profileKind copy];
        _importData = [importData copy];
        _schemaVersion = schemaVersion;
        _profileIdentifier = [profileIdentifier copy];
        _displayName = [displayName copy];
        _targetRelativePath = [targetRelativePath copy];
        _activeChampionRelativePath = [activeChampionRelativePath copy];
        _replacedProfileIdentifier = [replacedProfileIdentifier copy];
        _switchesActiveChampion = switchesActiveChampion;
        _destinationPreviouslyExisted = destinationPreviouslyExisted;
        _previousDestinationData = [previousDestinationData copy];
        _activeProfileDataByRelativePath = [activeProfileDataByRelativePath copy];
        _summaryLines = [summaryLines copy];
        _baseSnapshot = baseSnapshot;
        _repositoryCandidate = repositoryCandidate;
        _runtime = runtime;
        _skillControlPackage = skillControlPackage;
    }
    return self;
}
@end

@implementation MobaProfileTransferService {
    MobaProfileStore *_store;
    MobaProfileRepository *_repository;
    MobaProfileDecoder *_decoder;
    id<MobaChampionRuntimeBuilding> _runtimeBuilder;
    id<MobaSkillControlPackageBuilding> _controlPackageBuilder;
}

- (instancetype)initWithStore:(MobaProfileStore *)store
                     repository:(MobaProfileRepository *)repository
                  runtimeBuilder:(id<MobaChampionRuntimeBuilding>)runtimeBuilder
           controlPackageBuilder:(id<MobaSkillControlPackageBuilding>)controlPackageBuilder {
    if (store == nil || repository == nil || runtimeBuilder == nil || controlPackageBuilder == nil) return nil;
    self = [super init];
    if (self) {
        _store = store;
        _repository = repository;
        _decoder = [[MobaProfileDecoder alloc] init];
        _runtimeBuilder = runtimeBuilder;
        _controlPackageBuilder = controlPackageBuilder;
    }
    return self;
}

- (NSError *)errorWithCode:(MobaProfileErrorCode)code kind:(MobaProfileKind)kind
                      path:(NSString *)path operation:(NSString *)operation
               description:(NSString *)description underlying:(NSError *)underlying {
    return MobaProfileMakeError(code, kind ?: @"unknown", path, operation, description, underlying);
}

- (NSDictionary *)rootObjectForData:(NSData *)data error:(NSError **)error {
    NSError *parseError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:&parseError];
    if (object == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorJSONParseFailed kind:@"unknown"
            path:@"$" operation:@"detect-profile-type" description:@"The imported file is not valid JSON."
            underlying:parseError];
        return nil;
    }
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorRootTypeMismatch kind:@"unknown"
            path:@"$" operation:@"detect-profile-type" description:@"The imported JSON root must be a dictionary."
            underlying:nil];
        return nil;
    }
    return object;
}

- (MobaProfileKind)detectedKindForRoot:(NSDictionary *)root error:(NSError **)error {
    NSDictionary<MobaProfileKind, NSArray<NSString *> *> *strongSignatures = @{
        MobaProfileKindRuntime: @[@"canvas", @"requiredStreamResolution", @"videoMode", @"camera"],
        MobaProfileKindInput: @[@"profileId", @"movement", @"actions", @"cancelCastAction"],
        MobaProfileKindLayout: @[@"layoutId", @"deviceClass", @"controls"],
        MobaProfileKindChampion: @[@"championId", @"displayName", @"skills"],
    };
    NSMutableArray<MobaProfileKind> *matches = [NSMutableArray array];
    [strongSignatures enumerateKeysAndObjectsUsingBlock:^(MobaProfileKind kind,
                                                           NSArray<NSString *> *keys,
                                                           BOOL *stop) {
        BOOL complete = YES;
        for (NSString *key in keys) {
            if (root[key] == nil) {
                complete = NO;
                break;
            }
        }
        if (complete) [matches addObject:kind];
    }];
    if (matches.count == 1) return matches.firstObject;
    if (matches.count > 1) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorAmbiguousProfileType
            kind:@"unknown" path:@"$"
            operation:@"detect-profile-type"
            description:@"The JSON content contains multiple complete profile type signatures."
            underlying:nil];
        return nil;
    }

    NSMutableArray<MobaProfileKind> *fallbackMatches = [NSMutableArray array];
    if (root[@"championId"] != nil || root[@"skills"] != nil) {
        [fallbackMatches addObject:MobaProfileKindChampion];
    }
    if (root[@"layoutId"] != nil) [fallbackMatches addObject:MobaProfileKindLayout];
    if (root[@"profileId"] != nil) [fallbackMatches addObject:MobaProfileKindInput];
    NSUInteger runtimeCoreCount = 0;
    for (NSString *key in strongSignatures[MobaProfileKindRuntime]) {
        if (root[key] != nil) runtimeCoreCount += 1;
    }
    if (runtimeCoreCount >= 2) [fallbackMatches addObject:MobaProfileKindRuntime];
    if (fallbackMatches.count == 1) return fallbackMatches.firstObject;

    MobaProfileErrorCode code = fallbackMatches.count == 0
        ? MobaProfileErrorUnknownProfileType : MobaProfileErrorAmbiguousProfileType;
    NSString *description = fallbackMatches.count == 0
        ? @"The JSON content does not identify a supported profile type."
        : @"The malformed JSON content has conflicting profile type tendencies.";
    if (error != NULL) *error = [self errorWithCode:code kind:@"unknown" path:@"$"
        operation:@"detect-profile-type" description:description underlying:nil];
    return nil;
}

+ (NSString *)safeExportFileComponent:(NSString *)component {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    NSMutableString *result = [NSMutableString string];
    BOOL lastWasDash = NO;
    for (NSUInteger index = 0; index < component.length; index++) {
        unichar character = [component characterAtIndex:index];
        BOOL accepted = [allowed characterIsMember:character];
        if (accepted) {
            [result appendFormat:@"%C", character];
            lastWasDash = NO;
        }
        else if (!lastWasDash && result.length > 0) {
            [result appendString:@"-"];
            lastWasDash = YES;
        }
    }
    while ([result hasSuffix:@"-"]) [result deleteCharactersInRange:NSMakeRange(result.length - 1, 1)];
    return result.length > 0 ? result : @"profile";
}

+ (NSString *)safeChampionStorageComponentForIdentifier:(NSString *)identifier error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) {
        if (error != NULL) *error = MobaProfileMakeError(MobaProfileErrorValueOutOfRange,
            MobaProfileKindChampion, @"$.championId", @"derive-champion-path",
            @"championId must be a non-empty string.", nil);
        return nil;
    }
    NSCharacterSet *safe = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    if ([identifier rangeOfCharacterFromSet:safe.invertedSet].location == NSNotFound &&
        ![identifier isEqualToString:@"."] && ![identifier isEqualToString:@".."]) {
        return identifier;
    }
    NSData *utf8 = [identifier dataUsingEncoding:NSUTF8StringEncoding];
    if (utf8 == nil) {
        if (error != NULL) *error = MobaProfileMakeError(MobaProfileErrorValueOutOfRange,
            MobaProfileKindChampion, @"$.championId", @"derive-champion-path",
            @"championId could not be encoded as UTF-8.", nil);
        return nil;
    }
    NSString *encoded = [utf8 base64EncodedStringWithOptions:0];
    encoded = [[encoded stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
        stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    while ([encoded hasSuffix:@"="]) {
        encoded = [encoded substringToIndex:encoded.length - 1];
    }
    return [@"id-" stringByAppendingString:encoded];
}

- (NSData *)readRequiredPath:(NSString *)path kind:(MobaProfileKind)kind error:(NSError **)error {
    NSError *readError = nil;
    NSData *data = [_store readDataAtRelativePath:path error:&readError];
    if (data == nil && error != NULL) {
        *error = [self errorWithCode:MobaProfileErrorStorageReadFailed kind:kind path:@"$"
            operation:@"read-active-profile" description:@"An active profile file could not be read."
            underlying:readError];
    }
    return data;
}

- (NSString *)cancelTypeName:(MobaProfileCancelType)type {
    switch (type) {
        case MobaProfileCancelTypeKeyboard: return @"keyboard";
        case MobaProfileCancelTypeRightMouse: return @"rightMouse";
        case MobaProfileCancelTypeReleaseOnly: return @"releaseOnly";
    }
    return @"unknown";
}

- (NSString *)castTypeName:(MobaProfileSkillCastType)type {
    switch (type) {
        case MobaProfileSkillCastTypeInstant: return @"instant";
        case MobaProfileSkillCastTypeDirectional: return @"directional";
        case MobaProfileSkillCastTypePoint: return @"point";
    }
    return @"unknown";
}

- (NSArray<NSString *> *)summaryForKind:(MobaProfileKind)kind
                               snapshot:(MobaProfileSnapshot *)snapshot
                     replacedIdentifier:(NSString *)replacedIdentifier
                    targetRelativePath:(NSString *)targetRelativePath
                         switchChampion:(BOOL)switchChampion {
    NSUInteger schemaVersion = snapshot.runtimeProfile.schemaVersion;
    if ([kind isEqualToString:MobaProfileKindInput]) schemaVersion = snapshot.inputProfile.schemaVersion;
    else if ([kind isEqualToString:MobaProfileKindLayout]) schemaVersion = snapshot.layoutProfile.schemaVersion;
    else if ([kind isEqualToString:MobaProfileKindChampion]) schemaVersion = snapshot.championProfile.schemaVersion;
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithArray:@[
        [NSString stringWithFormat:@"Detected Type: %@", kind.capitalizedString],
        [NSString stringWithFormat:@"Schema Version: %lu", (unsigned long)schemaVersion],
        [NSString stringWithFormat:@"Replace: %@", targetRelativePath],
        [NSString stringWithFormat:@"Current: %@", replacedIdentifier],
        @"A complete active-profile backup will be created before replacement.",
    ]];
    if ([kind isEqualToString:MobaProfileKindRuntime]) {
        MobaRuntimeProfile *p = snapshot.runtimeProfile;
        [lines addObjectsFromArray:@[
            @"Profile ID: runtime",
            [NSString stringWithFormat:@"Canvas: %lux%lu", (unsigned long)p.canvas.width, (unsigned long)p.canvas.height],
            [NSString stringWithFormat:@"Required Resolution: %lux%lu", (unsigned long)p.requiredStreamResolution.width,
                (unsigned long)p.requiredStreamResolution.height],
            [NSString stringWithFormat:@"Video Mode: %@", p.videoMode],
            [NSString stringWithFormat:@"Hero Anchor: %.0f, %.0f", p.camera.heroAnchor.x, p.camera.heroAnchor.y],
            [NSString stringWithFormat:@"Update Rate: %lu Hz", (unsigned long)p.mouseUpdateRateHz],
            [NSString stringWithFormat:@"Global Opacity: %.3f", p.globalOpacityMultiplier],
        ]];
    }
    else if ([kind isEqualToString:MobaProfileKindInput]) {
        MobaInputProfile *p = snapshot.inputProfile;
        [lines addObjectsFromArray:@[
            [NSString stringWithFormat:@"Profile ID: %@", p.profileID],
            [NSString stringWithFormat:@"Movement: W=%u A=%u S=%u D=%u", p.movement.upKeyCode,
                p.movement.leftKeyCode, p.movement.downKeyCode, p.movement.rightKeyCode],
            [NSString stringWithFormat:@"Actions: %@", p.actions],
            [NSString stringWithFormat:@"Attack Tap: %lu ms", (unsigned long)p.attackTapDurationMs],
            [NSString stringWithFormat:@"Cancel Type: %@", [self cancelTypeName:p.cancelCastAction.type]],
        ]];
    }
    else if ([kind isEqualToString:MobaProfileKindLayout]) {
        MobaLayoutProfile *p = snapshot.layoutProfile;
        [lines addObjectsFromArray:@[
            [NSString stringWithFormat:@"Layout ID: %@", p.layoutID],
            [NSString stringWithFormat:@"Device Class: %@", p.deviceClass],
            [NSString stringWithFormat:@"Control Count: %lu", (unsigned long)p.controls.count],
            [NSString stringWithFormat:@"Cancel Zone: %@", p.cancelZone != nil ? @"present" : @"missing"],
        ]];
    }
    else {
        MobaChampionProfile *p = snapshot.championProfile;
        NSMutableArray *casts = [NSMutableArray array];
        for (NSString *slot in @[@"Q", @"W", @"E", @"R"]) {
            MobaChampionSkillProfile *skill = p.skills[slot];
            [casts addObject:[NSString stringWithFormat:@"%@=%@", slot, [self castTypeName:skill.castType]]];
        }
        [lines addObjectsFromArray:@[
            [NSString stringWithFormat:@"Champion ID: %@", p.championID],
            [NSString stringWithFormat:@"Display Name: %@", p.displayName],
            [NSString stringWithFormat:@"Cast Types: %@", [casts componentsJoinedByString:@", "]],
            [NSString stringWithFormat:@"Switch Active Champion: %@", switchChampion ? @"Yes" : @"No"],
        ]];
    }
    return lines;
}

- (MobaProfileImportPlan *)prepareImportPlanForData:(NSData *)data
                          activeChampionRelativePath:(NSString *)activeChampionRelativePath
                                               error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (![data isKindOfClass:[NSData class]] || activeChampionRelativePath.length == 0) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorJSONParseFailed kind:@"unknown"
            path:@"$" operation:@"prepare-import" description:@"Import data and active Champion path are required."
            underlying:nil];
        return nil;
    }
    NSDictionary *root = [self rootObjectForData:data error:error];
    if (root == nil) return nil;
    MobaProfileKind kind = [self detectedKindForRoot:root error:error];
    if (kind == nil) return nil;

    id model = nil;
    if ([kind isEqualToString:MobaProfileKindRuntime]) model = [_decoder decodeRuntimeProfileData:data error:error];
    else if ([kind isEqualToString:MobaProfileKindInput]) model = [_decoder decodeInputProfileData:data error:error];
    else if ([kind isEqualToString:MobaProfileKindLayout]) model = [_decoder decodeLayoutProfileData:data error:error];
    else model = [_decoder decodeChampionProfileData:data error:error];
    if (model == nil) return nil;

    MobaProfileSnapshot *base = _repository.activeSnapshot;
    if (base == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorCrossProfileReferenceInvalid kind:kind
            path:@"$" operation:@"prepare-import" description:@"An active Repository snapshot is required."
            underlying:nil];
        return nil;
    }
    NSString *identifier = @"runtime";
    NSString *displayName = nil;
    NSString *target = MobaRuntimeProfileRelativePath;
    NSString *replacedIdentifier = @"runtime";
    if ([kind isEqualToString:MobaProfileKindInput]) {
        identifier = ((MobaInputProfile *)model).profileID;
        replacedIdentifier = base.inputProfile.profileID;
        target = MobaInputProfileRelativePath;
    }
    else if ([kind isEqualToString:MobaProfileKindLayout]) {
        identifier = ((MobaLayoutProfile *)model).layoutID;
        replacedIdentifier = base.layoutProfile.layoutID;
        target = MobaActiveLayoutProfileRelativePath;
    }
    else if ([kind isEqualToString:MobaProfileKindChampion]) {
        MobaChampionProfile *champion = model;
        NSString *storageComponent = [self.class
            safeChampionStorageComponentForIdentifier:champion.championID error:error];
        if (storageComponent == nil) return nil;
        identifier = champion.championID;
        displayName = champion.displayName;
        replacedIdentifier = base.championProfile.championID;
        BOOL usesEncodedNamespace = ![storageComponent isEqualToString:champion.championID];
        target = usesEncodedNamespace
            ? [NSString stringWithFormat:@"champions/encoded/%@.json", storageComponent]
            : [NSString stringWithFormat:@"champions/%@.json", storageComponent];
    }

    NSError *stepError = nil;
    MobaProfileRepositoryCandidate *candidate = [_repository
        prepareImportCandidateWithProfileKind:kind data:data error:&stepError];
    if (candidate == nil) {
        if (error != NULL) *error = stepError;
        return nil;
    }
    MobaChampionRuntime *runtime = [_runtimeBuilder runtimeFromSnapshot:candidate.snapshot error:&stepError];
    if (runtime == nil) {
        if (error != NULL) *error = stepError ?: [self errorWithCode:MobaProfileErrorCrossProfileReferenceInvalid
            kind:kind path:@"$" operation:@"prebuild-runtime" description:@"The imported profile runtime could not be built."
            underlying:nil];
        return nil;
    }
    MobaSkillControlPackage *package = [_controlPackageBuilder controlPackageForRuntime:runtime error:&stepError];
    if (!package.isComplete) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = stepError ?: [self errorWithCode:MobaProfileErrorCrossProfileReferenceInvalid
            kind:kind path:@"$" operation:@"prebuild-control-package"
            description:@"The imported profile Q/W/E/R package could not be built." underlying:nil];
        return nil;
    }

    NSMutableDictionary<NSString *, NSData *> *activeBytes = [NSMutableDictionary dictionary];
    NSDictionary<MobaProfileKind, NSString *> *activePaths = @{
        MobaProfileKindRuntime: MobaRuntimeProfileRelativePath,
        MobaProfileKindInput: MobaInputProfileRelativePath,
        MobaProfileKindLayout: MobaActiveLayoutProfileRelativePath,
        MobaProfileKindChampion: activeChampionRelativePath,
    };
    for (MobaProfileKind activeKind in activePaths) {
        NSString *path = activePaths[activeKind];
        NSData *bytes = [self readRequiredPath:path kind:activeKind error:&stepError];
        if (bytes == nil) {
            [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
            if (error != NULL) *error = stepError;
            return nil;
        }
        activeBytes[path] = bytes;
    }
    NSError *existenceError = nil;
    BOOL existed = [_store dataExistsAtRelativePath:target error:&existenceError];
    if (!existed && existenceError != nil) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = existenceError;
        return nil;
    }
    NSData *previousDestination = existed ? [self readRequiredPath:target kind:kind error:&stepError] : nil;
    if (existed && previousDestination == nil) {
        [package silentResetForReason:MobaInputInterruptionReasonProfileReload];
        if (error != NULL) *error = stepError;
        return nil;
    }
    BOOL switchesChampion = [kind isEqualToString:MobaProfileKindChampion] &&
        ![identifier isEqualToString:base.championProfile.championID];
    NSArray *summary = [self summaryForKind:kind snapshot:candidate.snapshot
                         replacedIdentifier:replacedIdentifier targetRelativePath:target
                              switchChampion:switchesChampion];
    return [[MobaProfileImportPlan alloc] initWithProfileKind:kind importData:data
        schemaVersion:[root[@"schemaVersion"] unsignedIntegerValue] profileIdentifier:identifier
        displayName:displayName targetRelativePath:target activeChampionRelativePath:activeChampionRelativePath
        replacedProfileIdentifier:replacedIdentifier switchesActiveChampion:switchesChampion
        destinationPreviouslyExisted:existed previousDestinationData:previousDestination
        activeProfileDataByRelativePath:activeBytes summaryLines:summary baseSnapshot:base
        repositoryCandidate:candidate runtime:runtime skillControlPackage:package];
}

- (MobaProfileExportPayload *)exportPayloadForProfileKind:(MobaProfileKind)profileKind
                                activeChampionRelativePath:(NSString *)activeChampionRelativePath
                                                     error:(NSError **)error {
    if (error != NULL) *error = nil;
    MobaProfileSnapshot *snapshot = _repository.activeSnapshot;
    if (snapshot == nil) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorStorageReadFailed kind:profileKind
            path:@"$" operation:@"export" description:@"No active profile snapshot is available." underlying:nil];
        return nil;
    }
    NSString *path = nil;
    NSString *identifier = nil;
    if ([profileKind isEqualToString:MobaProfileKindRuntime]) {
        path = MobaRuntimeProfileRelativePath;
        identifier = @"runtime";
    }
    else if ([profileKind isEqualToString:MobaProfileKindInput]) {
        path = MobaInputProfileRelativePath;
        identifier = snapshot.inputProfile.profileID;
    }
    else if ([profileKind isEqualToString:MobaProfileKindLayout]) {
        path = MobaActiveLayoutProfileRelativePath;
        identifier = snapshot.layoutProfile.layoutID;
    }
    else if ([profileKind isEqualToString:MobaProfileKindChampion]) {
        path = activeChampionRelativePath;
        identifier = snapshot.championProfile.championID;
    }
    if (path.length == 0) {
        if (error != NULL) *error = [self errorWithCode:MobaProfileErrorUnknownProfileType kind:profileKind ?: @"unknown"
            path:@"$" operation:@"export" description:@"The requested export profile kind is not supported."
            underlying:nil];
        return nil;
    }
    NSData *data = [self readRequiredPath:path kind:profileKind error:error];
    if (data == nil) return nil;
    NSString *component = [self.class safeExportFileComponent:identifier];
    NSString *fileName = [profileKind isEqualToString:MobaProfileKindRuntime]
        ? @"moonlight-moba-runtime-v1.json"
        : [NSString stringWithFormat:@"moonlight-moba-%@-%@-v1.json", profileKind, component];
    return [[MobaProfileExportPayload alloc] initWithData:data fileName:fileName profileKind:profileKind];
}

@end
