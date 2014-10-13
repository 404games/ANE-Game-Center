//
//  GameCenterHandler.m
//  GameCenterIosExtension
//
//  Created by Richard Lord on 18/06/2012.
//  Copyright (c) 2012 Stick Sports Ltd. All rights reserved.
//

#import "GameCenterHandler.h"
#import <GameKit/GameKit.h>
#import "GC_NativeMessages.h"
#import "GC_BoardsController.h"
#import "GC_BoardsControllerPhone.h"
#import "GC_BoardsControllerPad.h"
#import "GC_LeaderboardWithNames.h"
#import "GC_TypeConversion.h"

#define DISPATCH_STATUS_EVENT(extensionContext, code, status) FREDispatchStatusEventAsync((extensionContext), (uint8_t*)code, (uint8_t*)status)

#define ASLocalPlayer "com.sticksports.nativeExtensions.gameCenter.GCLocalPlayer"
#define ASToken "com.sticksports.nativeExtensions.gameCenter.GCToken"
#define ASLeaderboard "com.sticksports.nativeExtensions.gameCenter.GCLeaderboard"
#define ASVectorScore "Vector.<com.sticksports.nativeExtensions.gameCenter.GCScore>"
#define ASVectorAchievement "Vector.<com.sticksports.nativeExtensions.gameCenter.GCAchievement>"

@interface GameCenterHandler () {
}
@property FREContext context;
@property (retain)NSMutableDictionary* returnObjects;
@property (retain)id<BoardsController> boardsController;
@property (retain)GC_TypeConversion* converter;
@end

static NSDictionary *tokenData;
@implementation GameCenterHandler


@synthesize context, returnObjects, boardsController, converter;

+ (FREObject) setTokenData:(NSDictionary *)myData {
  tokenData = [myData copy];
  return NULL;
}

- (id)initWithContext:(FREContext)extensionContext
{
    self = [super init];
    if( self )
    {
        context = extensionContext;
        returnObjects = [[NSMutableDictionary alloc] init];
        converter = [[GC_TypeConversion alloc] init];
    }
    return self;
}

- (void) createBoardsController
{
    if( !boardsController )
    {
        if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
        {
            boardsController = [[BoardsControllerPad alloc] initWithContext:context];
        }
        else
        {
            boardsController = [[BoardsControllerPhone alloc] initWithContext:context];
        }
    }
}

- (NSString*) storeReturnObject:(id)object
{
    NSString* key;
    do
    {
        key = [NSString stringWithFormat: @"%li", random()];
    } while ( [self.returnObjects valueForKey:key] != nil );
    [self.returnObjects setValue:object forKey:key];
    return key;
}

- (id) getReturnObject:(NSString*) key
{
    id object = [self.returnObjects valueForKey:key];
    [self.returnObjects setValue:nil forKey:key];
    return object;
}

- (FREObject) isSupported
{
    // Check for presence of GKLocalPlayer class.
    BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
    
    // The device must be running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    uint32_t retValue = (localPlayerClassAvailable && osVersionSupported) ? 1 : 0;
    
    FREObject result;
    if ( FRENewObjectFromBool(retValue, &result ) == FRE_OK )
    {
        return result;
    }
    return NULL;
}

- (FREObject) authenticateLocalPlayer
{
  GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
  if( localPlayer ) {
    //if ( localPlayer.isAuthenticated ) {
    //    DISPATCH_STATUS_EVENT( self.context, "", localPlayerAuthenticated );
    //} else {
      [localPlayer authenticateWithCompletionHandler:^(NSError *error) {
        if( localPlayer.isAuthenticated ) {
          [localPlayer generateIdentityVerificationSignatureWithCompletionHandler:^(NSURL *publicKeyUrl, NSData *signature, NSData *salt, uint64_t timestamp, NSError *error) {
            if(error) {
              NSLog(@"ERROR: %@", error);
              DISPATCH_STATUS_EVENT( self.context, "", localPlayerAuthenticated );
            } else {
              [GameCenterHandler setTokenData:@{
                @"publicKeyUrl": [publicKeyUrl absoluteString],
                @"timestamp": [NSString stringWithFormat:@"%llu", timestamp],
                @"signature": [signature base64EncodedStringWithOptions:0],
                @"salt": [salt base64EncodedStringWithOptions:0],
                @"playerID": localPlayer.playerID,
                @"bundleID": [[NSBundle mainBundle] bundleIdentifier]
              }];
              DISPATCH_STATUS_EVENT( self.context, "", localPlayerAuthenticated );
            }
          }];
        } else {
          DISPATCH_STATUS_EVENT( self.context, "", localPlayerNotAuthenticated );
        }
      }];
    //}
  }
  return NULL;
}
  /*
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( localPlayer )
    {
        if ( localPlayer.isAuthenticated )
        {
            DISPATCH_STATUS_EVENT( self.context, "", localPlayerAuthenticated );
            return NULL;
        }
        else
        {
            [localPlayer authenticateWithCompletionHandler:^(NSError *error) {
                if( localPlayer.isAuthenticated )
                {
                    DISPATCH_STATUS_EVENT( self.context, "", localPlayerAuthenticated );
                }
                else
                {     
                    DISPATCH_STATUS_EVENT( self.context, "", localPlayerNotAuthenticated );
                }
            }];
        }
    }
    return NULL;
}
    */

