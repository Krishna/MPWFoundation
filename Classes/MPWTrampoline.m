/*
    MPWTrampoline.m created by marcel on Tue 29-Jun-1999 
    Copyright (c) 1999-2017 by Marcel Weiher. All rights reserved.

R

*/


#import "MPWTrampoline.h"
#import "MPWObjectCache.h"
#import <MPWFoundation/MPWFastInvocation.h>
#import <MPWFoundation/NSInvocationAdditions_lookup.h>
//#import "NSInvocationAdditions_lookup.h"
#import "MPWRuntimeAdditions.h"
#import "DebugMacros.h"
#import "MPWEnumFilter.h"
#include <objc/runtime.h>
#include <objc/message.h>


@interface MPWTrampoline(isEqual)

-(id)isEqual:otherObject;

@end


@implementation MPWTrampoline

scalarAccessor( id, xxxAdditionalArg, setXxxAdditionalArg )

+(void)initialize
{
    static int initialized = NO;
    if (!initialized ) {
        initialized=YES;
    }
}


-init
{
    return self;
}

+trampoline
{
    return [[self alloc] autorelease];
}



+trampolineWithTarget:target selector:(SEL)selector
{
#if 0
    id trampoline=[self quickTrampoline];           // quickTrampoline crashes on iPhone 6S with a NULL in methodForSelector: initializing the cache
#else
    id trampoline=[self trampoline];
#endif
    [trampoline setXxxTarget:target];
    [trampoline setXxxSelector:selector];
    return trampoline;
}



CACHING_ALLOC( quickTrampoline, 5, YES )


+methodSignatureForSelector:(SEL)selector
{
//	NSLog(@"+methodSignatureForSelector: %@",NSStringFromSelector(selector));
    return [NSObject methodSignatureForSelector:selector];
}

-retain
{
    retainCount++;
    return self;
}

-(void)xxxSetTargetKey:aKey
{
	[[self xxxTarget] setKey:aKey];
}

-(oneway void)release
{
    if ( --retainCount < 0 ) {
        [self dealloc];
    }
}

-(NSUInteger)retainCount
{
    return retainCount+1;
}

-(void)forwardInvocation:(NSInvocation*)invocationToForward
{
    [invocationToForward setTarget:xxxTarget];
    [xxxTarget performSelector:xxxSelector withObject:invocationToForward withObject:xxxAdditionalArg];
	[self setXxxTarget:nil];
}

typedef id (*IDIMP2)(id, SEL,id,id);

static void __forwardStart0( MPWTrampoline* target, SEL selector )
{
    MPWFastInvocation *invocationToForward=[MPWFastInvocation quickInvocation];
    [invocationToForward setSelector:selector];
    [invocationToForward setTarget:target->xxxTarget];
    ((IDIMP2)objc_msgSend)(target->xxxTarget,target->xxxSelector, invocationToForward, target->xxxAdditionalArg);
//    [target->xxxTarget performSelector:target->xxxSelector withObject:invocationToForward withObject:target->xxxAdditionalArg];
}

#ifndef GS_API_LATEST

+(BOOL)resolveInstanceMethod_disabled:(SEL)selector
{
    if ( !strchr(sel_getName(selector), ':')) {
        class_addMethod(self, selector, (IMP)__forwardStart0, "@@:");
        return YES;
    }
    return NO;
}

#endif

#if LIB_FOUNDATION_LIBRARY

#warning compiling forward::

-(retval_t)forward:(SEL)aSel :(arglist_t)argFrame
{
	NSMethodSignature *sig;

//	NSLog(@"forward: %@",NSStringFromSelector(aSel));
	sig = [self methodSignatureForSelector:aSel];
//	NSLog(@"signature: %@",sig);
	if ( sig ) {
		NSInvocation *invocation;
		int i;
		id *args=argFrame->arg_ptr;
		static id retval=nil;

		invocation = [NSInvocation invocationWithMethodSignature:sig];
//		NSLog(@"invocation: %@",invocation);
		[invocation setTarget:self];
		[invocation setSelector:aSel];
		for (i=2;i<[sig numberOfArguments];i++) {
			[invocation setArgument:args+i atIndex:i];
		}	
		[self forwardInvocation:invocation];
//		NSLog(@"did send invocation: %@",invocation);
		[invocation getReturnValue:&retval];
//		NSLog(@"did get return value");
                
		return (retval_t)&retval;
	}

	return [super forward:aSel :argFrame];
}

#else
//#warning NOT compiling forward::
#endif

+(void)forwardInvocation:(NSInvocation*)invocationToForward
{
}

-sendTarget
{
    return xxxTarget;
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *sig;
//	NSLog(@"[%p/%@ -methodSignatureForSelector: %@",[self sendTarget],[[self sendTarget] class],NSStringFromSelector(aSelector));
    sig = [[self sendTarget] methodSignatureForHOMSelector:aSelector];
//	NSLog(@"sig= %p",sig);
    return sig;
}

- (BOOL)xxxRespondsToSelector:(SEL)aSelector
{
//    return [super respondsToSelector:aSelector];
    return NO;
}

