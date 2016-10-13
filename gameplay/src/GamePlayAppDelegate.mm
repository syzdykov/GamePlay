#import "GamePlayAppDelegate.h"
#import "PlatformIOS.h"
#import "GamePlayViewController.h"

@implementation GamePlayAppDelegate
@synthesize viewController, window;

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    __appDelegate = self;
    [UIApplication sharedApplication].statusBarHidden = YES;
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [self startMotionUpdate];
    
    window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    viewController = [self createGamePlayViewController];
    [window setRootViewController:viewController];
    [window makeKeyAndVisible];
    return YES;
}

- (void)startMotionUpdate
{
    motionManager = [[CMMotionManager alloc] init];
    if([motionManager isAccelerometerAvailable] == YES)
    {
        motionManager.accelerometerUpdateInterval = 1 / 40.0;    // 40Hz
        [motionManager startAccelerometerUpdates];
    }
    if([motionManager isGyroAvailable] == YES)
    {
        motionManager.gyroUpdateInterval = 1 / 40.0;    // 40Hz
        [motionManager startGyroUpdates];
    }
}

- (GamePlayViewController *)createGamePlayViewController
{
    return [[GamePlayViewController alloc] init];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)getAccelerometerPitch:(float*)pitch roll:(float*)roll
{
    float p = 0.0f;
    float r = 0.0f;
    CMAccelerometerData* accelerometerData = motionManager.accelerometerData;
    if(accelerometerData != nil)
    {
        float tx, ty, tz;
        
        switch ([[UIApplication sharedApplication] statusBarOrientation])
        {
            case UIInterfaceOrientationLandscapeRight:
                tx = -accelerometerData.acceleration.y;
                ty = accelerometerData.acceleration.x;
                break;
                
            case UIInterfaceOrientationLandscapeLeft:
                tx = accelerometerData.acceleration.y;
                ty = -accelerometerData.acceleration.x;
                break;
                
            case UIInterfaceOrientationPortraitUpsideDown:
                tx = -accelerometerData.acceleration.y;
                ty = -accelerometerData.acceleration.x;
                break;
                
            case UIInterfaceOrientationPortrait:
                tx = accelerometerData.acceleration.x;
                ty = accelerometerData.acceleration.y;
                break;
        }
        tz = accelerometerData.acceleration.z;
        
        p = atan(ty / sqrt(tx * tx + tz * tz)) * 180.0f * M_1_PI;
        r = atan(tx / sqrt(ty * ty + tz * tz)) * 180.0f * M_1_PI;
    }
    
    if(pitch != NULL)
        *pitch = p;
    if(roll != NULL)
        *roll = r;
}

- (void)getRawAccelX:(float*)x Y:(float*)y Z:(float*)z
{
    CMAccelerometerData* accelerometerData = motionManager.accelerometerData;
    if(accelerometerData != nil)
    {
        *x = -9.81f * accelerometerData.acceleration.x;
        *y = -9.81f * accelerometerData.acceleration.y;
        *z = -9.81f * accelerometerData.acceleration.z;
    }
}

- (void)getRawGyroX:(float*)x Y:(float*)y Z:(float*)z
{
    CMGyroData* gyroData = motionManager.gyroData;
    if(gyroData != nil)
    {
        *x = gyroData.rotationRate.x;
        *y = gyroData.rotationRate.y;
        *z = gyroData.rotationRate.z;
    }
}

- (void)applicationWillResignActive:(UIApplication*)application
{
    [viewController stopUpdating];
}

- (void)applicationDidEnterBackground:(UIApplication*)application
{
    [viewController stopUpdating];
}

- (void)applicationWillEnterForeground:(UIApplication*)application
{
    [viewController startUpdating];
}

- (void)applicationDidBecomeActive:(UIApplication*)application
{
    [viewController startUpdating];
}

- (void)applicationWillTerminate:(UIApplication*)application
{
    [viewController stopUpdating];
}

- (void)dealloc
{
    [window setRootViewController:nil];
    [viewController release];
    [window release];
    [motionManager release];
    [super dealloc];
}


@end
