//
//  LXCryptoModule.m
//  Android 侧：crypto/CryptoModule.java
//
//  用于「歌单同步」的握手与消息加密（见 src/plugins/sync/utils.ts），
//  以及音源脚本里的 AES/RSA 工具函数。
//

#import <React/RCTBridgeModule.h>
#import "LXCryptoUtil.h"

/// 宽松的 base64 解码：PEM 文本里含换行，Java 的 Base64.decode 会忽略空白字符，
/// iOS 默认解码器遇到换行会直接失败，因此必须显式忽略未知字符，否则同步握手必挂。
static NSData *LXDataFromBase64(NSString *text) {
  if (text.length == 0) return [NSData data];
  return [[NSData alloc] initWithBase64EncodedString:text
                                             options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

@interface LXCryptoModule : NSObject <RCTBridgeModule>
@end

@implementation LXCryptoModule

RCT_EXPORT_MODULE(CryptoModule)

+ (BOOL)requiresMainQueueSetup { return NO; }

RCT_EXPORT_METHOD(generateRsaKey:(RCTPromiseResolveBlock)resolve
                         rejecter:(RCTPromiseRejectBlock)reject) {
  NSError *error = nil;
  NSDictionary *keyPair = [LXCryptoUtil generateRsaKeyPairWithBits:2048 error:&error];
  if (keyPair == nil) {
    reject(@"-1", error.localizedDescription ?: @"RSA 密钥生成失败", error);
    return;
  }
  resolve(keyPair);
}

RCT_EXPORT_METHOD(rsaEncrypt:(NSString *)text
                       key:(NSString *)key
                   padding:(NSString *)padding
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSData *data = LXDataFromBase64(text);
  NSData *keyData = LXDataFromBase64(key);
  NSError *error = nil;
  NSData *result = [LXCryptoUtil rsaEncrypt:data publicKeyDer:keyData padding:padding error:&error];
  if (result == nil) {
    reject(@"-2", error.localizedDescription ?: @"RSA 加密失败", error);
    return;
  }
  resolve([result base64EncodedStringWithOptions:0]);
}

RCT_EXPORT_METHOD(rsaDecrypt:(NSString *)text
                       key:(NSString *)key
                   padding:(NSString *)padding
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSData *data = LXDataFromBase64(text);
  NSData *keyData = LXDataFromBase64(key);
  NSError *error = nil;
  NSData *result = [LXCryptoUtil rsaDecrypt:data privateKeyDer:keyData padding:padding error:&error];
  if (result == nil) {
    reject(@"-3", error.localizedDescription ?: @"RSA 解密失败", error);
    return;
  }
  resolve([result base64EncodedStringWithOptions:0]);
}

// 同步方法：同步模块的握手流程是同步调用的，必须保持同步语义。
// 项目 newArchEnabled=false（旧架构 Bridge），RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD 可用。
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaEncryptSync:(NSString *)text
                                                  key:(NSString *)key
                                              padding:(NSString *)padding) {
  NSData *result = [LXCryptoUtil rsaEncrypt:LXDataFromBase64(text)
                               publicKeyDer:LXDataFromBase64(key)
                                    padding:padding
                                      error:nil];
  return result == nil ? @"" : [result base64EncodedStringWithOptions:0];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaDecryptSync:(NSString *)text
                                                  key:(NSString *)key
                                              padding:(NSString *)padding) {
  NSData *result = [LXCryptoUtil rsaDecrypt:LXDataFromBase64(text)
                              privateKeyDer:LXDataFromBase64(key)
                                    padding:padding
                                      error:nil];
  return result == nil ? @"" : [result base64EncodedStringWithOptions:0];
}

RCT_EXPORT_METHOD(aesEncrypt:(NSString *)text
                       key:(NSString *)key
                        iv:(NSString *)iv
                      mode:(NSString *)mode
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSData *result = [LXCryptoUtil aesEncrypt:LXDataFromBase64(text)
                                        key:LXDataFromBase64(key)
                                         iv:LXDataFromBase64(iv)
                                       mode:mode];
  if (result == nil) {
    reject(@"-4", @"AES 加密失败", nil);
    return;
  }
  resolve([result base64EncodedStringWithOptions:0]);
}

RCT_EXPORT_METHOD(aesDecrypt:(NSString *)text
                       key:(NSString *)key
                        iv:(NSString *)iv
                      mode:(NSString *)mode
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSData *result = [LXCryptoUtil aesDecrypt:LXDataFromBase64(text)
                                        key:LXDataFromBase64(key)
                                         iv:LXDataFromBase64(iv)
                                       mode:mode];
  if (result == nil) {
    reject(@"-5", @"AES 解密失败", nil);
    return;
  }
  resolve([result base64EncodedStringWithOptions:0]);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesEncryptSync:(NSString *)text
                                                  key:(NSString *)key
                                                   iv:(NSString *)iv
                                                 mode:(NSString *)mode) {
  NSData *result = [LXCryptoUtil aesEncrypt:LXDataFromBase64(text)
                                        key:LXDataFromBase64(key)
                                         iv:LXDataFromBase64(iv)
                                       mode:mode];
  return result == nil ? @"" : [result base64EncodedStringWithOptions:0];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesDecryptSync:(NSString *)text
                                                  key:(NSString *)key
                                                   iv:(NSString *)iv
                                                 mode:(NSString *)mode) {
  NSData *result = [LXCryptoUtil aesDecrypt:LXDataFromBase64(text)
                                        key:LXDataFromBase64(key)
                                         iv:LXDataFromBase64(iv)
                                       mode:mode];
  return result == nil ? @"" : [result base64EncodedStringWithOptions:0];
}

RCT_EXPORT_METHOD(sha1:(NSString *)input
               resolver:(RCTPromiseResolveBlock)resolve
               rejecter:(RCTPromiseRejectBlock)reject) {
  NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
  resolve([LXCryptoUtil sha1Hex:data]);
}

@end
