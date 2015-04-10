//
//  BrightnessController.m
//  Lumen
//
//  Created by Anish Athalye on 4/10/15.
//  Copyright (c) 2015 Anish Athalye. All rights reserved.
//

#import "BrightnessController.h"
#import "Constants.h"
#import "util.h"
#import <IOKit/graphics/IOGraphicsLib.h>
#import <ApplicationServices/ApplicationServices.h>

@interface BrightnessController ()

@property (nonatomic, strong) NSTimer *timer;

- (void)tick:(NSTimer *)timer;
- (float)getBrightness;
- (void)setBrightness:(float) level;
- (CGImageRef)getScreenContents;
- (double)computeBrightness:(CGImageRef) image;

@end

@implementation BrightnessController

- (BOOL)isRunning {
    return self.timer && [self.timer isValid];
}

- (void)start {
    if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:TICK_INTERVAL
                                                  target:self
                                                selector:@selector(tick:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)tick:(NSTimer *)timer {
    CGImageRef contents = [self getScreenContents];
    if (contents) {
        double brightness = [self computeBrightness:contents];
        CFRelease(contents);
        double computed = clip(linear_interpolate(20, 0.8, 95, 0.3, brightness), 0, 1);
        [self setBrightness:computed];
    }
}

- (double)computeBrightness:(CGImageRef) image {
    CFDataRef dataRef = CGDataProviderCopyData(CGImageGetDataProvider(image));
    const unsigned char *data = CFDataGetBytePtr(dataRef);

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

    double brightness = 0;
    const unsigned int kSkip = 16; // uniformly sample screen pixels
    // find RMS brightness value
    if (data) {
        for (size_t y = 0; y < height; y += kSkip) {
            for (size_t x = 0; x < width; x += kSkip) {
                const unsigned char *dptr = &data[(width * y + x) * 4];
                double l = srgb_to_brightness(dptr[0], dptr[1], dptr[2]);

                brightness += l * l;
            }
        }
    }
    brightness = sqrt(brightness / (width * height / (kSkip * kSkip)));

    CFRelease(dataRef);

    return brightness;
}

- (CGImageRef)getScreenContents {
    CGImageRef imageRef = CGDisplayCreateImage(kCGDirectMainDisplay);
    return imageRef;
}

- (float)getBrightness {
    float level = 1.0f;
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                        IOServiceMatching("IODisplayConnect"),
                                                        &iterator);
    if (result == kIOReturnSuccess) {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &level);
            IOObjectRelease(service);
        }
    }
    return level;
}

- (void)setBrightness:(float)level {
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                        IOServiceMatching("IODisplayConnect"),
                                                        &iterator);
    if (result == kIOReturnSuccess) {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            IODisplaySetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), level);
            IOObjectRelease(service);
        }
    }
}

@end
