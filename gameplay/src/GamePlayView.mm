#import "GamePlayView.h"
#import "Gesture.h"
#import "PlatformIOS.h"
#include <sys/time.h>

using namespace gameplay;

@interface GamePlayView ()

@end

@implementation GamePlayView
{
    Game* game;
}

@synthesize updating;
@synthesize context;

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (id) initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        // A system version of 3.1 or greater is required to use CADisplayLink.
        NSString *reqSysVer = @"3.1";
        NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
        if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
        {
            // Log the system version
            NSLog(@"System Version: %@", currSysVer);
        }
        else
        {
            GP_ERROR("Invalid OS Version: %s\n", (currSysVer == NULL?"NULL":[currSysVer cStringUsingEncoding:NSASCIIStringEncoding]));
            [self release];
            return nil;
        }
        
        // Check for OS 4.0+ features
        if ([currSysVer compare:@"4.0" options:NSNumericSearch] != NSOrderedAscending)
        {
            oglDiscardSupported = YES;
        }
        else
        {
            oglDiscardSupported = NO;
        }
        
        // Configure the CAEAGLLayer and setup out the rendering context
        CGFloat scale = [[UIScreen mainScreen] scale];
        CAEAGLLayer* layer = (CAEAGLLayer *)self.layer;
        layer.opaque = TRUE;
        layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        self.contentScaleFactor = scale;
        layer.contentsScale = scale;
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context || ![EAGLContext setCurrentContext:context])
        {
            GP_ERROR("Failed to make context current.");
            [self release];
            return nil;
        }
        
        // Initialize Internal Defaults
        displayLink = nil;
        updateFramebuffer = YES;
        defaultFramebuffer = 0;
        colorRenderbuffer = 0;
        depthRenderbuffer = 0;
        framebufferWidth = 0;
        framebufferHeight = 0;
        multisampleFramebuffer = 0;
        multisampleRenderbuffer = 0;
        multisampleDepthbuffer = 0;
        swapInterval = 1;
        updating = FALSE;
        game = nil;
        
        // Set the resource path and initalize the game
        NSString* bundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/"];
        FileSystem::setResourcePath([bundlePath fileSystemRepresentation]);
    }
    return self;
}

- (void) dealloc
{
    if (game)
        game->exit();
    [self deleteFramebuffer];
    
    if ([EAGLContext currentContext] == context)
    {
        [EAGLContext setCurrentContext:nil];
    }
    [context release];
    [super dealloc];
}

- (BOOL)canBecomeFirstResponder
{
    // Override so we can control the keyboard
    return YES;
}

- (void) layoutSubviews
{
    // Called on 'resize'.
    // Mark that framebuffer needs to be updated.
    // NOTE: Current disabled since we need to have a way to reset the default frame buffer handle
    // in FrameBuffer.cpp (for FrameBuffer:bindDefault). This means that changing orientation at
    // runtime is currently not supported until we fix this.
    //updateFramebuffer = YES;
}