-(BOOL)respondsToSelector:(SEL)aSelector
{
//	NSLog(@"trampoline respondsToSelector:%@ with target: %@",NSStringFromSelector(aSelector),[self sendTarget]);
    return [[self sendTarget] respondsToSelector:aSelector];
}

+(BOOL)respondsToSelector:(SEL)aSelector
{
//	NSLog(@"trampoline class respondsToSelector:%@",NSStringFromSelector(aSelector));
	return [super respondsToSelector:aSelector];
}

#ifdef Darwin
-_class
{
    return (id)((IMP0)_objc_msgForward)( self, @selector(class));
}
#endif

idAccessor( xxxTarget, setXxxTarget )
scalarAccessor( SEL, xxxSelector, setXxxSelector )

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"

-(void)dealloc
{
    [xxxTarget release];
    NSDeallocateObject( (NSObject*)self );
	return; 
}
#pragma clang diagnostic pop

//---	scripting support:
//---	WebScript sends 'isKindOfClass:' before sending the actual message.
//---	trampoline shouldn't trigger on that
//---	consequently, I cannot forward "isKindOfClass:" messages, which kind of sucks...
//---	however, enum-filters would have to use __isKindOfClass: hack anyhow...

-(BOOL)isKindOfClass:(Class)aClass
{
    return [[self sendTarget] isKindOfClass:aClass];
}
typedef id (*IDSELIMP)(id, SEL,SEL);

+(IMP)instanceMethodForSelector:(SEL)sel
{
    static IDSELIMP ims=(IDSELIMP)nil;
    if (!ims) {
        ims = (IDSELIMP)[NSObject methodForSelector:_cmd];
    }
    return (IMP)ims( self, _cmd, sel );
}

+(IMP)methodForSelector:(SEL)sel
{
    static IMP1 mfs=(IMP1)nil;
    if (!mfs) {
        mfs = (IMP1)[NSObject methodForSelector:_cmd];
    }
    return (IMP)mfs( self, _cmd, sel );
}

@end

@implementation MPWTrampoline(isEqual)

-(id)isEqual:otherObject
{
	NSMethodSignature* sig=[NSObject methodSignatureForSelector:_cmd];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
	id retval;
	[invocation setTarget:self];
	[invocation setSelector:_cmd];
	[invocation setArgument:&otherObject atIndex:2];
	[self forwardInvocation:invocation];
	[invocation getReturnValue:&retval];
	return retval;
}


@end


@implementation NSString(dummy_return)

-dummy_return:arg
{
    static id a=@"bozo";
    [arg setReturnValue:&a];
    return a;
}

@end

@implementation MPWTrampoline(testing)

+testSelectors
{
    return @[
//        @"testAutorelease",
//            @"testJump"
        ];
}


+(void)testAutorelease
{
    id obj=[[self alloc] init];
    id pool=[[NSAutoreleasePool alloc] init];
	NSString *autorelease_name=@"autorelease-not-working";
	NSString *autorelease_msg=@"autorelease-not-working exception:%@";
	NSString *release_name=@"release-of-pool-not-working";
	NSString *release_msg=@"release-of-pool: %@";
    NS_DURING
    [obj autorelease];
    NS_HANDLER
       [NSException raise:autorelease_name format:autorelease_msg,localException];
    NS_ENDHANDLER
    NS_DURING
    [pool release];
    NS_HANDLER
       [NSException raise:release_name format:release_msg,localException];
    NS_ENDHANDLER
}

+(void)testJump
{
    id obj=[self trampoline];
    NSString* result;
    [obj setXxxTarget:@"dummy_target"];
    [obj setXxxSelector:@selector(dummy_return:)];
    result=[obj stringByAppendingString:@"hi"];
    IDEXPECT( result, @"bozo", @"result");
}

@end



@implementation NSObject(safely)

#if ! TARGET_OS_IPHONE

-exceptionPerformingInvocation:(NSInvocation*)invocation
{
    id pool=[[NSAutoreleasePool alloc] init];
    id exception=nil;
    const char *returnType=[[invocation methodSignature] methodReturnType];
    NS_DURING
        [invocation invokeWithTarget:self];
    NS_HANDLER
        exception = [localException retain];
        [pool release];
        [exception autorelease];
        pool=[[NSAutoreleasePool alloc] init];
    NS_ENDHANDLER
    if ( returnType && *returnType !='v') {
        [invocation setReturnValue:&exception];
    }
    [pool release];
    return exception;
}


-trampolineWithSelector:(SEL)selector
{
    return [MPWTrampoline trampolineWithTarget:self selector:selector];
}


-safely
{
    return [self trampolineWithSelector:@selector(exceptionPerformingInvocation:)];
}
#endif

-(id)isKindOf:aClass
{
    return (id)(NSUInteger)[self isKindOfClass:aClass];
}

-(NSMethodSignature*)methodSignatureForHOMSelector:(SEL)aSelector
{
	id sig;
//	NSLog(@"-methodSignatureForHOMSelector: %@",NSStringFromSelector(aSelector));
	sig = [self methodSignatureForSelector:aSelector];
//	NSLog(@"sig=%x",sig);
	return sig;
}



@end

