#import "GamePlayViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface GamePlayAppDelegate : UIResponder<UIApplicationDelegate>
{
    UIWindow* window;
    GamePlayViewController* viewController;
    CMMotionManager *motionManager;
}
@property (nonatomic, retain) GamePlayViewController *viewController;

@end
