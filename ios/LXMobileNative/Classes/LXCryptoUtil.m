//
//  LXCryptoUtil.m
//

#import "LXCryptoUtil.h"
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

static NSString *const LXCryptoErrorDomain = @"LXCryptoErrorDomain";

static NSError *LXError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:LXCryptoErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey: message ?: @"crypto error"}];
}

#pragma mark - 最小 DER 编解码
//
// Android 侧用 java.security 的 X509EncodedKeySpec / PKCS8EncodedKeySpec，
// 即公钥是 X.509 SubjectPublicKeyInfo、私钥是 PKCS#8。
// 而 iOS 的 SecKeyCreateWithData / SecKeyCopyExternalRepresentation 只认裸 PKCS#1，
// 所以这里必须自己做一层 DER 包装与解包。硬编码前缀只能覆盖 2048 位，
// 因此实现成通用的 TLV 编解码，任意密钥长度都能正确处理。

typedef struct {
  uint8_t tag;
  NSUInteger headerLength;  // tag + length 字段的总字节数
  NSUInteger contentLength;
  NSUInteger contentOffset; // 相对传入 offset 的绝对偏移
} LXTLV;

/// 读取一个 TLV 头。成功返回 YES。
static BOOL LXReadTLV(NSData *data, NSUInteger offset, LXTLV *out) {
  if (offset >= data.length) return NO;
  const uint8_t *bytes = (const uint8_t *)data.bytes;

  uint8_t tag = bytes[offset];
  NSUInteger cursor = offset + 1;
  if (cursor >= data.length) return NO;

  uint8_t first = bytes[cursor++];
  NSUInteger length = 0;
  if ((first & 0x80) == 0) {
    length = first;
  } else {
    NSUInteger byteCount = first & 0x7F;
    // DER 长度字段最多 4 字节，超过视为非法
    if (byteCount == 0 || byteCount > 4) return NO;
    if (cursor + byteCount > data.length) return NO;
    for (NSUInteger i = 0; i < byteCount; i++) {
      length = (length << 8) | bytes[cursor++];
    }
  }

  if (cursor + length > data.length) return NO;

  out->tag = tag;
  out->headerLength = cursor - offset;
  out->contentLength = length;
  out->contentOffset = cursor;
  return YES;
}

static NSData *LXDERLength(NSUInteger length) {
  NSMutableData *result = [NSMutableData data];
  if (length < 0x80) {
    uint8_t b = (uint8_t)length;
    [result appendBytes:&b length:1];
    return result;
  }
  uint8_t tmp[8];
  int count = 0;
  NSUInteger value = length;
  while (value > 0) {
    tmp[count++] = (uint8_t)(value & 0xFF);
    value >>= 8;
  }
  uint8_t tag = (uint8_t)(0x80 | count);
  [result appendBytes:&tag length:1];
  for (int i = count - 1; i >= 0; i--) {
    [result appendBytes:&tmp[i] length:1];
  }
  return result;
}

static NSData *LXDERWrap(uint8_t tag, NSData *content) {
  NSMutableData *result = [NSMutableData data];
  [result appendBytes:&tag length:1];
  [result appendData:LXDERLength(content.length)];
  [result appendData:content];
  return result;
}

static NSData *LXDERSequence(NSArray<NSData *> *items) {
  NSMutableData *content = [NSMutableData data];
  for (NSData *item in items) [content appendData:item];
  return LXDERWrap(0x30, content);
}

static NSData *LXDERBitString(NSData *content) {
  // BIT STRING 首字节表示 unused bits，密钥数据恒为 0
  NSMutableData *payload = [NSMutableData dataWithBytes:"\0" length:1];
  [payload appendData:content];
  return LXDERWrap(0x03, payload);
}

static NSData *LXDEROctetString(NSData *content) {
  return LXDERWrap(0x04, content);
}

static NSData *LXDERIntegerZero(void) {
  uint8_t zero = 0;
  return LXDERWrap(0x02, [NSData dataWithBytes:&zero length:1]);
}

static NSData *LXDERNull(void) {
  return LXDERWrap(0x05, [NSData data]);
}

static NSData *LXDEROIDRSAEncryption(void) {
  // 1.2.840.113549.1.1.1
  static const uint8_t oid[] = {0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01};
  return LXDERWrap(0x06, [NSData dataWithBytes:oid length:sizeof(oid)]);
}

