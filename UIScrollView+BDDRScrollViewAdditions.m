#import "UIScrollView+BDDRScrollViewAdditions.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

@implementation UIScrollView (BDDRScrollViewAdditions)

static void *const BDDRScrollViewAdditionsOneFingerZoomStartZoomScaleAssociationKey = (void *)&BDDRScrollViewAdditionsOneFingerZoomStartZoomScaleAssociationKey;
static void *const BDDRScrollViewAdditionsOneFingerZoomStartLocationYAssociationKey = (void *)&BDDRScrollViewAdditionsOneFingerZoomStartLocationYAssociationKey;

#pragma mark - Method Swizzling

+ (void)load {
	NSError *error;
	if (![self jr_swizzleMethod:@selector(setContentOffset:) withMethod:@selector(bddr_setContentOffset:) error:&error])
		NSLog(@"%@", [error localizedDescription]);
	if (![self jr_swizzleMethod:@selector(contentInset) withMethod:@selector(bddr_contentInset) error:&error])
		NSLog(@"%@", [error localizedDescription]);
	if (![self jr_swizzleMethod:@selector(setContentInset:) withMethod:@selector(bddr_setContentInset:) error:&error])
		NSLog(@"%@", [error localizedDescription]);
}

#pragma mark - Utility Methods

- (CGRect)zoomRectForZoomScale:(CGFloat)zoomScale withLocationOfGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
	UIView *view = [self.delegate respondsToSelector:@selector(viewForZoomingInScrollView:)] ? [self.delegate viewForZoomingInScrollView:self] : self;
	CGPoint location = [gestureRecognizer locationInView:view];
	CGSize boundsSize = self.bounds.size;
	CGRect zoomRect;
	
	zoomRect.size.width = boundsSize.width / zoomScale;
	zoomRect.size.height = boundsSize.height / zoomScale;
	zoomRect.origin.x = location.x - (zoomRect.size.width / 2.0f);
	zoomRect.origin.y = location.y - (zoomRect.size.height / 2.0f);
	
	return zoomRect;
}

#pragma mark - Content Centering

- (void)bddr_centerContentIfNeeded {
	if (!self.tracking)
		[self bddr_centerContent];
}

- (void)bddr_centerContent {
	CGSize contentSize = self.contentSize;
	CGSize boundsSize = self.bounds.size;
	UIEdgeInsets contentInset = self.contentInset;
	CGFloat horizontalInset = 0.0f;
	CGFloat verticalInset = 0.0f;
	
	if (self.bddr_centersContentHorizontally && contentSize.width < boundsSize.width)
		horizontalInset = (boundsSize.width - contentSize.width) / 2.0f;
	if (self.bddr_centersContentVertically && contentSize.height < boundsSize.height)
		verticalInset = (boundsSize.height - contentSize.height) / 2.0f;
	
	[self bddr_setContentInset:UIEdgeInsetsMake(verticalInset + contentInset.top,
												horizontalInset + contentInset.left,
												verticalInset + contentInset.bottom,
												horizontalInset + contentInset.right)];
}

#pragma mark - Double Tap Zoom In

- (void)bddr_addOrRemoveDoubleTapZoomInGestureRecognizer {
	UITapGestureRecognizer *doubleTapZoomInGestureRecognizer;
	
	if (self.bddr_doubleTapZoomInEnabled) {
		doubleTapZoomInGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bddr_handleDoubleTapZoomInGestureRecognizer:)];
		doubleTapZoomInGestureRecognizer.numberOfTapsRequired = 2;
		[self addGestureRecognizer:doubleTapZoomInGestureRecognizer];
		
		if (self.bddr_oneFingerZoomGestureRecognizer)
			[self.bddr_oneFingerZoomGestureRecognizer requireGestureRecognizerToFail:doubleTapZoomInGestureRecognizer];
	} else
		[self removeGestureRecognizer:self.bddr_doubleTapZoomInGestureRecognizer];
	
	self.bddr_doubleTapZoomInGestureRecognizer = doubleTapZoomInGestureRecognizer;
}

