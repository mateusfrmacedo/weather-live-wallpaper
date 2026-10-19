#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface WWSceneExporter : NSObject
@property(nonatomic,readonly) BOOL busy;
- (void)exportView:(UIView *)view gradient:(CAGradientLayer *)gradient metadata:(NSDictionary *)metadata completion:(void(^)(NSError *error))completion;
@end
