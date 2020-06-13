//
//  MPWStreamQLite.m
//  MPWFoundation
//
//  Created by Marcel Weiher on 13.06.20.
//

#import "MPWStreamQLite.h"
#import "MPWPListBuilder.h"
#include <sqlite3.h>

@interface MPWStreamQLite()

@property (nonatomic, strong) NSString *databasePath;

@end

@implementation MPWStreamQLite
{
    sqlite3 *db;
}

-(instancetype)initWithPath:(NSString*)newpath
{
    self=[super init];
    self.databasePath = newpath;
    return self;
}

-(void)sqlRow:(int)argc values:(char**)values keys:(char**)keys
{
    [self.builder beginDictionary];

    for(int i = 0; i<argc; i++){
        [self.builder writeObject:@(values[i]) forKey:@(keys[i])];
    }
    [self.builder endDictionary];
}

static int callback(void *data, int argc, char **argv, char **azColName){
    MPWStreamQLite *db=(MPWStreamQLite*)data;
    [db sqlRow:argc values:argv keys:azColName];
    return 0;
}

-(int)exec:(NSString*)sql
{
    sqlite3_stmt *res;

    [self.builder beginArray];
    int rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &res, 0);
    int step;
    while ( SQLITE_ROW == (step = sqlite3_step(res))) {
        [self.builder beginDictionary];
        int numCols=sqlite3_column_count(res);
        for (int i=0; i<numCols;i++) {
            NSString *key=@(sqlite3_column_name(res, i));
            NSString *value=@((const char*)sqlite3_column_text(res, i));
            [self.builder writeObject:value forKey:key];
        }
        [self.builder endDictionary];
    }
    sqlite3_finalize(res);
    [self.builder endArray];
    return rc;
}

-(int)open
{
    int rc;

    rc = sqlite3_open([self.databasePath UTF8String], &db);
    return rc;
}

-(void)close
{
    if (db) {
        sqlite3_close(db);
        db=NULL;
    }
}

-(NSString*)error
{
    return @(sqlite3_errmsg(db));
}

-(void)dealloc
{
    [self close];
    [_databasePath release];
    [super dealloc];
}

@end


#import <MPWFoundation/DebugMacros.h>

@implementation MPWStreamQLite(testing) 

+_chinookDB
{
    NSString *path=[[NSBundle bundleForClass:self] pathForResource:@"chinook" ofType:@"db"];
    return [[[self alloc] initWithPath:path] autorelease];
}

+(void)testOpenChinookAndReadArtists
{
    MPWStreamQLite *db=[self _chinookDB];
    MPWPListBuilder *builder=[MPWPListBuilder builder];
    db.builder = builder;
    [db open];
    [db exec:@"select * from artists;"];
    NSArray *artists=[builder result];
    INTEXPECT(artists.count, 275, @"number of artists");
}

+(NSArray*)testSelectors
{
   return @[
			@"testOpenChinookAndReadArtists",
			];
}

@end
