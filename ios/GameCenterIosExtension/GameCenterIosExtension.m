//
//  GameCenterIosExtension
//  GameCenterIosExtension.m
//
//  Created by Richard Lord on 19/12/2011.
//  Copyright (c) 2012 Stick Sports Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlashRuntimeExtensions.h"
#import "GameCenterHandler.h"
#import "GC_NativeMessages.h"

#define DEFINE_ANE_FUNCTION(fn) FREObject (fn)(FREContext context, void* functionData, uint32_t argc, FREObject argv[])

#define MAP_FUNCTION(fn, data) { (const uint8_t*)(#fn), (data), &(fn) }

GameCenterHandler* GC_handler;

DEFINE_ANE_FUNCTION( GC_isSupported )
{
    return [GC_handler isSupported];
}

DEFINE_ANE_FUNCTION( GC_authenticateLocalPlayer )
{
    return [GC_handler authenticateLocalPlayer];
}

DEFINE_ANE_FUNCTION( GC_getLocalPlayer )
{
    return [GC_handler getLocalPlayer];
}

DEFINE_ANE_FUNCTION( GC_getIdentityVerificationSignatureToken )
{
    return [GC_handler getIdentityVerificationSignatureToken];
}

DEFINE_ANE_FUNCTION( GC_reportScore )
{
    return [GC_handler reportScore:argv[1] inCategory:argv[0]];
}

DEFINE_ANE_FUNCTION( GC_showStandardLeaderboard )
{
    return [GC_handler showStandardLeaderboard];
}

DEFINE_ANE_FUNCTION( GC_showStandardLeaderboardWithCategory )
{
    return [GC_handler showStandardLeaderboardWithCategory:argv[0]];
}

DEFINE_ANE_FUNCTION( GC_showStandardLeaderboardWithTimescope )
{
    return [GC_handler showStandardLeaderboardWithTimescope:argv[0]];
}

DEFINE_ANE_FUNCTION( GC_showStandardLeaderboardWithCategoryAndTimescope )
{
    return [GC_handler showStandardLeaderboardWithCategory:argv[0] andTimescope:argv[1]];
}

DEFINE_ANE_FUNCTION( GC_getLeaderboard )
{
    return [GC_handler getLeaderboardWithCategory:argv[0] playerScope:argv[1] timeScope:argv[2] rangeMin:argv[3] rangeMax:argv[4]];
}

DEFINE_ANE_FUNCTION( GC_reportAchievement )
{
    return [GC_handler reportAchievement:argv[0] withValue:argv[1] andBanner:argv[2]];
}

DEFINE_ANE_FUNCTION( GC_showStandardAchievements )
{
    return [GC_handler showStandardAchievements];
}

DEFINE_ANE_FUNCTION( GC_getAchievements )
{
    return [GC_handler getAchievements];
}

DEFINE_ANE_FUNCTION( GC_getLocalPlayerFriends )
{
    return [GC_handler getLocalPlayerFriends];
}

DEFINE_ANE_FUNCTION( GC_getLocalPlayerScore )
{
    return [GC_handler getLocalPlayerScoreInCategory:argv[0] playerScope:argv[1] timeScope:argv[2]];
}

DEFINE_ANE_FUNCTION( GC_getStoredLocalPlayerScore )
{
    return [GC_handler getStoredLocalPlayerScore:argv[0]];
}

DEFINE_ANE_FUNCTION( GC_getStoredLeaderboard )
{
    return [GC_handler getStoredLeaderboard:argv[0]];
}

DEFINE_ANE_FUNCTION( GC_getStoredAchievements )
{
    return [GC_handler getStoredAchievements:argv[0]];
}

DEFINE_ANE_FUNCTION( GC_getStoredPlayers )
{
    return [GC_handler getStoredPlayers:argv[0]];
}

void GameCenterContextInitializer( void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToSet, const FRENamedFunction** functionsToSet )
{
    static FRENamedFunction functionMap[] = {
        MAP_FUNCTION( GC_isSupported, NULL ),
        MAP_FUNCTION( GC_authenticateLocalPlayer, NULL ),
        MAP_FUNCTION( GC_getLocalPlayer, NULL ),
        MAP_FUNCTION( GC_getIdentityVerificationSignatureToken, NULL ),
        MAP_FUNCTION( GC_reportScore, NULL ),
        MAP_FUNCTION( GC_reportAchievement, NULL ),
        MAP_FUNCTION( GC_showStandardLeaderboard, NULL ),
        MAP_FUNCTION( GC_showStandardLeaderboardWithCategory, NULL ),
        MAP_FUNCTION( GC_showStandardLeaderboardWithTimescope, NULL ),
        MAP_FUNCTION( GC_showStandardLeaderboardWithCategoryAndTimescope, NULL ),
        MAP_FUNCTION( GC_showStandardAchievements, NULL ),
        MAP_FUNCTION( GC_getLocalPlayerFriends, NULL ),
        MAP_FUNCTION( GC_getLocalPlayerScore, NULL ),
        MAP_FUNCTION( GC_getLeaderboard, NULL ),
        MAP_FUNCTION( GC_getStoredLeaderboard, NULL ),
        MAP_FUNCTION( GC_getStoredLocalPlayerScore, NULL ),
        MAP_FUNCTION( GC_getStoredPlayers, NULL ),
        MAP_FUNCTION( GC_getAchievements, NULL ),
        MAP_FUNCTION( GC_getStoredAchievements, NULL )
    };
    
	*numFunctionsToSet = sizeof( functionMap ) / sizeof( FRENamedFunction );
	*functionsToSet = functionMap;
    
    GC_handler = [[GameCenterHandler alloc] initWithContext:ctx];
}

void GameCenterContextFinalizer( FREContext ctx )
{
	return;
}

void GameCenterExtensionInitializer( void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet ) 
{ 
    extDataToSet = NULL;  // This example does not use any extension data. 
    *ctxInitializerToSet = &GameCenterContextInitializer;
    *ctxFinalizerToSet = &GameCenterContextFinalizer;
}

void GameCenterExtensionFinalizer()
{
    return;
}
