//
//  M2DWebViewController.m
//  BoostMedia
//
//  Created by Akira Matsuda on 2013/01/11.
//  Copyright (c) 2013年 akira.matsuda. All rights reserved.
//

#import "M2DWebViewController.h"

static const CGSize M2DArrowIconSize = {18, 18};

typedef NS_ENUM(NSUInteger, M2DArrowIconDirection) {
  M2DArrowIconDirectionLeft,
  M2DArrowIconDirectionRight
};

@implementation UIImage (M2DArrowIcon)

+ (UIImage *)m2d_arrowIconWithDirection:(M2DArrowIconDirection)direction size:(CGSize)size
{
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        return [[UIImage alloc] init];
    }

    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = {CGPointZero, size};

    CGContextSaveGState(context);
    CGContextBeginPath(context);

    if (direction == M2DArrowIconDirectionRight) {
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddLineToPoint(context, CGRectGetMaxX(rect), CGRectGetMidY(rect));
        CGContextAddLineToPoint(context, 0, CGRectGetMaxY(rect));
    } else {
        CGContextMoveToPoint(context, CGRectGetMaxX(rect), 0);
        CGContextAddLineToPoint(context, 0, CGRectGetMidY(rect));
        CGContextAddLineToPoint(context, CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    }

    CGContextClosePath(context);
    CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
    CGContextFillPath(context);
    CGContextRestoreGState(context);

    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return icon;
}

@end

@interface M2DWebViewController ()
{
	NSURL *url_;
	UIBarButtonItem *goForwardButton_;
	UIBarButtonItem *goBackButton_;
	UIBarButtonItem *actionButton_;
	id webView_;
	M2DWebViewType type_;
}

@property (nonatomic, copy) UIImage *backArrowImage;
@property (nonatomic, copy) UIImage *forwardArrowImage;

@end

@implementation M2DWebViewController

static NSString *const kM2DWebViewControllerGetTitleScript = @"var elements=document.getElementsByTagName(\'title\');elements[0].innerText";

@synthesize webView = webView_;

- (id)initWithURL:(NSURL *)url type:(M2DWebViewType)type
{
	self = [super init];
	if (self) {
		url_ = [url copy];
		type_ = type;
	}
	
	return self;
}

- (instancetype)initWithURL:(NSURL *)url type:(M2DWebViewType)type backArrowImage:(UIImage *)backArrowImage forwardArrowImage:(UIImage *)forwardArrowImage
{
	self = [self initWithURL:url type:type];
	if (self) {
		self.backArrowImage = backArrowImage;
		self.forwardArrowImage = forwardArrowImage;
	}
	
	return self;
}

- (void)dealloc
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Loading...", @"");

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
	type_ = M2DWebViewTypeUIKit;
#endif
	
	if (type_ == M2DWebViewTypeUIKit) {
		webView_ = [[UIWebView alloc] initWithFrame:self.view.bounds];
		[(UIWebView *)webView_ setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		((UIWebView *)webView_).delegate = self;
		[(UIWebView *)webView_ loadRequest:[NSURLRequest requestWithURL:url_]];
	}
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
	else if (type_ == M2DWebViewTypeWebKit || type_ == M2DWebViewTypeAutoSelect) {
		webView_ = [[WKWebView alloc] initWithFrame:self.view.bounds];
		[(WKWebView *)webView_ setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		((WKWebView *)webView_).navigationDelegate = self;
		[(WKWebView *)webView_ loadRequest:[NSURLRequest requestWithURL:url_]];
	}
#endif
	
	[self.view addSubview:webView_];
	[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.navigationController setToolbarHidden:NO animated:YES];
	if (goBackButton_ == nil) {
		NSArray *toolbarItems = nil;
		goBackButton_ = [[UIBarButtonItem alloc] initWithImage:self.backArrowImage ?: [UIImage m2d_arrowIconWithDirection:M2DArrowIconDirectionLeft size:M2DArrowIconSize] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
		goForwardButton_ = [[UIBarButtonItem alloc] initWithImage:self.forwardArrowImage ?: [UIImage m2d_arrowIconWithDirection:M2DArrowIconDirectionRight size:M2DArrowIconSize] style:UIBarButtonItemStylePlain target:self action:@selector(goForward:)];
		UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *fixedSpace19 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
		fixedSpace19.width = 19;
		UIBarButtonItem *fixedSpace6 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
		fixedSpace6.width = 6;
		UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];

		if (self.actionButtonPressedHandler) {
			actionButton_ = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(doAction:)];

			toolbarItems = @[fixedSpace6, goBackButton_, fixedSpace19, goForwardButton_, space, refreshButton, fixedSpace19, actionButton_, fixedSpace6];
		}
		else {
			toolbarItems = @[fixedSpace6, goBackButton_, fixedSpace19, goForwardButton_, space, refreshButton, fixedSpace6];
		}
		self.toolbarItems = toolbarItems;
		
		goForwardButton_.enabled = NO;
		goBackButton_.enabled = NO;
	}
}