- (FREObject) getIdentityVerificationSignatureToken
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if ( localPlayer && localPlayer.isAuthenticated )
    {
      FREObject asToken;
      if(  FRENewObject( ASToken, 0, NULL, &asToken, NULL ) == FRE_OK
        && [self.converter FRESetObject:asToken property:"publicKeyUrl" toString:tokenData[@"publicKeyUrl"]] == FRE_OK
        && [self.converter FRESetObject:asToken property:"timestamp" toString:tokenData[@"timestamp"]] == FRE_OK
        && [self.converter FRESetObject:asToken property:"signature" toString:tokenData[@"signature"]] == FRE_OK
        && [self.converter FRESetObject:asToken property:"salt" toString:tokenData[@"salt"]] == FRE_OK
        && [self.converter FRESetObject:asToken property:"playerID" toString:tokenData[@"playerID"]] == FRE_OK
        && [self.converter FRESetObject:asToken property:"bundleID" toString:tokenData[@"bundleID"]] == FRE_OK) 
      {
        return asToken;
      } else {
        NSLog(@"Error:%@", tokenData);
      }
    } else {
      DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
    }
    return NULL;
}

- (FREObject) getLocalPlayer
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if ( localPlayer && localPlayer.isAuthenticated )
    {
        FREObject asPlayer;
        if ( FRENewObject( ASLocalPlayer, 0, NULL, &asPlayer, NULL ) == FRE_OK
            && [self.converter FRESetObject:asPlayer property:"id" toString:localPlayer.playerID] == FRE_OK
            && [self.converter FRESetObject:asPlayer property:"alias" toString:localPlayer.alias] == FRE_OK )
        {
            return asPlayer;
        }
    }
    else
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
    }
    return NULL;
}

- (FREObject) reportScore:(FREObject)asScore inCategory:(FREObject)asCategory
{
    NSString* category;
    if( [self.converter FREGetObject:asCategory asString:&category] != FRE_OK ) return NULL;
    
    int32_t scoreValue = 0;
    if( FREGetObjectAsInt32( asScore, &scoreValue ) != FRE_OK ) return NULL;
    
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    GKScore* score = [[[GKScore alloc] initWithCategory:category] autorelease];
    if( score )
    {
        score.value = scoreValue;
        [score reportScoreWithCompletionHandler:^(NSError* error)
         {
             if( error == nil )
             {
                 DISPATCH_STATUS_EVENT( self.context, "", scoreReported );
             }
             else
             {
                 DISPATCH_STATUS_EVENT( self.context, "", scoreNotReported );
             }
         }];
    }
    return NULL;
}

- (FREObject) showStandardLeaderboard
{
    [self createBoardsController];
    [self.boardsController displayLeaderboard];
    return NULL;
}

- (FREObject) showStandardLeaderboardWithCategory:(FREObject)asCategory
{
    NSString* category;
    if( [self.converter FREGetObject:asCategory asString:&category] != FRE_OK ) return NULL;
    
    [self createBoardsController];
    [self.boardsController displayLeaderboardWithCategory:category];
    return NULL;
}

- (FREObject) showStandardLeaderboardWithTimescope:(FREObject)asTimescope
{
    int timeScope;
    if( FREGetObjectAsInt32( asTimescope, &timeScope ) != FRE_OK ) return NULL;
    
    [self createBoardsController];
    [self.boardsController displayLeaderboardWithTimescope:timeScope];
    return NULL;
}

