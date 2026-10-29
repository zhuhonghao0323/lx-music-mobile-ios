//
//  LXUserApiModule.m
//  Android 侧：userApi/{UserApiModule,QuickJS,JavaScriptThread,JsHandler,UtilsEvent}.java
//
//  作用：在原生侧运行「自定义音源脚本」，脚本通过 lx.request 发起请求，
//  原生把请求转交给 JS 线程（RN 侧）真正发 HTTP，再把结果回灌给脚本。
//
//  iOS 用系统内置的 JavaScriptCore 替代 Android 的 QuickJS：
//    - 不需要额外编译 third-party C 库，TrollStore / 自签场景下包体更小、更稳
//    - preload 脚本（user-api-preload.js）原样复用，宿主 API 契约 100% 对齐
//    - 注入的 7 个 __lx_native_call__* 函数与 Android QuickJS.java 一一对应
//
//  线程模型：
//    Android 为脚本单开一条 JavaScriptThread；iOS 用一条串行 dispatch queue，
//    所有 JSContext 操作都在这条队列上，避免 JSC 跨线程访问导致崩溃。
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "LXCryptoUtil.h"

static NSString *const LXUserApiEventName = @"api-action";
/// 用于识别当前是否已经处在脚本队列上，避免 invalidate 时 dispatch_sync 自锁
static void *LXUserApiQueueKey = &LXUserApiQueueKey;

@interface LXUserApiModule : RCTEventEmitter <RCTBridgeModule>
@end

@implementation LXUserApiModule {
  dispatch_queue_t _queue;
  JSContext *_context;
  NSString *_scriptKey;
  /// 每次 loadScript 自增，用于让上一次脚本残留的定时器失效
  NSUInteger _generation;
  BOOL _observing;
  NSMutableArray<NSDictionary *> *_pendingEvents;
  NSLock *_pendingLock;
}

RCT_EXPORT_MODULE(UserApiModule)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (instancetype)init {
  if (self = [super init]) {
    _queue = dispatch_queue_create("com.lxmusic.userapi", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_queue, LXUserApiQueueKey, (__bridge void *)self, NULL);
    _pendingEvents = [NSMutableArray array];
    _pendingLock = [[NSLock alloc] init];
    _generation = 0;
  }
  return self;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[LXUserApiEventName];
}

- (void)startObserving {
  _observing = YES;
  NSArray<NSDictionary *> *pending;
  [_pendingLock lock];
  pending = [_pendingEvents copy];
  [_pendingEvents removeAllObjects];
  [_pendingLock unlock];

  // 脚本往往在 JS 注册监听器之前就发出了 init 事件，
  // Android 侧这种情况会直接丢掉事件，这里补一个队列保证首屏能收到。
  for (NSDictionary *payload in pending) {
    [self sendEventWithName:LXUserApiEventName body:payload];
  }
}

- (void)stopObserving {
  _observing = NO;
}

#pragma mark - 事件发送

- (void)emitPayload:(NSDictionary *)payload {
  BOOL shouldSend;
  [_pendingLock lock];
  shouldSend = _observing;
  if (!shouldSend) {
    [_pendingEvents addObject:payload];
    // 防止脚本疯狂打日志把内存撑爆
    if (_pendingEvents.count > 200) [_pendingEvents removeObjectAtIndex:0];
  }
  [_pendingLock unlock];

  if (!shouldSend) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self sendEventWithName:LXUserApiEventName body:payload];
  });
}

/// 对应 Android JsHandler.sendActionEvent
- (void)emitAction:(NSString *)action data:(NSString *)data {
  [self emitPayload:@{ @"action": action ?: @"", @"data": data ?: @"null" }];
}

/// 对应 Android JsHandler.sendLogEvent
- (void)emitLog:(NSString *)type message:(NSString *)message {
  [self emitPayload:@{
    @"action": @"log",
    @"type": type ?: @"log",
    @"log": message ?: @"",
  }];
}

- (void)emitInitFailed:(NSString *)message {
  [self emitPayload:@{
    @"action": @"init",
    @"errorMessage": message ?: @"",
    @"data": @"{ \"info\": null, \"status\": false, \"errorMessage\": \"Create JavaScript Env Failed\" }",
  }];
  [self emitLog:@"error" message:message];
}

#pragma mark - 宿主 API 注入

