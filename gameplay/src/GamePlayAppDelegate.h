#import "GamePlayViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface GamePlayAppDelegate : UIResponder<UIApplicationDelegate>
{
    CMMotionManager *motionManager;
}
@property (nonatomic, retain) GamePlayViewController *gamePlayViewController;
@property (strong, nonatomic) UIWindow *window;

- (void)setGlobalGamePlayAppDelegate;
- (void)createGamePlayViewController;
- (void)startMotionUpdate;

@end