/// 从 X.509 SubjectPublicKeyInfo 或裸 PKCS#1 中取出 PKCS#1 RSAPublicKey
static NSData *LXExtractPKCS1PublicKey(NSData *der) {
  LXTLV outer;
  if (!LXReadTLV(der, 0, &outer) || outer.tag != 0x30) return nil;

  LXTLV first;
  if (!LXReadTLV(der, outer.contentOffset, &first)) return nil;

  // 裸 PKCS#1：SEQUENCE { INTEGER modulus, INTEGER exponent }
  if (first.tag == 0x02) return der;

  // X.509：SEQUENCE { AlgorithmIdentifier, BIT STRING }
  if (first.tag != 0x30) return nil;
  NSUInteger afterAlg = first.contentOffset + first.contentLength;

  LXTLV bitString;
  if (!LXReadTLV(der, afterAlg, &bitString) || bitString.tag != 0x03) return nil;
  if (bitString.contentLength < 1) return nil;

  // 跳过 unused-bits 字节
  return [der subdataWithRange:NSMakeRange(bitString.contentOffset + 1, bitString.contentLength - 1)];
}

/// 从 PKCS#8 或裸 PKCS#1 中取出 PKCS#1 RSAPrivateKey
static NSData *LXExtractPKCS1PrivateKey(NSData *der) {
  LXTLV outer;
  if (!LXReadTLV(der, 0, &outer) || outer.tag != 0x30) return nil;

  LXTLV first;
  if (!LXReadTLV(der, outer.contentOffset, &first)) return nil;

  // 裸 PKCS#1：SEQUENCE { INTEGER version, INTEGER modulus, ... }
  // 与 PKCS#8 的区别在于 PKCS#8 的第二个元素是 AlgorithmIdentifier(SEQUENCE)，
  // 而 PKCS#1 的第二个元素仍是 INTEGER，这里靠元素个数与类型判断。
  if (first.tag == 0x02) {
    NSUInteger secondOffset = first.contentOffset + first.contentLength;
    LXTLV second;
    if (LXReadTLV(der, secondOffset, &second) && second.tag == 0x02) return der;
  }

  // PKCS#8：SEQUENCE { INTEGER 0, AlgorithmIdentifier, OCTET STRING }
  NSUInteger cursor = outer.contentOffset;
  LXTLV item;
  if (!LXReadTLV(der, cursor, &item) || item.tag != 0x02) return nil;
  cursor = item.contentOffset + item.contentLength;

  if (!LXReadTLV(der, cursor, &item) || item.tag != 0x30) return nil;
  cursor = item.contentOffset + item.contentLength;

  if (!LXReadTLV(der, cursor, &item) || item.tag != 0x04) return nil;
  return [der subdataWithRange:NSMakeRange(item.contentOffset, item.contentLength)];
}

#pragma mark - AES

@implementation LXCryptoUtil

+ (NSData *)aesRun:(CCOperation)operation
              data:(NSData *)data
               key:(NSData *)key
                iv:(NSData *)iv
              mode:(NSString *)mode {
  if (data.length == 0) return [NSData data];
  if (key.length != kCCKeySizeAES128 && key.length != kCCKeySizeAES192 && key.length != kCCKeySizeAES256) {
    return nil;
  }

  BOOL isECB;
  BOOL usePKCS7;
  if ([mode isEqualToString:@"AES/CBC/PKCS7Padding"]) {
    isECB = NO;
    usePKCS7 = YES;
  } else if ([mode isEqualToString:@"AES/ECB/NoPadding"]) {
    isECB = YES;
    usePKCS7 = NO;
  } else {
    // Java 的 Cipher.getInstance("AES") 等价于 AES/ECB/PKCS5Padding，
    // 而 PKCS5 在 16 字节分组下与 PKCS7 完全一致，这里必须保持一致，
    // 否则与 Android 侧算出的密文对不上。
    isECB = YES;
    usePKCS7 = YES;
  }

  CCOptions options = 0;
  if (isECB) options |= kCCOptionECBMode;
  if (usePKCS7) options |= kCCOptionPKCS7Padding;

  // Android 的 AES.java 会把 iv 补齐/截断到 16 字节，不足部分填 0
  uint8_t ivBuffer[kCCBlockSizeAES128] = {0};
  if (!isECB) {
    NSUInteger copyLength = MIN(iv.length, (NSUInteger)kCCBlockSizeAES128);
    if (copyLength > 0) [iv getBytes:ivBuffer length:copyLength];
  }

  size_t bufferSize = data.length + kCCBlockSizeAES128;
  void *buffer = malloc(bufferSize);
  if (buffer == NULL) return nil;

  size_t moved = 0;
  CCCryptorStatus status = CCCrypt(operation,
                                   kCCAlgorithmAES,
                                   options,
                                   key.bytes,
                                   key.length,
                                   isECB ? NULL : ivBuffer,
                                   data.bytes,
                                   data.length,
                                   buffer,
                                   bufferSize,
                                   &moved);

  if (status != kCCSuccess) {
    free(buffer);
    return nil;
  }

  NSData *result = [NSData dataWithBytes:buffer length:moved];
  free(buffer);
  return result;
}