- (FREObject) showStandardLeaderboardWithCategory:(FREObject)asCategory andTimescope:(FREObject)asTimescope
{
    NSString* category;
    if( [self.converter FREGetObject:asCategory asString:&category] != FRE_OK ) return NULL;
    int timeScope;
    if( FREGetObjectAsInt32( asTimescope, &timeScope ) != FRE_OK ) return NULL;
    
    [self createBoardsController];
    [self.boardsController displayLeaderboardWithCategory:category andTimescope:timeScope];
    return NULL;
}

- (FREObject) getLeaderboardWithCategory:(FREObject)asCategory playerScope:(FREObject)asPlayerScope timeScope:(FREObject)asTimeScope rangeMin:(FREObject)asRangeMin rangeMax:(FREObject)asRangeMax
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    GKLeaderboard* leaderboard = [[GKLeaderboard alloc] init];
    
    NSString* propertyString;
    if( [self.converter FREGetObject:asCategory asString:&propertyString] != FRE_OK ) return NULL;
    leaderboard.category = propertyString;
    
    int propertyInt;
    if( FREGetObjectAsInt32( asPlayerScope, &propertyInt ) != FRE_OK ) return NULL;
    leaderboard.playerScope = propertyInt;
    
    if( FREGetObjectAsInt32( asTimeScope, &propertyInt ) != FRE_OK ) return NULL;
    leaderboard.timeScope = propertyInt;
    
    int propertyInt2;
    if( FREGetObjectAsInt32( asRangeMin, &propertyInt ) != FRE_OK ) return NULL;
    if( FREGetObjectAsInt32( asRangeMax, &propertyInt2 ) != FRE_OK ) return NULL;
    leaderboard.range = NSMakeRange( propertyInt, propertyInt2 );
    
    [leaderboard loadScoresWithCompletionHandler:^( NSArray* scores, NSError* error )
     {
         if( error == nil && scores != nil )
         {
             LeaderboardWithNames* leaderboardWithNames = [[LeaderboardWithNames alloc] initWithLeaderboard:leaderboard];
             NSMutableArray* playerIds = [[[NSMutableArray alloc] initWithCapacity:scores.count] autorelease];
             int i = 0;
             for ( GKScore* score in scores )
             {
                 [playerIds insertObject:score.playerID atIndex:i];
                 ++i;
             }
             [GKPlayer loadPlayersForIdentifiers:playerIds withCompletionHandler:^(NSArray *playerDetails, NSError *error)
              {
                  if ( error == nil && playerDetails != nil )
                  {
                      NSMutableDictionary* names = [[[NSMutableDictionary alloc] init] autorelease];
                      for( GKPlayer* player in playerDetails )
                      {
                          [names setValue:player forKey:player.playerID];
                      }
                      leaderboardWithNames.names = names;
                      NSString* code = [self storeReturnObject:leaderboardWithNames];
                      DISPATCH_STATUS_EVENT( self.context, code.UTF8String, loadLeaderboardComplete );
                  }
                  else
                  {
                      [leaderboardWithNames release];
                      DISPATCH_STATUS_EVENT( self.context, "", loadLeaderboardFailed );
                  }
              }];
         }
         else
         {
             [leaderboard release];
             DISPATCH_STATUS_EVENT( self.context, "", loadLeaderboardFailed );
         }
     }];
    return NULL;
}

- (FREObject) reportAchievement:(FREObject)asId withValue:(FREObject)asValue andBanner:(FREObject)asBanner
{
    NSString* identifier;
    if( [self.converter FREGetObject:asId asString:&identifier] != FRE_OK ) return NULL;
    
    double value = 0;
    if( FREGetObjectAsDouble( asValue, &value ) != FRE_OK ) return NULL;
    
    uint32_t banner = 0;
    if( FREGetObjectAsBool( asBanner, &banner ) != FRE_OK ) return NULL;
    
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    GKAchievement* achievement = [[[GKAchievement alloc] initWithIdentifier:identifier] autorelease];
    if( achievement )
    {
        achievement.percentComplete = value * 100;
        if( [achievement respondsToSelector:@selector(showsCompletionBanner)] )
        {
            achievement.showsCompletionBanner = ( banner == 1 );
        }
        [achievement reportAchievementWithCompletionHandler:^(NSError* error)
         {
             if( error == nil )
             {
                 DISPATCH_STATUS_EVENT( self.context, "", achievementReported );
             }
             else
             {
                 DISPATCH_STATUS_EVENT( self.context, "", achievementNotReported );
             }
         }];
    }
    return NULL;
}


- (FREObject) showStandardAchievements
{
    [self createBoardsController];
    [self.boardsController displayAchievements];
    return NULL;
}