- (void)setSmoothScroll:(BOOL)smoothScroll
{
	UIWebView *webView = webView_;
	if (smoothScroll) {
		webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
	}
	else {
		webView.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
	}
}

#pragma mark - WKUIDelegate

//- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
//{
//	if (!navigationAction.targetFrame.isMainFrame) {
//		[webView loadRequest:navigationAction.request];
//	}
//	
//	return nil;
//}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
	self.title = webView.title;
	
	if ([webView_ canGoBack]) {
		goBackButton_.enabled = YES;
	}
	else {
		goBackButton_.enabled = NO;
	}
	
	if ([webView_ canGoForward]) {
		goForwardButton_.enabled = YES;
	}
	else {
		goForwardButton_.enabled = NO;
	}
	
	url_ = [webView.URL copy];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateToolbarItemsWithType:UIBarButtonSystemItemRefresh];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
	if ([webView_ canGoBack]) {
		goBackButton_.enabled = YES;
	}
	else {
		goBackButton_.enabled = NO;
	}
	
	if ([webView_ canGoForward]) {
		goForwardButton_.enabled = YES;
	}
	else {
		goForwardButton_.enabled = NO;
	}
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self updateToolbarItemsWithType:UIBarButtonSystemItemStop];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateToolbarItemsWithType:UIBarButtonSystemItemRefresh];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	self.title = [webView stringByEvaluatingJavaScriptFromString:kM2DWebViewControllerGetTitleScript];
	if ([webView_ canGoBack]) {
		goBackButton_.enabled = YES;
	}
	else {
		goBackButton_.enabled = NO;
	}
	
	if ([webView_ canGoForward]) {
		goForwardButton_.enabled = YES;
	}
	else {
		goForwardButton_.enabled = NO;
	}
	url_ = [webView.request.URL copy];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateToolbarItemsWithType:UIBarButtonSystemItemRefresh];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	if ([webView_ canGoBack]) {
		goBackButton_.enabled = YES;
	}
	else {
		goBackButton_.enabled = NO;
	}
	
	if ([webView_ canGoForward]) {
		goForwardButton_.enabled = YES;
	}
	else {
		goForwardButton_.enabled = NO;
	}
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[self updateToolbarItemsWithType:UIBarButtonSystemItemStop];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[self updateToolbarItemsWithType:UIBarButtonSystemItemRefresh];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	self.title = [webView stringByEvaluatingJavaScriptFromString:kM2DWebViewControllerGetTitleScript];

	return YES;
}

#pragma mark -

- (void)goForward:(id)sender
{
	UIWebView *webView = webView_;
	[webView goForward];
}

- (void)goBack:(id)sender
{
	UIWebView *webView = webView_;
	[webView goBack];
}

- (void)refresh:(id)sender
{
	UIWebView *webView = webView_;
	[webView reload];
}

- (void)stop:(id)sender
{
	UIWebView *webView = webView_;
	[webView stopLoading];
}

- (void)doAction:(id)sender
{
	if (self.actionButtonPressedHandler) {
		self.actionButtonPressedHandler(self.title, url_);
	}
}

- (void)loadURL:(NSURL *)url
{
	UIWebView *webView = webView_;
	[webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (NSString *)getFilePath:(NSString *)filename
{
	return 	[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] pathForResource:@"M2DWebViewController" ofType:@"bundle"], filename];
}

- (void)updateToolbarItemsWithType:(UIBarButtonSystemItem)type
{
	if (type == UIBarButtonSystemItemRefresh) {
		NSMutableArray *items = [[self.navigationController.toolbar items] mutableCopy];
		UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
		[items replaceObjectAtIndex:5 withObject:refreshButton];
		[self.navigationController.toolbar setItems:items];
	}
	else if (type == UIBarButtonSystemItemStop) {
		NSMutableArray *items = [[self.navigationController.toolbar items] mutableCopy];
		UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop:)];
		[items replaceObjectAtIndex:5 withObject:refreshButton];
		[self.navigationController.toolbar setItems:items];
	}
}

@end
