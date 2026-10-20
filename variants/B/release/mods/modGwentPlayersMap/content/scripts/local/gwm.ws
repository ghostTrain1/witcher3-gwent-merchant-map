// Gwent Players Map
// Shows Gwent players on the world map and greys out the ones already beaten.
//
// Every pin comes from gwm_data.ws and is judged by one of:
//   tag   merchant: facts the game writes on the first win (see MerchantBeaten)
//   card  quest player: the unique card is in the inventory
//   none  anyone else: fact gwm_won_<pinId>, written by this mod after a win next to the pin
// A few players stop appearing after a story event the game records as a fact (goneFacts, found in
// the game's community spawn trees): their card is greyed out as "No longer available." Some pins
// carry a short spoiler-free note (noteKey), e.g. a player who has to be rescued first.
// Players whose shop sells Gwent cards (store) can show "Also sells Gwent cards." while the player
// lacks one of those cards ("Show who sells Gwent cards" option, off by default).
// Merchants also get gwm_won_<pinId> when beaten next to their pin: the game records nothing
// once the shared card pool is used up, and another mod may change the reward facts.
//
// Map file (content/blob0.bundle): a modified panel_worldmap.redswf with the card icons
// (GwentPlayer / GwentPlayerDisabled) and a "Gwent" map filter for those pin types. It also reports the
// filter it shows (OnGwmMapFilter): in the "Gwent" filter a card sits where its player stands, in any
// other filter next to the merchant's shop icon.

function GwmVersion() : string
{
	return "1.0.9-local.3";
}

struct GwmPin
{
	var id    : int;
	var world : string;
	var x     : float;
	var y     : float;
	var role  : string;		// English text, used when no translation is available
	var roleKey : string;	// localization key in the mod's .w3strings
	var tag   : name;
	var card  : name;
	var noteKey   : string;			// optional spoiler-free note, localization key
	var goneFacts : array< string >;	// any of these facts > 0: the player no longer appears
	var store     : string;				// shop that sells Gwent cards (see AddStoreCard), or ""
	var storeGoneFact : string;			// fact > 0: no longer sells them (e.g. someone else runs the shop)
}

class GwmData
{
	public var pins : array< GwmPin >;

	// Gwent cards each shop sells: storeNames[ k ] sells storeCards[ k ].
	private var storeNames : array< string >;
	private var storeCards : array< name >;
	private var storeExactCards : array< name >;	// collection name: item without gwint_card_ (poor_infantry3)
	private var storeBaseCards  : array< name >;	// ...and without the copy number (poor_infantry)
	private var storeCardNames : array< name >;	// Gwent card of each item (cached, see CacheStoreCardNames)

	// Frame labels added to the world map pin sprite (modified panel_worldmap.redswf in content/blob0.bundle).
	public var iconNormal   : string;	default iconNormal   = "GwentPlayer";
	public var iconDefeated : string;	default iconDefeated = "GwentPlayerDisabled";

	// The map shows the "Gwent" filter (reported by the map file, see OnGwmMapFilter). Kept for the
	// session, so the map opens with the cards where the last filter had them.
	public var gwentFilter : bool;

	private var cardIconsChecked : bool;
	private var cardIconsLoaded  : bool;

	public function Init()
	{
		pins.Clear();
		storeNames.Clear();
		storeCards.Clear();
		storeExactCards.Clear();
		storeBaseCards.Clear();
		storeCardNames.Clear();
		GwmLoadData( this );
	}

	// The marker file ships in the same bundle as the card icons: if it can be loaded, so was the map file.
	// Only reported by the "Debug info" option.
	public function CardIconsLoaded() : bool
	{
		var marker : C2dArray;

		if ( !cardIconsChecked )
		{
			marker = LoadCSV( "gameplay\gui_new\swf\worldmap\gwm_card_icons.csv" );
			if ( marker )
			{
				cardIconsLoaded = true;
			}
			cardIconsChecked = true;
		}
		return cardIconsLoaded;
	}

	public function AddPin( id : int, world : string, x : float, y : float, role : string, roleKey : string, tag : name, card : name )
	{
		var pin : GwmPin;

		pin.id = id;
		pin.world = world;
		pin.x = x;
		pin.y = y;
		pin.role = role;
		pin.roleKey = roleKey;
		pin.tag = tag;
		pin.card = card;
		pins.PushBack( pin );
	}

	public function SetNote( id : int, noteKey : string )
	{
		var i : int = PinIndex( id );
		var pin : GwmPin;

		if ( i >= 0 )
		{
			pin = pins[ i ];
			pin.noteKey = noteKey;
			pins[ i ] = pin;
		}
	}

	public function AddGoneFact( id : int, fact : string )
	{
		var i : int = PinIndex( id );
		var pin : GwmPin;

		if ( i >= 0 )
		{
			pin = pins[ i ];
			pin.goneFacts.PushBack( fact );
			pins[ i ] = pin;
		}
	}

