#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

@interface GamePlayViewController : UIViewController

- (void)startUpdating;
- (void)stopUpdating;
- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController;

+ (GamePlayViewController *)shared;

@end
