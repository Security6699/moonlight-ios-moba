//
//  MobaProfileStore.m
//  Moonlight
//

#import "MobaProfileStore.h"

NSErrorDomain const MobaProfileStoreErrorDomain = @"MobaProfileStoreErrorDomain";
NSString *const MobaProfileStoreErrorOperationKey = @"MobaProfileStoreOperation";
NSString *const MobaProfileStoreErrorRelativePathKey = @"MobaProfileStoreRelativePath";

static NSString *const MobaProfileStoreRootDirectoryName = @"MOBA";
static NSString *const MobaProfileStoreActiveLayoutPath = @"active-layout.json";

typedef NS_ENUM(NSUInteger, MobaProfileStoreItemKind) {
    MobaProfileStoreItemKindMissing,
    MobaProfileStoreItemKindRegularFile,
    MobaProfileStoreItemKindDirectory,
    MobaProfileStoreItemKindOther,
    MobaProfileStoreItemKindInspectionFailed,
};

@interface MobaProfileDefaultResource ()

- (instancetype)initWithBundleResourceName:(NSString *)bundleResourceName
                    bundleResourceExtension:(NSString *)bundleResourceExtension
                    destinationRelativePath:(NSString *)destinationRelativePath
                          seedsActiveLayout:(BOOL)seedsActiveLayout;

@end

@implementation MobaProfileDefaultResource

- (instancetype)initWithBundleResourceName:(NSString *)bundleResourceName
                    bundleResourceExtension:(NSString *)bundleResourceExtension
                    destinationRelativePath:(NSString *)destinationRelativePath
                          seedsActiveLayout:(BOOL)seedsActiveLayout {
    self = [super init];
    if (self) {
        _bundleResourceName = [bundleResourceName copy];
        _bundleResourceExtension = [bundleResourceExtension copy];
        _destinationRelativePath = [destinationRelativePath copy];
        _seedsActiveLayout = seedsActiveLayout;
    }
    return self;
}

@end

@interface MobaFoundationAtomicWriter : NSObject <MobaProfileAtomicWriting>

- (instancetype)initWithFileManager:(NSFileManager *)fileManager;

@end

@implementation MobaFoundationAtomicWriter {
    NSFileManager *_fileManager;
}

- (instancetype)initWithFileManager:(NSFileManager *)fileManager {
    self = [super init];
    if (self) {
        _fileManager = fileManager;
    }
    return self;
}

- (BOOL)writeData:(NSData *)data
             toURL:(NSURL *)url
   replaceExisting:(BOOL)replaceExisting
             error:(NSError **)error {
    if (replaceExisting) {
        return [data writeToURL:url options:NSDataWritingAtomic error:error];
    }

    NSURL *parentURL = [url URLByDeletingLastPathComponent];
    NSString *temporaryName = [NSString stringWithFormat:@".%@.%@.tmp",
                               url.lastPathComponent,
                               NSUUID.UUID.UUIDString];
    NSURL *temporaryURL = [parentURL URLByAppendingPathComponent:temporaryName isDirectory:NO];
    NSError *temporaryWriteError = nil;
    if (![data writeToURL:temporaryURL options:NSDataWritingAtomic error:&temporaryWriteError]) {
        if (error != NULL) {
            *error = temporaryWriteError;
        }
        return NO;
    }

    NSError *linkError = nil;
    BOOL linked = [_fileManager linkItemAtURL:temporaryURL toURL:url error:&linkError];
    [_fileManager removeItemAtURL:temporaryURL error:nil];
    if (!linked && error != NULL) {
        *error = linkError;
    }
    return linked;
}

@end

@implementation MobaProfileStore {
    id<MobaProfileResourceProviding> _resourceProvider;
    NSFileManager *_fileManager;
    id<MobaProfileAtomicWriting> _atomicWriter;
    NSError *_initializationError;
}