	public function AddStoreCard( store : string, card : name, exactCard : name, baseCard : name )
	{
		storeNames.PushBack( store );
		storeCards.PushBack( card );
		storeExactCards.PushBack( exactCard );
		storeBaseCards.PushBack( baseCard );
	}

	public function SetStore( id : int, store : string, goneFact : string )
	{
		var i : int = PinIndex( id );
		var pin : GwmPin;

		if ( i >= 0 )
		{
			pin = pins[ i ];
			pin.store = store;
			pin.storeGoneFact = goneFact;
			pins[ i ] = pin;
		}
	}

	// The Gwent card an item stands for, from the card definitions; looked up once per session
	// (GetCardNameFromItemName walks every card definition).
	private function CacheStoreCardNames()
	{
		var gwint : CR4GwintManager;
		var k : int;

		if ( storeCardNames.Size() == storeCards.Size() )
		{
			return;
		}
		gwint = theGame.GetGwintManager();
		storeCardNames.Clear();
		for ( k = 0; k < storeCards.Size(); k += 1 )
		{
			storeCardNames.PushBack( gwint.GetCardNameFromItemName( storeCards[ k ] ) );
		}
	}

	// The player has that card: the item itself, or the card in the Gwent collection (bought cards
	// live only there). Copy items such as gwint_card_poor_infantry3 have no card definition, and the
	// collection names the card poor_infantry, so the names derived from the item are checked too.
	private function StoreCardOwned( k : int ) : bool
	{
		var gwint : CR4GwintManager = theGame.GetGwintManager();

		if ( thePlayer.inv.HasItem( storeCards[ k ] ) )
		{
			return true;
		}
		CacheStoreCardNames();
		if ( IsNameValid( storeCardNames[ k ] ) && gwint.HasCardInCollection( storeCardNames[ k ] ) )
		{
			return true;
		}
		return gwint.HasCardInCollection( storeExactCards[ k ] ) || gwint.HasCardInCollection( storeBaseCards[ k ] );
	}

	// The pin's shop still has a Gwent card the player does not have. Checked each time, so cards
	// obtained before the mod was installed count too.
	public function SellsCardsYouLack( idx : int ) : bool
	{
		var k : int;

		if ( pins[ idx ].store == "" )
		{
			return false;
		}
		if ( pins[ idx ].storeGoneFact != "" && FactsQuerySum( pins[ idx ].storeGoneFact ) > 0 )
		{
			return false;
		}
		for ( k = 0; k < storeNames.Size(); k += 1 )
		{
			if ( storeNames[ k ] == pins[ idx ].store && !StoreCardOwned( k ) )
			{
				return true;
			}
		}
		return false;
	}

	// "Debug info": item names of the shop's cards the player lacks (validation aid, not translated).
	public function MissingStoreCards( idx : int ) : string
	{
		var k : int;
		var text : string;

		for ( k = 0; k < storeNames.Size(); k += 1 )
		{
			if ( storeNames[ k ] == pins[ idx ].store && !StoreCardOwned( k ) )
			{
				if ( text != "" )
				{
					text += ", ";
				}
				text += NameToString( storeCards[ k ] );
			}
		}
		return text;
	}

	private function PinIndex( id : int ) : int
	{
		var i : int;

		for ( i = 0; i < pins.Size(); i += 1 )
		{
			if ( pins[ i ].id == id )
			{
				return i;
			}
		}
		return -1;
	}

	// The game no longer spawns this player (a recorded story fact, see goneFacts).
	public function IsUnavailable( idx : int ) : bool
	{
		var i : int;

		for ( i = 0; i < pins[ idx ].goneFacts.Size(); i += 1 )
		{
			if ( FactsQuerySum( pins[ idx ].goneFacts[ i ] ) > 0 )
			{
				return true;
			}
		}
		return false;
	}

	// Facts written by GiveMerchantRandomGwintCardToPlayerQuest and friends on the first win.
	public function MerchantBeaten( tag : name ) : bool
	{
		var s : string = NameToString( tag );

		if ( FactsQuerySum( "merchant_card_" + s + "_card_already_given" ) > 0
			|| FactsQuerySum( s + "_gwent_given" ) > 0 )
		{
			return true;
		}
		// The game's quest data passes this tag with a trailing space.
		if ( tag == 'novigrad_poor_district_nowhere_01' )
		{
			return FactsQuerySum( "merchant_card_" + s + " _card_already_given" ) > 0;
		}
		return false;
	}

	public function IsDefeated( idx : int ) : bool
	{
		if ( IsNameValid( pins[ idx ].tag ) && MerchantBeaten( pins[ idx ].tag ) )
		{
			return true;
		}
		if ( IsNameValid( pins[ idx ].card ) && ( thePlayer.inv.HasItem( pins[ idx ].card )
			|| theGame.GetGwintManager().HasCardInCollection( theGame.GetGwintManager().GetCardNameFromItemName( pins[ idx ].card ) ) ) )
		{
			return true;
		}
		return FactsQuerySum( "gwm_won_" + pins[ idx ].id ) > 0;
	}