- (NSString *)preloadScriptSource {
  // pod 的 resources 会被复制进 main bundle；若被放进 framework bundle 也兼容
  NSArray<NSBundle *> *bundles = @[
    [NSBundle mainBundle],
    [NSBundle bundleForClass:[self class]],
  ];
  for (NSBundle *bundle in bundles) {
    NSURL *url = [bundle URLForResource:@"user-api-preload" withExtension:@"js"];
    if (url == nil) continue;
    NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    if (source.length > 0) return source;
  }
  return nil;
}

/// 注入 console：preload 会冻结 globalThis，因此必须在 evaluate preload 之前完成
- (void)installConsole:(JSContext *)context {
  __weak typeof(self) weakSelf = self;
  context[@"__lx_console__"] = ^(JSValue *level, JSValue *message) {
    NSString *type = [level toString] ?: @"log";
    NSString *text = [message toString] ?: @"";
    if (text.length > 2048) text = [[text substringToIndex:2048] stringByAppendingString:@"..."];
    [weakSelf emitLog:type message:text];
  };

  NSString *bootstrap =
    @"(function(){"
     "var raw = globalThis.__lx_console__;"
     "delete globalThis.__lx_console__;"
     "var stringify = function(v){"
     "  try {"
     "    if (typeof v === 'string') return v;"
     "    if (v instanceof Error) return v.stack || v.message || String(v);"
     "    if (typeof v === 'object' && v !== null) return JSON.stringify(v);"
     "    return String(v);"
     "  } catch (e) { return '[unserializable]'; }"
     "};"
     "var make = function(level){"
     "  return function(){"
     "    var parts = [];"
     "    for (var i = 0; i < arguments.length; i++) parts.push(stringify(arguments[i]));"
     "    raw(level, parts.join(' '));"
     "  };"
     "};"
     "globalThis.console = {"
     "  log: make('log'), info: make('info'), warn: make('warn'),"
     "  error: make('error'), debug: make('debug')"
     "};"
     "})();";
  [context evaluateScript:bootstrap];
}

