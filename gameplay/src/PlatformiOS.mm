#ifndef GP_NO_PLATFORM
#ifdef __APPLE__

#import "PlatformIOS.h"

#include "Base.h"
#include "Platform.h"
#include "FileSystem.h"
#include "Game.h"
#include "Form.h"
#include "ScriptController.h"
#include <unistd.h>
#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <mach/mach_time.h>


#define DeviceOrientedSize(o)         ((o == UIInterfaceOrientationPortrait || o == UIInterfaceOrientationPortraitUpsideDown)?                      \
                                            CGSizeMake([[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale], [[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale]):  \
                                            CGSizeMake([[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale], [[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale]))

using namespace std;
using namespace gameplay;

// UIScreen bounds are provided as if device was in portrait mode Gameplay defaults to landscape
extern const int WINDOW_WIDTH  = [[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale];
extern const int WINDOW_HEIGHT = [[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale];
extern const int WINDOW_SCALE = [[UIScreen mainScreen] scale];

int __argc = 0;
char** __argv = 0;

GamePlayAppDelegate *__appDelegate = NULL;
GamePlayView* __view = NULL;
Class __appDelegateClass = [GamePlayAppDelegate class];

// gestures

CGPoint  __gestureLongPressStartPosition;
long __gestureLongTapStartTimestamp = 0;
bool __gestureDraging = false;

// more than we'd ever need, to be safe
TouchPoint __touchPoints[TOUCH_POINTS_MAX];

double __timeStart;
static double __timeAbsolute;
static bool __vsync = WINDOW_VSYNC;
static float __pitch;
static float __roll;

double getMachTimeInMilliseconds();

int getKey(unichar keyCode);
int getUnicode(int key);

double getMachTimeInMilliseconds()
{
    static const double kOneMillion = 1000 * 1000;
    static mach_timebase_info_data_t s_timebase_info;
    
    if (s_timebase_info.denom == 0) 
        (void) mach_timebase_info(&s_timebase_info);
    
    // mach_absolute_time() returns billionth of seconds, so divide by one million to get milliseconds
    GP_ASSERT(s_timebase_info.denom);
    return ((double)mach_absolute_time() * (double)s_timebase_info.numer) / (kOneMillion * (double)s_timebase_info.denom);
}

int getKey(unichar keyCode)
{
    switch(keyCode) 
    {
        case 0x0A:
            return Keyboard::KEY_RETURN;
        case 0x20:
            return Keyboard::KEY_SPACE;
            
        case 0x30:
            return Keyboard::KEY_ZERO;
        case 0x31:
            return Keyboard::KEY_ONE;
        case 0x32:
            return Keyboard::KEY_TWO;
        case 0x33:
            return Keyboard::KEY_THREE;
        case 0x34:
            return Keyboard::KEY_FOUR;
        case 0x35:
            return Keyboard::KEY_FIVE;
        case 0x36:
            return Keyboard::KEY_SIX;
        case 0x37:
            return Keyboard::KEY_SEVEN;
        case 0x38:
            return Keyboard::KEY_EIGHT;
        case 0x39:
            return Keyboard::KEY_NINE;
            
        case 0x41:
            return Keyboard::KEY_CAPITAL_A;
        case 0x42:
            return Keyboard::KEY_CAPITAL_B;
        case 0x43:
            return Keyboard::KEY_CAPITAL_C;
        case 0x44:
            return Keyboard::KEY_CAPITAL_D;
        case 0x45:
            return Keyboard::KEY_CAPITAL_E;
        case 0x46:
            return Keyboard::KEY_CAPITAL_F;
        case 0x47:
            return Keyboard::KEY_CAPITAL_G;
        case 0x48:
            return Keyboard::KEY_CAPITAL_H;
        case 0x49:
            return Keyboard::KEY_CAPITAL_I;
        case 0x4A:
            return Keyboard::KEY_CAPITAL_J;
        case 0x4B:
            return Keyboard::KEY_CAPITAL_K;
        case 0x4C:
            return Keyboard::KEY_CAPITAL_L;
        case 0x4D:
            return Keyboard::KEY_CAPITAL_M;
        case 0x4E:
            return Keyboard::KEY_CAPITAL_N;
        case 0x4F:
            return Keyboard::KEY_CAPITAL_O;
        case 0x50:
            return Keyboard::KEY_CAPITAL_P;
        case 0x51:
            return Keyboard::KEY_CAPITAL_Q;
        case 0x52:
            return Keyboard::KEY_CAPITAL_R;
        case 0x53:
            return Keyboard::KEY_CAPITAL_S;
        case 0x54:
            return Keyboard::KEY_CAPITAL_T;
        case 0x55:
            return Keyboard::KEY_CAPITAL_U;
        case 0x56:
            return Keyboard::KEY_CAPITAL_V;
        case 0x57:
            return Keyboard::KEY_CAPITAL_W;
        case 0x58:
            return Keyboard::KEY_CAPITAL_X;
        case 0x59:
            return Keyboard::KEY_CAPITAL_Y;
        case 0x5A:
            return Keyboard::KEY_CAPITAL_Z;
            
            
        case 0x61:
            return Keyboard::KEY_A;
        case 0x62:
            return Keyboard::KEY_B;
        case 0x63:
            return Keyboard::KEY_C;
        case 0x64:
            return Keyboard::KEY_D;
        case 0x65:
            return Keyboard::KEY_E;
        case 0x66:
            return Keyboard::KEY_F;
        case 0x67:
            return Keyboard::KEY_G;
        case 0x68:
            return Keyboard::KEY_H;
        case 0x69:
            return Keyboard::KEY_I;
        case 0x6A:
            return Keyboard::KEY_J;
        case 0x6B:
            return Keyboard::KEY_K;
        case 0x6C:
            return Keyboard::KEY_L;
        case 0x6D:
            return Keyboard::KEY_M;
        case 0x6E:
            return Keyboard::KEY_N;
        case 0x6F:
            return Keyboard::KEY_O;
        case 0x70:
            return Keyboard::KEY_P;
        case 0x71:
            return Keyboard::KEY_Q;
        case 0x72:
            return Keyboard::KEY_R;
        case 0x73:
            return Keyboard::KEY_S;
        case 0x74:
            return Keyboard::KEY_T;
        case 0x75:
            return Keyboard::KEY_U;
        case 0x76:
            return Keyboard::KEY_V;
        case 0x77:
            return Keyboard::KEY_W;
        case 0x78:
            return Keyboard::KEY_X;
        case 0x79:
            return Keyboard::KEY_Y;
        case 0x7A:
            return Keyboard::KEY_Z;
        default:
            break;
            
       // Symbol Row 3
        case 0x2E:
            return Keyboard::KEY_PERIOD;
        case 0x2C:
            return Keyboard::KEY_COMMA;
        case 0x3F:
            return Keyboard::KEY_QUESTION;
        case 0x21:
            return Keyboard::KEY_EXCLAM;
        case 0x27:
            return Keyboard::KEY_APOSTROPHE;
            
        // Symbols Row 2
        case 0x2D:
            return Keyboard::KEY_MINUS;
        case 0x2F:
            return Keyboard::KEY_SLASH;
        case 0x3A:
            return Keyboard::KEY_COLON;
        case 0x3B:
            return Keyboard::KEY_SEMICOLON;
        case 0x28:
            return Keyboard::KEY_LEFT_PARENTHESIS;
        case 0x29:
            return Keyboard::KEY_RIGHT_PARENTHESIS;
        case 0x24:
            return Keyboard::KEY_DOLLAR;
        case 0x26:
            return Keyboard::KEY_AMPERSAND;
        case 0x40:
            return Keyboard::KEY_AT;
        case 0x22:
            return Keyboard::KEY_QUOTE;
            
        // Numeric Symbols Row 1
        case 0x5B:
            return Keyboard::KEY_LEFT_BRACKET;
        case 0x5D:
            return Keyboard::KEY_RIGHT_BRACKET;
        case 0x7B:
            return Keyboard::KEY_LEFT_BRACE;
        case 0x7D:
            return Keyboard::KEY_RIGHT_BRACE;
        case 0x23:
            return Keyboard::KEY_NUMBER;
        case 0x25:
            return Keyboard::KEY_PERCENT;
        case 0x5E:
            return Keyboard::KEY_CIRCUMFLEX;
        case 0x2A:
            return Keyboard::KEY_ASTERISK;
        case 0x2B:
            return Keyboard::KEY_PLUS;
        case 0x3D:
            return Keyboard::KEY_EQUAL;
            
        // Numeric Symbols Row 2
        case 0x5F:
            return Keyboard::KEY_UNDERSCORE;
        case 0x5C:
            return Keyboard::KEY_BACK_SLASH;
        case 0x7C:
            return Keyboard::KEY_BAR;
        case 0x7E:
            return Keyboard::KEY_TILDE;
        case 0x3C:
            return Keyboard::KEY_LESS_THAN;
        case 0x3E:
            return Keyboard::KEY_GREATER_THAN;
        case 0x80:
            return Keyboard::KEY_EURO;
        case 0xA3:
            return Keyboard::KEY_POUND;
        case 0xA5:
            return Keyboard::KEY_YEN;
        case 0xB7:
            return Keyboard::KEY_MIDDLE_DOT;
    }
    return Keyboard::KEY_NONE;
}

/**
 * Returns the unicode value for the given keycode or zero if the key is not a valid printable character.
 */
int getUnicode(int key)
{
    
    switch (key)
    {
        case Keyboard::KEY_BACKSPACE:
            return 0x0008;
        case Keyboard::KEY_TAB:
            return 0x0009;
        case Keyboard::KEY_RETURN:
        case Keyboard::KEY_KP_ENTER:
            return 0x000A;
        case Keyboard::KEY_ESCAPE:
            return 0x001B;
        case Keyboard::KEY_SPACE:
        case Keyboard::KEY_EXCLAM:
        case Keyboard::KEY_QUOTE:
        case Keyboard::KEY_NUMBER:
        case Keyboard::KEY_DOLLAR:
        case Keyboard::KEY_PERCENT:
        case Keyboard::KEY_CIRCUMFLEX:
        case Keyboard::KEY_AMPERSAND:
        case Keyboard::KEY_APOSTROPHE:
        case Keyboard::KEY_LEFT_PARENTHESIS:
        case Keyboard::KEY_RIGHT_PARENTHESIS:
        case Keyboard::KEY_ASTERISK:
        case Keyboard::KEY_PLUS:
        case Keyboard::KEY_COMMA:
        case Keyboard::KEY_MINUS:
        case Keyboard::KEY_PERIOD:
        case Keyboard::KEY_SLASH:
        case Keyboard::KEY_ZERO:
        case Keyboard::KEY_ONE:
        case Keyboard::KEY_TWO:
        case Keyboard::KEY_THREE:
        case Keyboard::KEY_FOUR:
        case Keyboard::KEY_FIVE:
        case Keyboard::KEY_SIX:
        case Keyboard::KEY_SEVEN:
        case Keyboard::KEY_EIGHT:
        case Keyboard::KEY_NINE:
        case Keyboard::KEY_COLON:
        case Keyboard::KEY_SEMICOLON:
        case Keyboard::KEY_LESS_THAN:
        case Keyboard::KEY_EQUAL:
        case Keyboard::KEY_GREATER_THAN:
        case Keyboard::KEY_QUESTION:
        case Keyboard::KEY_AT:
        case Keyboard::KEY_CAPITAL_A:
        case Keyboard::KEY_CAPITAL_B:
        case Keyboard::KEY_CAPITAL_C:
        case Keyboard::KEY_CAPITAL_D:
        case Keyboard::KEY_CAPITAL_E:
        case Keyboard::KEY_CAPITAL_F:
        case Keyboard::KEY_CAPITAL_G:
        case Keyboard::KEY_CAPITAL_H:
        case Keyboard::KEY_CAPITAL_I:
        case Keyboard::KEY_CAPITAL_J:
        case Keyboard::KEY_CAPITAL_K:
        case Keyboard::KEY_CAPITAL_L:
        case Keyboard::KEY_CAPITAL_M:
        case Keyboard::KEY_CAPITAL_N:
        case Keyboard::KEY_CAPITAL_O:
        case Keyboard::KEY_CAPITAL_P:
        case Keyboard::KEY_CAPITAL_Q:
        case Keyboard::KEY_CAPITAL_R:
        case Keyboard::KEY_CAPITAL_S:
        case Keyboard::KEY_CAPITAL_T:
        case Keyboard::KEY_CAPITAL_U:
        case Keyboard::KEY_CAPITAL_V:
        case Keyboard::KEY_CAPITAL_W:
        case Keyboard::KEY_CAPITAL_X:
        case Keyboard::KEY_CAPITAL_Y:
        case Keyboard::KEY_CAPITAL_Z:
        case Keyboard::KEY_LEFT_BRACKET:
        case Keyboard::KEY_BACK_SLASH:
        case Keyboard::KEY_RIGHT_BRACKET:
        case Keyboard::KEY_UNDERSCORE:
        case Keyboard::KEY_GRAVE:
        case Keyboard::KEY_A:
        case Keyboard::KEY_B:
        case Keyboard::KEY_C:
        case Keyboard::KEY_D:
        case Keyboard::KEY_E:
        case Keyboard::KEY_F:
        case Keyboard::KEY_G:
        case Keyboard::KEY_H:
        case Keyboard::KEY_I:
        case Keyboard::KEY_J:
        case Keyboard::KEY_K:
        case Keyboard::KEY_L:
        case Keyboard::KEY_M:
        case Keyboard::KEY_N:
        case Keyboard::KEY_O:
        case Keyboard::KEY_P:
        case Keyboard::KEY_Q:
        case Keyboard::KEY_R:
        case Keyboard::KEY_S:
        case Keyboard::KEY_T:
        case Keyboard::KEY_U:
        case Keyboard::KEY_V:
        case Keyboard::KEY_W:
        case Keyboard::KEY_X:
        case Keyboard::KEY_Y:
        case Keyboard::KEY_Z:
        case Keyboard::KEY_LEFT_BRACE:
        case Keyboard::KEY_BAR:
        case Keyboard::KEY_RIGHT_BRACE:
        case Keyboard::KEY_TILDE:
            return key;
        default:
            return 0;
    }
}

namespace gameplay
{
    
extern void print(const char* format, ...)
{
    GP_ASSERT(format);
    va_list argptr;
    va_start(argptr, format);
    vfprintf(stderr, format, argptr);
    va_end(argptr);
}

extern int strcmpnocase(const char* s1, const char* s2)
{
    return strcasecmp(s1, s2);
}

Platform::Platform(Game* game) : _game(game)
{
}

Platform::~Platform()
{
}

Platform* Platform::create(Game* game)
{
    Platform* platform = new Platform(game);
    return platform;
}

int Platform::enterMessagePump()
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [GamePlayAppDelegate load];
    UIApplicationMain(0, nil, NSStringFromClass([UIApplication class]), NSStringFromClass(__appDelegateClass));
    [pool release];
    return EXIT_SUCCESS;
}

void Platform::signalShutdown() 
{
    // Cannot 'exit' an iOS Application
    assert(false);
    [__view stopUpdating];
    exit(0);
}

bool Platform::canExit()
{
    return false;
}

unsigned int Platform::getDisplayWidth()
{
#ifdef NSFoundationVersionNumber_iOS_7_1
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1)
    {
        //iOS 8+
        return [[UIScreen mainScreen] bounds].size.width * [[UIScreen mainScreen] scale];
    }
    else
#endif
    {
        CGSize size = DeviceOrientedSize([__appDelegate.gamePlayViewController interfaceOrientation]);
        return size.width;
    }
}

unsigned int Platform::getDisplayHeight()
{
#ifdef NSFoundationVersionNumber_iOS_7_1
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1)
    {
        //iOS 8+
        return [[UIScreen mainScreen] bounds].size.height * [[UIScreen mainScreen] scale];
    }
    else
#endif
    {
        CGSize size = DeviceOrientedSize([__appDelegate.gamePlayViewController interfaceOrientation]);
        return size.height;
    }
}

double Platform::getAbsoluteTime()
{
    __timeAbsolute = getMachTimeInMilliseconds();
    return __timeAbsolute;
}

void Platform::setAbsoluteTime(double time)
{
    __timeAbsolute = time;
}

bool Platform::isVsync()
{
    return __vsync;
}

void Platform::setVsync(bool enable)
{
    __vsync = enable;
}

void Platform::swapBuffers()
{
    if (__view)
        [__view swapBuffers];
}
void Platform::sleep(long ms)
{
    usleep(ms * 1000);
}

bool Platform::hasAccelerometer()
{
    return true;
}

void Platform::getAccelerometerValues(float* pitch, float* roll)
{
    [__appDelegate getAccelerometerPitch:pitch roll:roll];
}

void Platform::getSensorValues(float* accelX, float* accelY, float* accelZ, float* gyroX, float* gyroY, float* gyroZ)
{
    float x, y, z;
    [__appDelegate getRawAccelX:&x Y:&y Z:&z];
    if (accelX)
    {
        *accelX = x;
    }
    if (accelY)
    {
        *accelY = y;
    }
    if (accelZ)
    {
        *accelZ = z;
    }

    [__appDelegate getRawGyroX:&x Y:&y Z:&z];
    if (gyroX)
    {
        *gyroX = x;
    }
    if (gyroY)
    {
        *gyroY = y;
    }
    if (gyroZ)
    {
        *gyroZ = z;
    }
}

void Platform::getArguments(int* argc, char*** argv)
{
    if (argc)
        *argc = __argc;
    if (argv)
        *argv = __argv;
}

bool Platform::hasMouse()
{
    // not supported
    return false;
}

void Platform::setMouseCaptured(bool captured)
{
    // not supported
}

bool Platform::isMouseCaptured()
{
    // not supported
    return false;
}

void Platform::setCursorVisible(bool visible)
{
    // not supported
}

bool Platform::isCursorVisible()
{
    // not supported
    return false;
}

void Platform::setMultiSampling(bool enabled)
{
    //todo
}

bool Platform::isMultiSampling()
{
    return false; //todo
}

void Platform::setMultiTouch(bool enabled) 
{
    __view.multipleTouchEnabled = enabled;
}

bool Platform::isMultiTouch() 
{
    return __view.multipleTouchEnabled;
}

void Platform::displayKeyboard(bool display) 
{
    if(__view) 
    {
        if(display)
        {
            [__view showKeyboard];
        }
        else
        {
            [__view dismissKeyboard];
        }
    }
}

void Platform::shutdownInternal()
{
    Game::getInstance()->shutdown();
}

bool Platform::isGestureSupported(Gesture::GestureEvent evt)
{
    return true;
}

void Platform::registerGesture(Gesture::GestureEvent evt)
{
    [__view registerGesture:evt];
}

void Platform::unregisterGesture(Gesture::GestureEvent evt)
{
    [__view unregisterGesture:evt];
}

bool Platform::isGestureRegistered(Gesture::GestureEvent evt)
{
    return [__view isGestureRegistered:evt];
}

void Platform::pollGamepadState(Gamepad* gamepad)
{
}

bool Platform::launchURL(const char *url)
{
    if (url == NULL || *url == '\0')
        return false;

    return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithUTF8String: url]]];
}

std::string Platform::displayFileDialog(size_t mode, const char* title, const char* filterDescription, const char* filterExtensions, const char* initialDirectory)
{
    return "";
}
 
}

#endif
#endif
