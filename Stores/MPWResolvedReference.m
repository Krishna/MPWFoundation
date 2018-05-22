//
//  MPWResolvedReference.m
//  MPWFoundation
//
//  Created by Marcel Weiher on 5/21/18.
//

#import "MPWResolvedReference.h"
#import "MPWAbstractStore.h"
#import "MPWReference.h"

@implementation MPWResolvedReference

-value
{
    return [self.store objectForReference:self.reference];
}

-(void)setValue:newValue
{
    [self.store setObject:newValue forReference:self.reference];
}


-(void)delete
{
    [self.store deleteObjectForReference:self.reference];
}


@end