	// Nearest pin to pos within maxDist metres, or -1.
	public function FindNearest( world : string, pos : Vector, maxDist : float ) : int
	{
		var i, best : int;
		var dx, dy, d, bestDist : float;

		best = -1;
		bestDist = maxDist * maxDist;
		for ( i = 0; i < pins.Size(); i += 1 )
		{
			if ( pins[ i ].world != world )
			{
				continue;
			}
			dx = pins[ i ].x - pos.X;
			dy = pins[ i ].y - pos.Y;
			d = dx * dx + dy * dy;
			if ( d < bestDist )
			{
				bestDist = d;
				best = i;
			}
		}
		return best;
	}

	// Merchant whose NPC stands next to the player (the opponent of the match just played), or -1.
	private function MerchantPinNextToPlayer( world : string ) : int
	{
		var i : int;
		var npc : CNewNPC;
		var playerPos : Vector = thePlayer.GetWorldPosition();

		for ( i = 0; i < pins.Size(); i += 1 )
		{
			if ( pins[ i ].world != world || !IsNameValid( pins[ i ].tag ) )
			{
				continue;
			}
			npc = theGame.GetNPCByTag( pins[ i ].tag );
			if ( npc && VecDistanceSquared2D( npc.GetWorldPosition(), playerPos ) < 6 * 6 )
			{
				return i;
			}
		}
		return -1;
	}

	private function MarkWon( idx : int )
	{
		if ( FactsQuerySum( "gwm_won_" + pins[ idx ].id ) == 0 )
		{
			FactsAdd( "gwm_won_" + pins[ idx ].id, 1, -1 );
			if ( GwmConfigBool( 'GwmNotify', false ) )
			{
				theGame.GetGuiManager().ShowNotification( StrReplace( GwmLoc( "gwm_notify_beaten", "Gwent: {role} beaten. Marked on the map." ), "{role}", GwmRoleText( pins[ idx ] ) ) );
			}
		}
	}

	// Called on every won match. The game's own records stay the main source; this covers the
	// wins it does not record (card pool used up, Gwent overhauls changing the rewards).
	public function OnGwentWon()
	{
		var idx : int;
		var world : string = GwmCurrentWorldKey();

		if ( world == "" )
		{
			return;
		}

		// A merchant standing right next to the player was the opponent.
		idx = MerchantPinNextToPlayer( world );
		if ( idx >= 0 )
		{
			MarkWon( idx );
			return;
		}

		// Otherwise the closest pin, with a short radius so quest matches (tournaments, parties)
		// away from fixed players do not mark anyone. Merchants are included: once the shared
		// card pool is used up the game gives crafting materials and records nothing, and their
		// NPC is not always found by tag. Quest players are left to their card check.
		idx = FindNearest( world, thePlayer.GetWorldPosition(), 15 );
		if ( idx >= 0 && !IsNameValid( pins[ idx ].card ) )
		{
			MarkWon( idx );
		}
	}
}

@addField( CR4Game ) var gwmData : GwmData;

// theGame is const outside its class, so the field is created from a CR4Game method.
@addMethod( CR4Game ) function GwmGetOrCreateData() : GwmData
{
	if ( !gwmData )
	{
		gwmData = new GwmData in this;
		gwmData.Init();
		GwmInitConfig();
	}
	return gwmData;
}

function GwmGetData() : GwmData
{
	return theGame.GwmGetOrCreateData();
}

// Settings from Options > Mods > Gwent Players Map (bin\config\r4game\user_config_matrix\pc\modGwentPlayersMap.xml).
// Unset vars read as "", so defaults are written once; if the menu file is not
// installed the writes are no-ops and the code defaults below still apply.
function GwmInitConfig()
{
	var config : CInGameConfigWrapper = theGame.GetInGameConfigWrapper();
	var changed : bool;

	// Card size (1.0.7): new installs get the small card; players updating from an earlier version
	// (their settings already exist) keep the large card they know. Either can be changed later.
	if ( config.GetVarValue( 'GwentPlayersMap', 'GwmCardSize' ) == "" )
	{
		if ( config.GetVarValue( 'GwentPlayersMap', 'GwmShowPins' ) == "" )
		{
			config.SetVarValue( 'GwentPlayersMap', 'GwmCardSize', "0" );
		}
		else
		{
			config.SetVarValue( 'GwentPlayersMap', 'GwmCardSize', "1" );
		}
		changed = true;
	}
	if ( config.GetVarValue( 'GwentPlayersMap', 'GwmShowPins' ) == "" )
	{
		config.SetVarValue( 'GwentPlayersMap', 'GwmShowPins', "true" );
		changed = true;
	}
	if ( config.GetVarValue( 'GwentPlayersMap', 'GwmShowDefeated' ) == "" )
	{
		config.SetVarValue( 'GwentPlayersMap', 'GwmShowDefeated', "true" );
		changed = true;
	}
	if ( config.GetVarValue( 'GwentPlayersMap', 'GwmShowSellers' ) == "" )
	{
		config.SetVarValue( 'GwentPlayersMap', 'GwmShowSellers', "true" );
		changed = true;
	}
	if ( config.GetVarValue( 'GwentPlayersMap', 'GwmNotify' ) == "" )
	{
		config.SetVarValue( 'GwentPlayersMap', 'GwmNotify', "false" );
		changed = true;
	}
	if ( config.GetVarValue( 'GwentPlayersMap', 'GwmDebug' ) == "" )
	{
		config.SetVarValue( 'GwentPlayersMap', 'GwmDebug', "false" );
		changed = true;
	}
	if ( changed )
	{
		theGame.SaveUserSettings();
	}
}

