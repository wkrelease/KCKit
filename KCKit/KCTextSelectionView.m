//
//  KCTextSelectionView.m
//  Jade
//
//  Created by king on 16/6/7.
//  Copyright © 2016年 KC. All rights reserved.
//

#import "KCTextSelectionView.h"
#import "KCCGUtilities.h"
#import "KCWeakProxy.h"

#define kMarkAlpha 0.2
#define kLineWidth 2.0
#define kBlinkDuration 0.5
#define kBlinkFadeDuration 0.2
#define kBlinkFirstDelay 0.1
#define kTouchTestExtend 14.0
#define kTouchDotExtend 7.0



@implementation KCSelectionGrabberDot

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.userInteractionEnabled = NO;
    self.mirror = [UIView new];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat length = MIN(self.bounds.size.width, self.bounds.size.height);
    self.layer.cornerRadius = length * 0.5;
    self.mirror.bounds = self.bounds;
    self.mirror.layer.cornerRadius = self.layer.cornerRadius;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    _mirror.backgroundColor = backgroundColor;
}

@end






@implementation KCSelectionGrabber

- (instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _dot = [[KCSelectionGrabberDot alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    return self;
}

- (void)setDotDirection:(KCTextDirection)dotDirection {
    _dotDirection = dotDirection;
    [self addSubview:_dot];
    CGRect frame = _dot.frame;
    CGFloat ofs = 0.5;
    if (dotDirection == KCTextDirectionTop) {
        frame.origin.y = -frame.size.height + ofs;
        frame.origin.x = (self.bounds.size.width - frame.size.width) / 2;
    } else if (dotDirection == KCTextDirectionRight) {
        frame.origin.x = self.bounds.size.width - ofs;
        frame.origin.y = (self.bounds.size.height - frame.size.height) / 2;
    } else if (dotDirection == KCTextDirectionBottom) {
        frame.origin.y = self.bounds.size.height - ofs;
        frame.origin.x = (self.bounds.size.width - frame.size.width) / 2;
    } else if (dotDirection == KCTextDirectionLeft) {
        frame.origin.x = -frame.size.width + ofs;
        frame.origin.y = (self.bounds.size.height - frame.size.height) / 2;
    } else {
        [_dot removeFromSuperview];
    }
    _dot.frame = frame;
}

- (void)setColor:(UIColor *)color {
    self.backgroundColor = color;
    _dot.backgroundColor = color;
    _color = color;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setDotDirection:_dotDirection];
}

- (CGRect)touchRect {
    CGRect rect = CGRectInset(self.frame, -kTouchTestExtend, -kTouchTestExtend);
    UIEdgeInsets insets = {0};
    if (_dotDirection == KCTextDirectionTop) {
        insets.top = -kTouchDotExtend;
    } else if (_dotDirection == KCTextDirectionRight) {
        insets.right = -kTouchDotExtend;
    } else if (_dotDirection == KCTextDirectionBottom) {
        insets.bottom = -kTouchDotExtend;
    } else if (_dotDirection == KCTextDirectionLeft) {
        insets.left = -kTouchDotExtend;
    }
    rect = UIEdgeInsetsInsetRect(rect, insets);
    return rect;
}

@end








@interface KCTextSelectionView ()
@property (nonatomic, strong) NSTimer *caretTimer;
@property (nonatomic, strong) UIView *caretView;
@property (nonatomic, strong) KCSelectionGrabber *startGrabber;
@property (nonatomic, strong) KCSelectionGrabber *endGrabber;
@property (nonatomic, strong) NSMutableArray *markViews;
@end
@implementation KCTextSelectionView


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.userInteractionEnabled = NO;
    self.clipsToBounds = NO;
    _markViews = [NSMutableArray array];
    _caretView = [UIView new];
    _caretView.hidden = YES;
    _startGrabber = [KCSelectionGrabber new];
    _startGrabber.dotDirection = KCTextDirectionTop;
    _startGrabber.hidden = YES;
    _endGrabber = [KCSelectionGrabber new];
    _endGrabber.dotDirection = KCTextDirectionBottom;
    _endGrabber.hidden = YES;
    
    [self addSubview:_startGrabber];
    [self addSubview:_endGrabber];
    [self addSubview:_caretView];
    
    return self;
}

