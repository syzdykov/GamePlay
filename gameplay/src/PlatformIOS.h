#ifndef platformios_h
#define platformios_h

#import <QuartzCore/QuartzCore.h>
#import "GamePlayAppDelegate.h"
#import "GamePlayView.h"

#define TOUCH_POINTS_MAX (10)
#define GESTURE_LONG_PRESS_DURATION_MIN 0.2
#define GESTURE_LONG_PRESS_DISTANCE_MIN 10

#define UIInterfaceOrientationEnum(x) ([x isEqualToString:@"UIInterfaceOrientationPortrait"]?UIInterfaceOrientationPortrait:                        \
                                        ([x isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]?UIInterfaceOrientationPortraitUpsideDown:    \
                                        ([x isEqualToString:@"UIInterfaceOrientationLandscapeLeft"]?UIInterfaceOrientationLandscapeLeft:              \
                                        UIInterfaceOrientationLandscapeRight)))

class TouchPoint
{
public:
    unsigned int hashId;
    int x;
    int y;
    bool down;
    
    TouchPoint()
    {
        hashId = 0;
        x = 0;
        y = 0;
        down = false;
    }
};

extern double __timeStart;
extern TouchPoint __touchPoints[TOUCH_POINTS_MAX];
double getMachTimeInMilliseconds();
int getKey(unichar keyCode);
int getUnicode(int key);
extern const int WINDOW_SCALE;
extern long __gestureLongTapStartTimestamp;
extern CGPoint  __gestureLongPressStartPosition;
extern bool __gestureDraging;
extern GamePlayAppDelegate *__appDelegate;
extern GamePlayView* __view;


#endif