function GwmConfigBool( varName : name, defaultValue : bool ) : bool
{
	var value : string = theGame.GetInGameConfigWrapper().GetVarValue( 'GwentPlayersMap', varName );

	if ( value == "" )
	{
		return defaultValue;
	}
	// The game stores toggles as "true"/"false" or as "1"/"0" depending on how they were set.
	value = StrLower( value );
	return value == "true" || value == "1";
}

// Map data is per world: Velen and Novigrad share one, Toussaint is "bob".
function GwmWorldKey( path : string ) : string
{
	path = StrLower( path );
	if ( StrContains( path, "winter" ) )
	{
		return "";
	}
	if ( StrContains( path, "novigrad" ) )
	{
		return "novigrad";
	}
	if ( StrContains( path, "skellige" ) )
	{
		return "skellige";
	}
	if ( StrContains( path, "prolog_village" ) )
	{
		return "prolog_village";
	}
	if ( StrContains( path, "bob" ) )
	{
		return "bob";
	}
	return "";
}

function GwmCurrentWorldKey() : string
{
	return GwmWorldKey( theGame.GetWorld().GetDepotPath() );
}

// Vanilla map pin types that mark a shop or service NPC.
function GwmIsShopPinType( type : name ) : bool
{
	return type == 'Shopkeeper' || type == 'Blacksmith' || type == 'Armorer' || type == 'Innkeeper'
		|| type == 'Herbalist' || type == 'Alchemic' || type == 'Enchanter' || type == 'Hairdresser'
		|| type == 'Prostitute' || type == 'WineMerchant' || type == 'DyeMerchant' || type == 'Cammerlengo'
		|| type == 'Archmaster' || type == 'BoatBuilder';
}

// Distance in metres the card is moved east of the merchant icon outside the "Gwent" filter
// (about one icon width at the usual city zoom).
function GwmSideOffset() : float
{
	return 18;
}

@wrapMethod( CR4Player ) function SetGwintMinigameState( minigameState : EMinigameState )
{
	var wasWon : bool = GetGwintMinigameState() == EMS_End_PlayerWon;

	wrappedMethod( minigameState );

	// The gwent menu and quest scenes can both report the same result.
	if ( minigameState == EMS_End_PlayerWon && !wasWon )
	{
		GwmGetData().OnGwentWon();
	}
}

