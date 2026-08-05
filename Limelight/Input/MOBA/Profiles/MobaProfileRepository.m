//
//  MobaProfileRepository.m
//  Moonlight
//

#import "MobaProfileRepository.h"

#import "MobaProfileError.h"

NSString *const MobaRuntimeProfileRelativePath = @"runtime.json";
NSString *const MobaInputProfileRelativePath = @"input.json";
NSString *const MobaActiveLayoutProfileRelativePath = @"active-layout.json";

@implementation MobaProfileRepository {
    MobaProfileStore *_store;
    MobaProfileDecoder *_decoder;
    MobaProfileSnapshot *_activeSnapshot;
}

- (instancetype)initWithStore:(MobaProfileStore *)store {
    return [self initWithStore:store decoder:[[MobaProfileDecoder alloc] init]];
}

- (instancetype)initWithStore:(MobaProfileStore *)store
                       decoder:(MobaProfileDecoder *)decoder {
    self = [super init];
    if (self) {
        _store = store;
        _decoder = decoder;
    }
    return self;
}

- (MobaProfileSnapshot *)activeSnapshot {
    @synchronized (self) {
        return _activeSnapshot;
    }
}

- (NSData *)readRelativePath:(NSString *)relativePath
                 profileKind:(MobaProfileKind)profileKind
                    operation:(NSString *)operation
                        error:(NSError **)error {
    NSError *storageError = nil;
    NSData *data = [_store readDataAtRelativePath:relativePath error:&storageError];
    if (data == nil && error != NULL) {
        *error = MobaProfileMakeError(MobaProfileErrorStorageReadFailed,
                                      profileKind,
                                      @"$",
                                      operation,
                                      @"Unable to read profile bytes from the profile store.",
                                      storageError);
    }
    return data;
}

- (BOOL)validateChampion:(MobaChampionProfile *)champion
             inputProfile:(MobaInputProfile *)input
                     error:(NSError **)error {
    for (NSString *skillName in champion.skills) {
        MobaChampionSkillProfile *skill = champion.skills[skillName];
        if ([input keyCodeForAction:skill.inputAction] == nil) {
            if (error != NULL) {
                NSString *path = [NSString stringWithFormat:@"$.skills.%@.inputAction", skillName];
                *error = MobaProfileMakeError(MobaProfileErrorCrossProfileReferenceInvalid,
                                              MobaProfileKindChampion,
                                              path,
                                              @"cross-profile-validation",
                                              @"The champion skill references an unknown input action.",
                                              nil);
            }
            return NO;
        }
    }
    return YES;
}

- (BOOL)reloadWithChampionRelativePath:(NSString *)championRelativePath error:(NSError **)error {
    return [self loadRuntimeRelativePath:MobaRuntimeProfileRelativePath
                       inputRelativePath:MobaInputProfileRelativePath
                      layoutRelativePath:MobaActiveLayoutProfileRelativePath
                    championRelativePath:championRelativePath
                                   error:error];
}

- (BOOL)loadRuntimeRelativePath:(NSString *)runtimeRelativePath
              inputRelativePath:(NSString *)inputRelativePath
             layoutRelativePath:(NSString *)layoutRelativePath
           championRelativePath:(NSString *)championRelativePath
                          error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }

    // Every value remains local until all four profiles and their references
    // have succeeded. No failure path writes the active snapshot.
    NSData *runtimeData = [self readRelativePath:runtimeRelativePath
                                     profileKind:MobaProfileKindRuntime
                                        operation:@"read-runtime"
                                            error:error];
    if (runtimeData == nil) {
        return NO;
    }
    NSData *inputData = [self readRelativePath:inputRelativePath
                                   profileKind:MobaProfileKindInput
                                      operation:@"read-input"
                                          error:error];
    if (inputData == nil) {
        return NO;
    }
    NSData *layoutData = [self readRelativePath:layoutRelativePath
                                    profileKind:MobaProfileKindLayout
                                       operation:@"read-layout"
                                           error:error];
    if (layoutData == nil) {
        return NO;
    }
    NSData *championData = [self readRelativePath:championRelativePath
                                      profileKind:MobaProfileKindChampion
                                         operation:@"read-champion"
                                             error:error];
    if (championData == nil) {
        return NO;
    }

    MobaRuntimeProfile *runtime = [_decoder decodeRuntimeProfileData:runtimeData error:error];
    if (runtime == nil) {
        return NO;
    }
    MobaInputProfile *input = [_decoder decodeInputProfileData:inputData error:error];
    if (input == nil) {
        return NO;
    }
    MobaLayoutProfile *layout = [_decoder decodeLayoutProfileData:layoutData error:error];
    if (layout == nil) {
        return NO;
    }
    MobaChampionProfile *champion = [_decoder decodeChampionProfileData:championData error:error];
    if (champion == nil || ![self validateChampion:champion inputProfile:input error:error]) {
        return NO;
    }

    MobaProfileSnapshot *candidate = [[MobaProfileSnapshot alloc] initWithRuntimeProfile:runtime
                                                                            inputProfile:input
                                                                           layoutProfile:layout
                                                                         championProfile:champion];
    @synchronized (self) {
        _activeSnapshot = candidate;
    }
    return YES;
}

@end