/// 注入 Android QuickJS.java 里那 7 个原生函数
- (void)installNativeFunctions:(JSContext *)context {
  __weak typeof(self) weakSelf = self;

  // __lx_native_call__(key, action, data)：脚本 -> 原生
  context[@"__lx_native_call__"] = ^JSValue *(JSValue *key, JSValue *action, JSValue *data) {
    // 注意：不能用 __typeof__(weakSelf)，它展开后仍是 __weak，
    // 通过 weak 指针访问 ivar 会被 clang 拒绝（-Warc-unsafe-retained-assign）。
    LXUserApiModule *strongSelf = weakSelf;
    if (strongSelf == nil) return nil;
    if (![[key toString] isEqualToString:strongSelf->_scriptKey]) return nil;
    NSString *actionName = [action toString] ?: @"";
    NSString *payload = data.isUndefined || data.isNull ? nil : [data toString];
    // emitAction 内部已经切到主线程，这里不用再包一层
    [strongSelf emitAction:actionName data:payload];
    return nil;
  };

  // utils_str2b64(str)：UTF-8 字符串 -> base64
  context[@"__lx_native_call__utils_str2b64"] = ^JSValue *(JSValue *value) {
    NSString *text = [value toString] ?: @"";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    return [JSValue valueWithObject:[data base64EncodedStringWithOptions:0]
                          inContext:[JSContext currentContext]];
  };

  // utils_b642buf(b64)：base64 -> JSON 数组字符串
  // 注意 Android 侧 (int) byte 是有符号的（-128..127），这里必须保持一致，
  // 否则 preload 里 new Uint8Array(...) 得到的字节值会全部错位。
  context[@"__lx_native_call__utils_b642buf"] = ^JSValue *(JSValue *value) {
    NSString *text = [value toString] ?: @"";
    NSData *data = [[NSData alloc] initWithBase64EncodedString:text
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (data == nil) return [JSValue valueWithObject:@"" inContext:[JSContext currentContext]];

    const int8_t *bytes = (const int8_t *)data.bytes;
    NSMutableString *json = [NSMutableString stringWithCapacity:data.length * 4];
    [json appendString:@"["];
    for (NSUInteger i = 0; i < data.length; i++) {
      if (i > 0) [json appendString:@","];
      [json appendFormat:@"%d", (int)bytes[i]];
    }
    [json appendString:@"]"];
    return [JSValue valueWithObject:json inContext:[JSContext currentContext]];
  };

  // utils_str2md5(str)：先 URL 解码再 MD5（与 Android URLDecoder + MessageDigest 一致）
  context[@"__lx_native_call__utils_str2md5"] = ^JSValue *(JSValue *value) {
    NSString *encoded = [value toString] ?: @"";
    NSString *decoded = [encoded stringByRemovingPercentEncoding] ?: encoded;
    NSData *data = [decoded dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    return [JSValue valueWithObject:[LXCryptoUtil md5Hex:data] inContext:[JSContext currentContext]];
  };

  // utils_aes_encrypt(dataB64, keyB64, ivB64, mode) -> base64
  context[@"__lx_native_call__utils_aes_encrypt"] = ^JSValue *(JSValue *dataValue, JSValue *keyValue,
                                                               JSValue *ivValue, JSValue *modeValue) {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:[dataValue toString] ?: @""
                                                      options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *key = [[NSData alloc] initWithBase64EncodedString:[keyValue toString] ?: @""
                                                      options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *iv = [[NSData alloc] initWithBase64EncodedString:[ivValue toString] ?: @""
                                                     options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSString *mode = [modeValue toString] ?: @"AES";
    NSData *result = [LXCryptoUtil aesEncrypt:data ?: [NSData data] key:key ?: [NSData data] iv:iv mode:mode];
    return [JSValue valueWithObject:[result base64EncodedStringWithOptions:0] ?: @""
                          inContext:[JSContext currentContext]];
  };

  // utils_rsa_encrypt(dataB64, keyB64, padding) -> base64
  context[@"__lx_native_call__utils_rsa_encrypt"] = ^JSValue *(JSValue *dataValue, JSValue *keyValue,
                                                               JSValue *paddingValue) {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:[dataValue toString] ?: @""
                                                      options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *key = [[NSData alloc] initWithBase64EncodedString:[keyValue toString] ?: @""
                                                      options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSString *padding = [paddingValue toString] ?: @"RSA/ECB/NoPadding";
    NSData *result = [LXCryptoUtil rsaEncrypt:data ?: [NSData data]
                                 publicKeyDer:key ?: [NSData data]
                                      padding:padding
                                        error:nil];
    return [JSValue valueWithObject:[result base64EncodedStringWithOptions:0] ?: @""
                          inContext:[JSContext currentContext]];
  };

  // set_timeout(id, ms)：preload 只负责登记回调，由原生负责在 ms 后回调 __set_timeout__
  context[@"__lx_native_call__set_timeout"] = ^JSValue *(JSValue *idValue, JSValue *delayValue) {
    // 注意：不能用 __typeof__(weakSelf)，它展开后仍是 __weak，
    // 通过 weak 指针访问 ivar 会被 clang 拒绝（-Warc-unsafe-retained-assign）。
    LXUserApiModule *strongSelf = weakSelf;
    if (strongSelf == nil) return nil;
    int identifier = [idValue toInt32];
    int delay = [delayValue toInt32];
    if (delay < 0) delay = 0;
    NSUInteger generation = strongSelf->_generation;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay * NSEC_PER_MSEC),
                   strongSelf->_queue, ^{
      LXUserApiModule *strong = weakSelf;
      if (strong == nil) return;
      // 脚本已被替换/销毁，旧定时器直接丢弃
      if (generation != strong->_generation) return;
      [strong invokeJSFunction:@"__lx_native__"
                     arguments:@[strong->_scriptKey ?: @"",
                                 @"__set_timeout__",
                                 [NSString stringWithFormat:@"%d", identifier]]];
    });
    return nil;
  };
}

#pragma mark - JS 调用

/// 调用 JS 全局函数，异常统一转成 log 事件
- (JSValue *)invokeJSFunction:(NSString *)name arguments:(NSArray *)arguments {
  JSContext *context = _context;
  if (context == nil) return nil;
  JSValue *function = context[name];
  if (function == nil || function.isUndefined) return nil;
  return [function callWithArguments:arguments];
}

- (void)handleException:(JSValue *)exception {
  NSString *message = @"Unknown error";
  if (exception != nil && !exception.isUndefined) {
    NSString *stack = [[exception objectForKeyedSubscript:@"stack"] toString];
    message = stack.length > 0 ? stack : ([exception toString] ?: message);
  }
  if (message.length > 1024) message = [[message substringToIndex:1024] stringByAppendingString:@"..."];
  [self emitLog:@"error" message:[NSString stringWithFormat:@"Call script error: %@", message]];
}

#pragma mark - 对外方法

RCT_EXPORT_METHOD(loadScript:(NSDictionary *)info) {
  dispatch_async(_queue, ^{
    [self loadScriptOnQueue:info];
  });
}

- (void)loadScriptOnQueue:(NSDictionary *)info {
  _generation += 1;
  [self teardownContext];

  NSString *script = info[@"script"];
  if (![script isKindOfClass:[NSString class]] || script.length == 0) {
    [self emitInitFailed:@"脚本内容为空"];
    return;
  }

  NSString *preload = [self preloadScriptSource];
  if (preload == nil) {
    [self emitInitFailed:@"找不到 user-api-preload.js 资源，请确认 pod 的 resources 已正确打包"];
    return;
  }

  _scriptKey = [[NSUUID UUID] UUIDString];

  JSContext *context = [[JSContext alloc] init];
  _context = context;

  __weak typeof(self) weakSelf = self;
  context.exceptionHandler = ^(JSContext *ctx, JSValue *exception) {
    [weakSelf handleException:exception];
  };

  [self installConsole:context];
  [self installNativeFunctions:context];

  JSValue *preloadResult = [context evaluateScript:preload];
  if (preloadResult == nil || context.exception != nil) {
    NSString *reason = [[context.exception toString] copy] ?: @"preload 脚本执行失败";
    context.exception = nil;
    [self emitInitFailed:reason];
    return;
  }

  JSValue *setup = context[@"lx_setup"];
  if (setup == nil || setup.isUndefined) {
    [self emitInitFailed:@"preload 未导出 lx_setup"];
    return;
  }

  NSArray *setupArguments = @[
    _scriptKey,
    [self stringOrEmpty:info[@"id"]],
    [self stringOrEmpty:info[@"name"] default:@"Unknown"],
    [self stringOrEmpty:info[@"description"]],
    [self stringOrEmpty:info[@"version"]],
    [self stringOrEmpty:info[@"author"]],
    [self stringOrEmpty:info[@"homepage"]],
    script,
  ];
  [setup callWithArguments:setupArguments];
  if (context.exception != nil) {
    NSString *reason = [[context.exception toString] copy] ?: @"lx_setup 执行失败";
    context.exception = nil;
    [self emitInitFailed:reason];
    return;
  }

  JSValue *scriptResult = [context evaluateScript:script];
  if (scriptResult == nil || context.exception != nil) {
    NSString *reason = [[context.exception toString] copy] ?: @"脚本执行失败";
    context.exception = nil;
    // 与 Android 行为一致：先通知脚本运行出错，再上报
    [self invokeJSFunction:@"__lx_native__"
                 arguments:@[_scriptKey, @"__run_error__"]];
    [self emitLog:@"error" message:[NSString stringWithFormat:@"load script error: %@", reason]];
    return;
  }
}

- (NSString *)stringOrEmpty:(id)value {
  return [self stringOrEmpty:value default:@""];
}

- (NSString *)stringOrEmpty:(id)value default:(NSString *)fallback {
  if ([value isKindOfClass:[NSString class]]) return value;
  if (value == nil || value == [NSNull null]) return fallback;
  return [value description] ?: fallback;
}

RCT_EXPORT_METHOD(sendAction:(NSString *)action info:(NSString *)info) {
  dispatch_async(_queue, ^{
    if (self->_context == nil) return;
    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:self->_scriptKey ?: @"", action ?: @"", nil];
    // preload 里 __lx_native__ 会对第三个参数做 JSON.parse，
    // 因此这里必须原样传字符串，不能提前解析。
    if (info != nil) [arguments addObject:info];
    [self invokeJSFunction:@"__lx_native__" arguments:arguments];
  });
}

RCT_EXPORT_METHOD(destroy) {
  dispatch_async(_queue, ^{
    self->_generation += 1;
    [self teardownContext];
  });
}

- (void)teardownContext {
  if (_context == nil) return;
  _context.exceptionHandler = nil;
  // 主动断开引用，让 JSC 上下文尽快释放
  _context = nil;
  _scriptKey = nil;
}

- (void)invalidate {
  void (^teardown)(void) = ^{
    self->_generation += 1;
    [self teardownContext];
  };
  if (dispatch_get_specific(LXUserApiQueueKey) == (__bridge void *)self) {
    teardown();
  } else {
    dispatch_sync(_queue, teardown);
  }
  [super invalidate];
}

@end