@wrapMethod( CR4MapMenu ) function UpdateEntityPins( out flashArray : CScriptedFlashArray ) : void
{
	var data          : GwmData;
	var mapManager    : CCommonMapManager;
	var worldPath     : string;
	var worldKey      : string;
	var instances     : array< SCommonMapPinInstance >;
	var shopPos       : array< Vector >;
	var shopUses      : array< int >;
	var i, j, k       : int;
	var showDefeated  : bool;
	var pos           : Vector;
	var playerPos     : Vector;
	var obj           : CScriptedFlashObject;
	var defeated      : bool;
	var unavailable   : bool;
	var pinType       : string;
	var d, bestDist   : float;
	var showDebug     : bool;
	var largeCards    : bool;
	var added         : int;
	var showSellers   : bool;
	var description   : string;
	var missing       : string;

	wrappedMethod( flashArray );

	showDebug = GwmConfigBool( 'GwmDebug', false );
	if ( !GwmConfigBool( 'GwmShowPins', true ) )
	{
		if ( showDebug )
		{
			GwmDebugNote( "markers are switched off in the options" );
		}
		return;
	}

	data = GwmGetData();
	mapManager = theGame.GetCommonMapManager();
	worldPath = mapManager.GetWorldPathFromAreaType( m_shownArea );
	worldKey = GwmWorldKey( worldPath );
	if ( worldKey == "" )
	{
		if ( showDebug )
		{
			GwmDebugNote( "no Gwent players on this map (" + worldPath + ")" );
		}
		return;
	}

	largeCards = theGame.GetInGameConfigWrapper().GetVarValue( 'GwentPlayersMap', 'GwmCardSize' ) == "1";
	showDefeated = GwmConfigBool( 'GwmShowDefeated', true );
	showSellers = GwmConfigBool( 'GwmShowSellers', true );

	// Shop icons the vanilla map is showing, to line the cards up with.
	instances = mapManager.GetMapPinInstances( worldPath );
	for ( i = 0; i < instances.Size(); i += 1 )
	{
		if ( ( instances[ i ].isDiscovered || instances[ i ].isKnown ) && GwmIsShopPinType( instances[ i ].type ) )
		{
			shopPos.PushBack( instances[ i ].position );
			shopUses.PushBack( 0 );
		}
	}

	playerPos = thePlayer.GetWorldPosition();
	for ( i = 0; i < data.pins.Size(); i += 1 )
	{
		if ( data.pins[ i ].world != worldKey )
		{
			continue;
		}

		defeated = data.IsDefeated( i );
		unavailable = !defeated && data.IsUnavailable( i );
		// Players no longer available are greyed out like beaten ones and follow the same option.
		if ( defeated || ( unavailable && !showDefeated ) )
		{
			continue;
		}
		if ( defeated || unavailable )
		{
			pinType = data.iconDefeated;
			if ( largeCards ) { pinType = "GwentPlayerLargeDisabled"; }
		}
		else
		{
			pinType = data.iconNormal;
			if ( largeCards ) { pinType = "GwentPlayerLarge"; }
		}

		pos = Vector( data.pins[ i ].x, data.pins[ i ].y, 0 );

		// "Gwent" filter (only the cards are listed): the card stays where the player stands.
		// Any other filter: a merchant with a shop icon close by gets the card next to that icon.
		j = -1;
		if ( IsNameValid( data.pins[ i ].tag ) && !data.gwentFilter )
		{
			bestDist = 30 * 30;
			for ( k = 0; k < shopPos.Size(); k += 1 )
			{
				d = VecDistanceSquared2D( pos, shopPos[ k ] );
				if ( d < bestDist )
				{
					bestDist = d;
					j = k;
				}
			}
		}
		if ( j >= 0 )
		{
			// A second card next to the same icon (e.g. two smiths at one forge) goes one step further.
			pos = shopPos[ j ];
			pos.X += GwmSideOffset() * ( shopUses[ j ] + 1 );
			shopUses[ j ] += 1;
		}

		obj = GetMenuFlashValueStorage().CreateTempFlashObject( "red.game.witcher3.data.StaticMapPinData" );
		// Fixed offset keeps our ids away from the name hashes vanilla pins use.
		obj.SetMemberFlashUInt(   "id",            1196883968 + data.pins[ i ].id );
		obj.SetMemberFlashUInt(   "areaId",        NameToFlashUInt( m_shownArea ) );
		obj.SetMemberFlashUInt(   "journalAreaId", NameToFlashUInt( mapManager.GetJournalAreaByPosition( m_shownArea, pos ) ) );
		obj.SetMemberFlashNumber( "posX",          pos.X );
		obj.SetMemberFlashNumber( "posY",          pos.Y );
		obj.SetMemberFlashString( "type",          pinType );
		// The patched map file files "GwentPlayer" under its "Gwent" filter (and "Default").
		// One filtered type for beaten and not beaten keeps them in a single legend row.
		obj.SetMemberFlashString( "filteredType",  "GwentPlayer" );
		obj.SetMemberFlashNumber( "radius",        0 );
		obj.SetMemberFlashBool(   "isFastTravel",  false );
		obj.SetMemberFlashBool(   "isQuest",       false );
		obj.SetMemberFlashBool(   "isPlayer",      false );
		obj.SetMemberFlashBool(   "isUserPin",     false );
		if ( IsCurrentAreaShown() )
		{
			obj.SetMemberFlashNumber( "distance", VecDistanceSquared2D( playerPos, pos ) );
		}
		else
		{
			obj.SetMemberFlashNumber( "distance", 0 );
		}
		// The legend row takes its text from the label, so the label is the same for every card.
		obj.SetMemberFlashString( "label", GwmLoc( "gwm_label_gwent_player", "Gwent player" ) );
		description = GwmRoleText( data.pins[ i ] ) + " - " + GwmStatusText( data.pins[ i ], defeated, unavailable ) + GwmNoteText( data.pins[ i ] )
			+ ( data.LocalSellerText( i, showSellers && !unavailable ) );
		if ( showDebug && showSellers )
		{
			missing = data.MissingStoreCards( i );
			if ( missing != "" )
			{
				description += " [" + missing + "]";
			}
		}
		obj.SetMemberFlashString( "description", description );
		flashArray.PushBackFlashObject( obj );
		added += 1;
	}

	GwmAppendShopPins( flashArray, data, worldKey, showSellers );

	if ( showDebug )
	{
		if ( data.CardIconsLoaded() )
		{
			GwmDebugNote( added + " markers on " + worldKey + ", map file loaded" );
		}
		else
		{
			GwmDebugNote( added + " markers on " + worldKey + ", MAP FILE NOT LOADED (cards are invisible)" );
		}
	}
}