- (void)bddr_handleDoubleTapZoomInGestureRecognizer:(UITapGestureRecognizer *)doubleTapZoomInGestureRecognizer {
	if (self.zoomScale == self.maximumZoomScale && self.bddr_doubleTapZoomsToMinimumZoomScaleAtMaximumZoom) {
		[self setZoomScale:self.minimumZoomScale animated:YES];
		return;
	}
	
	CGFloat newZoomScale = self.zoomScale * self.bddr_zoomScaleStepFactor;
	CGRect zoomRect = [self zoomRectForZoomScale:newZoomScale withLocationOfGestureRecognizer:doubleTapZoomInGestureRecognizer];
	[self zoomToRect:zoomRect animated:YES];
}

#pragma mark - Two Finger Zoom Out

- (void)bddr_addOrRemoveTwoFingerZoomOutGestureRecognizer {
	UITapGestureRecognizer *twoFingerZoomOutGestureRecognizer;
	
	if (self.bddr_twoFingerZoomOutEnabled) {
		twoFingerZoomOutGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bddr_handleTwoFingerZoomOutGestureRecognizer:)];
		twoFingerZoomOutGestureRecognizer.numberOfTouchesRequired = 2;
		[self addGestureRecognizer:twoFingerZoomOutGestureRecognizer];
	} else
		[self removeGestureRecognizer:self.bddr_twoFingerZoomOutGestureRecognizer];
	
	self.bddr_twoFingerZoomOutGestureRecognizer = twoFingerZoomOutGestureRecognizer;
}

- (void)bddr_handleTwoFingerZoomOutGestureRecognizer:(UITapGestureRecognizer *)twoFingerZoomOutGestureRecognizer {
	CGFloat newZoomScale = self.zoomScale / self.bddr_zoomScaleStepFactor;
	CGRect zoomRect = [self zoomRectForZoomScale:newZoomScale withLocationOfGestureRecognizer:twoFingerZoomOutGestureRecognizer];
	[self zoomToRect:zoomRect animated:YES];
}

#pragma mark - One Finger Zoom

- (void)bddr_addOrRemoveOneFingerZoomGestureRecognizer {
	UILongPressGestureRecognizer *oneFingerZoomGestureRecognizer;
	
	if (self.bddr_oneFingerZoomEnabled) {
		oneFingerZoomGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(bddr_handleOneFingerZoomGestureRecognizer:)];
		oneFingerZoomGestureRecognizer.numberOfTapsRequired = 1;
		oneFingerZoomGestureRecognizer.minimumPressDuration = 0.0f;
		[self addGestureRecognizer:oneFingerZoomGestureRecognizer];
		
		if (self.bddr_doubleTapZoomInGestureRecognizer)
			[oneFingerZoomGestureRecognizer requireGestureRecognizerToFail:self.bddr_doubleTapZoomInGestureRecognizer ];
	} else
		[self removeGestureRecognizer:self.bddr_oneFingerZoomGestureRecognizer];
	
	self.bddr_oneFingerZoomGestureRecognizer = oneFingerZoomGestureRecognizer;
}

