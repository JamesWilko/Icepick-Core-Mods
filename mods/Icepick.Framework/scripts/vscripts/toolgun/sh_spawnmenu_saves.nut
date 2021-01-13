
global function Spawnmenu_Init_Saves

#if CLIENT
global function Spawnmenu_OnSavedGameToFile
#endif

#if SERVER
global function Spawnmenu_PerformUtility
global function AddOnSpawnmenuUtilityCallback
#endif

struct
{
	array<void functionref(string id)> onPerformUtilityCallback,
	array<string> saveCategories,
	array<string> existingSaveFiles
} file

void function Spawnmenu_Init_Saves()
{
	#if CLIENT
	RegisterSpawnmenuPage( "saves", "Saves" );

	// Add some utility functions for cleaning up the map
	RegisterPageCategory( "saves", "utilities", "Utilities", "Spawnmenu_PerformUtility" );
	RegisterCategoryItem( "utilities", "cleanup.all", "Cleanup Everything" );
	RegisterCategoryItem( "utilities", "cleanup.props", "Cleanup Props" );
	RegisterCategoryItem( "utilities", "cleanup.ziplines", "Cleanup Ziplines" );
	RegisterCategoryItem( "utilities", "cleanup.teleporters", "Cleanup Teleporters" );
	RegisterCategoryItem( "utilities", "cleanup.spawnpoints", "Cleanup Spawn Points" );
	RegisterCategoryItem( "utilities", "cleanup.weapons", "Cleanup Weapons" );
	RegisterCategoryItem( "utilities", "cleanup.npcs", "Cleanup NPCs" );

	// Add categories where all our saves will be listed
	RegisterPageCategory( "saves", "saves-current", GetLocalizedMapName( GetMapName() ) + " Saves", "Spawnmenu_LoadSave" ); // Current map saves
	file.saveCategories.append( "saves-current" );

	// List save files in the saves folder
	array<string> saveNames = UntypedArrayToStringArray( GetSaveFiles() );
	foreach( saveFile in saveNames )
	{
		AddSaveFileToMenu( saveFile );
	}
	#endif
}

#if CLIENT
string function GetLocalizedMapName( string mapName )
{
	string mapLocalizationKey = "#" + mapName.toupper();
	string localized = Localize( mapLocalizationKey );

	// Campaign maps have different localization keys, so check for them if it fails
	if( localized == mapLocalizationKey )
	{
		localized = Localize( mapLocalizationKey + "_CAMPAIGN_NAME" );
	}

	// Append a map number for some campaign maps 
	switch( mapName )
	{
		case "sp_boomtown_start":
			localized += " Chapter 1";
			break;
		case "sp_boomtown":
			localized += " Chapter 2";
			break;
		case "sp_boomtown_end":
			localized += " Chapter 3";
			break;
		case "sp_beacon":
			localized += " Chapter 1/3";
			break;
		case "sp_beacon_spoke0":
			localized += " Chapter 2";
			break;
		case "sp_hub_timeshift":
			localized += " Chapter 1/3";
			break;
		case "sp_timeshift_spoke02":
			localized += " Chapter 2";
			break;
	}

	return localized;
}

void function AddSaveFileToMenu( string saveFile )
{
	// Make sure the file is unique when we refresh the list
	foreach( existingSave in file.existingSaveFiles )
	{
		if( existingSave == saveFile )
		{
			return;
		}
	}

	// Parse and add the file
	array<string> splitName = split( saveFile, "\\" );
	splitName = split( splitName[splitName.len() - 1], "." );

	string saveMap = splitName[ splitName.len() - 2 ];
	bool isCurrentMapSave = saveMap == GetMapName();
	string itemCategory = isCurrentMapSave ? "saves-current" : saveMap;

	// Create a category for every map so that people can easily find where their saves are
	if( file.saveCategories.find( itemCategory ) < 0 )
	{
		RegisterPageCategory( "saves", itemCategory, GetLocalizedMapName( saveMap ) + " Saves", "Spawnmenu_LoadSave" );
		file.saveCategories.append( itemCategory );
	}

	string fileName = "";
	string displayName = "";
	for( int i = 0; i < splitName.len(); ++i )
	{
		fileName += (fileName == "" ? "" : ".") + splitName[i];
		if( i < splitName.len() - 2 )
		{
			displayName += (displayName == "" ? "" : ".") + splitName[i];
		}
	}

	RegisterCategoryItem( itemCategory, fileName, displayName );

	// Record the file as existing so we don't get duplicates
	file.existingSaveFiles.append( saveFile );
}