- (void)dealloc {
    [_caretTimer invalidate];
}

- (void)setColor:(UIColor *)color {
    _color = color;
    self.caretView.backgroundColor = color;
    self.startGrabber.color = color;
    self.endGrabber.color = color;
    [self.markViews enumerateObjectsUsingBlock: ^(UIView *v, NSUInteger idx, BOOL *stop) {
        v.backgroundColor = color;
    }];
}

- (void)setCaretBlinks:(BOOL)caretBlinks {
    if (_caretBlinks != caretBlinks) {
        _caretView.alpha = 1;
        [self.class cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startBlinks) object:nil];
        if (caretBlinks) {
            [self performSelector:@selector(_startBlinks) withObject:nil afterDelay:kBlinkFirstDelay];
        } else {
            [_caretTimer invalidate];
            _caretTimer = nil;
        }
        _caretBlinks = caretBlinks;
    }
}

- (void)_startBlinks {
    [_caretTimer invalidate];
    if (_caretVisible) {
        _caretTimer = [NSTimer timerWithTimeInterval:kBlinkDuration target:[KCWeakProxy proxyWithTarget:self] selector:@selector(_doBlink) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_caretTimer forMode:NSDefaultRunLoopMode];
    } else {
        _caretView.alpha = 1;
    }
}

- (void)_doBlink {
    [UIView animateWithDuration:kBlinkFadeDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations: ^{
        if (_caretView.alpha == 1) _caretView.alpha = 0;
        else _caretView.alpha = 1;
    } completion:NULL];
}

- (void)setCaretVisible:(BOOL)caretVisible {
    _caretVisible = caretVisible;
    self.caretView.hidden = !caretVisible;
    _caretView.alpha = 1;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startBlinks) object:nil];
    if (_caretBlinks) {
        [self performSelector:@selector(_startBlinks) withObject:nil afterDelay:kBlinkFirstDelay];
    }
}

- (void)setVerticalForm:(BOOL)verticalForm {
    if (_verticalForm != verticalForm) {
        _verticalForm = verticalForm;
        [self setCaretRect:_caretRect];
        self.startGrabber.dotDirection = verticalForm ? KCTextDirectionRight : KCTextDirectionTop;
        self.endGrabber.dotDirection = verticalForm ? KCTextDirectionLeft : KCTextDirectionBottom;
    }
}

- (CGRect)_standardCaretRect:(CGRect)caretRect {
    caretRect = CGRectStandardize(caretRect);
    if (_verticalForm) {
        if (caretRect.size.height == 0) {
            caretRect.size.height = kLineWidth;
            caretRect.origin.y -= kLineWidth * 0.5;
        }
        if (caretRect.origin.y < 0) {
            caretRect.origin.y = 0;
        } else if (caretRect.origin.y + caretRect.size.height > self.bounds.size.height) {
            caretRect.origin.y = self.bounds.size.height - caretRect.size.height;
        }
    } else {
        if (caretRect.size.width == 0) {
            caretRect.size.width = kLineWidth;
            caretRect.origin.x -= kLineWidth * 0.5;
        }
        if (caretRect.origin.x < 0) {
            caretRect.origin.x = 0;
        } else if (caretRect.origin.x + caretRect.size.width > self.bounds.size.width) {
            caretRect.origin.x = self.bounds.size.width - caretRect.size.width;
        }
    }
    caretRect = CGRectPixelRound(caretRect);
    if (isnan(caretRect.origin.x) || isinf(caretRect.origin.x)) caretRect.origin.x = 0;
    if (isnan(caretRect.origin.y) || isinf(caretRect.origin.y)) caretRect.origin.y = 0;
    if (isnan(caretRect.size.width) || isinf(caretRect.size.width)) caretRect.size.width = 0;
    if (isnan(caretRect.size.height) || isinf(caretRect.size.height)) caretRect.size.height = 0;
    return caretRect;
}