+ (NSArray<MobaProfileDefaultResource *> *)defaultResourceManifest {
    static NSArray<MobaProfileDefaultResource *> *manifest;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manifest = @[
            [[MobaProfileDefaultResource alloc] initWithBundleResourceName:@"runtime"
                                                   bundleResourceExtension:@"json"
                                                   destinationRelativePath:@"runtime.json"
                                                         seedsActiveLayout:NO],
            [[MobaProfileDefaultResource alloc] initWithBundleResourceName:@"input"
                                                   bundleResourceExtension:@"json"
                                                   destinationRelativePath:@"input.json"
                                                         seedsActiveLayout:NO],
            [[MobaProfileDefaultResource alloc] initWithBundleResourceName:@"ipad-pro-13-layout"
                                                   bundleResourceExtension:@"json"
                                                   destinationRelativePath:@"layouts/ipad-pro-13-layout.json"
                                                         seedsActiveLayout:YES],
            [[MobaProfileDefaultResource alloc] initWithBundleResourceName:@"caitlyn"
                                                   bundleResourceExtension:@"json"
                                                   destinationRelativePath:@"champions/caitlyn.json"
                                                         seedsActiveLayout:NO],
            [[MobaProfileDefaultResource alloc] initWithBundleResourceName:@"debug-instant"
                                                   bundleResourceExtension:@"json"
                                                   destinationRelativePath:@"champions/debug-instant.json"
                                                         seedsActiveLayout:NO],
        ];
    });
    return manifest;
}

- (instancetype)init {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *directoryError = nil;
    NSURL *applicationSupportURL = [fileManager URLForDirectory:NSApplicationSupportDirectory
                                                      inDomain:NSUserDomainMask
                                             appropriateForURL:nil
                                                        create:NO
                                                         error:&directoryError];
    if (applicationSupportURL != nil) {
        NSURL *rootURL = [applicationSupportURL URLByAppendingPathComponent:MobaProfileStoreRootDirectoryName
                                                                isDirectory:YES];
        return [self initWithRootDirectoryURL:rootURL
                            resourceProvider:(id<MobaProfileResourceProviding>)[NSBundle mainBundle]
                                 fileManager:fileManager
                                atomicWriter:[[MobaFoundationAtomicWriter alloc] initWithFileManager:fileManager]];
    }

    self = [self initWithRootDirectoryURL:[NSURL fileURLWithPath:@"/" isDirectory:YES]
                         resourceProvider:(id<MobaProfileResourceProviding>)[NSBundle mainBundle]
                              fileManager:fileManager
                             atomicWriter:[[MobaFoundationAtomicWriter alloc] initWithFileManager:fileManager]];
    if (self) {
        _rootDirectoryURL = nil;
        _initializationError = [self errorWithCode:MobaProfileStoreErrorApplicationSupportUnavailable
                                         operation:@"resolve-application-support"
                                      relativePath:@"."
                                    underlyingError:directoryError
                                        description:@"Unable to resolve the Application Support directory."];
    }
    return self;
}

- (instancetype)initWithRootDirectoryURL:(NSURL *)rootDirectoryURL
                         resourceProvider:(id<MobaProfileResourceProviding>)resourceProvider
                              fileManager:(NSFileManager *)fileManager {
    return [self initWithRootDirectoryURL:rootDirectoryURL
                         resourceProvider:resourceProvider
                              fileManager:fileManager
                             atomicWriter:[[MobaFoundationAtomicWriter alloc] initWithFileManager:fileManager]];
}

- (instancetype)initWithRootDirectoryURL:(NSURL *)rootDirectoryURL
                         resourceProvider:(id<MobaProfileResourceProviding>)resourceProvider
                              fileManager:(NSFileManager *)fileManager
                             atomicWriter:(id<MobaProfileAtomicWriting>)atomicWriter {
    self = [super init];
    if (self) {
        _rootDirectoryURL = [[rootDirectoryURL URLByStandardizingPath] copy];
        _resourceProvider = resourceProvider;
        _fileManager = fileManager;
        _atomicWriter = atomicWriter;
    }
    return self;
}

- (NSError *)errorWithCode:(MobaProfileStoreErrorCode)code
                  operation:(NSString *)operation
               relativePath:(NSString *)relativePath
             underlyingError:(NSError *)underlyingError
                 description:(NSString *)description {
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey: description,
        MobaProfileStoreErrorOperationKey: operation,
        MobaProfileStoreErrorRelativePathKey: relativePath,
    } mutableCopy];
    if (underlyingError != nil) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:MobaProfileStoreErrorDomain code:code userInfo:userInfo];
}