- (BOOL)createFramebuffer
{
    // iOS Requires all content go to a rendering buffer then it is swapped into the windows rendering surface
    assert(defaultFramebuffer == 0);
    
    // Create the default frame buffer
    GL_ASSERT( glGenFramebuffers(1, &defaultFramebuffer) );
    GL_ASSERT( glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer) );
    
    // Create a color buffer to attach to the frame buffer
    GL_ASSERT( glGenRenderbuffers(1, &colorRenderbuffer) );
    GL_ASSERT( glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer) );
    
    // Associate render buffer storage with CAEAGLLauyer so that the rendered content is display on our UI layer.
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    // Attach the color buffer to our frame buffer
    GL_ASSERT( glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer) );
    
    // Retrieve framebuffer size
    GL_ASSERT( glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth) );
    GL_ASSERT( glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight) );
    
    NSLog(@"width: %d, height: %d", framebufferWidth, framebufferHeight);
    
    // If multisampling is enabled in config, create and setup a multisample buffer
    Properties* config = Game::getInstance()->getConfig()->getNamespace("window", true);
    int samples = config ? config->getInt("samples") : 0;
    if (samples < 0)
        samples = 0;
    if (samples)
    {
        // Create multisample framebuffer
        GL_ASSERT( glGenFramebuffers(1, &multisampleFramebuffer) );
        GL_ASSERT( glBindFramebuffer(GL_FRAMEBUFFER, multisampleFramebuffer) );
        
        // Create multisample render and depth buffers
        GL_ASSERT( glGenRenderbuffers(1, &multisampleRenderbuffer) );
        GL_ASSERT( glGenRenderbuffers(1, &multisampleDepthbuffer) );
        
        // Try to find a supported multisample configuration starting with the defined sample count
        while (samples)
        {
            GL_ASSERT( glBindRenderbuffer(GL_RENDERBUFFER, multisampleRenderbuffer) );
            GL_ASSERT( glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, samples, GL_RGBA8_OES, framebufferWidth, framebufferHeight) );
            GL_ASSERT( glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, multisampleRenderbuffer) );
            
            GL_ASSERT( glBindRenderbuffer(GL_RENDERBUFFER, multisampleDepthbuffer) );
            GL_ASSERT( glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, samples, GL_DEPTH_COMPONENT24_OES, framebufferWidth, framebufferHeight) );
            GL_ASSERT( glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, multisampleDepthbuffer) );
            
            if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE)
                break; // success!
            
            NSLog(@"Creation of multisample buffer with samples=%d failed. Attempting to use configuration with samples=%d instead: %x", samples, samples / 2, glCheckFramebufferStatus(GL_FRAMEBUFFER));
            samples /= 2;
        }
        
        //todo: __multiSampling = samples > 0;
        
        // Re-bind the default framebuffer
        GL_ASSERT( glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer) );
        
        if (samples == 0)
        {
            // Unable to find a valid/supported multisample configuratoin - fallback to no multisampling
            GL_ASSERT( glDeleteRenderbuffers(1, &multisampleRenderbuffer) );
            GL_ASSERT( glDeleteRenderbuffers(1, &multisampleDepthbuffer) );
            GL_ASSERT( glDeleteFramebuffers(1, &multisampleFramebuffer) );
            multisampleFramebuffer = multisampleRenderbuffer = multisampleDepthbuffer = 0;
        }
    }
    
    // Create default depth buffer and attach to the frame buffer.
    // Note: If we are using multisample buffers, we can skip depth buffer creation here since we only
    // need the color buffer to resolve to.
    if (multisampleFramebuffer == 0)
    {
        GL_ASSERT( glGenRenderbuffers(1, &depthRenderbuffer) );
        GL_ASSERT( glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer) );
        GL_ASSERT( glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, framebufferWidth, framebufferHeight) );
        GL_ASSERT( glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer) );
    }
    
    // Sanity check, ensure that the framebuffer is valid
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"ERROR: Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        [self deleteFramebuffer];
        return NO;
    }
    
    // If multisampling is enabled, set the currently bound framebuffer to the multisample buffer
    // since that is the buffer code should be drawing into (and FrameBuffr::initialize will detect
    // and set this bound buffer as the default one during initialization.
    if (multisampleFramebuffer)
        GL_ASSERT( glBindFramebuffer(GL_FRAMEBUFFER, multisampleFramebuffer) );
    
    return YES;
}

- (void)deleteFramebuffer
{
    if (context)
    {
        [EAGLContext setCurrentContext:context];
        if (defaultFramebuffer)
        {
            GL_ASSERT( glDeleteFramebuffers(1, &defaultFramebuffer) );
            defaultFramebuffer = 0;
        }
        if (colorRenderbuffer)
        {
            GL_ASSERT( glDeleteRenderbuffers(1, &colorRenderbuffer) );
            colorRenderbuffer = 0;
        }
        if (depthRenderbuffer)
        {
            GL_ASSERT( glDeleteRenderbuffers(1, &depthRenderbuffer) );
            depthRenderbuffer = 0;
        }
        if (multisampleFramebuffer)
        {
            GL_ASSERT( glDeleteFramebuffers(1, &multisampleFramebuffer) );
            multisampleFramebuffer = 0;
        }
        if (multisampleRenderbuffer)
        {
            GL_ASSERT( glDeleteRenderbuffers(1, &multisampleRenderbuffer) );
            multisampleRenderbuffer = 0;
        }
        if (multisampleDepthbuffer)
        {
            GL_ASSERT( glDeleteRenderbuffers(1, &multisampleDepthbuffer) );
            multisampleDepthbuffer = 0;
        }
    }
}

