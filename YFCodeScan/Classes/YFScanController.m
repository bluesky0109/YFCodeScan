//
//  YFScanController.m
//  Pods
//
//  Created by sky on 2017/10/16.
//

#import "YFScanController.h"

static NSString * const kPodName = @"YFCodeScan";

// 主线程执行
NS_INLINE void dispatch_main_async(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@interface YFScanController ()<YFScannerDelegate>

@property (nonatomic, strong, readwrite)YFScanner *scanner;

@property (nonatomic, assign) BOOL preIdleTimerDisabled;

@property (nonatomic, assign) BOOL preNavigationBarHidden;

@property (nonatomic, assign) UIStatusBarStyle preStatusBarStyle;

@property (nonatomic, strong) UIView *topBarView;

@property (nonatomic, weak) UIView *topBarTitleView;

@end

@implementation YFScanController

@synthesize metadataObjectTypes = _metadataObjectTypes;

#pragma mark - initial
- (instancetype)init
{
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

+ (instancetype)defaultScanCtroller
{
    return [[self alloc] init];
}

- (void)commonInit
{
    _topBarTitle = @"扫一扫";
    _preivewView = [YFScanPreviewView defaultPreview];
    _scanCodeType = YFScanCodeTypeQRAndBarCode;
    _enableInterestRect = YES;
}

#pragma mark - lifeCycle

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    _scanner = [[YFScanner alloc] init];
    _scanner.delegate = self;
    
    self.preIdleTimerDisabled = [UIApplication sharedApplication].idleTimerDisabled;
    self.preNavigationBarHidden = self.navigationController.navigationBarHidden;
    self.preStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    
    [self.view addSubview:self.preivewView];
    [self configTopBar];
    
    AVCaptureVideoPreviewLayer *previewLayer = [self.scanner previewLayer];
    previewLayer.frame = self.preivewView.layer.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.preivewView.layer insertSublayer:previewLayer atIndex:0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.navigationController.navigationBarHidden = YES;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;

    __weak __typeof(self) weakSelf = self;

    switch (self.scanner.status) {
        case YFSessionStatusSetupSucceed:
        {
            [weakSelf.scanner startScanning];
        }
            break;
        case YFSessionStatusSetupFailed:
        {
            dispatch_main_async(^{
                UIAlertController *alertCtl = [UIAlertController alertControllerWithTitle:@"无法捕获图像" message:@"" preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil];
                [alertCtl addAction:sureAction];
                [weakSelf presentViewController:alertCtl animated:YES completion:nil];
            });
        }
            break;
            
        case YFSessionStatusPemissionDenied:
        {
            dispatch_main_async(^{
                NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
                NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
                NSString *message = [NSString stringWithFormat:@"请在iPhone的\"设置-隐私-相机\"中允许%@访问你的相机",appName];
                
                UIAlertController *alertCtl = [UIAlertController alertControllerWithTitle:@"相机被禁用" message:message preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSURL *settingURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    if ([[UIApplication sharedApplication] canOpenURL:settingURL]) {
                        [[UIApplication sharedApplication] openURL:settingURL];
                    }
                }];
                [alertCtl addAction:sureAction];
                
                [weakSelf presentViewController:alertCtl animated:YES completion:nil];
            });
        }
            break;
        default:
            break;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self stopScanning];
    [UIApplication sharedApplication].idleTimerDisabled = self.preIdleTimerDisabled;
    self.navigationController.navigationBarHidden = self.preNavigationBarHidden;
    [UIApplication sharedApplication].statusBarStyle = self.preStatusBarStyle;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.scanner.status == YFSessionStatusSetupSucceed) {
        dispatch_main_async(^{
            [self.preivewView startScanningAnimation];
        });
    }
}

#pragma mark - config

