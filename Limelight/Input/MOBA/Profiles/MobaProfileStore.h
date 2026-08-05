//
//  MobaProfileStore.h
//  Moonlight
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MobaProfileStoreErrorDomain;
FOUNDATION_EXPORT NSString *const MobaProfileStoreErrorOperationKey;
FOUNDATION_EXPORT NSString *const MobaProfileStoreErrorRelativePathKey;

typedef NS_ERROR_ENUM(MobaProfileStoreErrorDomain, MobaProfileStoreErrorCode) {
    MobaProfileStoreErrorApplicationSupportUnavailable = 1,
    MobaProfileStoreErrorInvalidPath,
    MobaProfileStoreErrorDirectoryCreationFailed,
    MobaProfileStoreErrorResourceMissing,
    MobaProfileStoreErrorResourceReadFailed,
    MobaProfileStoreErrorDestinationConflict,
    MobaProfileStoreErrorDestinationExists,
    MobaProfileStoreErrorReadFailed,
    MobaProfileStoreErrorWriteFailed,
};

@protocol MobaProfileResourceProviding <NSObject>

- (nullable NSURL *)URLForResource:(NSString *)name
                     withExtension:(nullable NSString *)extension;

@end

@protocol MobaProfileAtomicWriting <NSObject>

- (BOOL)writeData:(NSData *)data
             toURL:(NSURL *)url
           options:(NSDataWritingOptions)options
             error:(NSError **)error;

@end

@interface MobaProfileDefaultResource : NSObject

@property (nonatomic, copy, readonly) NSString *bundleResourceName;
@property (nonatomic, copy, readonly) NSString *bundleResourceExtension;
@property (nonatomic, copy, readonly) NSString *destinationRelativePath;
@property (nonatomic, readonly) BOOL seedsActiveLayout;

@end


// Owns only the MOBA directory structure, bundled-default seeding, and atomic
// byte I/O. It intentionally does not parse or validate JSON.
@interface MobaProfileStore : NSObject

@property (class, nonatomic, readonly) NSArray<MobaProfileDefaultResource *> *defaultResourceManifest;
@property (nonatomic, strong, readonly, nullable) NSURL *rootDirectoryURL;

// Production convenience initializer. Resolves <Application Support>/MOBA
// without creating it. Creation happens only when bootstrap is explicitly run.
- (instancetype)init;

- (instancetype)initWithRootDirectoryURL:(NSURL *)rootDirectoryURL
                         resourceProvider:(id<MobaProfileResourceProviding>)resourceProvider
                              fileManager:(NSFileManager *)fileManager
                             atomicWriter:(id<MobaProfileAtomicWriting>)atomicWriter NS_DESIGNATED_INITIALIZER;

// This seam keeps the no-op disabled path directly testable. When disabled it
// does not validate, create, read, or write anything beneath the root URL.
- (BOOL)bootstrapDefaultsIfFeatureEnabled:(BOOL)featureEnabled
                                    error:(NSError **)error;

// Safe to retry. Existing regular files are preserved byte-for-byte.
- (BOOL)bootstrapDefaultsWithError:(NSError **)error;

- (nullable NSData *)readDataAtRelativePath:(NSString *)relativePath
                                      error:(NSError **)error;

- (BOOL)writeData:(NSData *)data
    toRelativePath:(NSString *)relativePath
   replaceExisting:(BOOL)replaceExisting
             error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
