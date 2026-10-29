//
//  LXCryptoUtil.h
//  洛雪音乐 iOS —— 加密工具层
//
//  Android 侧对应实现：android/app/src/main/java/cn/toside/music/mobile/crypto/{AES,RSA}.java
//  iOS 侧用系统 Security.framework + CommonCrypto 重写，对外行为保持一致：
//    - 输入输出一律 base64
//    - AES 支持 CBC/PKCS7、ECB/PKCS7（Java 的 "AES" 默认值）、ECB/NoPadding
//    - RSA 支持 OAEP-SHA1 与 Raw(NoPadding)
//    - RSA 密钥编码沿用 Android 的 X.509(公钥) / PKCS#8(私钥) DER
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LXCryptoUtil : NSObject

/// AES 加密。mode 取 Android 侧的 cipher 名称，语义逐一对齐。
/// @param mode "AES/CBC/PKCS7Padding" | "AES" | "AES/ECB/NoPadding"
/// @return 密文；失败返回 nil
+ (nullable NSData *)aesEncrypt:(NSData *)data
                            key:(NSData *)key
                             iv:(nullable NSData *)iv
                           mode:(NSString *)mode;

/// AES 解密，mode 语义同加密。
+ (nullable NSData *)aesDecrypt:(NSData *)data
                            key:(NSData *)key
                             iv:(nullable NSData *)iv
                           mode:(NSString *)mode;

/// MD5 十六进制小写
+ (NSString *)md5Hex:(NSData *)data;

/// SHA1 十六进制小写
+ (NSString *)sha1Hex:(NSData *)data;

/// RSA 公钥加密。keyDerBase64 为 Android 使用的 X.509 SubjectPublicKeyInfo（也兼容裸 PKCS#1）。
/// @param padding "RSA/ECB/OAEPWithSHA1AndMGF1Padding" | "RSA/ECB/NoPadding"
+ (nullable NSData *)rsaEncrypt:(NSData *)data
                  publicKeyDer:(NSData *)keyDer
                       padding:(NSString *)padding
                         error:(NSError **)error;

/// RSA 私钥解密。keyDerBase64 为 Android 使用的 PKCS#8（也兼容裸 PKCS#1）。
+ (nullable NSData *)rsaDecrypt:(NSData *)data
                 privateKeyDer:(NSData *)keyDer
                       padding:(NSString *)padding
                         error:(NSError **)error;

/// 生成 RSA 密钥对，返回 @{ @"publicKey": base64(X.509 DER), @"privateKey": base64(PKCS#8 DER) }
/// 与 Android CryptoModule.generateRsaKey 的返回结构一致。
+ (nullable NSDictionary<NSString *, NSString *> *)generateRsaKeyPairWithBits:(NSUInteger)bits
                                                                        error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