void function Spawnmenu_OnSavedGameToFile( string fileName )
{
	AddSaveFileToMenu( fileName );
}
#endif

#if SERVER

// -----------------------------------------------------------------------------

void function AddOnSpawnmenuUtilityCallback( void functionref(string id) callbackFunc )
{
	Assert( !file.onPerformUtilityCallback.contains( callbackFunc ), "Already added " + string( callbackFunc ) + " with AddOnSpawnmenuUtilityCallback" );
	file.onPerformUtilityCallback.append( callbackFunc );
}

void function Spawnmenu_PerformUtility( string utility )
{
	switch( utility )
	{
		case "cleanup.all":
			Cleanup_All();
			break;
		case "cleanup.props":
			Cleanup_Props();
			break;
		case "cleanup.ziplines":
			Cleanup_Ziplines();
			break;
		case "cleanup.teleporters":
			Cleanup_Teleporters();
			break;
		case "cleanup.spawnpoints":
			Cleanup_SpawnPoints();
			break;
		case "cleanup.weapons":
			Cleanup_Weapons();
			break;
		case "cleanup.npcs":
			Cleanup_NPCs();
			break;
	}

	foreach ( callbackFunc in file.onPerformUtilityCallback )
	{
		callbackFunc( utility );
	}
}

void function Cleanup_All()
{
	Cleanup_Props();
	Cleanup_Ziplines();
	Cleanup_Teleporters();
	Cleanup_SpawnPoints();
	Cleanup_Weapons();
	Cleanup_NPCs();
}

void function Cleanup_Props()
{
	for( int i = 0; i < ToolgunData.SpawnedEntities.len(); ++i )
	{
		ToolgunData.SpawnedEntities[i].Destroy();
	}
	ToolgunData.SpawnedEntities.clear();
}

void function Cleanup_Ziplines()
{
	for( int i = 0; i < PlacedZiplines.len(); ++i )
	{
		ToolZipline_DestroyZipline( PlacedZiplines[i], true );
	}
	PlacedZiplines.clear();
}

void function Cleanup_Teleporters()
{
	for( int i = PlacedTeleporters.len() - 1; i >= 0; --i )
	{
		PlacedTeleporter teleporter = PlacedTeleporters[i];
		if( IsValid(teleporter.entryEnt) )
		{
			teleporter.entryEnt.Destroy();
		}
		if( IsValid(teleporter.entryEnt) )
		{
			teleporter.exitEnt.Destroy();
		}
	}
	
	PlacedTeleporters.clear();
}

void function Cleanup_SpawnPoints()
{
	for( int i = PlacedSpawnPoints.len() - 1; i >= 0; --i )
	{
		CustomSpawnPoint spawn = PlacedSpawnPoints[i];
		spawn.anchorEnt.Destroy();
	}

	PlacedSpawnPoints.clear();
}

void function Cleanup_Weapons()
{
	foreach ( weapon in GetWeaponArray( true ) )
	{
		// don't clean up weapon pickups that were placed in leveled
		int spawnflags = expect string( weapon.kv.spawnflags ).tointeger();
		if ( spawnflags & SF_WEAPON_START_CONSTRAINED )
		{
			continue;
		}
		weapon.Destroy();
	}
}

void function Cleanup_NPCs()
{
	foreach ( npc in GetNPCArrayOfTeam( TEAM_IMC ) )
	{
		npc.Destroy();
	}
}

#endif