- (void)setSwapInterval:(NSInteger)interval
{
    if (interval >= 1)
    {
        swapInterval = interval;
        if (updating)
        {
            [self stopUpdating];
            [self startUpdating];
        }
    }
}

- (int)swapInterval
{
    return swapInterval;
}

- (void)swapBuffers
{
    if (context)
    {
        if (multisampleFramebuffer)
        {
            // Multisampling is enabled: resolve the multisample buffer into the default framebuffer
            GL_ASSERT( glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, defaultFramebuffer) );
            GL_ASSERT( glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, multisampleFramebuffer) );
            GL_ASSERT( glResolveMultisampleFramebufferAPPLE() );
            
            if (oglDiscardSupported)
            {
                // Performance hint that the GL driver can discard the contents of the multisample buffers
                // since they have now been resolved into the default framebuffer
                const GLenum discards[]  = { GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT };
                GL_ASSERT( glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 2, discards) );
            }
        }
        else
        {
            if (oglDiscardSupported)
            {
                // Performance hint to the GL driver that the depth buffer is no longer required.
                const GLenum discards[]  = { GL_DEPTH_ATTACHMENT };
                GL_ASSERT( glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer) );
                GL_ASSERT( glDiscardFramebufferEXT(GL_FRAMEBUFFER, 1, discards) );
            }
        }
        
        // Present the color buffer
        GL_ASSERT( glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer) );
        [context presentRenderbuffer:GL_RENDERBUFFER];
    }
}

- (void)startGame
{
    if (game == nil)
    {
        game = Game::getInstance();
        __timeStart = getMachTimeInMilliseconds();
        game->run();
    }
}

- (void)startUpdating
{
    if (!updating)
    {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update:)];
        [displayLink setFrameInterval:swapInterval];
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        if (game)
            game->resume();
        updating = TRUE;
    }
}

- (void)stopUpdating
{
    if (updating)
    {
        if (game)
            game->pause();
        [displayLink invalidate];
        displayLink = nil;
        updating = FALSE;
    }
}

- (void)update:(id)sender
{
    if (context != nil)
    {
        // Ensure our context is current
        [EAGLContext setCurrentContext:context];
        
        // If the framebuffer needs (re)creating, do so
        if (updateFramebuffer)
        {
            updateFramebuffer = NO;
            [self deleteFramebuffer];
            [self createFramebuffer];
            
            // Start the game after our framebuffer is created for the first time.
            if (game == nil)
            {
                [self startGame];
                
                // HACK: Skip the first display update after creating buffers and initializing the game.
                // If we don't do this, the first frame (which includes any drawing during initialization)
                // does not make it to the display for some reason.
                return;
            }
        }
        
        // Bind our framebuffer for rendering.
        // If multisampling is enabled, bind the multisample buffer - otherwise bind the default buffer
        GL_ASSERT( glBindFramebuffer(GL_FRAMEBUFFER, multisampleFramebuffer ? multisampleFramebuffer : defaultFramebuffer) );
        GL_ASSERT( glViewport(0, 0, framebufferWidth, framebufferHeight) );
        
        // Execute a single game frame
        if (game)
            game->frame();
        
        // Present the contents of the color buffer
        [self swapBuffers];
    }
}

- (BOOL)showKeyboard
{
    return [self becomeFirstResponder];
}

- (BOOL)dismissKeyboard
{
    return [self resignFirstResponder];
}

- (void)insertText:(NSString*)text
{
    if([text length] == 0) return;
    assert([text length] == 1);
    unichar c = [text characterAtIndex:0];
    int key = getKey(c);
    Platform::keyEventInternal(Keyboard::KEY_PRESS, key);
    
    int character = getUnicode(key);
    if (character)
    {
        Platform::keyEventInternal(Keyboard::KEY_CHAR, /*character*/c);
    }
    
    Platform::keyEventInternal(Keyboard::KEY_RELEASE, key);
}