// Called by the map file each time it shows a filter category ("All", "Default", "Gwent", ...).
// A map file without this call (an older merged map) never reports one: the cards stay next to the icons.
@addMethod( CR4MapMenu ) event OnGwmMapFilter( category : string )
{
	var data : GwmData = GwmGetData();
	var gwent : bool = category == "Gwent";

	// Rebuilding the markers shows the category again, so this only acts when the mode changes.
	if ( gwent != data.gwentFilter )
	{
		data.gwentFilter = gwent;
		UpdateData( true );
	}
}

// "Debug info" option: one line on screen each time the world map builds its markers.
function GwmDebugNote( text : string )
{
	theGame.GetGuiManager().ShowNotification( "Gwent Players Map " + GwmVersion() + ": " + text );
}

// Quest players are judged by their card, so say that; everyone else is beaten or not.
function GwmStatusText( pin : GwmPin, defeated : bool, unavailable : bool ) : string
{
	if ( unavailable )
	{
		return GwmLoc( "gwm_status_unavailable", "No longer available." );
	}
	if ( IsNameValid( pin.card ) )
	{
		if ( defeated )
		{
			return GwmLoc( "gwm_status_card_obtained", "Card obtained." );
		}
		return GwmLoc( "gwm_status_card_not_obtained", "Card not obtained yet." );
	}
	if ( defeated )
	{
		return "已赢过：存档存在首胜或本 Mod 胜利记录。";
	}
	return "未发现首胜记录（不代表从未打过）。";
}

// Optional spoiler-free note after the status (English fallbacks match gen_strings.py).
function GwmNoteText( pin : GwmPin ) : string
{
	if ( pin.noteKey == "gwm_note_may_leave" )
	{
		return " " + GwmLoc( pin.noteKey, "May no longer be available after a certain quest." );
	}
	if ( pin.noteKey == "gwm_note_rescue_first" )
	{
		return " " + GwmLoc( pin.noteKey, "Must be rescued first." );
	}
	return "";
}

// "Show who sells Gwent cards" option: one more line while the shop has a card the player lacks.
function GwmSellerText( show : bool ) : string
{
	if ( !show )
	{
		return "";
	}
	return " " + GwmLoc( "gwm_note_sells_cards", "Also sells Gwent cards." );
}

// Text shown to the player: the translation from the mod's .w3strings, or the English text when
// the key is missing (a deleted or incomplete language file shows English instead of "#key").
// The Debug info lines stay in English on purpose, so reports are easy to read.
function GwmLoc( key : string, english : string ) : string
{
	var text : string = GetLocStringByKeyExt( key );

	if ( StrLen( text ) == 0 || StrBeginsWith( text, "#" ) )
	{
		return english;
	}
	return text;
}

function GwmRoleText( pin : GwmPin ) : string
{
	return GwmLoc( pin.roleKey, pin.role );
}


// Local customization 2026-10-19. Original: mateusands, CC BY-NC-SA 4.0.
// -1 means unavailable to the streaming world, NOT sold out. Do not invent remote stock.
@addMethod( GwmData ) function LocalLiveStock( idx : int ) : int
{
    var npc : CNewNPC;
    var inventory : CInventoryComponent;
    var ids : array< SItemUniqueId >;
    var k, count : int;
    if ( pins[ idx ].world != GwmCurrentWorldKey() )
    {
        return -1;
    }
    npc = LocalKnownNpc( idx );
    if ( !npc ) { return -1; }
    inventory = npc.GetInventory();
    if ( !inventory ) { return -1; }
    inventory.GetAllItems( ids );
    for ( k = 0; k < ids.Size(); k += 1 )
    {
        if ( inventory.ItemHasTag( ids[ k ], 'GwintCard' ) )
        {
            count += inventory.GetItemQuantity( ids[ k ] );
        }
    }
    return count;
}

@addMethod( GwmData ) function LocalSellerText( idx : int, show : bool ) : string
{
    var count : int;
    if ( !show || pins[ idx ].store == "" ) { return ""; }
    if ( pins[ idx ].storeGoneFact != "" && FactsQuerySum( pins[ idx ].storeGoneFact ) > 0 )
    {
        return " 购牌：此商店已不可用。";
    }
    count = LocalPurchaseRemaining( idx );
    if ( count > 0 ) { return " 购牌：尚余 " + count + " 张昆特牌（最近一次实际商店核验，含复数卡）。"; }
    if ( count == 0 ) { return " 购牌：最近一次实际商店核验已无可售昆特牌。"; }
    if ( SellsCardsYouLack( idx ) )
    {
        return " 购牌候选：此商店的已知牌单中有卡组尚缺的牌；远程库存未核实。";
    }
    return " 购牌待核实：已有对应牌种，不代表买齐所有复数卡；远程库存未加载。";
}