- (void)captureError:(NSError *)candidate firstError:(NSError **)firstError {
    if (*firstError == nil && candidate != nil) {
        *firstError = candidate;
    }
}

- (BOOL)isMissingItemError:(NSError *)error {
    return [error.domain isEqualToString:NSCocoaErrorDomain] &&
        (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError);
}

- (MobaProfileStoreItemKind)itemKindAtURL:(NSURL *)url error:(NSError **)error {
    NSError *attributesError = nil;
    NSDictionary<NSFileAttributeKey, id> *attributes =
        [_fileManager attributesOfItemAtPath:url.path error:&attributesError];
    if (attributes == nil) {
        if ([self isMissingItemError:attributesError]) {
            return MobaProfileStoreItemKindMissing;
        }
        if (error != NULL) {
            *error = attributesError;
        }
        return MobaProfileStoreItemKindInspectionFailed;
    }

    NSFileAttributeType type = attributes[NSFileType];
    if ([type isEqualToString:NSFileTypeRegular]) {
        return MobaProfileStoreItemKindRegularFile;
    }
    if ([type isEqualToString:NSFileTypeDirectory]) {
        return MobaProfileStoreItemKindDirectory;
    }
    return MobaProfileStoreItemKindOther;
}

- (nullable NSURL *)destinationURLForRelativePath:(id)relativePath error:(NSError **)error {
    BOOL validString = [relativePath isKindOfClass:[NSString class]];
    NSString *path = validString ? (NSString *)relativePath : nil;
    NSArray<NSString *> *components = validString ? [path componentsSeparatedByString:@"/"] : @[];
    BOOL validComponents = components.count > 0;
    for (NSString *component in components) {
        if (component.length == 0 || [component isEqualToString:@"."] || [component isEqualToString:@".."]) {
            validComponents = NO;
            break;
        }
    }

    BOOL invalidSyntax = !validString || path.length == 0 || path.isAbsolutePath ||
        [path hasPrefix:@"~"] || [path rangeOfString:@"\\"].location != NSNotFound ||
        [path rangeOfString:@":"].location != NSNotFound || !validComponents;
    if (invalidSyntax || self.rootDirectoryURL == nil || !self.rootDirectoryURL.isFileURL) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorInvalidPath
                               operation:@"validate-path"
                            relativePath:validString && path.length > 0 ? path : @"."
                          underlyingError:nil
                              description:@"The path must be a non-empty relative path beneath the MOBA root directory."];
        }
        return nil;
    }

    NSURL *standardizedRoot = [self.rootDirectoryURL URLByStandardizingPath];
    NSURL *resolvedRoot = [[standardizedRoot URLByResolvingSymlinksInPath] URLByStandardizingPath];
    NSString *rootPath = resolvedRoot.path;
    NSString *rootPrefix = [rootPath stringByAppendingString:@"/"];

    NSURL *destination = standardizedRoot;
    for (NSString *component in components) {
        destination = [[destination URLByAppendingPathComponent:component isDirectory:NO] URLByStandardizingPath];
        NSURL *resolvedComponent = [[destination URLByResolvingSymlinksInPath] URLByStandardizingPath];
        NSString *resolvedComponentPath = resolvedComponent.path;
        if ([resolvedComponentPath isEqualToString:rootPath] || ![resolvedComponentPath hasPrefix:rootPrefix]) {
            if (error != NULL) {
                *error = [self errorWithCode:MobaProfileStoreErrorInvalidPath
                                   operation:@"validate-path"
                                relativePath:path
                              underlyingError:nil
                                  description:@"The resolved path escapes the MOBA root directory."];
            }
            return nil;
        }
    }
    return destination;
}

- (BOOL)ensureDirectoryAtURL:(NSURL *)directoryURL
                relativePath:(NSString *)relativePath
                       error:(NSError **)error {
    NSError *inspectionError = nil;
    MobaProfileStoreItemKind kind = [self itemKindAtURL:directoryURL error:&inspectionError];
    if (kind == MobaProfileStoreItemKindDirectory) {
        return YES;
    }
    if (kind != MobaProfileStoreItemKindMissing) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorDestinationConflict
                               operation:@"create-directory"
                            relativePath:relativePath
                          underlyingError:inspectionError
                              description:@"A non-directory item occupies a required directory path."];
        }
        return NO;
    }

    NSError *creationError = nil;
    if (![_fileManager createDirectoryAtURL:directoryURL
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&creationError]) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorDirectoryCreationFailed
                               operation:@"create-directory"
                            relativePath:relativePath
                          underlyingError:creationError
                              description:@"Unable to create a required MOBA profile directory."];
        }
        return NO;
    }
    return YES;
}