- (void)deleteBackward
{
    Platform::keyEventInternal(Keyboard::KEY_PRESS, Keyboard::KEY_BACKSPACE);
    Platform::keyEventInternal(Keyboard::KEY_CHAR, getUnicode(Keyboard::KEY_BACKSPACE));
    Platform::keyEventInternal(Keyboard::KEY_RELEASE, Keyboard::KEY_BACKSPACE);
}

- (BOOL)hasText
{
    return YES;
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    unsigned int touchID = 0;
    for(UITouch* touch in touches)
    {
        CGPoint touchPoint = [touch locationInView:self];
        if(self.multipleTouchEnabled == YES)
        {
            touchID = [touch hash];
        }
        
        // Nested loop efficiency shouldn't be a concern since both loop sizes are small (<= 10)
        int i = 0;
        while (i < TOUCH_POINTS_MAX && __touchPoints[i].down)
        {
            i++;
        }
        
        if (i < TOUCH_POINTS_MAX)
        {
            __touchPoints[i].hashId = touchID;
            __touchPoints[i].x = touchPoint.x * WINDOW_SCALE;
            __touchPoints[i].y = touchPoint.y * WINDOW_SCALE;
            __touchPoints[i].down = true;
            
            Platform::touchEventInternal(Touch::TOUCH_PRESS, __touchPoints[i].x, __touchPoints[i].y, i);
        }
        else
        {
            print("touchesBegan: unable to find free element in __touchPoints");
        }
    }
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    unsigned int touchID = 0;
    for(UITouch* touch in touches)
    {
        CGPoint touchPoint = [touch locationInView:self];
        if(self.multipleTouchEnabled == YES)
            touchID = [touch hash];
        
        // Nested loop efficiency shouldn't be a concern since both loop sizes are small (<= 10)
        bool found = false;
        for (int i = 0; !found && i < TOUCH_POINTS_MAX; i++)
        {
            if (__touchPoints[i].down && __touchPoints[i].hashId == touchID)
            {
                __touchPoints[i].down = false;
                Platform::touchEventInternal(Touch::TOUCH_RELEASE, touchPoint.x * WINDOW_SCALE, touchPoint.y * WINDOW_SCALE, i);
                found = true;
            }
        }
        
        if (!found)
        {
            // It seems possible to receive an ID not in the array.
            // The best we can do is clear the whole array.
            for (int i = 0; i < TOUCH_POINTS_MAX; i++)
            {
                if (__touchPoints[i].down)
                {
                    __touchPoints[i].down = false;
                    Platform::touchEventInternal(Touch::TOUCH_RELEASE, __touchPoints[i].x, __touchPoints[i].y, i);
                }
            }
        }
    }
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
    // No equivalent for this in GamePlay -- treat as touch end
    [self touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    unsigned int touchID = 0;
    for(UITouch* touch in touches)
    {
        CGPoint touchPoint = [touch locationInView:self];
        if(self.multipleTouchEnabled == YES)
            touchID = [touch hash];
        
        // Nested loop efficiency shouldn't be a concern since both loop sizes are small (<= 10)
        for (int i = 0; i < TOUCH_POINTS_MAX; i++)
        {
            if (__touchPoints[i].down && __touchPoints[i].hashId == touchID)
            {
                __touchPoints[i].x = touchPoint.x * WINDOW_SCALE;
                __touchPoints[i].y = touchPoint.y * WINDOW_SCALE;
                Platform::touchEventInternal(Touch::TOUCH_MOVE, __touchPoints[i].x, __touchPoints[i].y, i);
                break;
            }
        }
    }
}

// Gesture support for Mac OS X Trackpads
- (bool)isGestureRegistered: (Gesture::GestureEvent) evt
{
    switch(evt) {
        case Gesture::GESTURE_SWIPE:
            return (_swipeRecognizer != NULL);
        case Gesture::GESTURE_PINCH:
            return (_pinchRecognizer != NULL);
        case Gesture::GESTURE_TAP:
            return (_tapRecognizer != NULL);
        case Gesture::GESTURE_LONG_TAP:
            return (_longTapRecognizer != NULL);
        case Gesture::GESTURE_DRAG:
        case Gesture::GESTURE_DROP:
            return (_dragAndDropRecognizer != NULL);
        default:
            break;
    }
    return false;
}

- (void)registerGesture: (Gesture::GestureEvent) evt
{
    if((evt & Gesture::GESTURE_SWIPE) == Gesture::GESTURE_SWIPE && _swipeRecognizer == NULL)
    {
        // right swipe (default)
        _swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
        [self addGestureRecognizer:_swipeRecognizer];
        
        // left swipe
        UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
        swipeGesture.direction = UISwipeGestureRecognizerDirectionLeft;
        [self addGestureRecognizer:swipeGesture];
        [swipeGesture release];
        
        // up swipe
        UISwipeGestureRecognizer *swipeGesture2 = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
        swipeGesture2.direction = UISwipeGestureRecognizerDirectionUp;
        [self addGestureRecognizer:swipeGesture2];
        [swipeGesture2 release];
        
        // down swipe
        UISwipeGestureRecognizer *swipeGesture3 = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
        swipeGesture3.direction = UISwipeGestureRecognizerDirectionDown;
        [self addGestureRecognizer:swipeGesture3];
        [swipeGesture3 release];
    }
    if((evt & Gesture::GESTURE_PINCH) == Gesture::GESTURE_PINCH && _pinchRecognizer == NULL)
    {
        _pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
        [self addGestureRecognizer:_pinchRecognizer];
    }
    if((evt & Gesture::GESTURE_TAP) == Gesture::GESTURE_TAP && _tapRecognizer == NULL)
    {
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        [self addGestureRecognizer:_tapRecognizer];
    }
    if ((evt & Gesture::GESTURE_LONG_TAP) == Gesture::GESTURE_LONG_TAP && _longTapRecognizer == NULL)
    {
        if (_longPressRecognizer == NULL)
        {
            _longPressRecognizer =[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestures:)];
            _longPressRecognizer.minimumPressDuration = GESTURE_LONG_PRESS_DURATION_MIN;
            _longPressRecognizer.allowableMovement = CGFLOAT_MAX;
            [self addGestureRecognizer:_longPressRecognizer];
        }
        _longTapRecognizer = _longPressRecognizer;
    }
    if (((evt & Gesture::GESTURE_DRAG) == Gesture::GESTURE_DRAG || (evt & Gesture::GESTURE_DROP) == Gesture::GESTURE_DROP) && _dragAndDropRecognizer == NULL)
    {
        if (_longPressRecognizer == NULL)
        {
            _longPressRecognizer =[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestures:)];
            _longPressRecognizer.minimumPressDuration = GESTURE_LONG_PRESS_DURATION_MIN;
            _longPressRecognizer.allowableMovement = CGFLOAT_MAX;
            [self addGestureRecognizer:_longPressRecognizer];
        }
        _dragAndDropRecognizer = _longPressRecognizer;
    }
}

