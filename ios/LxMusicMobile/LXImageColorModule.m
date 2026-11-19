//
//  LXImageColorModule.m
//
//  封面主色提取（动态背景用）。
//  - 下载/加载封面图片（系统缓存 + ImageIO 优先）
//  - CIAreaAverage 计算平均色（iOS 官方 API，GPU/CI 加速，开销极低）
//  - 回调返回 { r, g, b } 或空
//
// 用 Objective-C 实现，避免 Swift 桥接头引入 Yoga 的编译冲突。
//

#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>

@interface LXImageColorModule : NSObject <RCTBridgeModule>
@end

@implementation LXImageColorModule

RCT_EXPORT_MODULE(LXImageColor);

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

/** 把 UIImage 缩到极小再求平均色，避免大图解码开销 */
static UIColor * LXAverageColor(UIImage *image)
{
  if (!image) return nil;

  CIImage *ciImage = [[CIImage alloc] initWithImage:image];
  if (!ciImage) {
    ciImage = [[CIImage alloc] initWithCGImage:image.CGImage];
  }
  if (!ciImage) return nil;

  // CIAreaAverage 默认对整个 extent 求平均
  CIFilter *filter = [CIFilter filterWithName:@"CIAreaAverage"
                                keysAndValues:kCIInputImageKey, ciImage, nil];
  CIImage *output = filter.outputImage;
  if (!output) return nil;

  // 输出是 1x1 像素，渲染出来读颜色
  CGRect extent = output.extent;
  size_t width = (size_t)extent.size.width;
  size_t height = (size_t)extent.size.height;
  if (width == 0 || height == 0) return nil;

  uint8_t bitmap[4] = {0, 0, 0, 0};
  CIContext *context = [CIContext contextWithOptions:nil];
  [context render:output
         toBitmap:bitmap
         rowBytes:4
           bounds:CGRectMake(0, 0, 1, 1)
           format:kCIFormatRGBA8
       colorSpace:CGColorSpaceCreateDeviceRGB()];

  return [UIColor colorWithRed:bitmap[0] / 255.0
                         green:bitmap[1] / 255.0
                          blue:bitmap[2] / 255.0
                         alpha:1.0];
}

RCT_EXPORT_METHOD(averageColor:(NSString *)url
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (!url || url.length == 0) {
    resolve((id)[NSNull null]);
    return;
  }

  // 先在内存/磁盘缓存找（NSURLCache 由 RN 网络层管理，这里再兜一层简单缓存）
  static NSCache *imageCache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    imageCache = [[NSCache alloc] init];
    imageCache.countLimit = 60;
  });

  NSString *cacheKey = url;
  UIImage *cached = [imageCache objectForKey:cacheKey];
  if (cached) {
    UIColor *color = LXAverageColor(cached);
    if (color) {
      CGFloat r = 0, g = 0, b = 0, a = 0;
      [color getRed:&r green:&g blue:&b alpha:&a];
      resolve(@{ @"r": @(round(r * 255)), @"g": @(round(g * 255)), @"b": @(round(b * 255)) });
      return;
    }
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSURL *urlObj = [NSURL URLWithString:url];
    if (!urlObj) {
      dispatch_async(dispatch_get_main_queue(), ^{
        resolve((id)[NSNull null]);
      });
      return;
    }

    NSData *data = [NSData dataWithContentsOfURL:urlObj];
    UIImage *image = data ? [UIImage imageWithData:data] : nil;
    if (!image) {
      dispatch_async(dispatch_get_main_queue(), ^{
        resolve((id)[NSNull null]);
      });
      return;
    }

    [imageCache setObject:image forKey:cacheKey];

    // 缩到 64x64 再取平均色，性能足够且颜色更平滑
    CGSize target = CGSizeMake(64, 64);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
    UIImage *small = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
      [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    }];

    UIColor *color = LXAverageColor(small);
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [color getRed:&r green:&g blue:&b alpha:&a];

    dispatch_async(dispatch_get_main_queue(), ^{
      resolve(@{ @"r": @(round(r * 255)), @"g": @(round(g * 255)), @"b": @(round(b * 255)) });
    });
  });
}

@end