// Independent bag pins remain visible even with defeated opponents hidden.
// They are filed under Gwent so the Gwent-only filter includes purchase reminders too.
@addMethod( CR4MapMenu ) function GwmAppendShopPins( out flashArray : CScriptedFlashArray, data : GwmData, worldKey : string, show : bool )
{
    var i, count : int;
    var pos : Vector;
    var obj : CScriptedFlashObject;
    var mapManager : CCommonMapManager;
    if ( !show ) { return; }
    mapManager = theGame.GetCommonMapManager();
    for ( i = 0; i < data.pins.Size(); i += 1 )
    {
        if ( data.pins[ i ].world != worldKey || data.pins[ i ].store == "" || data.IsUnavailable( i ) ) { continue; }
        if ( data.pins[ i ].storeGoneFact != "" && FactsQuerySum( data.pins[ i ].storeGoneFact ) > 0 ) { continue; }
        count = data.LocalPurchaseRemaining( i );
        if ( count == 0 ) { continue; }
        pos = Vector( data.pins[ i ].x - 18, data.pins[ i ].y, 0 );
        obj = GetMenuFlashValueStorage().CreateTempFlashObject( "red.game.witcher3.data.StaticMapPinData" );
        obj.SetMemberFlashUInt( "id", 1196893968 + data.pins[ i ].id );
        obj.SetMemberFlashUInt( "areaId", NameToFlashUInt( m_shownArea ) );
        obj.SetMemberFlashUInt( "journalAreaId", NameToFlashUInt( mapManager.GetJournalAreaByPosition( m_shownArea, pos ) ) );
        obj.SetMemberFlashNumber( "posX", pos.X );
        obj.SetMemberFlashNumber( "posY", pos.Y );
        obj.SetMemberFlashString( "type", "Shopkeeper" );
        obj.SetMemberFlashString( "filteredType", "GwentPlayer" );
        obj.SetMemberFlashNumber( "radius", 0 );
        obj.SetMemberFlashBool( "isFastTravel", false );
        obj.SetMemberFlashBool( "isQuest", false );
        obj.SetMemberFlashBool( "isPlayer", false );
        obj.SetMemberFlashBool( "isUserPin", false );
        obj.SetMemberFlashNumber( "distance", 0 );
        obj.SetMemberFlashString( "label", GwmLoc( "gwm_label_gwent_player", "Gwent player" ) );
        obj.SetMemberFlashString( "description", "【购牌】" + GwmRoleText( data.pins[ i ] ) + data.LocalSellerText( i, true ) );
        flashArray.PushBackFlashObject( obj );
    }
}

// Local.3: per-save trade observations and nearby native minimap reminders.
// Never infer that a shop is empty from an unloaded NPC or from owning one card copy.
@addMethod( GwmData ) function LocalCountShopCards( inventory : CInventoryComponent ) : int
{
    var ids : array< SItemUniqueId >;
    var i, count : int;
    if ( !inventory ) { return -1; }
    inventory.GetAllItems( ids );
    for ( i = 0; i < ids.Size(); i += 1 )
    {
        if ( inventory.ItemHasTag( ids[ i ], 'GwintCard' ) )
        {
            count += inventory.GetItemQuantity( ids[ i ] );
        }
    }
    return count;
}

@addMethod( GwmData ) function LocalShopIndex( npc : CNewNPC ) : int
{
    var i, candidate, matches : int;
    var world : string;
    var pos : Vector;
    if ( !npc ) { return -1; }
    world = GwmCurrentWorldKey();
    for ( i = 0; i < pins.Size(); i += 1 )
    {
        if ( pins[ i ].world == world && pins[ i ].store != "" && IsNameValid( pins[ i ].tag ) && npc.HasTag( pins[ i ].tag ) ) { return i; }
    }
    // A few fixed quest innkeepers have no known tag. Only accept a unique nearby
    // tagless shop, using the actual merchant's position, never the player's position.
    candidate = -1;
    for ( i = 0; i < pins.Size(); i += 1 )
    {
        if ( pins[ i ].world != world || pins[ i ].store == "" || IsNameValid( pins[ i ].tag ) ) { continue; }
        pos = Vector( pins[ i ].x, pins[ i ].y, 0 );
        if ( VecDistanceSquared2D( npc.GetWorldPosition(), pos ) < 8 * 8 )
        {
            candidate = i;
            matches += 1;
        }
    }
    if ( matches == 1 ) { return candidate; }
    return -1;
}

@addMethod( GwmData ) function LocalObserveShop( npc : CNewNPC, inventory : CInventoryComponent )
{
    var idx, count : int;
    var seenKey, leftKey : string;
    var actorTag : name;
    idx = LocalShopIndex( npc );
    if ( idx < 0 || !inventory ) { return; }
    count = LocalCountShopCards( inventory );
    if ( count < 0 ) { return; }
    seenKey = "gwm_shop_seen_" + pins[ idx ].id;
    leftKey = "gwm_shop_left_" + pins[ idx ].id;
    if ( FactsQuerySum( seenKey ) == 0 || FactsQuerySum( leftKey ) != count )
    {
        FactsSet( leftKey, count, -1 );
        FactsSet( seenKey, 1, -1 );
    }
    actorTag = StringToName( "gwm_shop_actor_" + pins[ idx ].id );
    if ( !npc.HasTag( actorTag ) ) { npc.AddTag( actorTag ); }
}

