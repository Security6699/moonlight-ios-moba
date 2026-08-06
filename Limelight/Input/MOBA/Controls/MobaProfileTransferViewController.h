//
//  MobaProfileTransferViewController.h
//  Moonlight
//

#import <UIKit/UIKit.h>

#import "../Profiles/MobaProfileImportTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@class MobaProfileTransferViewController;
@protocol MobaProfileTransferViewControllerDelegate <NSObject>
- (void)mobaProfileTransferViewControllerDidRequestClose:(MobaProfileTransferViewController *)controller;
- (void)mobaProfileTransferViewController:(MobaProfileTransferViewController *)controller
              didImportActiveChampionPath:(NSString *)activeChampionRelativePath;
@end

@interface MobaProfileTransferViewController : UIViewController <UIDocumentPickerDelegate>

@property (nonatomic, weak, nullable) id<MobaProfileTransferViewControllerDelegate> delegate;
@property (nonatomic, strong, readonly, nullable) MobaProfileImportPlan *pendingImportPlan;
@property (nonatomic, copy, readonly) NSString *activeChampionRelativePath;
@property (nonatomic, copy, readonly, nullable) NSString *lastStatusMessage;
@property (nonatomic, strong, readonly, nullable) NSURL *temporaryExportURL;

- (nullable instancetype)initWithTransferService:(MobaProfileTransferService *)transferService
                                importTransaction:(MobaProfileImportTransaction *)importTransaction
                       activeChampionRelativePath:(NSString *)activeChampionRelativePath NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

// Deterministic seams used after coordinated URL reads and by XCTest.
- (nullable MobaProfileImportPlan *)prepareImportFromData:(NSData *)data
                                           sourceFileName:(nullable NSString *)sourceFileName
                                                    error:(NSError **)error;
- (nullable MobaProfileImportResult *)confirmPendingImportWithError:(NSError **)error;
- (void)cancelPendingTransfer;
- (nullable NSURL *)prepareTemporaryExportForProfileKind:(MobaProfileKind)profileKind
                                                    error:(NSError **)error;
- (void)cleanupTemporaryExport;

@end
NS_ASSUME_NONNULL_END
