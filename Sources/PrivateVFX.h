#import <UIKit/UIKit.h>
// Selectors verified against the installed macOS 27 WeatherUI / VFX runtime.
@interface NSObject (WeatherVFX)
- (instancetype)initWithContentsOf:(NSURL *)url options:(id)options error:(NSError **)error;
- (void)setScene:(id)scene;
- (id)scene;
- (void)setPreferredFramesPerSecond:(NSInteger)fps;
- (void)setPixelFormat:(NSUInteger)format;
- (void)setRendersContinuously:(BOOL)enabled;
- (void)setIsPlaying:(BOOL)playing;
- (void)setPaused:(BOOL)paused;
- (void)_allowGPUBackgroundExecution;
- (void)prepare;
- (id)parameterOf:(NSString *)object named:(NSString *)name;
- (void)setParameterOf:(NSString *)object named:(NSString *)name :(id)value;
- (void)withPointerToParameterOf:(NSString *)object named:(NSString *)name block:(void (^)(void *))block;
- (void)beginTransaction;
- (void)endTransaction;
- (void)setEnabled:(NSString *)object enabled:(BOOL)enabled;
- (id)effects;
- (id)addEffectFromTemplate:(id)scene;
- (id)addEffectWithEffectID:(int)identifier;
- (id)cameras;
- (id)snapshot;
@end
