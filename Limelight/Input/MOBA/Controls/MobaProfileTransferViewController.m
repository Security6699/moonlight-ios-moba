//
//  MobaProfileTransferViewController.m
//  Moonlight
//

#import "MobaProfileTransferViewController.h"

@interface MobaProfileTransferViewController ()
@property (nonatomic, strong, readwrite, nullable) MobaProfileImportPlan *pendingImportPlan;
@property (nonatomic, copy, readwrite) NSString *activeChampionRelativePath;
@property (nonatomic, copy, readwrite, nullable) NSString *lastStatusMessage;
@property (nonatomic, strong, readwrite, nullable) NSURL *temporaryExportURL;
@end

@implementation MobaProfileTransferViewController {
    MobaProfileTransferService *_transferService;
    MobaProfileImportTransaction *_importTransaction;
    UILabel *_statusLabel;
    UIStackView *_stackView;
    BOOL _exportPickerActive;
}

- (instancetype)initWithTransferService:(MobaProfileTransferService *)transferService
                        importTransaction:(MobaProfileImportTransaction *)importTransaction
               activeChampionRelativePath:(NSString *)activeChampionRelativePath {
    if (transferService == nil || importTransaction == nil || activeChampionRelativePath.length == 0) return nil;
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _transferService = transferService;
        _importTransaction = importTransaction;
        _activeChampionRelativePath = [activeChampionRelativePath copy];
        self.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    return self;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 14, 10, 14);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"MOBA Profiles";
    _stackView = [[UIStackView alloc] init];
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = 10;
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_stackView];
    [_stackView addArrangedSubview:[self buttonWithTitle:@"Import JSON" action:@selector(importTapped)]];
    NSArray *exports = @[
        @[@"Export Runtime", MobaProfileKindRuntime],
        @[@"Export Input", MobaProfileKindInput],
        @[@"Export Layout", MobaProfileKindLayout],
        @[@"Export Active Champion", MobaProfileKindChampion],
    ];
    for (NSArray *entry in exports) {
        UIButton *button = [self buttonWithTitle:entry[0] action:@selector(exportTapped:)];
        button.accessibilityIdentifier = entry[1];
        [_stackView addArrangedSubview:button];
    }
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.numberOfLines = 0;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_stackView addArrangedSubview:_statusLabel];
    [_stackView addArrangedSubview:[self buttonWithTitle:@"Close" action:@selector(closeTapped)]];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_stackView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [_stackView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [_stackView.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
    ]];
}

- (void)setStatus:(NSString *)message error:(BOOL)isError {
    self.lastStatusMessage = message;
    _statusLabel.text = message;
    _statusLabel.textColor = isError ? UIColor.systemRedColor : UIColor.labelColor;
}

- (NSString *)messageForError:(NSError *)error {
    NSString *kind = error.userInfo[MobaProfileErrorProfileKindKey];
    NSString *path = error.userInfo[MobaProfileErrorFieldPathKey];
    NSString *operation = error.userInfo[MobaProfileErrorOperationKey];
    NSMutableArray *parts = [NSMutableArray array];
    if (kind.length > 0) [parts addObject:[NSString stringWithFormat:@"Type: %@", kind]];
    if (path.length > 0) [parts addObject:[NSString stringWithFormat:@"Path: %@", path]];
    if (operation.length > 0) [parts addObject:[NSString stringWithFormat:@"Operation: %@", operation]];
    if (error.localizedDescription.length > 0) [parts addObject:error.localizedDescription];
    return [parts componentsJoinedByString:@"\n"];
}

- (MobaProfileImportPlan *)prepareImportFromData:(NSData *)data
                                   sourceFileName:(NSString *)sourceFileName
                                            error:(NSError **)error {
    (void)sourceFileName;
    self.pendingImportPlan = [_transferService prepareImportPlanForData:data
        activeChampionRelativePath:self.activeChampionRelativePath error:error];
    return self.pendingImportPlan;
}

- (MobaProfileImportResult *)confirmPendingImportWithError:(NSError **)error {
    if (self.pendingImportPlan == nil) return nil;
    MobaProfileImportResult *result = [_importTransaction applyImportPlan:self.pendingImportPlan error:error];
    if (result != nil) {
        self.activeChampionRelativePath = result.activeChampionRelativePath;
        self.pendingImportPlan = nil;
        [self.delegate mobaProfileTransferViewController:self
                            didImportActiveChampionPath:self.activeChampionRelativePath];
    }
    return result;
}