- (BOOL)ensureParentDirectoryForURL:(NSURL *)destinationURL
                       relativePath:(NSString *)relativePath
                              error:(NSError **)error {
    NSString *parentRelativePath = [relativePath stringByDeletingLastPathComponent];
    if (parentRelativePath.length == 0 || [parentRelativePath isEqualToString:@"."]) {
        parentRelativePath = @".";
    }
    return [self ensureDirectoryAtURL:[destinationURL URLByDeletingLastPathComponent]
                         relativePath:parentRelativePath
                                error:error];
}

- (BOOL)bootstrapDefaultsIfFeatureEnabled:(BOOL)featureEnabled error:(NSError **)error {
    if (!featureEnabled) {
        if (error != NULL) {
            *error = nil;
        }
        return YES;
    }
    return [self bootstrapDefaultsWithError:error];
}

- (BOOL)bootstrapDefaultsWithError:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (_initializationError != nil) {
        if (error != NULL) {
            *error = _initializationError;
        }
        return NO;
    }
    if (self.rootDirectoryURL == nil || !self.rootDirectoryURL.isFileURL) {
        NSError *rootError = [self errorWithCode:MobaProfileStoreErrorInvalidPath
                                       operation:@"validate-root"
                                    relativePath:@"."
                                  underlyingError:nil
                                      description:@"The MOBA profile root must be a file URL."];
        if (error != NULL) {
            *error = rootError;
        }
        return NO;
    }

    NSError *firstError = nil;
    NSError *directoryError = nil;
    if (![self ensureDirectoryAtURL:self.rootDirectoryURL relativePath:@"." error:&directoryError]) {
        if (error != NULL) {
            *error = directoryError;
        }
        return NO;
    }

    for (NSString *directory in @[@"layouts", @"champions", @"backups"]) {
        NSError *pathError = nil;
        NSURL *directoryURL = [self destinationURLForRelativePath:directory error:&pathError];
        if (directoryURL == nil || ![self ensureDirectoryAtURL:directoryURL relativePath:directory error:&pathError]) {
            [self captureError:pathError firstError:&firstError];
        }
    }

    for (MobaProfileDefaultResource *resource in self.class.defaultResourceManifest) {
        NSMutableArray<NSString *> *destinations = [NSMutableArray arrayWithObject:resource.destinationRelativePath];
        if (resource.seedsActiveLayout) {
            [destinations addObject:MobaProfileStoreActiveLayoutPath];
        }

        NSMutableArray<NSString *> *missingDestinations = [NSMutableArray array];
        for (NSString *relativePath in destinations) {
            NSError *pathError = nil;
            NSURL *destinationURL = [self destinationURLForRelativePath:relativePath error:&pathError];
            if (destinationURL == nil) {
                [self captureError:pathError firstError:&firstError];
                continue;
            }

            NSError *inspectionError = nil;
            MobaProfileStoreItemKind kind = [self itemKindAtURL:destinationURL error:&inspectionError];
            if (kind == MobaProfileStoreItemKindMissing) {
                [missingDestinations addObject:relativePath];
            }
            else if (kind != MobaProfileStoreItemKindRegularFile) {
                NSError *conflictError = [self errorWithCode:MobaProfileStoreErrorDestinationConflict
                                                   operation:@"seed-default"
                                                relativePath:relativePath
                                              underlyingError:inspectionError
                                                  description:@"A directory or other non-file item occupies a default profile destination."];
                [self captureError:conflictError firstError:&firstError];
            }
        }

        if (missingDestinations.count == 0) {
            continue;
        }

        NSURL *resourceURL = [_resourceProvider URLForResource:resource.bundleResourceName
                                                 withExtension:resource.bundleResourceExtension];
        if (resourceURL == nil) {
            NSString *resourceFile = [resource.bundleResourceName
                stringByAppendingPathExtension:resource.bundleResourceExtension];
            NSError *resourceError = [self errorWithCode:MobaProfileStoreErrorResourceMissing
                                                operation:@"locate-bundle-resource"
                                             relativePath:resourceFile
                                           underlyingError:nil
                                               description:@"A bundled MOBA default resource is missing."];
            [self captureError:resourceError firstError:&firstError];
            continue;
        }

        NSError *resourceReadError = nil;
        NSData *resourceData = [NSData dataWithContentsOfURL:resourceURL
                                                    options:0
                                                      error:&resourceReadError];
        if (resourceData == nil) {
            NSString *resourceFile = [resource.bundleResourceName
                stringByAppendingPathExtension:resource.bundleResourceExtension];
            NSError *wrappedError = [self errorWithCode:MobaProfileStoreErrorResourceReadFailed
                                               operation:@"read-bundle-resource"
                                            relativePath:resourceFile
                                          underlyingError:resourceReadError
                                              description:@"Unable to read a bundled MOBA default resource."];
            [self captureError:wrappedError firstError:&firstError];
            continue;
        }

        for (NSString *relativePath in missingDestinations) {
            NSError *writeError = nil;
            if (![self writeData:resourceData
                  toRelativePath:relativePath
                 replaceExisting:NO
                           error:&writeError]) {
                // A concurrent creator wins safely. Treat an ordinary file as
                // an already-installed user file and preserve it.
                NSError *pathError = nil;
                NSURL *destinationURL = [self destinationURLForRelativePath:relativePath error:&pathError];
                MobaProfileStoreItemKind kind = destinationURL == nil
                    ? MobaProfileStoreItemKindInspectionFailed
                    : [self itemKindAtURL:destinationURL error:&pathError];
                if (kind != MobaProfileStoreItemKindRegularFile) {
                    [self captureError:writeError ?: pathError firstError:&firstError];
                }
            }
        }
    }

    if (error != NULL) {
        *error = firstError;
    }
    return firstError == nil;
}