- (FREObject) getAchievements
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    [GKAchievement loadAchievementsWithCompletionHandler:^( NSArray* achievements, NSError* error )
     {
         if( error == nil && achievements != nil )
         {
             [achievements retain];
             NSString* code = [self storeReturnObject:achievements];
             DISPATCH_STATUS_EVENT( self.context, code.UTF8String, loadAchievementsComplete );
         }
         else
         {
             DISPATCH_STATUS_EVENT( self.context, "", loadAchievementsFailed );
         }
     }];
    return NULL;
}

- (FREObject) getLocalPlayerFriends
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    [localPlayer loadFriendsWithCompletionHandler:^(NSArray *friendIds, NSError *error)
     {
         if ( error == nil && friendIds != nil )
         {
             if( friendIds.count == 0 )
             {
                 [friendIds retain];
                 NSString* code = [self storeReturnObject:friendIds];
                 DISPATCH_STATUS_EVENT( self.context, code.UTF8String, loadFriendsComplete );
             }
             else
             {
                 [GKPlayer loadPlayersForIdentifiers:friendIds withCompletionHandler:^(NSArray *friendDetails, NSError *error)
                  {
                      if ( error == nil && friendDetails != nil )
                      {
                          [friendDetails retain];
                          NSString* code = [self storeReturnObject:friendDetails];
                          DISPATCH_STATUS_EVENT( self.context, code.UTF8String, loadFriendsComplete );
                      }
                      else
                      {
                          DISPATCH_STATUS_EVENT( self.context, "", loadFriendsFailed );
                      }
                  }];
             }
         }
         else
         {
             DISPATCH_STATUS_EVENT( self.context, "", loadFriendsFailed );
         }
     }];
    return NULL;
}

- (FREObject) getLocalPlayerScoreInCategory:(FREObject)asCategory playerScope:(FREObject)asPlayerScope timeScope:(FREObject)asTimeScope
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    GKLeaderboard* leaderboard = [[GKLeaderboard alloc] init];
    
    NSString* propertyString;
    if( [self.converter FREGetObject:asCategory asString:&propertyString] != FRE_OK ) return NULL;
    leaderboard.category = propertyString;
    
    int propertyInt;
    if( FREGetObjectAsInt32( asPlayerScope, &propertyInt ) != FRE_OK ) return NULL;
    leaderboard.playerScope = propertyInt;
    
    if( FREGetObjectAsInt32( asTimeScope, &propertyInt ) != FRE_OK ) return NULL;
    leaderboard.timeScope = propertyInt;
    
    leaderboard.range = NSMakeRange( 1, 1 );
    
    [leaderboard loadScoresWithCompletionHandler:^( NSArray* scores, NSError* error )
     {
         if( error == nil && scores != nil )
         {
             NSString* code = [self storeReturnObject:leaderboard];
             DISPATCH_STATUS_EVENT( self.context, code.UTF8String, loadLocalPlayerScoreComplete );
         }
         else
         {
             [leaderboard release];
             DISPATCH_STATUS_EVENT( self.context, "", loadLocalPlayerScoreFailed );
         }
     }];
    return NULL;
}

- (FREObject) getStoredLocalPlayerScore:(FREObject)asKey
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    NSString* key;
    if( [self.converter FREGetObject:asKey asString:&key] != FRE_OK ) return NULL;
    
    GKLeaderboard* leaderboard = [self getReturnObject:key];
    
    if( leaderboard == nil )
    {
        return NULL;
    }
    FREObject asLeaderboard;
    FREObject asScore;
    
    if ( FRENewObject( ASLeaderboard, 0, NULL, &asLeaderboard, NULL) == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"timeScope" toInt:leaderboard.timeScope] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"playerScope" toInt:leaderboard.playerScope] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"category" toString:leaderboard.category] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"title" toString:leaderboard.title] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"rangeMax" toInt:leaderboard.maxRange] == FRE_OK )
    {
        if( leaderboard.localPlayerScore && [self.converter FREGetGKScore:leaderboard.localPlayerScore forPlayer:localPlayer asObject:&asScore] == FRE_OK )
        {
            FRESetObjectProperty( asLeaderboard, "localPlayerScore", asScore, NULL );
        }
        [leaderboard release];
        return asLeaderboard;
    }
    [leaderboard release];
    return NULL;
}

