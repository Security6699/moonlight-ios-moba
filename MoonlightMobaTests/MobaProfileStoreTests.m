//
//  MobaProfileStoreTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>
#import "../Limelight/Input/MOBA/Profiles/MobaProfileStore.h"

@interface MobaFakeProfileResourceProvider : NSObject <MobaProfileResourceProviding>
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *resourceURLs;
@end

@implementation MobaFakeProfileResourceProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _resourceURLs = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)extension {
    return self.resourceURLs[[name stringByAppendingPathExtension:extension]];
}

@end

@interface MobaFakeAtomicWriter : NSObject <MobaProfileAtomicWriting>
@property (nonatomic) NSUInteger writeCount;
@property (nonatomic) BOOL lastReplaceExisting;
@property (nonatomic) BOOL failNextWrite;
@property (nonatomic, copy, nullable) NSString *failingPathSuffix;
@end

@implementation MobaFakeAtomicWriter

- (BOOL)writeData:(NSData *)data
             toURL:(NSURL *)url
   replaceExisting:(BOOL)replaceExisting
             error:(NSError **)error {
    self.writeCount += 1;
    self.lastReplaceExisting = replaceExisting;
    BOOL shouldFail = self.failNextWrite ||
        (self.failingPathSuffix != nil && [url.path hasSuffix:self.failingPathSuffix]);
    self.failNextWrite = NO;
    if (shouldFail) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"MobaFakeAtomicWriter"
                                         code:7
                                     userInfo:@{NSLocalizedDescriptionKey: @"Injected atomic write failure"}];
        }
        return NO;
    }
    if (!replaceExisting && [NSFileManager.defaultManager fileExistsAtPath:url.path]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError userInfo:nil];
        }
        return NO;
    }
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

@end

@interface MobaProfileStoreTests : XCTestCase
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSURL *temporaryContainerURL;
@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) NSURL *resourceDirectoryURL;
@property (nonatomic, strong) MobaFakeProfileResourceProvider *resourceProvider;
@property (nonatomic, strong) MobaFakeAtomicWriter *atomicWriter;
@property (nonatomic, strong) MobaProfileStore *store;
@end

@implementation MobaProfileStoreTests

- (void)setUp {
    [super setUp];
    self.fileManager = [[NSFileManager alloc] init];
    NSString *uniqueName = [NSString stringWithFormat:@"MobaProfileStoreTests-%@", NSUUID.UUID.UUIDString];
    self.temporaryContainerURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:uniqueName isDirectory:YES];
    self.rootURL = [self.temporaryContainerURL URLByAppendingPathComponent:@"MOBA" isDirectory:YES];
    self.resourceDirectoryURL = [self.temporaryContainerURL URLByAppendingPathComponent:@"Bundle" isDirectory:YES];
    XCTAssertTrue([self.fileManager createDirectoryAtURL:self.resourceDirectoryURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil]);

    self.resourceProvider = [[MobaFakeProfileResourceProvider alloc] init];
    for (NSString *fileName in @[
        @"runtime.json",
        @"input.json",
        @"ipad-pro-13-layout.json",
        @"caitlyn.json",
        @"debug-instant.json",
    ]) {
        NSData *data = [[NSString stringWithFormat:@"bundled:%@", fileName]
            dataUsingEncoding:NSUTF8StringEncoding];
        NSURL *url = [self.resourceDirectoryURL URLByAppendingPathComponent:fileName];
        XCTAssertTrue([data writeToURL:url options:NSDataWritingAtomic error:nil]);
        self.resourceProvider.resourceURLs[fileName] = url;
    }

    self.atomicWriter = [[MobaFakeAtomicWriter alloc] init];
    self.store = [[MobaProfileStore alloc] initWithRootDirectoryURL:self.rootURL
                                                  resourceProvider:self.resourceProvider
                                                       fileManager:self.fileManager
                                                      atomicWriter:self.atomicWriter];
}

- (void)tearDown {
    [self.fileManager removeItemAtURL:self.temporaryContainerURL error:nil];
    [super tearDown];
}

- (NSData *)dataForString:(NSString *)string {
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSURL *)URLForRelativePath:(NSString *)relativePath {
    return [self.rootURL URLByAppendingPathComponent:relativePath];
}