- (void)configTopBar {
    [self.view addSubview:self.topBarView];
    self.topBarView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *views = NSDictionaryOfVariableBindings(_topBarView);
    [self.view addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"H:|[_topBarView]|"
                               options:0
                               metrics:nil views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"V:|[_topBarView(64)]"
                               options:0
                               metrics:nil views:views]];
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *bundleURL = [bundle URLForResource:kPodName withExtension:@"bundle"];
    bundle = [NSBundle bundleWithURL:bundleURL];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *normalImage = [UIImage imageNamed:@"yf_navigationBar_backArrow_normal" inBundle:bundle compatibleWithTraitCollection:nil];
    UIImage *highlightedImage = [UIImage imageNamed:@"yf_navigationBar_backArrow_highlighted" inBundle:bundle compatibleWithTraitCollection:nil];
    [backButton setImage:normalImage forState:UIControlStateNormal];
    [backButton setImage:highlightedImage forState:UIControlStateHighlighted];
    [backButton addTarget:self action:@selector(backButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.topBarView addSubview:backButton];
    
    views = NSDictionaryOfVariableBindings(backButton);
    [self.topBarView addConstraints:[NSLayoutConstraint
                                     constraintsWithVisualFormat:@"H:|-5-[backButton(44)]"
                                     options:0
                                     metrics:nil views:views]];
    
    [self.topBarView addConstraints:[NSLayoutConstraint
                                     constraintsWithVisualFormat:@"V:[backButton(44)]"
                                     options:0
                                     metrics:nil views:views]];
    
    NSLayoutConstraint *buttonCenterY = [NSLayoutConstraint constraintWithItem:backButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.topBarView attribute:NSLayoutAttributeCenterY multiplier:1 constant:10];
    [self.topBarView addConstraint:buttonCenterY];
    
    UILabel *topBarTitleView = [[UILabel alloc] init];
    topBarTitleView.font = [UIFont systemFontOfSize:16];
    topBarTitleView.textColor = [UIColor whiteColor];
    topBarTitleView.text = self.topBarTitle;
    topBarTitleView.textAlignment = NSTextAlignmentCenter;
    [self.topBarView addSubview:topBarTitleView];
    self.topBarTitleView = topBarTitleView;
    
    topBarTitleView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *titleCenterX = [NSLayoutConstraint constraintWithItem:topBarTitleView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.topBarView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
    
    NSLayoutConstraint *titleCenterY = [NSLayoutConstraint constraintWithItem:topBarTitleView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.topBarView attribute:NSLayoutAttributeCenterY multiplier:1 constant:10];

    [self.topBarView addConstraint:titleCenterX];
    [self.topBarView addConstraint:titleCenterY];
    [topBarTitleView sizeToFit];
}

- (void)backButtonClicked
{
    if (self.navigationController.topViewController == self) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)startScanning
{
    [self.scanner startScanning];
    [self.preivewView startScanningAnimation];
}

- (void)stopScanning
{
    [self.scanner stopScanning];
    [self.preivewView stopScanningAnimation];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - YFScannerDelegate

- (void)scannerWillStartSetup:(YFScanner *_Nonnull)scanner
{
    NSLog(@"%s",__FUNCTION__);
}

- (void)scannerDidAddDeviceInputSucceed:(YFScanner *_Nonnull)scanner
{
    NSLog(@"%s",__FUNCTION__);
}

- (void)scannerDidAddMetadataOutputSucceed:(YFScanner *_Nonnull)scanner
{
    NSLog(@"%s",__FUNCTION__);
    scanner.metadataObjectTypes = self.metadataObjectTypes;
}

- (void)scannerDidSessionStatusChanged:(YFScanner *_Nonnull)scanner
{
    NSLog(@"%s",__FUNCTION__);
    if (scanner.status == YFSessionStatusSetupSucceed) {
        [scanner startScanning];
    }
}

#pragma mark - getters && setters
- (void)setMetadataObjectTypes:(NSArray<NSString *> *)metadataObjectTypes
{
    if (_metadataObjectTypes == metadataObjectTypes) {
        return;
    }
    
    if (metadataObjectTypes && metadataObjectTypes.count > 0) {
        _metadataObjectTypes = metadataObjectTypes;
    } else {
        _metadataObjectTypes = [self defaultMetaDataObjectTypes];
    }
    
    self.scanner.metadataObjectTypes = _metadataObjectTypes;
}

-(NSArray<NSString *> *)metadataObjectTypes
{
    if (!_metadataObjectTypes) {
        _metadataObjectTypes = [self defaultMetaDataObjectTypes];
    }
    return _metadataObjectTypes;
}

- (UIView *)topBarView
{
    if (!_topBarView) {
        _topBarView = [[UIView alloc] initWithFrame:CGRectZero];
        _topBarView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    }
    return _topBarView;
}

- (void)setScannedHandle:(void (^)(NSString *))scannedHandle
{
    if (_scannedHandle != scannedHandle) {
        _scannedHandle = scannedHandle;
        self.scanner.scanSuccessResult = scannedHandle;
    }
}

- (void)setScanCodeType:(YFScanCodeType)scanCodeType
{
    if (_scanCodeType != scanCodeType) {
        _scanCodeType = scanCodeType;
        
        self.metadataObjectTypes = [self defaultMetaDataObjectTypes];
    }
}

- (NSArray<NSString *> *)defaultMetaDataObjectTypes
{
    NSArray *qrCodeTypes = @[AVMetadataObjectTypeQRCode];
    NSArray *barCodeTypes = @[AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeCode128Code];

    if (self.scanCodeType == YFScanCodeTypeQRCode) {
        return qrCodeTypes;
    } else if (self.scanCodeType == YFScanCodeTypeBarCode) {
        return barCodeTypes;
    } else {
        return [[NSArray arrayWithArray:qrCodeTypes] arrayByAddingObjectsFromArray:barCodeTypes];
    }
}

@end
