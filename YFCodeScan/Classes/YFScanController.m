//
//  YFScanController.m
//  Pods
//
//  Created by sky on 2017/10/16.
//

#import "YFScanController.h"

static NSString * const kPodName = @"YFCodeScan";

@interface YFScanController ()

@property (nonatomic, strong, readwrite)YFScanner *scanner;

@property (nonatomic, assign) BOOL preIdleTimerDisabled;

@property (nonatomic, assign) BOOL preNavigationBarHidden;

@property (nonatomic, assign) UIStatusBarStyle preStatusBarStyle;

@property (nonatomic, strong) UIView *topBarView;

@property (nonatomic, weak) UIView *topBarTitleView;

@end

@implementation YFScanController

@synthesize metadataObjectTypes = _metadataObjectTypes;

- (instancetype)init
{
    YFScanPreviewView *previewView = [[YFScanPreviewView alloc] initWithFrame:CGRectZero];
    return [self initWithPreviewView:previewView scanCodeType:YFScanCodeTypeQRAndBarCode];
}

- (instancetype)initWithPreviewView:(YFScanPreviewView *)previewView scanCodeType:(YFScanCodeType)scanCodeType
{
    if (self = [super init]) {
        _scanner = [[YFScanner alloc] init];
        _topBarTitle = @"扫一扫";
        _preivewView = previewView;
        _scanCodeType = scanCodeType;
        _enableInterestRect = YES;
    }
    return self;
}

+ (instancetype)scanCtrollerWith:(YFScanPreviewView *)previewView
{
    return [self scanCtrollerWith:previewView scanCodeType:YFScanCodeTypeQRAndBarCode];
}

+ (instancetype)scanCtrollerWith:(YFScanPreviewView *)previewView scanCodeType:(YFScanCodeType)scanCodeType
{
    return [[self alloc] initWithPreviewView:previewView scanCodeType:scanCodeType];
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
    
    YFScanPreviewView *previewView = self.preivewView;
    if (!previewView) {
        previewView = [[YFScanPreviewView alloc] initWithFrame:self.view.bounds];
        self.preivewView = previewView;
    }
    [self.view addSubview:self.preivewView];
    [self configTopBar];
    
    [self checkCameraPemission];
    dispatch_async(self.scanner.sessionQueue, ^{
        [self.scanner setupCaptureSession];
    });
    
    self.preIdleTimerDisabled = [UIApplication sharedApplication].idleTimerDisabled;
    self.preNavigationBarHidden = self.navigationController.navigationBarHidden;
    self.preStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.navigationController.navigationBarHidden = YES;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    
    __weak __typeof(self) weakSelf = self;
    dispatch_async(self.scanner.sessionQueue, ^{
        switch (weakSelf.scanner.sessionSetupResult) {
            case YFSessionSetupResultSuccess:
            {
                [weakSelf.scanner startScanning];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.preivewView startScanningAnimation];
                    AVCaptureVideoPreviewLayer *previewLayer = [self.scanner previewLayer];
                    if (previewLayer && ![self.preivewView.layer.sublayers containsObject:previewLayer]) {
                        previewLayer.frame = self.preivewView.layer.bounds;
                        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                        [weakSelf.preivewView.layer insertSublayer:previewLayer atIndex:0];
                    }
                });
            }
                break;
            case YFSessionSetupResultFailed:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alertCtl = [UIAlertController alertControllerWithTitle:@"无法捕获图像" message:@"" preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil];
                    [alertCtl addAction:sureAction];
                    [weakSelf presentViewController:alertCtl animated:YES completion:nil];
                });
            }
                break;
                
            case YFSessionSetupResultNotAuthorized:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
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
    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self stopScanning];
    [UIApplication sharedApplication].idleTimerDisabled = self.preIdleTimerDisabled;
    self.navigationController.navigationBarHidden = self.preNavigationBarHidden;
    [UIApplication sharedApplication].statusBarStyle = self.preStatusBarStyle;
}

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

- (void)checkCameraPemission {
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
        AVAuthorizationStatus permission =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        
        switch (permission) {
            case AVAuthorizationStatusAuthorized:
                self.scanner.sessionSetupResult = YFSessionSetupResultSuccess;
                break;

            case AVAuthorizationStatusNotDetermined:
            {
                dispatch_suspend(self.scanner.sessionQueue);
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                         completionHandler:^(BOOL granted) {
                                             if (!granted) {
                                                 self.scanner.sessionSetupResult = YFSessionSetupResultNotAuthorized;
                                             }
                                             dispatch_resume(self.scanner.sessionQueue);
                                         }];
            }
                break;
                
            default:
                self.scanner.sessionSetupResult = YFSessionSetupResultNotAuthorized;
                
        }
    }
}

#pragma mark - getters && setters
- (void)setMetadataObjectTypes:(NSArray<AVMetadataObjectType> *)metadataObjectTypes
{
    if (_metadataObjectTypes == metadataObjectTypes) {
        return;
    }
    
    if (metadataObjectTypes && metadataObjectTypes.count > 0) {
        _metadataObjectTypes = metadataObjectTypes;
    } else {
        _metadataObjectTypes = [self defaultMetaDataObjectTypes];
    }
}

-(NSArray<AVMetadataObjectType> *)metadataObjectTypes
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

- (NSArray *)defaultMetaDataObjectTypes
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
