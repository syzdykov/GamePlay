#import "GamePlayViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface GamePlayAppDelegate : UIResponder<UIApplicationDelegate>
{
    GamePlayViewController* viewController;
    CMMotionManager *motionManager;
}
@property (nonatomic, retain) GamePlayViewController *viewController;
@property (strong, nonatomic) UIWindow *window;

@end