- (void)bddr_handleOneFingerZoomGestureRecognizer:(UILongPressGestureRecognizer *)oneFingerZoomGestureRecognizer {
	CGFloat currentLocationY = [oneFingerZoomGestureRecognizer locationInView:self.window].y;
	
	if (oneFingerZoomGestureRecognizer.state == UIGestureRecognizerStateBegan) {
		objc_setAssociatedObject(self, BDDRScrollViewAdditionsOneFingerZoomStartZoomScaleAssociationKey, @(self.zoomScale), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(self, BDDRScrollViewAdditionsOneFingerZoomStartLocationYAssociationKey, @(currentLocationY), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else if (oneFingerZoomGestureRecognizer.state == UIGestureRecognizerStateChanged) {
		CGFloat startZoomScale = [objc_getAssociatedObject(self, BDDRScrollViewAdditionsOneFingerZoomStartZoomScaleAssociationKey) floatValue];
		CGFloat startLocationY = [objc_getAssociatedObject(self, BDDRScrollViewAdditionsOneFingerZoomStartLocationYAssociationKey) floatValue];
		CGFloat boundsSizeY = self.bounds.size.height;
		CGFloat zoomFactor = (startLocationY - currentLocationY) / (boundsSizeY / 2.0f);
		
		if (zoomFactor > 0.0f)
			self.zoomScale = startZoomScale * (1.0f + zoomFactor * self.bddr_zoomScaleStepFactor);
		else if (zoomFactor < 0.0f)
			self.zoomScale = startZoomScale / (1.0f + -zoomFactor * self.bddr_zoomScaleStepFactor);
	}
}

#pragma mark - Overridden Getters and Setters

- (void)bddr_setContentOffset:(CGPoint)contentOffset {
	[self bddr_setContentOffset:contentOffset];
	[self bddr_centerContent];
}

- (UIEdgeInsets)bddr_contentInset {
	return [objc_getAssociatedObject(self, @selector(bddr_contentInset)) UIEdgeInsetsValue];
}

- (void)bddr_setContentInset:(UIEdgeInsets)contentInset {
	objc_setAssociatedObject(self, @selector(bddr_contentInset), [NSValue valueWithUIEdgeInsets:contentInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self bddr_centerContentIfNeeded];
}

#pragma mark - Getters of animated Properties

- (CGPoint)bddr_presentationLayerContentOffset {
	CALayer *presentationLayer = self.layer.presentationLayer;
	return presentationLayer.bounds.origin;
}

- (CGSize)bddr_presentationLayerContentSize {
	if ([self.delegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
		UIView *zoomView = [self.delegate viewForZoomingInScrollView:self];
		CALayer *zoomPresentationLayer = zoomView.layer.presentationLayer;
		
		return zoomPresentationLayer.frame.size;
	} else
		return self.contentSize;
}

- (CGFloat)bddr_presentationLayerZoomScale {
	if ([self.delegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
		UIView *zoomView = [self.delegate viewForZoomingInScrollView:self];
		CALayer *zoomPresentationLayer = zoomView.layer.presentationLayer;
		
		return zoomPresentationLayer.transform.m11;
	} else
		return self.zoomScale;
}

#pragma mark - Getters and Setters

- (void)bddr_setCentersContent:(BOOL)centersContent {
	self.bddr_centersContentHorizontally = centersContent;
	self.bddr_centersContentVertically = centersContent;
}

- (BOOL)bddr_centersContentHorizontally {
	return [objc_getAssociatedObject(self, @selector(bddr_centersContentHorizontally)) boolValue];
}

- (void)setBddr_centersContentHorizontally:(BOOL)centersContentHorizontally {
	objc_setAssociatedObject(self, @selector(bddr_centersContentHorizontally), @(centersContentHorizontally), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self bddr_centerContentIfNeeded];
}

- (BOOL)bddr_centersContentVertically {
	return [objc_getAssociatedObject(self, @selector(bddr_centersContentVertically)) boolValue];
}

- (void)setBddr_centersContentVertically:(BOOL)centersContentVertically {
	objc_setAssociatedObject(self, @selector(bddr_centersContentVertically), @(centersContentVertically), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self bddr_centerContentIfNeeded];
}

- (BOOL)bddr_doubleTapZoomInEnabled {
	return [objc_getAssociatedObject(self, @selector(bddr_doubleTapZoomInEnabled)) boolValue];
}

- (void)setBddr_doubleTapZoomInEnabled:(BOOL)doubleTapZoomInEnabled {
	objc_setAssociatedObject(self, @selector(bddr_doubleTapZoomInEnabled), @(doubleTapZoomInEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self bddr_addOrRemoveDoubleTapZoomInGestureRecognizer];
}

- (BOOL)bddr_doubleTapZoomsToMinimumZoomScaleAtMaximumZoom {
	NSNumber *doubleTapZoomsToMinimumZoomScaleAtMaximumZoomValue = objc_getAssociatedObject(self, @selector(bddr_doubleTapZoomsToMinimumZoomScaleAtMaximumZoom));
	
	if (!doubleTapZoomsToMinimumZoomScaleAtMaximumZoomValue) {
		doubleTapZoomsToMinimumZoomScaleAtMaximumZoomValue = @(YES);
		objc_setAssociatedObject(self, @selector(bddr_doubleTapZoomsToMinimumZoomScaleAtMaximumZoom), doubleTapZoomsToMinimumZoomScaleAtMaximumZoomValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return [doubleTapZoomsToMinimumZoomScaleAtMaximumZoomValue boolValue];
}

- (void)setBddr_doubleTapZoomsToMinimumZoomScaleAtMaximumZoom:(BOOL)doubleTapZoomsToMinimumZoomScaleAtMaximumZoom {
	objc_setAssociatedObject(self, @selector(bddr_doubleTapZoomsToMinimumZoomScaleAtMaximumZoom), @(doubleTapZoomsToMinimumZoomScaleAtMaximumZoom), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UITapGestureRecognizer *)bddr_doubleTapZoomInGestureRecognizer {
	return objc_getAssociatedObject(self, @selector(bddr_doubleTapZoomInGestureRecognizer));
}

- (void)setBddr_doubleTapZoomInGestureRecognizer:(UITapGestureRecognizer *)doubleTapZoomInGestureRecognizer {
	objc_setAssociatedObject(self, @selector(bddr_doubleTapZoomInGestureRecognizer), doubleTapZoomInGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)bddr_twoFingerZoomOutEnabled {
	return [objc_getAssociatedObject(self, @selector(bddr_twoFingerZoomOutEnabled)) boolValue];
}

- (void)setBddr_twoFingerZoomOutEnabled:(BOOL)twoFingerZoomOutEnabled {
	objc_setAssociatedObject(self, @selector(bddr_twoFingerZoomOutEnabled), @(twoFingerZoomOutEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self bddr_addOrRemoveTwoFingerZoomOutGestureRecognizer];
}

- (UITapGestureRecognizer *)bddr_twoFingerZoomOutGestureRecognizer {
	return objc_getAssociatedObject(self, @selector(bddr_twoFingerZoomOutGestureRecognizer));
}

- (void)setBddr_twoFingerZoomOutGestureRecognizer:(UITapGestureRecognizer *)twoFingerZoomOutGestureRecognizer {
	objc_setAssociatedObject(self, @selector(bddr_twoFingerZoomOutGestureRecognizer), twoFingerZoomOutGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)bddr_zoomScaleStepFactor {
	NSNumber *zoomScaleStepFactorValue = objc_getAssociatedObject(self, @selector(bddr_zoomScaleStepFactor));
	
	if (!zoomScaleStepFactorValue) {
		zoomScaleStepFactorValue = @(1.5f);
		objc_setAssociatedObject(self, @selector(bddr_zoomScaleStepFactor), zoomScaleStepFactorValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return [zoomScaleStepFactorValue floatValue];
}

- (void)setBddr_zoomScaleStepFactor:(CGFloat)zoomScaleStepFactor {
	zoomScaleStepFactor = MAX(1.0f, zoomScaleStepFactor);
	objc_setAssociatedObject(self, @selector(bddr_zoomScaleStepFactor), @(zoomScaleStepFactor), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)bddr_oneFingerZoomEnabled {
	return [objc_getAssociatedObject(self, @selector(bddr_oneFingerZoomEnabled)) boolValue];
}

- (void)setBddr_oneFingerZoomEnabled:(BOOL)oneFingerZoomEnabled {
	objc_setAssociatedObject(self, @selector(bddr_oneFingerZoomEnabled), @(oneFingerZoomEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[self bddr_addOrRemoveOneFingerZoomGestureRecognizer];
}

- (UILongPressGestureRecognizer *)bddr_oneFingerZoomGestureRecognizer {
	return objc_getAssociatedObject(self, @selector(bddr_oneFingerZoomGestureRecognizer));
}

- (void)setBddr_oneFingerZoomGestureRecognizer:(UILongPressGestureRecognizer *)oneFingerZoomGestureRecognizer {
	objc_setAssociatedObject(self, @selector(bddr_oneFingerZoomGestureRecognizer), oneFingerZoomGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end