- (NSData *)dataAtRelativePath:(NSString *)relativePath {
    return [NSData dataWithContentsOfURL:[self URLForRelativePath:relativePath]];
}

- (void)createParentForRelativePath:(NSString *)relativePath {
    NSURL *parentURL = [[self URLForRelativePath:relativePath] URLByDeletingLastPathComponent];
    XCTAssertTrue([self.fileManager createDirectoryAtURL:parentURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil]);
}

- (void)installData:(NSData *)data atRelativePath:(NSString *)relativePath {
    [self createParentForRelativePath:relativePath];
    XCTAssertTrue([data writeToURL:[self URLForRelativePath:relativePath]
                           options:NSDataWritingAtomic
                             error:nil]);
}

- (void)assertRegularFileExistsAtRelativePath:(NSString *)relativePath {
    BOOL isDirectory = NO;
    XCTAssertTrue([self.fileManager fileExistsAtPath:[self URLForRelativePath:relativePath].path
                                         isDirectory:&isDirectory]);
    XCTAssertFalse(isDirectory);
}

- (void)testDefaultResourceManifestMatchesActualExampleFileNames {
    NSArray<MobaProfileDefaultResource *> *manifest = MobaProfileStore.defaultResourceManifest;
    XCTAssertEqual(manifest.count, 5u);

    NSMutableArray<NSString *> *descriptions = [NSMutableArray array];
    for (MobaProfileDefaultResource *resource in manifest) {
        [descriptions addObject:[NSString stringWithFormat:@"%@.%@|%@|%@",
                                 resource.bundleResourceName,
                                 resource.bundleResourceExtension,
                                 resource.destinationRelativePath,
                                 resource.seedsActiveLayout ? @"active" : @"single"]];
    }
    XCTAssertEqualObjects(descriptions, (@[
        @"runtime.json|runtime.json|single",
        @"input.json|input.json|single",
        @"ipad-pro-13-layout.json|layouts/ipad-pro-13-layout.json|active",
        @"caitlyn.json|champions/caitlyn.json|single",
        @"debug-instant.json|champions/debug-instant.json|single",
    ]));
}

- (void)testFirstBootstrapCreatesCompleteDirectoryStructure {
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    for (NSString *relativePath in @[@".", @"layouts", @"champions", @"backups"]) {
        NSURL *url = [relativePath isEqualToString:@"."] ? self.rootURL : [self URLForRelativePath:relativePath];
        BOOL isDirectory = NO;
        XCTAssertTrue([self.fileManager fileExistsAtPath:url.path isDirectory:&isDirectory]);
        XCTAssertTrue(isDirectory);
    }
}

- (void)testFirstBootstrapCopiesEveryManifestDefault {
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    for (NSString *relativePath in @[
        @"runtime.json",
        @"input.json",
        @"layouts/ipad-pro-13-layout.json",
        @"champions/caitlyn.json",
        @"champions/debug-instant.json",
    ]) {
        [self assertRegularFileExistsAtRelativePath:relativePath];
    }
}

- (void)testLayoutSeedsStoredLayoutAndActiveLayoutWithIdenticalBytes {
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    NSData *expected = [self dataForString:@"bundled:ipad-pro-13-layout.json"];
    XCTAssertEqualObjects([self dataAtRelativePath:@"layouts/ipad-pro-13-layout.json"], expected);
    XCTAssertEqualObjects([self dataAtRelativePath:@"active-layout.json"], expected);
}

- (void)testSecondBootstrapIsIdempotentWithoutWritesOrMtimeChanges {
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    NSUInteger firstWriteCount = self.atomicWriter.writeCount;
    NSURL *runtimeURL = [self URLForRelativePath:@"runtime.json"];
    NSDate *firstModificationDate = [self.fileManager attributesOfItemAtPath:runtimeURL.path error:nil][NSFileModificationDate];
    NSData *firstData = [NSData dataWithContentsOfURL:runtimeURL];

    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);

    NSDate *secondModificationDate = [self.fileManager attributesOfItemAtPath:runtimeURL.path error:nil][NSFileModificationDate];
    XCTAssertEqual(self.atomicWriter.writeCount, firstWriteCount);
    XCTAssertEqualObjects([NSData dataWithContentsOfURL:runtimeURL], firstData);
    XCTAssertEqualObjects(secondModificationDate, firstModificationDate);
}

