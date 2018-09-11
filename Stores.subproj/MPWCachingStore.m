//
//  MPWCachingStore.m
//  MPWFoundation
//
//  Created by Marcel Weiher on 7/1/18.
//

#import "MPWCachingStore.h"
#import "MPWDictStore.h"
#import "AccessorMacros.h"
#import "MPWGenericReference.h"
#import "DebugMacros.h"


@interface MPWWriteThroughCache()

@property (nonatomic, strong) id <MPWStorage> cache;

@end

@implementation MPWWriteThroughCache

CONVENIENCEANDINIT(store, WithSource:newSource cache:newCache )
{
    self=[super initWithSource:newSource];
    self.cache=newCache;
    return self;
}

-(id)copyFromSourceToCache:(id <MPWReferencing>)aReference
{
    result=[self.source objectForReference:aReference];
    [self.cache setObject:result forReference:aReference];
    return result;
}

-objectForReference:(id <MPWReferencing>)aReference
{
    id result=[self.cache objectForReference:aReference];
    if (!result ) {
        result = [self copyFromSourceToCache:aReference];
    }
    return result;
}

-(void)writeToSource:newObject forReference:(id <MPWReferencing>)aReference
{
    if (!self.readOnlySource) {
        [self.source setObject:newObject forReference:aReference];
    }
}

-(void)setObject:newObject forReference:(id <MPWReferencing>)aReference
{
    [self.cache setObject:newObject forReference:aReference];
    [self writeToSource:newObject forReference:aReference];
}


-(void)mergeObject:newObject forReference:(id <MPWReferencing>)aReference
{
    [self copyFromSourceToCache:aReference];
    [self.cache mergeObject:newObject forReference:aReference];
    [self writeToSource:[self.cache objectForReference:aReference] forReference:aReference];
}



-(void)invalidate:(id)aRef
{
    [self.cache deleteObjectForReference:aRef];
}

@end


@interface MPWCachingStoreTests : NSObject

@property (nonatomic, strong)  MPWGenericReference *key;
@property (nonatomic, strong)  NSString *value;
@property (nonatomic, strong)  MPWDictStore *cache,*source;
@property (nonatomic, strong)  MPWCachingStore *store;

-(instancetype)initWithTestClass:(Class)testClass;

@end


@implementation MPWWriteThroughCache(testing)


+testFixture
{
    return [[[MPWCachingStoreTests alloc] initWithTestClass:self] autorelease];
}


+testSelectors
{
    return @[
             @"testReadingPopulatesCache",
             @"testCacheIsReadFirst",
             @"testWritePopulatesCacheAndSource",
             @"testWritePopulatesCacheAndSourceUnlessDontWriteIsSet",
             @"testCanInvalidateCache",
             @"testMergeWorksLikeStore",
             ];
}

@end


@implementation MPWCachingStoreTests

-(instancetype)initWithTestClass:(Class)testClass
{
    self=[super init];
    self.key = [MPWGenericReference referenceWithPath:@"aKey"];
    self.value = @"Hello World";
    self.cache = [MPWDictStore store];
    self.source = [MPWDictStore store];
    self.store = [testClass storeWithSource:self.source cache:self.cache];
    return self;
}

-(void)testReadingPopulatesCache
{
    id resultFromCache = self.cache[self.key];
    EXPECTNIL( resultFromCache , @"shouldn't have anything yet");
    [self.source setObject:self.value forReference:self.key];
    id mainResult = self.store[self.key];
    IDEXPECT( mainResult, self.value, @"reading the cache");
    resultFromCache = self.cache[self.key];
    IDEXPECT( resultFromCache, self.value, @"after accessing caching store, cache is populated");
}

-(void)testCacheIsReadFirst
{
    id resultFromCache = self.cache[self.key];
    EXPECTNIL( resultFromCache , @"shouldn't have anything yet");
    [self.cache setObject:self.value forReference:self.key];
    id resultFromSource = self.source[self.key];
    EXPECTNIL( resultFromSource , @"nothing in source");
    id mainResult = self.store[self.key];
    IDEXPECT( mainResult, self.value, @"reading the cache");
}

-(void)testWritePopulatesCacheAndSource
{
    [self.store setObject:self.value forReference:self.key];
    IDEXPECT( [self.source objectForReference:self.key], self.value, @"reading the source");
    IDEXPECT( [self.cache objectForReference:self.key], self.value, @"reading the cache");
}

-(void)testWritePopulatesCacheAndSourceUnlessDontWriteIsSet
{
    self.store.readOnlySource=YES;
    [self.store setObject:self.value forReference:self.key];
    EXPECTNIL( [self.source objectForReference:self.key], @"reading the source");
    IDEXPECT( [self.cache objectForReference:self.key], self.value, @"reading the cache");
}

-(void)testCanInvalidateCache
{
    [self.store setObject:self.value forReference:self.key];
    [self.store invalidate:self.key];
    EXPECTNIL( self.cache[self.key] , @"cache should be invalidated");
}

-(void)testMergeWorksLikeStore
{
    [self.store mergeObject:self.value forReference:self.key];
    IDEXPECT( [self.source objectForReference:self.key], self.value, @"reading the source");
    IDEXPECT( [self.cache objectForReference:self.key], self.value, @"reading the cache");
}

// FIXME:  need good test for merge bug when cache is not loaded yet

@end

@implementation MPWCachingStore
@end

