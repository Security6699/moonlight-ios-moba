//
//  MobaChampionSelectorViewTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Controls/MobaChampionSelectorView.h"

@interface MobaSelectorDelegate : NSObject <MobaChampionSelectorViewDelegate>
@property (nonatomic) BOOL acceptsSelection;
@property (nonatomic, strong) NSMutableArray<NSString *> *requestedChampionIDs;
@end
@implementation MobaSelectorDelegate
- (instancetype)init { self = [super init]; if (self) { _acceptsSelection = YES; _requestedChampionIDs = [NSMutableArray array]; } return self; }
- (BOOL)mobaChampionSelectorView:(MobaChampionSelectorView *)selectorView
               requestChampionID:(NSString *)championID
                            error:(NSError **)error {
    (void)selectorView;
    [self.requestedChampionIDs addObject:championID];
    if (!self.acceptsSelection && error != NULL) {
        *error = [NSError errorWithDomain:@"MobaSelectorTest" code:1 userInfo:nil];
    }
    return self.acceptsSelection;
}
@end

@interface MobaChampionSelectorViewTests : XCTestCase
@property (nonatomic, strong) MobaChampionSelectorView *view;
@property (nonatomic, strong) MobaSelectorDelegate *delegate;
@end

@implementation MobaChampionSelectorViewTests

- (void)setUp {
    [super setUp];
    self.view = [[MobaChampionSelectorView alloc]
        initWithCatalogEntries:MobaChampionSelectionController.defaultCatalogEntries];
    self.delegate = [[MobaSelectorDelegate alloc] init];
    self.view.delegate = self.delegate;
    [self.view setMode:MobaOverlayModeUI];
}

- (void)testSelectorShowsOnlyCaitlynAndDebugInstant {
    XCTAssertEqual(self.view.catalogEntries.count, 2u);
    XCTAssertEqualObjects(self.view.displayedChampionNames, (@[@"Caitlyn", @"Debug Instant Cast"]));
    XCTAssertEqualObjects(self.view.catalogEntries[0].championID, @"caitlyn");
    XCTAssertEqualObjects(self.view.catalogEntries[1].championID, @"debug-instant");
}

- (void)testSelectedChampionReflectsControllerCommittedSelection {
    self.view.selectedChampionID = @"caitlyn";
    XCTAssertEqualObjects(self.view.selectedChampionID, @"caitlyn");
    self.view.selectedChampionID = @"debug-instant";
    XCTAssertEqualObjects(self.view.selectedChampionID, @"debug-instant");
}

- (void)testAcceptedRequestChangesSelectionOnlyAfterDelegateSuccess {
    self.view.selectedChampionID = @"caitlyn";
    XCTAssertTrue([self.view requestSelectionAtIndex:1 error:nil]);
    XCTAssertEqualObjects(self.delegate.requestedChampionIDs, (@[@"debug-instant"]));
    XCTAssertEqualObjects(self.view.selectedChampionID, @"debug-instant");
}

- (void)testFailedRequestRestoresPreviousSelection {
    self.view.selectedChampionID = @"caitlyn";
    self.delegate.acceptsSelection = NO;
    NSError *error = nil;
    XCTAssertFalse([self.view requestSelectionAtIndex:1 error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(self.view.selectedChampionID, @"caitlyn");
}

- (void)testOnlyUIModeIsVisibleAndInteractive {
    [self.view setMode:MobaOverlayModeUI];
    XCTAssertFalse(self.view.hidden);
    XCTAssertTrue(self.view.userInteractionEnabled);
    for (NSNumber *mode in @[@(MobaOverlayModeBattle), @(MobaOverlayModeLayoutEdit), @(MobaOverlayModeSkillTuning)]) {
        [self.view setMode:mode.integerValue];
        XCTAssertTrue(self.view.hidden);
        XCTAssertFalse(self.view.userInteractionEnabled);
    }
}

- (void)testProgrammaticRequestOutsideUIModeIsRejectedWithoutDelegateCall {
    self.view.selectedChampionID = @"caitlyn";
    [self.view setMode:MobaOverlayModeBattle];
    XCTAssertFalse([self.view requestSelectionAtIndex:1 error:nil]);
    XCTAssertEqual(self.delegate.requestedChampionIDs.count, 0u);
    XCTAssertEqualObjects(self.view.selectedChampionID, @"caitlyn");
}

- (void)testDisplayedTextContainsNoHostKeyMappingLabels {
    NSString *joined = [self.view.displayedChampionNames componentsJoinedByString:@" "];
    XCTAssertEqual([joined rangeOfString:@"host Q" options:NSCaseInsensitiveSearch].location, NSNotFound);
    XCTAssertEqual([joined rangeOfString:@"host E" options:NSCaseInsensitiveSearch].location, NSNotFound);
    XCTAssertEqual([joined rangeOfString:@"host R" options:NSCaseInsensitiveSearch].location, NSNotFound);
    XCTAssertEqual([joined rangeOfString:@"host T" options:NSCaseInsensitiveSearch].location, NSNotFound);
    XCTAssertEqual([joined rangeOfString:@"ability1" options:NSCaseInsensitiveSearch].location, NSNotFound);
}

- (void)testSelectionViewDelegatesExactlyOnceAndOwnsNoInputBoundary {
    self.view.selectedChampionID = @"caitlyn";
    XCTAssertTrue([self.view requestSelectionAtIndex:1 error:nil]);
    XCTAssertEqual(self.delegate.requestedChampionIDs.count, 1u);
    XCTAssertFalse([self.view respondsToSelector:NSSelectorFromString(@"setKeyCode:down:")]);
    XCTAssertFalse([self.view respondsToSelector:NSSelectorFromString(@"runtimeFromSnapshot:error:")]);
}

- (void)testStopRemovalBoundaryDetachesSelectorFromSuperview {
    UIView *streamShell = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1024, 768)];
    [streamShell addSubview:self.view];
    XCTAssertTrue(self.view.superview == streamShell);
    [self.view removeFromSuperview];
    XCTAssertNil(self.view.superview);
}

@end