- (FREObject) getStoredLeaderboard:(FREObject)asKey
{
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if( !localPlayer.isAuthenticated )
    {
        DISPATCH_STATUS_EVENT( self.context, "", notAuthenticated );
        return NULL;
    }
    
    NSString* key;
    if( [self.converter FREGetObject:asKey asString:&key] != FRE_OK ) return NULL;
    
    LeaderboardWithNames* leaderboardWithNames = [self getReturnObject:key];
    GKLeaderboard* leaderboard = leaderboardWithNames.leaderboard;
    NSDictionary* names = leaderboardWithNames.names;
    
    if( leaderboard == nil || names == nil )
    {
        return NULL;
    }
    FREObject asLeaderboard;
    FREObject asLocalScore;
    
    if ( FRENewObject( ASLeaderboard, 0, NULL, &asLeaderboard, NULL) == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"timeScope" toInt:leaderboard.timeScope] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"playerScope" toInt:leaderboard.playerScope] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"category" toString:leaderboard.category] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"title" toString:leaderboard.title] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"rangeMax" toInt:leaderboard.maxRange] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"rangeStart" toInt:leaderboard.range.location] == FRE_OK
        && [self.converter FRESetObject:asLeaderboard property:"rangeLength" toInt:leaderboard.range.length] == FRE_OK
        )
    {
        if( leaderboard.localPlayerScore && [self.converter FREGetGKScore:leaderboard.localPlayerScore forPlayer:localPlayer asObject:&asLocalScore] == FRE_OK )
        {
            FRESetObjectProperty( asLeaderboard, "localPlayerScore", asLocalScore, NULL );
        }
        if( leaderboard.scores )
        {
            FREObject asScores;
            if ( FRENewObject( ASVectorScore, 0, NULL, &asScores, NULL ) == FRE_OK && FRESetArrayLength( asScores, leaderboard.scores.count ) == FRE_OK )
            {
                int nextIndex = 0;
                for( GKScore* score in leaderboard.scores )
                {
                    GKPlayer* player = [names valueForKey:score.playerID];
                    if( player != nil )
                    {
                        FREObject asScore;
                        if( [self.converter FREGetGKScore:score forPlayer:player asObject:&asScore] == FRE_OK )
                        {
                            FRESetArrayElementAt( asScores, nextIndex, asScore );
                            ++nextIndex;
                        }
                    }
                }
                FRESetObjectProperty( asLeaderboard, "scores", asScores, NULL );
            }
        }
        [leaderboardWithNames release];
        return asLeaderboard;
    }
    [leaderboardWithNames release];
    return NULL;
}

- (FREObject) getStoredAchievements:(FREObject)asKey
{
    NSString* key;
    if( [self.converter FREGetObject:asKey asString:&key] != FRE_OK ) return NULL;
    
    NSArray* achievements = [self getReturnObject:key];
    if( achievements == nil )
    {
        return NULL;
    }
    FREObject asAchievements;
    if ( FRENewObject( ASVectorAchievement, 0, NULL, &asAchievements, NULL ) == FRE_OK && FRESetArrayLength( asAchievements, achievements.count ) == FRE_OK )
    {
        int nextIndex = 0;
        for( GKAchievement* achievement in achievements )
        {
            FREObject asAchievement;
            if( [self.converter FREGetGKAchievement:achievement asObject:&asAchievement] == FRE_OK )
            {
                FRESetArrayElementAt( asAchievements, nextIndex, asAchievement );
                ++nextIndex;
            }
        }
        [achievements release];
        return asAchievements;
    }
    [achievements release];
    return NULL;
}

- (FREObject) getStoredPlayers:(FREObject)asKey
{
    NSString* key;
    if( [self.converter FREGetObject:asKey asString:&key] != FRE_OK ) return NULL;
    
    NSArray* friendDetails = [self getReturnObject:key];
    if( friendDetails == nil )
    {
        return NULL;
    }
    FREObject friends;
    if ( FRENewObject( "Array", 0, NULL, &friends, NULL ) == FRE_OK && FRESetArrayLength( friends, friendDetails.count ) == FRE_OK )
    {
        int nextIndex = 0;
        for( GKPlayer* friend in friendDetails )
        {
            FREObject asPlayer;
            if( [self.converter FREGetGKPlayer:friend asObject:&asPlayer] == FRE_OK )
            {
                FRESetArrayElementAt( friends, nextIndex, asPlayer );
                ++nextIndex;
            }
        }
        [friendDetails release];
        return friends;
    }
    [friendDetails release];
    return NULL;
}


@end