- (void)cancelPendingTransfer {
    self.pendingImportPlan = nil;
    [self cleanupTemporaryExport];
}

- (NSURL *)prepareTemporaryExportForProfileKind:(MobaProfileKind)profileKind error:(NSError **)error {
    [self cleanupTemporaryExport];
    MobaProfileExportPayload *payload = [_transferService exportPayloadForProfileKind:profileKind
        activeChampionRelativePath:self.activeChampionRelativePath error:error];
    if (payload == nil) return nil;
    NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"MobaProfileExport-%@", NSUUID.UUID.UUIDString]
        isDirectory:YES];
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory
        withIntermediateDirectories:NO attributes:nil error:&directoryError]) {
        if (error != NULL) *error = directoryError;
        return nil;
    }
    NSURL *url = [directory URLByAppendingPathComponent:payload.fileName isDirectory:NO];
    NSError *writeError = nil;
    if (![payload.data writeToURL:url options:NSDataWritingAtomic error:&writeError]) {
        [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
        if (error != NULL) *error = writeError;
        return nil;
    }
    self.temporaryExportURL = url;
    return url;
}

- (void)cleanupTemporaryExport {
    NSURL *url = self.temporaryExportURL;
    self.temporaryExportURL = nil;
    if (url != nil) [NSFileManager.defaultManager removeItemAtURL:url.URLByDeletingLastPathComponent error:nil];
}

- (void)importTapped {
    _exportPickerActive = NO;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:@[@"public.json"]
        inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)exportTapped:(UIButton *)sender {
    NSError *error = nil;
    NSURL *url = [self prepareTemporaryExportForProfileKind:sender.accessibilityIdentifier error:&error];
    if (url == nil) {
        [self setStatus:[self messageForError:error] error:YES];
        return;
    }
    _exportPickerActive = YES;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initWithURL:url inMode:UIDocumentPickerModeExportToService];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (NSData *)coordinatedDataAtURL:(NSURL *)url error:(NSError **)error {
    __block NSData *data = nil;
    __block NSError *readError = nil;
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&readError byAccessor:^(NSURL *newURL) {
        data = [NSData dataWithContentsOfURL:newURL options:NSDataReadingMappedIfSafe error:&readError];
    }];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (data == nil && error != NULL) *error = readError;
    return data;
}

- (void)showConfirmationForPlan:(MobaProfileImportPlan *)plan {
    NSString *message = [plan.summaryLines componentsJoinedByString:@"\n"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Profile"
        message:message preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [weakSelf cancelPendingTransfer];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Import and Replace"
        style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSError *error = nil;
        MobaProfileImportResult *result = [weakSelf confirmPendingImportWithError:&error];
        if (result == nil) [weakSelf setStatus:[weakSelf messageForError:error] error:YES];
        else [weakSelf setStatus:[NSString stringWithFormat:@"Imported. Backup: %@", result.backupRelativePath]
                             error:NO];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
  didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (_exportPickerActive) {
        _exportPickerActive = NO;
        [self cleanupTemporaryExport];
        [self setStatus:@"Export completed" error:NO];
        return;
    }
    NSURL *url = urls.firstObject;
    NSError *error = nil;
    NSData *data = url == nil ? nil : [self coordinatedDataAtURL:url error:&error];
    MobaProfileImportPlan *plan = data == nil ? nil
        : [self prepareImportFromData:data sourceFileName:url.lastPathComponent error:&error];
    if (plan == nil) {
        [self setStatus:[self messageForError:error] error:YES];
        return;
    }
    [self showConfirmationForPlan:plan];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
       didPickDocumentAtURL:(NSURL *)url {
    [self documentPicker:controller didPickDocumentsAtURLs:url == nil ? @[] : @[url]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    (void)controller;
    _exportPickerActive = NO;
    [self cancelPendingTransfer];
}

- (void)closeTapped {
    [self cancelPendingTransfer];
    [self.delegate mobaProfileTransferViewControllerDidRequestClose:self];
}

- (void)dealloc {
    [self cleanupTemporaryExport];
}

@end