@addMethod( GwmData ) function LocalKnownNpc( idx : int ) : CNewNPC
{
    var npc : CNewNPC;
    if ( pins[ idx ].world != GwmCurrentWorldKey() ) { return NULL; }
    if ( IsNameValid( pins[ idx ].tag ) ) { npc = theGame.GetNPCByTag( pins[ idx ].tag ); }
    if ( !npc ) { npc = theGame.GetNPCByTag( StringToName( "gwm_shop_actor_" + pins[ idx ].id ) ); }
    return npc;
}

@addMethod( GwmData ) function LocalPurchaseRemaining( idx : int ) : int
{
    var live : int;
    // Only the real trade UI writes these facts. Read them on every query, so
    // switching to another save/new game cannot reuse another save's purchase state.
    if ( FactsQuerySum( "gwm_shop_seen_" + pins[ idx ].id ) > 0 )
    {
        return Max( 0, FactsQuerySum( "gwm_shop_left_" + pins[ idx ].id ) );
    }
    live = LocalLiveStock( idx );
    // A streamed entity with an uninitialised inventory is not proof of buying out a shop.
    if ( live == 0 ) { return -1; }
    return live;
}

@wrapMethod( CR4InventoryMenu ) function UpdateMerchantData() : void
{
    wrappedMethod();
    // Vanilla invokes this on opening a shop and after a successful buy/sell.
    if ( _shopNpc && _shopInv )
    {
        GwmGetData().LocalObserveShop( _shopNpc, _shopInv.GetInventoryComponent() );
    }
}

@addField( GwmData ) var localMiniTags : array< name >;
@addField( GwmData ) var localMiniTypes : array< name >;

@addMethod( GwmData ) function LocalUpdateMinimap()
{
    var i, j, stock : int;
    var npc, oldNpc : CNewNPC;
    var markerTag, markerType : name;
    var nextTags, nextTypes : array< name >;
    var manager : CCommonMapManager;
    var world : string;
    var enabled, sellers : bool;
    if ( !thePlayer || !theGame.IsActive() ) { return; }
    manager = theGame.GetCommonMapManager();
    world = GwmCurrentWorldKey();
    enabled = GwmConfigBool( 'GwmShowPins', true );
    sellers = GwmConfigBool( 'GwmShowSellers', true );
    for ( i = 0; i < pins.Size(); i += 1 )
    {
        if ( !enabled || world == "" || pins[ i ].world != world || IsUnavailable( i ) ) { continue; }
        npc = LocalKnownNpc( i );
        if ( !npc || VecDistanceSquared2D( npc.GetWorldPosition(), thePlayer.GetWorldPosition() ) > 150 * 150 ) { continue; }
        markerType = '';
        if ( !IsDefeated( i ) ) { markerType = 'User1'; }
        else if ( sellers && pins[ i ].store != "" )
        {
            if ( pins[ i ].storeGoneFact == "" || FactsQuerySum( pins[ i ].storeGoneFact ) == 0 )
            {
                stock = LocalPurchaseRemaining( i );
                if ( stock != 0 ) { markerType = 'User2'; }
            }
        }
        if ( !IsNameValid( markerType ) ) { continue; }
        // One reminder per actor avoids two icons on top of each other: duel first,
        // then purchase. Uses native minimap-supported symbols, not the world-map SWF.
        markerTag = StringToName( "gwm_mini_" + pins[ i ].id );
        if ( !npc.HasTag( markerTag ) ) { npc.AddTag( markerTag ); }
        for ( j = 0; j < localMiniTags.Size(); j += 1 )
        {
            if ( localMiniTags[ j ] == markerTag && localMiniTypes[ j ] != markerType )
            {
                manager.EnableDynamicMappin( markerTag, false, localMiniTypes[ j ], false, false );
            }
        }
        manager.EnableDynamicMappin( markerTag, true, markerType, false, false );
        nextTags.PushBack( markerTag );
        nextTypes.PushBack( markerType );
    }
    for ( i = 0; i < localMiniTags.Size(); i += 1 )
    {
        if ( !nextTags.Contains( localMiniTags[ i ] ) )
        {
            manager.EnableDynamicMappin( localMiniTags[ i ], false, localMiniTypes[ i ], false, false );
            oldNpc = theGame.GetNPCByTag( localMiniTags[ i ] );
            if ( oldNpc ) { oldNpc.RemoveTag( localMiniTags[ i ] ); }
        }
    }
    localMiniTags = nextTags;
    localMiniTypes = nextTypes;
}

@addField( CR4HudModuleMinimap2 ) var gwmMiniElapsed : float;
@wrapMethod( CR4HudModuleMinimap2 ) function UpdatePlayerPositionAndRotation( timeDelta : float )
{
    wrappedMethod( timeDelta );
    gwmMiniElapsed += timeDelta;
    if ( gwmMiniElapsed >= 1.0 )
    {
        gwmMiniElapsed = 0;
        GwmGetData().LocalUpdateMinimap();
    }
}
