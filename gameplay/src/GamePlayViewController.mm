#import "GamePlayViewController.h"
#import "GamePlayView.h"
#import "PlatformIOS.h"

@interface GamePlayViewController ()

@end

@implementation GamePlayViewController
- (id)init
{
    if((self = [super init]))
    {
    }
    return self;
}

- (void)dealloc
{
    __view = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle
- (void)loadView
{
    self.view = [[[GamePlayView alloc] init] autorelease];
    if(__view == nil)
    {
        __view = (GamePlayView*)self.view;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Fetch the supported orientations array
    NSArray *supportedOrientations = NULL;
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        supportedOrientations = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations~ipad"];
    }
    else if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        supportedOrientations = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations~iphone"];
    }
    
    if(supportedOrientations == NULL)
    {
        supportedOrientations = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations"];
    }
    
    // If no supported orientations default to v1.0 handling (landscape only)
    if(supportedOrientations == nil) {
        return UIInterfaceOrientationIsLandscape(interfaceOrientation);
    }
    for(NSString *s in supportedOrientations) {
        if(interfaceOrientation == UIInterfaceOrientationEnum(s)) return YES;
    }
    return NO;
}

- (void)startUpdating
{
    [(GamePlayView*)self.view startUpdating];
}

- (void)stopUpdating
{
    [(GamePlayView*)self.view stopUpdating];
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