+ (NSData *)aesEncrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv mode:(NSString *)mode {
  return [self aesRun:kCCEncrypt data:data key:key iv:iv mode:mode];
}

+ (NSData *)aesDecrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv mode:(NSString *)mode {
  return [self aesRun:kCCDecrypt data:data key:key iv:iv mode:mode];
}

#pragma mark - 摘要

+ (NSString *)hexStringFromBytes:(const uint8_t *)bytes length:(NSUInteger)length {
  NSMutableString *result = [NSMutableString stringWithCapacity:length * 2];
  for (NSUInteger i = 0; i < length; i++) {
    [result appendFormat:@"%02x", bytes[i]];
  }
  return result;
}

+ (NSString *)md5Hex:(NSData *)data {
  unsigned char digest[CC_MD5_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CC_MD5(data.bytes, (CC_LONG)data.length, digest);
#pragma clang diagnostic pop
  return [self hexStringFromBytes:digest length:CC_MD5_DIGEST_LENGTH];
}

+ (NSString *)sha1Hex:(NSData *)data {
  unsigned char digest[CC_SHA1_DIGEST_LENGTH];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
#pragma clang diagnostic pop
  return [self hexStringFromBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

#pragma mark - RSA

+ (SecKeyRef)copyPublicKeyFromDER:(NSData *)der error:(NSError **)error {
  NSData *pkcs1 = LXExtractPKCS1PublicKey(der);
  if (pkcs1 == nil) {
    if (error) *error = LXError(-1, @"无法解析 RSA 公钥（期望 X.509 或 PKCS#1 DER）");
    return NULL;
  }
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
  };
  CFErrorRef cfError = NULL;
  SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)pkcs1, (__bridge CFDictionaryRef)attrs, &cfError);
  if (key == NULL) {
    if (error) *error = CFBridgingRelease(cfError) ?: LXError(-2, @"RSA 公钥加载失败");
    return NULL;
  }
  return key;
}

+ (SecKeyRef)copyPrivateKeyFromDER:(NSData *)der error:(NSError **)error {
  NSData *pkcs1 = LXExtractPKCS1PrivateKey(der);
  if (pkcs1 == nil) {
    if (error) *error = LXError(-3, @"无法解析 RSA 私钥（期望 PKCS#8 或 PKCS#1 DER）");
    return NULL;
  }
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPrivate,
  };
  CFErrorRef cfError = NULL;
  SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)pkcs1, (__bridge CFDictionaryRef)attrs, &cfError);
  if (key == NULL) {
    if (error) *error = CFBridgingRelease(cfError) ?: LXError(-4, @"RSA 私钥加载失败");
    return NULL;
  }
  return key;
}

+ (SecKeyAlgorithm)algorithmForPadding:(NSString *)padding {
  if ([padding isEqualToString:@"RSA/ECB/OAEPWithSHA1AndMGF1Padding"]) {
    return kSecKeyAlgorithmRSAEncryptionOAEPSHA1;
  }
  // Android 的 "RSA/ECB/NoPadding" 对应 iOS 的 Raw 算法。
  // 注意 Raw 不做任何填充，输入长度必须正好等于模长，这一点与 Java 行为一致。
  return kSecKeyAlgorithmRSAEncryptionRaw;
}