- (nullable NSData *)readDataAtRelativePath:(NSString *)relativePath error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSError *pathError = nil;
    NSURL *destinationURL = [self destinationURLForRelativePath:relativePath error:&pathError];
    if (destinationURL == nil) {
        if (error != NULL) {
            *error = pathError;
        }
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:destinationURL options:0 error:&readError];
    if (data == nil && error != NULL) {
        *error = [self errorWithCode:MobaProfileStoreErrorReadFailed
                           operation:@"read"
                        relativePath:relativePath
                      underlyingError:readError
                          description:@"Unable to read MOBA profile data."];
    }
    return data;
}

- (BOOL)dataExistsAtRelativePath:(NSString *)relativePath error:(NSError **)error {
    if (error != NULL) *error = nil;
    NSError *pathError = nil;
    NSURL *destinationURL = [self destinationURLForRelativePath:relativePath error:&pathError];
    if (destinationURL == nil) {
        if (error != NULL) *error = pathError;
        return NO;
    }
    NSError *inspectionError = nil;
    MobaProfileStoreItemKind kind = [self itemKindAtURL:destinationURL error:&inspectionError];
    if (kind == MobaProfileStoreItemKindRegularFile) return YES;
    if (kind == MobaProfileStoreItemKindMissing) return NO;
    if (error != NULL) {
        *error = [self errorWithCode:MobaProfileStoreErrorDestinationConflict
                           operation:@"inspect"
                        relativePath:relativePath
                      underlyingError:inspectionError
                          description:@"The profile path is occupied by a non-file item."];
    }
    return NO;
}

