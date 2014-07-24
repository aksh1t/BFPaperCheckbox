//
//  BFPaperCheckbox.m
//  BFPaperCheckbox
//
//  Created by Bence Feher on 7/22/14.
//  Copyright (c) 2014 Bence Feher. All rights reserved.
//
/*
 The MIT License (MIT)
 
 Copyright (c) 2014 Bence Feher
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


#import "BFPaperCheckbox.h"
#import "UIColor+BFPaperColors.h"

@interface BFPaperCheckbox()
@property CGPoint centerPoint;
@property (nonatomic, strong) CAShapeLayer *lineLeft;   // Also used for checkmark left, shorter line.
@property (nonatomic, strong) CAShapeLayer *lineTop;
@property (nonatomic, strong) CAShapeLayer *lineRight;
@property (nonatomic, strong) CAShapeLayer *lineBottom; // Also used for checkmark right, longer line.
@property CGPoint tapPoint;
@property NSMutableArray *rippleAnimationQueue;
@property CGFloat radius;
@property int checkboxSidesCompletedAnimating;          // This should bounce between 0 and 4, representing the number of checkbox sides which have completed animating.
@property int checkmarkSidesCompletedAnimating;         // This should bounce between 0 and 2, representing the number of checkmark sides which have completed animating.
@property BOOL finishedAnimations;
@end




@implementation BFPaperCheckbox
// -Button size:
CGFloat const bfPaperCheckboxDefaultRadius = 39.f;//43.5f;
// -animation durations:
static CGFloat const bfPaperCheckbox_animationDurationConstant       = 0.12f;
static CGFloat const bfPaperCheckbox_tapCircleGrowthDurationConstant = bfPaperCheckbox_animationDurationConstant * 2;
// -tap-circle's size:
static CGFloat const bfPaperCheckbox_tapCircleDiameterStartValue     = 1.f;// for the mask
// -tap-circle's beauty:
static CGFloat const bfPaperCheckbox_tapFillConstant                 = 0.3f;
// -checkbox's beauty:
static CGFloat const bfPaperCheckbox_checkboxSideLength              = 9.f;
// -animation function names:
static NSString *const leftLineStrokeAnimationName = @"leftLineStroke";
static NSString *const topLineStrokeAnimationName = @"topLineStroke";
static NSString *const rightLineStrokeAnimationName = @"rightLineStroke";
static NSString *const bottomLineStrokeAnimationName = @"bottomLineStroke";
static NSString *const smallCheckmarkLineAnimationName = @"smallCheckmarkLine";
static NSString *const largeCheckmarkLineStrokeAnimationName = @"largeCheckmarkLine";
static NSString *const leftLineStrokeAnimationName2 = @"leftLineStroke2";
static NSString *const topLineStrokeAnimationName2 = @"topLineStroke2";
static NSString *const rightLineStrokeAnimationName2 = @"rightLineStroke2";
static NSString *const bottomLineStrokeAnimationName2 = @"bottomLineStroke2";
static NSString *const smallCheckmarkLineAnimationName2 = @"smallCheckmarkLine2";
static NSString *const largeCheckmarkLineStrokeAnimationName2 = @"largeCheckmarkLine2";




#pragma mark - Default Initializers
#pragma mark - Default Initializers
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupWithRadius:bfPaperCheckboxDefaultRadius];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupWithRadius:MAX(CGRectGetWidth(frame), CGRectGetHeight(frame)) / 2.f];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    if (self) {
        [self setupWithRadius:bfPaperCheckboxDefaultRadius];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

#pragma mark - Parent Overrides

#pragma mark - Custom Initializers
- (void)setupWithRadius:(CGFloat)radius
{
    // Defaults:
    self.radius = radius;
    self.finishedAnimations = YES;
    self.isChecked = NO;
    self.rippleFromTapLocation = YES;
    self.tapCirclePositiveColor = nil;
    self.tapCircleNegativeColor = nil;
    self.checkmarkColor = [UIColor paperColorGreen];
    self.tintColor = [UIColor paperColorGray700];
    self.layer.masksToBounds = YES;
    self.clipsToBounds = YES;
    self.layer.shadowOpacity = 0.f;
    self.layer.cornerRadius = self.radius;
    self.backgroundColor = [UIColor clearColor];
    self.rippleAnimationQueue = [NSMutableArray array];
    
    
    self.lineLeft   = [CAShapeLayer new];
    self.lineTop    = [CAShapeLayer new];
    self.lineRight  = [CAShapeLayer new];
    self.lineBottom = [CAShapeLayer new];
    
    [@[ self.lineLeft, self.lineTop, self.lineRight, self.lineBottom ] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CAShapeLayer *layer = obj;
        layer.fillColor = [UIColor clearColor].CGColor;
        layer.anchorPoint = CGPointMake(0.0, 0.0);
        layer.lineJoin = kCALineJoinRound;
        layer.lineCap = kCALineCapSquare;
        layer.contentsScale = self.layer.contentsScale;
        layer.lineWidth = 2.f;
        layer.strokeColor = self.tintColor.CGColor;
        
        
        // initialize with an empty path so we can animate the path w/o having to check for NULLs.
        CGPathRef dummyPath = CGPathCreateMutable();
        layer.path = dummyPath;
        CGPathRelease(dummyPath);
        
        [self.layer addSublayer:layer];
    }];
    
    [self drawCheckBoxAnimated:NO];

    
    [self addTarget:self action:@selector(paperTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(paperTouchUpAndSwitchStates:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(paperTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(paperTouchUp:) forControlEvents:UIControlEventTouchCancel];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:nil];
    tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:tapGestureRecognizer];
    
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];
}


#pragma mark - Gesture Recognizer Delegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    CGPoint location = [touch locationInView:self];
    //NSLog(@"location: x = %0.2f, y = %0.2f", location.x, location.y);
    
    self.tapPoint = location;
    
    return NO;  // Disallow recognition of tap gestures. We just needed this to grab that tasty tap location.
}


#pragma mark - IBAction Callback Handlers
- (void)paperTouchDown:(BFPaperCheckbox *)sender
{
    //NSLog(@"Touch down handler");
    [self growTapCircle];
}


- (void)paperTouchUp:(BFPaperCheckbox *)sender
{
    //NSLog(@"Touch Up handler");
    [self fadeTapCircleOut];
}

- (void)paperTouchUpAndSwitchStates:(BFPaperCheckbox *)sender
{
    //NSLog(@"Touch Up handler with switching states");
    if (!self.finishedAnimations) {
        [self fadeTapCircleOut];
        return;
    }
    
    // Change states:
    self.isChecked = !self.isChecked;
    //NSLog(@"self.isChecked: %@", self.isChecked ? @"YES" : @"NO");
    
    if (self.isChecked) {
        [self shrinkAwayCheckboxAnimated:YES];
    }
    else {
        [self shrinkAwayCheckmarkAnimated:YES];
    }
    [self fadeTapCircleOut];
    
    // Notify our delegate that we changed states!
    [self.delegate paperCheckboxChangedState:self];
}


#pragma mark - Animation
- (void)growTapCircle
{
    //NSLog(@"expanding a tap circle");
    
    // Spawn a growing circle that "ripples" through the button:
    CGRect endRect = CGRectMake(self.bounds.origin.x, self.bounds.origin.y , self.bounds.size.width, self.bounds.size.height);
    
    
    CALayer *tempAnimationLayer = [CALayer new];
    tempAnimationLayer.frame = endRect;
    tempAnimationLayer.cornerRadius = self.radius;
    
    
    // Set animation layer's background color:
    if (self.isChecked) {
        // It is currently checked, so we are unchecking it:
        tempAnimationLayer.backgroundColor = (nil == self.tapCircleNegativeColor) ? [[UIColor paperColorGray700] colorWithAlphaComponent:bfPaperCheckbox_tapFillConstant].CGColor : self.tapCircleNegativeColor.CGColor;
    }
    else {
        // It is currently unchecked, so we are checking it:
        tempAnimationLayer.backgroundColor = (nil == self.tapCirclePositiveColor) ? [self.checkmarkColor colorWithAlphaComponent:bfPaperCheckbox_tapFillConstant].CGColor : self.tapCirclePositiveColor.CGColor;
    }
    tempAnimationLayer.borderColor = [UIColor clearColor].CGColor;
    tempAnimationLayer.borderWidth = 0;
    
    
    // Animation Mask Rects
    CGPoint origin = self.rippleFromTapLocation ? self.tapPoint : CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    //NSLog(@"self.center: (x%0.2f, y%0.2f)", self.center.x, self.center.y);
    UIBezierPath *startingTapCirclePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(origin.x - (bfPaperCheckbox_tapCircleDiameterStartValue / 2.f), origin.y - (bfPaperCheckbox_tapCircleDiameterStartValue / 2.f), bfPaperCheckbox_tapCircleDiameterStartValue, bfPaperCheckbox_tapCircleDiameterStartValue) cornerRadius:bfPaperCheckbox_tapCircleDiameterStartValue / 2.f];
    
    CGFloat tapCircleDiameterEndValue = (self.rippleFromTapLocation) ? self.radius * 4 : self.self.radius * 2.f;
    UIBezierPath *endTapCirclePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(origin.x - (tapCircleDiameterEndValue/ 2.f), origin.y - (tapCircleDiameterEndValue/ 2.f), tapCircleDiameterEndValue, tapCircleDiameterEndValue) cornerRadius:tapCircleDiameterEndValue/ 2.f];
    
    // Animation Mask Layer:
    CAShapeLayer *animationMaskLayer = [CAShapeLayer layer];
    animationMaskLayer.path = endTapCirclePath.CGPath;
    animationMaskLayer.fillColor = [UIColor blackColor].CGColor;
    animationMaskLayer.strokeColor = [UIColor clearColor].CGColor;
    animationMaskLayer.borderColor = [UIColor clearColor].CGColor;
    animationMaskLayer.borderWidth = 0;
    
    tempAnimationLayer.mask = animationMaskLayer;
    
    // Grow tap-circle animation:
    CABasicAnimation *tapCircleGrowthAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    tapCircleGrowthAnimation.delegate = self;
    [tapCircleGrowthAnimation setValue:@"tapGrowth" forKey:@"id"];
    tapCircleGrowthAnimation.duration = bfPaperCheckbox_tapCircleGrowthDurationConstant;
    tapCircleGrowthAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    tapCircleGrowthAnimation.fromValue = (__bridge id)startingTapCirclePath.CGPath;
    tapCircleGrowthAnimation.toValue = (__bridge id)endTapCirclePath.CGPath;
    tapCircleGrowthAnimation.fillMode = kCAFillModeForwards;
    tapCircleGrowthAnimation.removedOnCompletion = NO;
    
    // Fade in self.animationLayer:
    CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeIn.duration = bfPaperCheckbox_animationDurationConstant;
    fadeIn.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    fadeIn.fromValue = [NSNumber numberWithFloat:0.f];
    fadeIn.toValue = [NSNumber numberWithFloat:1.f];
    fadeIn.fillMode = kCAFillModeForwards;
    fadeIn.removedOnCompletion = NO;
    
    
    // Add the animation layer to our animation queue and insert it into our view:
    [self.rippleAnimationQueue addObject:tempAnimationLayer];
    [self.layer insertSublayer:tempAnimationLayer atIndex:0];
    
    [animationMaskLayer addAnimation:tapCircleGrowthAnimation forKey:@"animatePath"];
    [tempAnimationLayer addAnimation:fadeIn forKey:@"opacityAnimation"];
}


- (void)fadeTapCircleOut
{
    //NSLog(@"Fading away");
    
    CALayer *tempAnimationLayer = [self.rippleAnimationQueue firstObject];
    [self.rippleAnimationQueue removeObjectAtIndex:0];
    
    CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeOut.fromValue = [NSNumber numberWithFloat:tempAnimationLayer.opacity];
    fadeOut.toValue = [NSNumber numberWithFloat:0.f];
    fadeOut.duration = bfPaperCheckbox_tapCircleGrowthDurationConstant;
    fadeOut.fillMode = kCAFillModeForwards;
    fadeOut.removedOnCompletion = NO;
    
    [tempAnimationLayer addAnimation:fadeOut forKey:@"opacityAnimation"];
}


- (void)drawCheckBoxAnimated:(BOOL)animated
{
    self.lineLeft.opacity   = 1;
    self.lineTop.opacity    = 1;
    self.lineRight.opacity  = 1;
    self.lineBottom.opacity = 1;
    
    // Using layers and paths:
    CGPathRef newLeftPath   = NULL;
    CGPathRef newTopPath    = NULL;
    CGPathRef newRightPath  = NULL;
    CGPathRef newBottomPath = NULL;
    
    newLeftPath = [self createCenteredLineWithRadius:bfPaperCheckbox_checkboxSideLength angle:M_PI_2 offset:CGPointMake(-bfPaperCheckbox_checkboxSideLength, 0)];
    newTopPath = [self createCenteredLineWithRadius:bfPaperCheckbox_checkboxSideLength angle:0 offset:CGPointMake(0, -bfPaperCheckbox_checkboxSideLength)];
    newRightPath = [self createCenteredLineWithRadius:bfPaperCheckbox_checkboxSideLength angle:M_PI_2 offset:CGPointMake(bfPaperCheckbox_checkboxSideLength, 0)];
    newBottomPath = [self createCenteredLineWithRadius:bfPaperCheckbox_checkboxSideLength angle:0 offset:CGPointMake(0, bfPaperCheckbox_checkboxSideLength)];
    
    if (animated) {
        {
            CABasicAnimation *lineLeftAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineLeftAnimation.removedOnCompletion = NO;
            lineLeftAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineLeftAnimation.fromValue = (__bridge id)self.lineLeft.path;
            lineLeftAnimation.toValue = (__bridge id)newLeftPath;
            [lineLeftAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineLeftAnimation setValue:leftLineStrokeAnimationName forKey:@"id"];
            lineLeftAnimation.delegate = self;
            [self.lineLeft addAnimation:lineLeftAnimation forKey:@"animateLeftLinePath"];
            
            CABasicAnimation *leftLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            leftLineColorAnimation.removedOnCompletion = NO;
            leftLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            leftLineColorAnimation.fromValue = (__bridge id)self.lineLeft.strokeColor;
            leftLineColorAnimation.toValue = (__bridge id)self.tintColor.CGColor;
            [leftLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [self.lineLeft addAnimation:leftLineColorAnimation forKey:@"animateLeftLineStrokeColor"];
        }
        {
            CABasicAnimation *lineTopAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineTopAnimation.removedOnCompletion = NO;
            lineTopAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineTopAnimation.fromValue = (__bridge id)self.lineTop.path;
            lineTopAnimation.toValue = (__bridge id)newTopPath;
            [lineTopAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineTopAnimation setValue:topLineStrokeAnimationName forKey:@"id"];
            lineTopAnimation.delegate = self;
            [self.lineTop addAnimation:lineTopAnimation forKey:@"animateTopLinePath"];
            
            CABasicAnimation *topLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            topLineColorAnimation.removedOnCompletion = NO;
            topLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            topLineColorAnimation.fromValue = (__bridge id)self.lineTop.strokeColor;
            topLineColorAnimation.toValue = (__bridge id)self.tintColor.CGColor;
            [topLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [self.lineTop addAnimation:topLineColorAnimation forKey:@"animateTopLineStrokeColor"];
        }
        {
            CABasicAnimation *lineRightAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineRightAnimation.removedOnCompletion = NO;
            lineRightAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineRightAnimation.fromValue = (__bridge id)self.lineRight.path;
            lineRightAnimation.toValue = (__bridge id)newRightPath;
            [lineRightAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineRightAnimation setValue:rightLineStrokeAnimationName forKey:@"id"];
            lineRightAnimation.delegate = self;
            [self.lineRight addAnimation:lineRightAnimation forKey:@"animateRightLinePath"];
            
            CABasicAnimation *rightLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            rightLineColorAnimation.removedOnCompletion = NO;
            rightLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            rightLineColorAnimation.fromValue = (__bridge id)self.lineRight.strokeColor;
            rightLineColorAnimation.toValue = (__bridge id)self.tintColor.CGColor;
            [rightLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [self.lineRight addAnimation:rightLineColorAnimation forKey:@"animateRightLineStrokeColor"];
        }
        {
            CABasicAnimation *lineBottomAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineBottomAnimation.removedOnCompletion = NO;
            lineBottomAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineBottomAnimation.fromValue = (__bridge id)self.lineBottom.path;
            lineBottomAnimation.toValue = (__bridge id)newBottomPath;
            [lineBottomAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineBottomAnimation setValue:bottomLineStrokeAnimationName forKey:@"id"];
            lineBottomAnimation.delegate = self;
            [self.lineBottom addAnimation:lineBottomAnimation forKey:@"animateBottomLinePath"];
            
            CABasicAnimation *bottomLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            bottomLineColorAnimation.removedOnCompletion = NO;
            bottomLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            bottomLineColorAnimation.fromValue = (__bridge id)self.lineBottom.strokeColor;
            bottomLineColorAnimation.toValue = (__bridge id)self.tintColor.CGColor;
            [bottomLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [self.lineBottom addAnimation:bottomLineColorAnimation forKey:@"animateBottomLineStrokeColor"];
        }
    }
    
    self.lineLeft.path = newLeftPath;
    self.lineTop.path = newTopPath;
    self.lineRight.path = newRightPath;
    self.lineBottom.path = newBottomPath;
    
    self.lineLeft.strokeColor = self.tintColor.CGColor;
    self.lineTop.strokeColor = self.tintColor.CGColor;
    self.lineRight.strokeColor = self.tintColor.CGColor;
    self.lineBottom.strokeColor = self.tintColor.CGColor;
    
    CGPathRelease(newLeftPath);
    CGPathRelease(newTopPath);
    CGPathRelease(newRightPath);
    CGPathRelease(newBottomPath);
}


- (void)shrinkAwayCheckboxAnimated:(BOOL)animated
// This fucntion only modyfies the checkbox. When it's animation is complete, it calls a function to draw the checkmark.
{
    self.finishedAnimations = NO;
    self.checkmarkSidesCompletedAnimating = 0;
    
    // Red dot for debugging
    /*CALayer *redDot = [[CALayer alloc] init];
    redDot.backgroundColor = [UIColor redColor].CGColor;
    redDot.frame = CGRectMake(CGRectGetMidX(self.bounds) - 3, CGRectGetMidY(self.bounds) + 11, 1, 1);
    [self.layer addSublayer:redDot];*/

    CGPathRef newLeftPath   = NULL;
    CGPathRef newTopPath    = NULL;
    CGPathRef newRightPath  = NULL;
    CGPathRef newBottomPath = NULL;
    
    CGFloat radiusDenominator = 20.f;
    CGFloat ratioDenominator = radiusDenominator * 4;
    CGFloat radius = bfPaperCheckbox_checkboxSideLength / radiusDenominator;
    CGFloat ratio = bfPaperCheckbox_checkboxSideLength / ratioDenominator;
    CGFloat offset = radius - ratio;
    CGPoint slightOffsetForCheckmarkCentering = CGPointMake(4, 9);  // Hardcoded in the most offensive way. Forgive me Father, for I have sinned.
    
    newLeftPath   = [self createCenteredLineWithRadius:radius angle:-5 * M_PI_4 offset:CGPointMake(-offset - slightOffsetForCheckmarkCentering.x, -offset + slightOffsetForCheckmarkCentering.y)];
    newTopPath    = [self createCenteredLineWithRadius:radius angle:M_PI_4 offset:CGPointMake(offset - slightOffsetForCheckmarkCentering.x, -offset + slightOffsetForCheckmarkCentering.y)];
    newRightPath  = [self createCenteredLineWithRadius:radius angle:-5 * M_PI_4 offset:CGPointMake(offset - slightOffsetForCheckmarkCentering.x, offset + slightOffsetForCheckmarkCentering.y)];
    newBottomPath = [self createCenteredLineWithRadius:radius angle:M_PI_4 offset:CGPointMake(-offset - slightOffsetForCheckmarkCentering.x, offset + slightOffsetForCheckmarkCentering.y)];
    
    if (animated) {
        {
            // LEFT:
            CABasicAnimation *lineLeftAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineLeftAnimation.removedOnCompletion = NO;
            lineLeftAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineLeftAnimation.fromValue = (__bridge id)self.lineLeft.path;
            lineLeftAnimation.toValue = (__bridge id)newLeftPath;
            [lineLeftAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            [self.lineLeft addAnimation:lineLeftAnimation forKey:@"animateLeftLinePath"];
            
            CABasicAnimation *leftLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            leftLineColorAnimation.removedOnCompletion = NO;
            leftLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            leftLineColorAnimation.fromValue = (__bridge id)self.lineLeft.strokeColor;
            leftLineColorAnimation.toValue = (__bridge id)self.checkmarkColor.CGColor;
            [leftLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [leftLineColorAnimation setValue:leftLineStrokeAnimationName2 forKey:@"id"];
            leftLineColorAnimation.delegate = self;
            [self.lineLeft addAnimation:leftLineColorAnimation forKey:@"animateLeftLineStrokeColor"];
            
        }
        {
            // TOP:
            CABasicAnimation *lineTopAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineTopAnimation.removedOnCompletion = NO;
            lineTopAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineTopAnimation.fromValue = (__bridge id)self.lineTop.path;
            lineTopAnimation.toValue = (__bridge id)newTopPath;
            [lineTopAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            [self.lineTop addAnimation:lineTopAnimation forKey:@"animateTopLinePath"];
            
            CABasicAnimation *topLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            topLineColorAnimation.removedOnCompletion = NO;
            topLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            topLineColorAnimation.fromValue = (__bridge id)self.lineTop.strokeColor;
            topLineColorAnimation.toValue = (__bridge id)self.checkmarkColor.CGColor;
            [topLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [topLineColorAnimation setValue:topLineStrokeAnimationName2 forKey:@"id"];
            topLineColorAnimation.delegate = self;
            [self.lineTop addAnimation:topLineColorAnimation forKey:@"animateTopLineStrokeColor"];
        }
        {
            // RIGHT:
            CABasicAnimation *lineRightAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineRightAnimation.removedOnCompletion = NO;
            lineRightAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineRightAnimation.fromValue = (__bridge id)self.lineRight.path;
            lineRightAnimation.toValue = (__bridge id)newRightPath;
            [lineRightAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            [self.lineRight addAnimation:lineRightAnimation forKey:@"animateRightLinePath"];
            
            CABasicAnimation *rightLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            rightLineColorAnimation.removedOnCompletion = NO;
            rightLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            rightLineColorAnimation.fromValue = (__bridge id)self.lineRight.strokeColor;
            rightLineColorAnimation.toValue = (__bridge id)self.checkmarkColor.CGColor;
            [rightLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [rightLineColorAnimation setValue:rightLineStrokeAnimationName2 forKey:@"id"];
            rightLineColorAnimation.delegate = self;
            [self.lineRight addAnimation:rightLineColorAnimation forKey:@"animateRightLineStrokeColor"];
        }
        {
            // BOTTOM:
            CABasicAnimation *lineBottomAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineBottomAnimation.removedOnCompletion = NO;
            lineBottomAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineBottomAnimation.fromValue = (__bridge id)self.lineBottom.path;
            lineBottomAnimation.toValue = (__bridge id)newBottomPath;
            [lineBottomAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            [self.lineBottom addAnimation:lineBottomAnimation forKey:@"animateBottomLinePath"];
            
            CABasicAnimation *bottomLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            bottomLineColorAnimation.removedOnCompletion = NO;
            bottomLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            bottomLineColorAnimation.fromValue = (__bridge id)self.lineBottom.strokeColor;
            bottomLineColorAnimation.toValue = (__bridge id)self.checkmarkColor.CGColor;
            [bottomLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [bottomLineColorAnimation setValue:bottomLineStrokeAnimationName2 forKey:@"id"];
            bottomLineColorAnimation.delegate = self;
            [self.lineBottom addAnimation:bottomLineColorAnimation forKey:@"animateBottomLineStrokeColor"];
        }
    }
    
    self.lineLeft.path = newLeftPath;
    self.lineTop.path = newTopPath;
    self.lineRight.path = newRightPath;
    self.lineBottom.path = newBottomPath;
    
    self.lineLeft.strokeColor = self.checkmarkColor.CGColor;
    self.lineTop.strokeColor = self.checkmarkColor.CGColor;
    self.lineRight.strokeColor = self.checkmarkColor.CGColor;
    self.lineBottom.strokeColor = self.checkmarkColor.CGColor;
    
    CGPathRelease(newLeftPath);
    CGPathRelease(newTopPath);
    CGPathRelease(newRightPath);
    CGPathRelease(newBottomPath);
}


- (void)drawCheckmarkAnimated:(BOOL)animated
{
    self.lineLeft.opacity = 0;
    self.lineTop.opacity = 0;
    
    CGPathRef newRightPath  = NULL;
    CGPathRef newBottomPath = NULL;
    
    CGFloat checkmarkSmallSideLength = bfPaperCheckbox_checkboxSideLength * 0.6f;
    CGFloat checkmarkLargeSideLength = bfPaperCheckbox_checkboxSideLength * 1.3f;
    
    CGPoint smallSideOffset = CGPointMake(-9, 5);       // Hardcoded in the most offensive way.
    CGPoint largeSideOffset = CGPointMake(3.5, 0.5);    // Hardcoded in the most offensive way. Forgive me father, for I have sinned!
    

    // Right path will become the large part of the checkmark:
    newRightPath = [self createCenteredLineWithRadius:checkmarkLargeSideLength angle:-5 * M_PI_4 offset:largeSideOffset];
    
    // Bottom path will become the small part of the checkmark:
    newBottomPath = [self createCenteredLineWithRadius:checkmarkSmallSideLength angle:M_PI_4 offset:smallSideOffset];

    if (animated) {
        {
            // RIGHT:
            CABasicAnimation *lineRightAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineRightAnimation.removedOnCompletion = NO;
            lineRightAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineRightAnimation.fromValue = (__bridge id)self.lineRight.path;
            lineRightAnimation.toValue = (__bridge id)newRightPath;
            [lineRightAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineRightAnimation setValue:largeCheckmarkLineStrokeAnimationName forKey:@"id"];
            lineRightAnimation.delegate = self;
            [self.lineRight addAnimation:lineRightAnimation forKey:@"animateRightLinePath"];
        }
        {
            // BOTTOM:
            CABasicAnimation *lineBottomAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineBottomAnimation.removedOnCompletion = NO;
            lineBottomAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineBottomAnimation.fromValue = (__bridge id)self.lineBottom.path;
            lineBottomAnimation.toValue = (__bridge id)newBottomPath;
            [lineBottomAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineBottomAnimation setValue:largeCheckmarkLineStrokeAnimationName forKey:@"id"];
            lineBottomAnimation.delegate = self;
            [self.lineBottom addAnimation:lineBottomAnimation forKey:@"animateBottomLinePath"];
        }
    }
    
    self.lineRight.path = newRightPath;
    self.lineBottom.path = newBottomPath;
    
    CGPathRelease(newRightPath);
    CGPathRelease(newBottomPath);
}


- (void)shrinkAwayCheckmarkAnimated:(BOOL)animated
// This fucntion only modyfies the checkmark. When it's animation is complete, it calls a function to draw the checkbox.
{
    self.finishedAnimations = NO;
    self.checkmarkSidesCompletedAnimating = 0;
    
    CGPathRef newRightPath  = NULL;
    CGPathRef newBottomPath = NULL;
    
    CGFloat radiusDenominator = 18.f;
    CGFloat ratioDenominator = radiusDenominator * 4;
    CGFloat radius = bfPaperCheckbox_checkboxSideLength / radiusDenominator;
    CGFloat ratio = bfPaperCheckbox_checkboxSideLength / ratioDenominator;
    CGFloat offset = radius - ratio;
    CGPoint slightOffsetForCheckmarkCentering = CGPointMake(3, 11);
    
    newRightPath = [self createCenteredLineWithRadius:radius angle:-5 * M_PI_4 offset:CGPointMake(offset - slightOffsetForCheckmarkCentering.x, offset + slightOffsetForCheckmarkCentering.y)];
    newBottomPath = [self createCenteredLineWithRadius:radius angle:M_PI_4 offset:CGPointMake(-offset - slightOffsetForCheckmarkCentering.x, offset + slightOffsetForCheckmarkCentering.y)];
    if (animated) {
        {
            // RIGHT:
            CABasicAnimation *lineRightAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineRightAnimation.removedOnCompletion = NO;
            lineRightAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineRightAnimation.fromValue = (__bridge id)self.lineRight.path;
            lineRightAnimation.toValue = (__bridge id)newRightPath;
            [lineRightAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineRightAnimation setValue:largeCheckmarkLineStrokeAnimationName2 forKey:@"id"];
            lineRightAnimation.delegate = self;
            [self.lineRight addAnimation:lineRightAnimation forKey:@"animateRightLinePath"];
            
            CABasicAnimation *rightLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            rightLineColorAnimation.removedOnCompletion = NO;
            rightLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            rightLineColorAnimation.fromValue = (__bridge id)self.lineRight.strokeColor;
            rightLineColorAnimation.toValue = (__bridge id)self.tintColor.CGColor;
            [rightLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [self.lineRight addAnimation:rightLineColorAnimation forKey:@"animateRightLineStrokeColor"];
        }
        {
            // BOTTOM:
            CABasicAnimation *lineBottomAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            lineBottomAnimation.removedOnCompletion = NO;
            lineBottomAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            lineBottomAnimation.fromValue = (__bridge id)self.lineBottom.path;
            lineBottomAnimation.toValue = (__bridge id)newBottomPath;
            [lineBottomAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [lineBottomAnimation setValue:smallCheckmarkLineAnimationName2 forKey:@"id"];
            lineBottomAnimation.delegate = self;
            [self.lineBottom addAnimation:lineBottomAnimation forKey:@"animateBottomLinePath"];
            
            CABasicAnimation *bottomLineColorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            bottomLineColorAnimation.removedOnCompletion = NO;
            bottomLineColorAnimation.duration = bfPaperCheckbox_animationDurationConstant;
            bottomLineColorAnimation.fromValue = (__bridge id)self.lineBottom.strokeColor;
            bottomLineColorAnimation.toValue = (__bridge id)self.tintColor.CGColor;
            [bottomLineColorAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
            [self.lineBottom addAnimation:bottomLineColorAnimation forKey:@"animateBottomLineStrokeColor"];
        }
    }
    
    self.lineRight.path = newRightPath;
    self.lineBottom.path = newBottomPath;
    
    self.lineLeft.strokeColor = self.tintColor.CGColor;
    self.lineTop.strokeColor = self.tintColor.CGColor;
    self.lineRight.strokeColor = self.tintColor.CGColor;
    self.lineBottom.strokeColor = self.tintColor.CGColor;
    
    CGPathRelease(newRightPath);
    CGPathRelease(newBottomPath);
}


- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag
{
    if ([[animation valueForKey:@"id"] isEqualToString:leftLineStrokeAnimationName]
        ||
        [[animation valueForKey:@"id"] isEqualToString:topLineStrokeAnimationName]
        ||
        [[animation valueForKey:@"id"] isEqualToString:rightLineStrokeAnimationName]
        ||
        [[animation valueForKey:@"id"] isEqualToString:bottomLineStrokeAnimationName]) {
        self.checkboxSidesCompletedAnimating++;
        
        if (self.checkboxSidesCompletedAnimating >= 4) {
            self.checkboxSidesCompletedAnimating = 0;
            self.finishedAnimations = YES;
            //NSLog(@"FINISHED animating 4 sides of checkbox");
        }
    }
    else if ([[animation valueForKey:@"id"] isEqualToString:leftLineStrokeAnimationName2]
             ||
             [[animation valueForKey:@"id"] isEqualToString:topLineStrokeAnimationName2]
             ||
             [[animation valueForKey:@"id"] isEqualToString:rightLineStrokeAnimationName2]
             ||
             [[animation valueForKey:@"id"] isEqualToString:bottomLineStrokeAnimationName2]) {
        self.checkboxSidesCompletedAnimating++;
        
        if (self.checkboxSidesCompletedAnimating >= 4) {
            self.checkboxSidesCompletedAnimating = 0;
            [self drawCheckmarkAnimated:YES];
        }
    }
    else if ([[animation valueForKey:@"id"] isEqualToString:smallCheckmarkLineAnimationName]
             ||
             [[animation valueForKey:@"id"] isEqualToString:largeCheckmarkLineStrokeAnimationName]) {
        self.checkmarkSidesCompletedAnimating++;
        if (self.checkmarkSidesCompletedAnimating >= 2) {
            self.checkmarkSidesCompletedAnimating = 0;
            self.finishedAnimations = YES;
            //NSLog(@"FINISHED animating 2 lines of checkmark");
        }
    }
    else if ([[animation valueForKey:@"id"] isEqualToString:smallCheckmarkLineAnimationName2]
             ||
             [[animation valueForKey:@"id"] isEqualToString:largeCheckmarkLineStrokeAnimationName2]) {
        self.checkmarkSidesCompletedAnimating++;
        if (self.checkmarkSidesCompletedAnimating >= 2) {
            self.checkmarkSidesCompletedAnimating = 0;
            [self drawCheckBoxAnimated:YES];
        }
    }

}


- (CGPathRef)createCenteredLineWithRadius:(CGFloat)radius angle:(CGFloat)angle offset:(CGPoint)offset
// you are responsible for releasing the return CGPath
{
    self.centerPoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));

    CGMutablePathRef path = CGPathCreateMutable();
    
    float c = cosf(angle);
    float s = sinf(angle);
    
    CGPathMoveToPoint(path, NULL,
                      self.centerPoint.x + offset.x + radius * c,
                      self.centerPoint.y + offset.y + radius * s);
    CGPathAddLineToPoint(path, NULL,
                         self.centerPoint.x + offset.x - radius * c,
                         self.centerPoint.y + offset.y - radius * s);
    
    return path;
}

@end