//
//  KCImage.m
//  Jade
//
//  Created by king on 16/5/16.
//  Copyright © 2016年 KC. All rights reserved.
//

#import "KCImage.h"
#import "NSString+KCAdd.h"
#import "NSBundle+KCAdd.h"
#import <libkern/OSAtomic.h>

@implementation KCImage{
    
    KCImageDecoder *_decoder;
    NSArray *_preloadedFrames;
    OSSpinLock _preloadedLock;
    NSUInteger _bytesPerFrame;
    
}

+ (KCImage *)imageNamed:(NSString *)name {
    if (name.length == 0) return nil;
    if ([name hasSuffix:@"/"]) return nil;
    
    NSString *res = name.stringByDeletingPathExtension;
    NSString *ext = name.pathExtension;
    NSString *path = nil;
    CGFloat scale = 1;
    
    NSArray *scales = [NSBundle preferredScales];
    for (int s = 0; s < scales.count; s++) {
        scale = ((NSNumber *)scales[s]).floatValue;
        NSString *scaledName = [res stringByAppendingNameScale:scale];
        // If no extension, guess by system supported (same as UIImage).
        NSArray *exts = ext.length > 0 ? @[ext] : @[@"", @"png", @"jpeg", @"jpg", @"gif", @"webp"];
        for (NSString *e in exts) {
            path = [[NSBundle mainBundle] pathForResource:scaledName ofType:e];
            if (path) break;
        }
        if (path) break;
    }
    if (path.length == 0) return nil;
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) return nil;
    
    return [[self alloc] initWithData:data scale:scale];
}

+ (KCImage *)imageWithContentsOfFile:(NSString *)path {
    return [[self alloc] initWithContentsOfFile:path];
}

+ (KCImage *)imageWithData:(NSData *)data {
    return [[self alloc] initWithData:data];
}

+ (KCImage *)imageWithData:(NSData *)data scale:(CGFloat)scale {
    return [[self alloc] initWithData:data scale:scale];
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [self initWithData:data scale:path.pathScale];
}

- (instancetype)initWithData:(NSData *)data {
    return [self initWithData:data scale:1];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale {
    if (data.length == 0) return nil;
    if (scale <= 0) scale = [UIScreen mainScreen].scale;
    _preloadedLock = OS_SPINLOCK_INIT;
    @autoreleasepool {
        KCImageDecoder *decoder = [KCImageDecoder decoderWithData:data scale:scale];
        KCImageFrame *frame = [decoder frameAtIndex:0 decodeForDisplay:YES];
        UIImage *image = frame.image;
        if (!image) return nil;
        self = [self initWithCGImage:image.CGImage scale:decoder.scale orientation:image.imageOrientation];
        if (!self) return nil;
        _animatedImageType = decoder.type;
        if (decoder.frameCount > 1) {
            _decoder = decoder;
            _bytesPerFrame = CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage);
            _animatedImageMemorySize = _bytesPerFrame * decoder.frameCount;
        }
        self.isDecodedForDisplay = YES;
    }
    return self;
}

- (NSData *)animatedImageData {
    return _decoder.data;
}

- (void)setPreloadAllAnimatedImageFrames:(BOOL)preloadAllAnimatedImageFrames {
    if (_preloadAllAnimatedImageFrames != preloadAllAnimatedImageFrames) {
        if (preloadAllAnimatedImageFrames && _decoder.frameCount > 0) {
            NSMutableArray *frames = [NSMutableArray new];
            for (NSUInteger i = 0, max = _decoder.frameCount; i < max; i++) {
                UIImage *img = [self animatedImageFrameAtIndex:i];
                if (img) {
                    [frames addObject:img];
                } else {
                    [frames addObject:[NSNull null]];
                }
            }
            OSSpinLockLock(&_preloadedLock);
            _preloadedFrames = frames;
            OSSpinLockUnlock(&_preloadedLock);
        } else {
            OSSpinLockLock(&_preloadedLock);
            _preloadedFrames = nil;
            OSSpinLockUnlock(&_preloadedLock);
        }
    }
}

#pragma mark - protocol NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSNumber *scale = [aDecoder decodeObjectForKey:@"KCImageScale"];
    NSData *data = [aDecoder decodeObjectForKey:@"KCImageData"];
    if (data.length) {
        self = [self initWithData:data scale:scale.doubleValue];
    } else {
        self = [super initWithCoder:aDecoder];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    if (_decoder.data.length) {
        [aCoder encodeObject:@(self.scale) forKey:@"KCImageScale"];
        [aCoder encodeObject:_decoder.data forKey:@"KCImageData"];
    } else {
        [super encodeWithCoder:aCoder]; // Apple use UIImagePNGRepresentation() to encode UIImage.
    }
}

#pragma mark - protocol KCAnimatedImage

- (NSUInteger)animatedImageFrameCount {
    return _decoder.frameCount;
}

- (NSUInteger)animatedImageLoopCount {
    return _decoder.loopCount;
}

- (NSUInteger)animatedImageBytesPerFrame {
    return _bytesPerFrame;
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    if (index >= _decoder.frameCount) return nil;
    OSSpinLockLock(&_preloadedLock);
    UIImage *image = _preloadedFrames[index];
    OSSpinLockUnlock(&_preloadedLock);
    if (image) return image == (id)[NSNull null] ? nil : image;
    return [_decoder frameAtIndex:index decodeForDisplay:YES].image;
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    NSTimeInterval duration = [_decoder frameDurationAtIndex:index];
    
    /*
     http://opensource.apple.com/source/WebCore/WebCore-7600.1.25/platform/graphics/cg/ImageSourceCG.cpp
     Many annoying ads specify a 0 duration to make an image flash as quickly as
     possible. We follow Safari and Firefox's behavior and use a duration of 100 ms
     for any frames that specify a duration of <= 10 ms.
     See <rdar://problem/7689300> and <http://webkit.org/b/36082> for more information.
     
     See also: http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser.
     */
    if (duration < 0.011f) return 0.100f;
    return duration;
}

@end