- (void)unregisterGesture: (Gesture::GestureEvent) evt
{
    if((evt & Gesture::GESTURE_SWIPE) == Gesture::GESTURE_SWIPE && _swipeRecognizer != NULL)
    {
        [self removeGestureRecognizer:_swipeRecognizer];
        [_swipeRecognizer release];
        _swipeRecognizer = NULL;
    }
    if((evt & Gesture::GESTURE_PINCH) == Gesture::GESTURE_PINCH && _pinchRecognizer != NULL)
    {
        [self removeGestureRecognizer:_pinchRecognizer];
        [_pinchRecognizer release];
        _pinchRecognizer = NULL;
    }
    if((evt & Gesture::GESTURE_TAP) == Gesture::GESTURE_TAP && _tapRecognizer != NULL)
    {
        [self removeGestureRecognizer:_tapRecognizer];
        [_tapRecognizer release];
        _tapRecognizer = NULL;
    }
    if((evt & Gesture::GESTURE_LONG_TAP) == Gesture::GESTURE_LONG_TAP && _longTapRecognizer != NULL)
    {
        if (_longTapRecognizer == NULL)
        {
            [self removeGestureRecognizer:_longTapRecognizer];
            [_longTapRecognizer release];
        }
        _longTapRecognizer = NULL;
    }
    if (((evt & Gesture::GESTURE_DRAG) == Gesture::GESTURE_DRAG || (evt & Gesture::GESTURE_DROP) == Gesture::GESTURE_DROP) && _dragAndDropRecognizer != NULL)
    {
        if (_dragAndDropRecognizer == NULL)
        {
            [self removeGestureRecognizer:_dragAndDropRecognizer];
            [_dragAndDropRecognizer release];
        }
        _dragAndDropRecognizer = NULL;
    }
}