- (void)testExistingRuntimeIsPreservedByteForByte {
    NSData *userData = [self dataForString:@"user-runtime"];
    [self installData:userData atRelativePath:@"runtime.json"];
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"runtime.json"], userData);
}

- (void)testExistingInputIsNotOverwritten {
    NSData *userData = [self dataForString:@"user-input"];
    [self installData:userData atRelativePath:@"input.json"];
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"input.json"], userData);
}

- (void)testExistingActiveLayoutIsNotOverwritten {
    NSData *userData = [self dataForString:@"user-active-layout"];
    [self installData:userData atRelativePath:@"active-layout.json"];
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"active-layout.json"], userData);
    XCTAssertEqualObjects([self dataAtRelativePath:@"layouts/ipad-pro-13-layout.json"],
                          [self dataForString:@"bundled:ipad-pro-13-layout.json"]);
}

- (void)testExistingStoredLayoutDoesNotPreventMissingActiveLayoutSeed {
    NSData *userData = [self dataForString:@"user-stored-layout"];
    [self installData:userData atRelativePath:@"layouts/ipad-pro-13-layout.json"];
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"layouts/ipad-pro-13-layout.json"], userData);
    XCTAssertEqualObjects([self dataAtRelativePath:@"active-layout.json"],
                          [self dataForString:@"bundled:ipad-pro-13-layout.json"]);
}

- (void)testExistingChampionIsNotOverwritten {
    NSData *userData = [self dataForString:@"user-caitlyn"];
    [self installData:userData atRelativePath:@"champions/caitlyn.json"];
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"champions/caitlyn.json"], userData);
}

- (void)testPartialInstallationOnlyFillsMissingFiles {
    NSData *runtimeData = [self dataForString:@"installed-runtime"];
    NSData *championData = [self dataForString:@"installed-caitlyn"];
    [self installData:runtimeData atRelativePath:@"runtime.json"];
    [self installData:championData atRelativePath:@"champions/caitlyn.json"];

    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);

    XCTAssertEqual(self.atomicWriter.writeCount, 4u);
    XCTAssertEqualObjects([self dataAtRelativePath:@"runtime.json"], runtimeData);
    XCTAssertEqualObjects([self dataAtRelativePath:@"champions/caitlyn.json"], championData);
    [self assertRegularFileExistsAtRelativePath:@"input.json"];
    [self assertRegularFileExistsAtRelativePath:@"active-layout.json"];
    [self assertRegularFileExistsAtRelativePath:@"layouts/ipad-pro-13-layout.json"];
    [self assertRegularFileExistsAtRelativePath:@"champions/debug-instant.json"];
}

- (void)testMissingBundledResourceReturnsErrorButKeepsOtherSuccessfulSeeds {
    [self.resourceProvider.resourceURLs removeObjectForKey:@"input.json"];
    NSError *error = nil;
    XCTAssertFalse([self.store bootstrapDefaultsWithError:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorResourceMissing);
    XCTAssertFalse([self.fileManager fileExistsAtPath:[self URLForRelativePath:@"input.json"].path]);
    [self assertRegularFileExistsAtRelativePath:@"runtime.json"];
    [self assertRegularFileExistsAtRelativePath:@"active-layout.json"];
    [self assertRegularFileExistsAtRelativePath:@"champions/caitlyn.json"];
    [self assertRegularFileExistsAtRelativePath:@"champions/debug-instant.json"];
}

- (void)testDestinationDirectoryConflictFailsNonfatallyAndPreservesDirectory {
    NSURL *conflictURL = [self URLForRelativePath:@"runtime.json"];
    XCTAssertTrue([self.fileManager createDirectoryAtURL:conflictURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil]);
    NSError *error = nil;
    XCTAssertFalse([self.store bootstrapDefaultsWithError:&error]);
    BOOL isDirectory = NO;
    XCTAssertTrue([self.fileManager fileExistsAtPath:conflictURL.path isDirectory:&isDirectory]);
    XCTAssertTrue(isDirectory);
    [self assertRegularFileExistsAtRelativePath:@"input.json"];
}

- (void)testParentPathOccupiedByFileFailsSafelyAndPreservesFile {
    NSData *blockingData = [self dataForString:@"blocking-layouts-file"];
    [self installData:blockingData atRelativePath:@"layouts"];
    NSError *error = nil;
    XCTAssertFalse([self.store bootstrapDefaultsWithError:&error]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"layouts"], blockingData);
    [self assertRegularFileExistsAtRelativePath:@"runtime.json"];
}