- (void)setCaretRect:(CGRect)caretRect {
    _caretRect = caretRect;
    self.caretView.frame = [self _standardCaretRect:caretRect];
}

- (void)setSelectionRects:(NSArray *)selectionRects {
    _selectionRects = selectionRects.copy;
    [self.markViews enumerateObjectsUsingBlock: ^(UIView *v, NSUInteger idx, BOOL *stop) {
        [v removeFromSuperview];
    }];
    [self.markViews removeAllObjects];
    self.startGrabber.hidden = YES;
    self.endGrabber.hidden = YES;
    
    [selectionRects enumerateObjectsUsingBlock: ^(KCTextSelectionRect *r, NSUInteger idx, BOOL *stop) {
        CGRect rect = r.rect;
        rect = CGRectStandardize(rect);
        rect = CGRectPixelRound(rect);
        if (r.containsStart || r.containsEnd) {
            rect = [self _standardCaretRect:rect];
            if (r.containsStart) {
                self.startGrabber.hidden = NO;
                self.startGrabber.frame = rect;
            }
            if (r.containsEnd) {
                self.endGrabber.hidden = NO;
                self.endGrabber.frame = rect;
            }
        } else {
            if (rect.size.width > 0 && rect.size.height > 0) {
                UIView *mark = [[UIView alloc] initWithFrame:rect];
                mark.backgroundColor = _color;
                mark.alpha = kMarkAlpha;
                [self insertSubview:mark atIndex:0];
                [self.markViews addObject:mark];
            }
        }
    }];
}

- (BOOL)isGrabberContainsPoint:(CGPoint)point {
    return [self isStartGrabberContainsPoint:point] || [self isEndGrabberContainsPoint:point];
}

- (BOOL)isStartGrabberContainsPoint:(CGPoint)point {
    if (_startGrabber.hidden) return NO;
    CGRect startRect = [_startGrabber touchRect];
    CGRect endRect = [_endGrabber touchRect];
    if (CGRectIntersectsRect(startRect, endRect)) {
        CGFloat distStart = CGPointGetDistanceToPoint(point, CGRectGetCenter(startRect));
        CGFloat distEnd = CGPointGetDistanceToPoint(point, CGRectGetCenter(endRect));
        if (distEnd <= distStart) return NO;
    }
    return CGRectContainsPoint(startRect, point);
}

- (BOOL)isEndGrabberContainsPoint:(CGPoint)point {
    if (_endGrabber.hidden) return NO;
    CGRect startRect = [_startGrabber touchRect];
    CGRect endRect = [_endGrabber touchRect];
    if (CGRectIntersectsRect(startRect, endRect)) {
        CGFloat distStart = CGPointGetDistanceToPoint(point, CGRectGetCenter(startRect));
        CGFloat distEnd = CGPointGetDistanceToPoint(point, CGRectGetCenter(endRect));
        if (distEnd > distStart) return NO;
    }
    return CGRectContainsPoint(endRect, point);
}

- (BOOL)isCaretContainsPoint:(CGPoint)point {
    if (_caretVisible) {
        CGRect rect = CGRectInset(_caretRect, -kTouchTestExtend, -kTouchTestExtend);
        return CGRectContainsPoint(rect, point);
    }
    return NO;
}

- (BOOL)isSelectionRectsContainsPoint:(CGPoint)point {
    if (_selectionRects.count == 0) return NO;
    for (KCTextSelectionRect *rect in _selectionRects) {
        if (CGRectContainsPoint(rect.rect, point)) return YES;
    }
    return NO;
}



@end