- (void)handleTapGesture:(UITapGestureRecognizer*)sender
{
    CGPoint location = [sender locationInView:self];
    gameplay::Platform::gestureTapEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE);
}

- (void)handleLongTapGesture:(UILongPressGestureRecognizer*)sender
{
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        struct timeval time;
        
        gettimeofday(&time, NULL);
        __gestureLongTapStartTimestamp = (time.tv_sec * 1000) + (time.tv_usec / 1000);
    }
    else if (sender.state == UIGestureRecognizerStateEnded)
    {
        CGPoint location = [sender locationInView:self];
        struct timeval time;
        long currentTimeStamp;
        
        gettimeofday(&time, NULL);
        currentTimeStamp = (time.tv_sec * 1000) + (time.tv_usec / 1000);
        gameplay::Platform::gestureLongTapEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE, currentTimeStamp - __gestureLongTapStartTimestamp);
    }
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer*)sender
{
    CGFloat factor = [sender scale];
    CGPoint location = [sender locationInView:self];
    gameplay::Platform::gesturePinchEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE, factor);
}

- (void)handleSwipeGesture:(UISwipeGestureRecognizer*)sender
{
    UISwipeGestureRecognizerDirection direction = [sender direction];
    CGPoint location = [sender locationInView:self];
    int gameplayDirection = 0;
    switch(direction) {
        case UISwipeGestureRecognizerDirectionRight:
            gameplayDirection = Gesture::SWIPE_DIRECTION_RIGHT;
            break;
        case UISwipeGestureRecognizerDirectionLeft:
            gameplayDirection = Gesture::SWIPE_DIRECTION_LEFT;
            break;
        case UISwipeGestureRecognizerDirectionUp:
            gameplayDirection = Gesture::SWIPE_DIRECTION_UP;
            break;
        case UISwipeGestureRecognizerDirectionDown:
            gameplayDirection = Gesture::SWIPE_DIRECTION_DOWN;
            break;
    }
    gameplay::Platform::gestureSwipeEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE, gameplayDirection);
}

- (void)handleLongPressGestures:(UILongPressGestureRecognizer*)sender
{
    CGPoint location = [sender locationInView:self];
    
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        struct timeval time;
        
        gettimeofday(&time, NULL);
        __gestureLongTapStartTimestamp = (time.tv_sec * 1000) + (time.tv_usec / 1000);
        __gestureLongPressStartPosition = location;
    }
    if (sender.state == UIGestureRecognizerStateChanged)
    {
        if (__gestureDraging)
            gameplay::Platform::gestureDragEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE);
        else
        {
            float delta = sqrt(pow(__gestureLongPressStartPosition.x - location.x, 2) + pow(__gestureLongPressStartPosition.y - location.y, 2));
            
            if (delta >= GESTURE_LONG_PRESS_DISTANCE_MIN)
            {
                __gestureDraging = true;
                gameplay::Platform::gestureDragEventInternal(__gestureLongPressStartPosition.x * WINDOW_SCALE, __gestureLongPressStartPosition.y * WINDOW_SCALE);
            }
        }
    }
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        if (__gestureDraging)
        {
            gameplay::Platform::gestureDropEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE);
            __gestureDraging = false;
        }
        else
        {
            struct timeval time;
            long currentTimeStamp;
            
            gettimeofday(&time, NULL);
            currentTimeStamp = (time.tv_sec * 1000) + (time.tv_usec / 1000);
            gameplay::Platform::gestureLongTapEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE, currentTimeStamp - __gestureLongTapStartTimestamp);
        }
    }
    if ((sender.state == UIGestureRecognizerStateCancelled || sender.state == UIGestureRecognizerStateFailed) && __gestureDraging)
    {
        gameplay::Platform::gestureDropEventInternal(location.x * WINDOW_SCALE, location.y * WINDOW_SCALE);
        __gestureDraging = false;
    }
}


@end