- (NSData *)readBundledDefaultDataForDestinationRelativePath:(NSString *)relativePath
                                                        error:(NSError **)error {
    if (error != NULL) *error = nil;
    MobaProfileDefaultResource *matched = nil;
    for (MobaProfileDefaultResource *resource in self.class.defaultResourceManifest) {
        if ([resource.destinationRelativePath isEqualToString:relativePath] ||
            (resource.seedsActiveLayout && [relativePath isEqualToString:MobaProfileStoreActiveLayoutPath])) {
            matched = resource;
            break;
        }
    }
    if (matched == nil) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorResourceMissing
                               operation:@"locate-bundle-resource"
                            relativePath:relativePath ?: @"."
                          underlyingError:nil
                              description:@"No bundled default is registered for this profile destination."];
        }
        return nil;
    }
    NSURL *resourceURL = [_resourceProvider URLForResource:matched.bundleResourceName
                                             withExtension:matched.bundleResourceExtension];
    NSError *readError = nil;
    NSData *data = resourceURL == nil ? nil : [NSData dataWithContentsOfURL:resourceURL
                                                                    options:0
                                                                      error:&readError];
    if (data == nil && error != NULL) {
        *error = [self errorWithCode:resourceURL == nil ? MobaProfileStoreErrorResourceMissing
                                                       : MobaProfileStoreErrorResourceReadFailed
                           operation:resourceURL == nil ? @"locate-bundle-resource" : @"read-bundle-resource"
                        relativePath:relativePath
                      underlyingError:readError
                          description:@"Unable to read the bundled MOBA default resource."];
    }
    return data;
}

- (BOOL)writeData:(NSData *)data
    toRelativePath:(NSString *)relativePath
   replaceExisting:(BOOL)replaceExisting
             error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (![data isKindOfClass:[NSData class]]) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorWriteFailed
                               operation:@"write"
                            relativePath:[relativePath isKindOfClass:[NSString class]] && relativePath.length > 0
                                ? relativePath : @"."
                          underlyingError:nil
                              description:@"MOBA profile data must not be nil."];
        }
        return NO;
    }

    NSError *pathError = nil;
    NSURL *destinationURL = [self destinationURLForRelativePath:relativePath error:&pathError];
    if (destinationURL == nil) {
        if (error != NULL) {
            *error = pathError;
        }
        return NO;
    }

    NSError *parentError = nil;
    if (![self ensureParentDirectoryForURL:destinationURL relativePath:relativePath error:&parentError]) {
        if (error != NULL) {
            *error = parentError;
        }
        return NO;
    }

    NSError *inspectionError = nil;
    MobaProfileStoreItemKind kind = [self itemKindAtURL:destinationURL error:&inspectionError];
    if (kind == MobaProfileStoreItemKindDirectory || kind == MobaProfileStoreItemKindOther ||
        kind == MobaProfileStoreItemKindInspectionFailed) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorDestinationConflict
                               operation:@"write"
                            relativePath:relativePath
                          underlyingError:inspectionError
                              description:@"A directory or other non-file item occupies the write destination."];
        }
        return NO;
    }
    if (kind == MobaProfileStoreItemKindRegularFile && !replaceExisting) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorDestinationExists
                               operation:@"write"
                            relativePath:relativePath
                          underlyingError:nil
                              description:@"The destination already exists and replacement was not requested."];
        }
        return NO;
    }

    NSError *writeError = nil;
    if (![_atomicWriter writeData:data
                           toURL:destinationURL
                 replaceExisting:replaceExisting
                           error:&writeError]) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorWriteFailed
                               operation:@"write"
                            relativePath:relativePath
                          underlyingError:writeError
                              description:@"Unable to atomically write MOBA profile data."];
        }
        return NO;
    }
    return YES;
}

- (BOOL)removeDataAtRelativePath:(NSString *)relativePath error:(NSError **)error {
    if (error != NULL) *error = nil;
    NSError *pathError = nil;
    NSURL *destinationURL = [self destinationURLForRelativePath:relativePath error:&pathError];
    if (destinationURL == nil) {
        if (error != NULL) *error = pathError;
        return NO;
    }
    NSError *inspectionError = nil;
    MobaProfileStoreItemKind kind = [self itemKindAtURL:destinationURL error:&inspectionError];
    if (kind == MobaProfileStoreItemKindMissing) return YES;
    if (kind != MobaProfileStoreItemKindRegularFile) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorDestinationConflict
                               operation:@"remove"
                            relativePath:relativePath
                          underlyingError:inspectionError
                              description:@"Only a regular profile file can be removed."];
        }
        return NO;
    }
    NSError *removeError = nil;
    if (![_fileManager removeItemAtURL:destinationURL error:&removeError]) {
        if (error != NULL) {
            *error = [self errorWithCode:MobaProfileStoreErrorRemoveFailed
                               operation:@"remove"
                            relativePath:relativePath
                          underlyingError:removeError
                              description:@"Unable to remove the profile file during rollback."];
        }
        return NO;
    }
    return YES;
}

@end