- (void)testAtomicWriteThenReadReturnsIdenticalBytes {
    NSData *expected = [self dataForString:@"complete-binary-data"];
    MobaProfileStore *productionStore = [[MobaProfileStore alloc]
        initWithRootDirectoryURL:self.rootURL
                resourceProvider:self.resourceProvider
                     fileManager:self.fileManager];
    XCTAssertTrue([productionStore writeData:expected
                              toRelativePath:@"custom/nested/data.bin"
                             replaceExisting:NO
                                       error:nil]);
    XCTAssertEqualObjects([productionStore readDataAtRelativePath:@"custom/nested/data.bin" error:nil], expected);
}

- (void)testReplaceExistingNoPreservesOldData {
    NSData *oldData = [self dataForString:@"old"];
    NSData *newData = [self dataForString:@"new"];
    MobaProfileStore *productionStore = [[MobaProfileStore alloc]
        initWithRootDirectoryURL:self.rootURL
                resourceProvider:self.resourceProvider
                     fileManager:self.fileManager];
    XCTAssertTrue([productionStore writeData:oldData toRelativePath:@"runtime.json" replaceExisting:NO error:nil]);
    NSError *error = nil;
    XCTAssertFalse([productionStore writeData:newData toRelativePath:@"runtime.json" replaceExisting:NO error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorDestinationExists);
    XCTAssertEqualObjects([self dataAtRelativePath:@"runtime.json"], oldData);
}

- (void)testReplaceExistingYesAtomicallyReplacesWithNewData {
    NSData *oldData = [self dataForString:@"old"];
    NSData *newData = [self dataForString:@"new-complete-data"];
    MobaProfileStore *productionStore = [[MobaProfileStore alloc]
        initWithRootDirectoryURL:self.rootURL
                resourceProvider:self.resourceProvider
                     fileManager:self.fileManager];
    XCTAssertTrue([productionStore writeData:oldData toRelativePath:@"runtime.json" replaceExisting:NO error:nil]);
    XCTAssertTrue([productionStore writeData:newData toRelativePath:@"runtime.json" replaceExisting:YES error:nil]);
    XCTAssertEqualObjects([self dataAtRelativePath:@"runtime.json"], newData);
}

- (void)testInjectedReplacementFailureKeepsOldFileIntact {
    NSData *oldData = [self dataForString:@"old-intact"];
    XCTAssertTrue([self.store writeData:oldData toRelativePath:@"runtime.json" replaceExisting:NO error:nil]);
    self.atomicWriter.failNextWrite = YES;
    NSError *error = nil;
    XCTAssertFalse([self.store writeData:[self dataForString:@"new"]
                          toRelativePath:@"runtime.json"
                         replaceExisting:YES
                                   error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorWriteFailed);
    XCTAssertEqualObjects([self dataAtRelativePath:@"runtime.json"], oldData);
}

- (void)testAbsolutePathIsRejected {
    NSError *error = nil;
    XCTAssertFalse([self.store writeData:[self dataForString:@"x"]
                          toRelativePath:@"/tmp/outside.json"
                         replaceExisting:YES
                                   error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorInvalidPath);
}

- (void)testParentTraversalIsRejected {
    NSError *error = nil;
    XCTAssertNil([self.store readDataAtRelativePath:@"../Documents/config.json" error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorInvalidPath);
}

- (void)testResolvedSymlinkEscapeIsRejected {
    XCTAssertTrue([self.fileManager createDirectoryAtURL:self.rootURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil]);
    NSURL *outsideURL = [self.temporaryContainerURL URLByAppendingPathComponent:@"Outside" isDirectory:YES];
    XCTAssertTrue([self.fileManager createDirectoryAtURL:outsideURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil]);
    NSURL *linkURL = [self.rootURL URLByAppendingPathComponent:@"escape" isDirectory:YES];
    XCTAssertTrue([self.fileManager createSymbolicLinkAtURL:linkURL withDestinationURL:outsideURL error:nil]);

    NSError *error = nil;
    XCTAssertFalse([self.store writeData:[self dataForString:@"x"]
                          toRelativePath:@"escape/outside.json"
                         replaceExisting:YES
                                   error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorInvalidPath);
    XCTAssertFalse([self.fileManager fileExistsAtPath:[outsideURL URLByAppendingPathComponent:@"outside.json"].path]);
}

- (void)testEmptyDotAndRootPathsAreRejected {
    for (NSString *path in @[@"", @".", @"folder/./file.json", @"folder//file.json"]) {
        NSError *error = nil;
        XCTAssertNil([self.store readDataAtRelativePath:path error:&error]);
        XCTAssertEqual(error.code, MobaProfileStoreErrorInvalidPath);
    }
}

- (void)testNilDataAndNonStringPathAreRejected {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSError *nilDataError = nil;
    XCTAssertFalse([self.store writeData:nil
                          toRelativePath:@"runtime.json"
                         replaceExisting:YES
                                   error:&nilDataError]);
    NSError *pathError = nil;
    XCTAssertNil([self.store readDataAtRelativePath:(NSString *)(id)@42 error:&pathError]);
#pragma clang diagnostic pop
    XCTAssertEqual(nilDataError.code, MobaProfileStoreErrorWriteFailed);
    XCTAssertEqual(pathError.code, MobaProfileStoreErrorInvalidPath);
}

- (void)testRepeatedFailureCanBeRetriedAfterResourceAppears {
    NSURL *inputURL = self.resourceProvider.resourceURLs[@"input.json"];
    [self.resourceProvider.resourceURLs removeObjectForKey:@"input.json"];
    XCTAssertFalse([self.store bootstrapDefaultsWithError:nil]);
    NSData *runtimeBeforeRetry = [self dataAtRelativePath:@"runtime.json"];
    NSUInteger writesBeforeRetry = self.atomicWriter.writeCount;

    self.resourceProvider.resourceURLs[@"input.json"] = inputURL;
    XCTAssertTrue([self.store bootstrapDefaultsWithError:nil]);
    XCTAssertEqual(self.atomicWriter.writeCount, writesBeforeRetry + 1);
    XCTAssertEqualObjects([self dataAtRelativePath:@"runtime.json"], runtimeBeforeRetry);
    [self assertRegularFileExistsAtRelativePath:@"input.json"];
}

- (void)testStoreDoesNotParseOrValidateJSONBytes {
    NSData *arbitraryData = [NSData dataWithBytes:(uint8_t[]){0x00, 0xFF, 0x01, 0x7B} length:4];
    XCTAssertTrue([self.store writeData:arbitraryData
                         toRelativePath:@"champions/arbitrary.bin"
                        replaceExisting:NO
                                  error:nil]);
    XCTAssertEqualObjects([self.store readDataAtRelativePath:@"champions/arbitrary.bin" error:nil], arbitraryData);
}

- (void)testFeatureDisabledBootstrapDoesNotCreateMobaDirectoryOrReadResources {
    [self.resourceProvider.resourceURLs removeAllObjects];
    XCTAssertTrue([self.store bootstrapDefaultsIfFeatureEnabled:NO error:nil]);
    XCTAssertFalse([self.fileManager fileExistsAtPath:self.rootURL.path]);
    XCTAssertEqual(self.atomicWriter.writeCount, 0u);
}

- (void)testBootstrapFailureIsNonfatalAndCallerCanContinueInitialization {
    [self.resourceProvider.resourceURLs removeAllObjects];
    __block BOOL bootstrapResult = YES;
    XCTAssertNoThrow(bootstrapResult = [self.store bootstrapDefaultsIfFeatureEnabled:YES error:nil]);
    XCTAssertFalse(bootstrapResult);

    BOOL ordinaryInitializationContinued = YES;
    XCTAssertTrue(ordinaryInitializationContinued);
}

- (void)testOneInjectedSeedWriteFailureDoesNotRemoveOtherSuccessfulFiles {
    self.atomicWriter.failingPathSuffix = @"input.json";
    NSError *error = nil;
    XCTAssertFalse([self.store bootstrapDefaultsWithError:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorWriteFailed);
    XCTAssertFalse([self.fileManager fileExistsAtPath:[self URLForRelativePath:@"input.json"].path]);
    [self assertRegularFileExistsAtRelativePath:@"runtime.json"];
    [self assertRegularFileExistsAtRelativePath:@"active-layout.json"];
    [self assertRegularFileExistsAtRelativePath:@"champions/caitlyn.json"];
    [self assertRegularFileExistsAtRelativePath:@"champions/debug-instant.json"];
}

- (void)testErrorsContainOperationAndRelatedRelativePath {
    NSError *error = nil;
    XCTAssertNil([self.store readDataAtRelativePath:@"../outside" error:&error]);
    XCTAssertEqualObjects(error.domain, MobaProfileStoreErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MobaProfileStoreErrorOperationKey], @"validate-path");
    XCTAssertEqualObjects(error.userInfo[MobaProfileStoreErrorRelativePathKey], @"../outside");
}

- (void)testBundledDefaultReadByDestinationDoesNotReadWritableProfile {
    NSData *expected = [self dataForString:@"bundled:ipad-pro-13-layout.json"];
    XCTAssertEqualObjects([self.store
        readBundledDefaultDataForDestinationRelativePath:@"active-layout.json" error:nil], expected);
    XCTAssertFalse([self.fileManager fileExistsAtPath:self.rootURL.path]);
    XCTAssertEqual(self.atomicWriter.writeCount, 0u);
}

- (void)testUnknownBundledDefaultDestinationReturnsResourceError {
    NSError *error = nil;
    XCTAssertNil([self.store readBundledDefaultDataForDestinationRelativePath:@"future.json" error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorResourceMissing);
    XCTAssertEqualObjects(error.userInfo[MobaProfileStoreErrorRelativePathKey], @"future.json");
}

- (void)testDataExistsReturnsFalseForMissingSafePathWithoutCreatingRoot {
    NSError *error = nil;
    XCTAssertFalse([self.store dataExistsAtRelativePath:@"champions/missing.json" error:&error]);
    XCTAssertNil(error);
    XCTAssertFalse([self.fileManager fileExistsAtPath:self.rootURL.path]);
}

- (void)testDataExistsReturnsTrueForRegularFile {
    XCTAssertTrue([self.store writeData:[self dataForString:@"profile"]
                         toRelativePath:@"champions/imported.json" replaceExisting:NO error:nil]);
    XCTAssertTrue([self.store dataExistsAtRelativePath:@"champions/imported.json" error:nil]);
}

- (void)testDataExistsRejectsTraversal {
    NSError *error = nil;
    XCTAssertFalse([self.store dataExistsAtRelativePath:@"../outside.json" error:&error]);
    XCTAssertEqual(error.code, MobaProfileStoreErrorInvalidPath);
}

- (void)testRemoveDataDeletesOnlyRequestedRegularFile {
    XCTAssertTrue([self.store writeData:[self dataForString:@"profile"]
                         toRelativePath:@"champions/imported.json" replaceExisting:NO error:nil]);
    XCTAssertTrue([self.store removeDataAtRelativePath:@"champions/imported.json" error:nil]);
    XCTAssertFalse([self.fileManager fileExistsAtPath:[self URLForRelativePath:@"champions/imported.json"].path]);
}

- (void)testRemoveMissingDataIsIdempotent {
    XCTAssertTrue([self.store removeDataAtRelativePath:@"champions/missing.json" error:nil]);
    XCTAssertTrue([self.store removeDataAtRelativePath:@"champions/missing.json" error:nil]);
}

- (void)testRemoveDataRejectsDirectoryAndTraversal {
    XCTAssertTrue([self.fileManager createDirectoryAtURL:[self URLForRelativePath:@"champions/occupied.json"]
                              withIntermediateDirectories:YES attributes:nil error:nil]);
    NSError *directoryError = nil;
    XCTAssertFalse([self.store removeDataAtRelativePath:@"champions/occupied.json" error:&directoryError]);
    XCTAssertEqual(directoryError.code, MobaProfileStoreErrorDestinationConflict);
    NSError *pathError = nil;
    XCTAssertFalse([self.store removeDataAtRelativePath:@"../outside.json" error:&pathError]);
    XCTAssertEqual(pathError.code, MobaProfileStoreErrorInvalidPath);
}

@end