+ (NSData *)rsaEncrypt:(NSData *)data
          publicKeyDer:(NSData *)keyDer
               padding:(NSString *)padding
                 error:(NSError **)error {
  NSError *keyError = nil;
  SecKeyRef key = [self copyPublicKeyFromDER:keyDer error:&keyError];
  if (key == NULL) {
    if (error) *error = keyError;
    return nil;
  }
  SecKeyAlgorithm algorithm = [self algorithmForPadding:padding];
  // 不做 SecKeyIsAlgorithmSupported 预检：个别系统版本对 Raw 算法会误报不支持，
  // 直接尝试加密，失败时再按真实错误返回。
  CFErrorRef cfError = NULL;
  CFDataRef encrypted = SecKeyCreateEncryptedData(key, algorithm, (__bridge CFDataRef)data, &cfError);
  CFRelease(key);
  if (encrypted == NULL) {
    if (error) *error = CFBridgingRelease(cfError) ?: LXError(-6, @"RSA 加密失败");
    return nil;
  }
  return CFBridgingRelease(encrypted);
}

+ (NSData *)rsaDecrypt:(NSData *)data
         privateKeyDer:(NSData *)keyDer
               padding:(NSString *)padding
                 error:(NSError **)error {
  NSError *keyError = nil;
  SecKeyRef key = [self copyPrivateKeyFromDER:keyDer error:&keyError];
  if (key == NULL) {
    if (error) *error = keyError;
    return nil;
  }
  SecKeyAlgorithm algorithm = [self algorithmForPadding:padding];
  CFErrorRef cfError = NULL;
  CFDataRef decrypted = SecKeyCreateDecryptedData(key, algorithm, (__bridge CFDataRef)data, &cfError);
  CFRelease(key);
  if (decrypted == NULL) {
    if (error) *error = CFBridgingRelease(cfError) ?: LXError(-8, @"RSA 解密失败");
    return nil;
  }
  return CFBridgingRelease(decrypted);
}

+ (NSDictionary<NSString *, NSString *> *)generateRsaKeyPairWithBits:(NSUInteger)bits
                                                               error:(NSError **)error {
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeySizeInBits: @(bits),
  };
  CFErrorRef cfError = NULL;
  SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attrs, &cfError);
  if (privateKey == NULL) {
    if (error) *error = CFBridgingRelease(cfError) ?: LXError(-9, @"RSA 密钥生成失败");
    return nil;
  }

  SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
  if (publicKey == NULL) {
    CFRelease(privateKey);
    if (error) *error = LXError(-10, @"导出 RSA 公钥失败");
    return nil;
  }

  CFErrorRef pubError = NULL;
  CFDataRef pubPKCS1 = SecKeyCopyExternalRepresentation(publicKey, &pubError);
  CFRelease(publicKey);
  if (pubPKCS1 == NULL) {
    CFRelease(privateKey);
    if (error) *error = CFBridgingRelease(pubError) ?: LXError(-11, @"导出 RSA 公钥数据失败");
    return nil;
  }

  CFErrorRef privError = NULL;
  CFDataRef privPKCS1 = SecKeyCopyExternalRepresentation(privateKey, &privError);
  CFRelease(privateKey);
  if (privPKCS1 == NULL) {
    CFRelease(pubPKCS1);
    if (error) *error = CFBridgingRelease(privError) ?: LXError(-12, @"导出 RSA 私钥数据失败");
    return nil;
  }

  NSData *publicDER = LXDERSequence(@[
    LXDERSequence(@[LXDEROIDRSAEncryption(), LXDERNull()]),
    LXDERBitString((__bridge NSData *)pubPKCS1),
  ]);
  NSData *privateDER = LXDERSequence(@[
    LXDERIntegerZero(),
    LXDERSequence(@[LXDEROIDRSAEncryption(), LXDERNull()]),
    LXDEROctetString((__bridge NSData *)privPKCS1),
  ]);
  CFRelease(pubPKCS1);
  CFRelease(privPKCS1);

  return @{
    @"publicKey": [publicDER base64EncodedStringWithOptions:0],
    @"privateKey": [privateDER base64EncodedStringWithOptions:0],
  };
}

@end
