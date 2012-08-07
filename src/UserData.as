package {
	import com.robotacid.engine.Item;
	import com.robotacid.engine.Player;
	import com.robotacid.engine.Portal;
	import com.robotacid.gfx.Renderer;
	import com.robotacid.level.Content;
	import com.robotacid.level.Map;
	import com.robotacid.sound.SoundManager;
	import com.robotacid.ui.Key;
	import com.robotacid.ui.menu.Menu;
	import com.robotacid.ui.menu.MenuOption;
	import flash.ui.Keyboard;
	import flash.net.SharedObject;
	/**
	/**
	 * Provides an interface for storing game data in a shared object and restoring the game from
	 * the shared object
	 *
	 * Games are saved when going down stairs and through the menu. The difference being that
	 * a menu save will only capture the current state of the menu - not the player.
	 *
	 * The data we capture is as follows:
	 *
	 * 	game settings
	 * 	key definitions
	 * 	player and minion status
	 * 	inventory
	 * 	hot key bindings
	 * 	content manager stocks
	 * 
	 * @author Aaron Steed, robotacid.com
	 */
	public class UserData {
		
		public static var game:Game
		public static var renderer:Renderer;
		
		public static var settings:Object;
		public static var gameState:Object
		
		private static var i:int;
		
		public function UserData() {
			
		}
		
		public static function push(settingsOnly:Boolean = false):void{
			var sharedObject:SharedObject = SharedObject.getLocal("red_rogue");
			sharedObject.data.settings = settings;
			if(!settingsOnly) sharedObject.data.gameState = gameState;
			sharedObject.flush();
			sharedObject.close();
		}
		
		public static function pull():void{
			var sharedObject:SharedObject = SharedObject.getLocal("red_rogue");
			if(sharedObject.data.settings) overwrite(settings, sharedObject.data.settings);
			//if(sharedObject.data.gameState) overwrite(gameState, sharedObject.data.gameState);
			sharedObject.flush();
			sharedObject.close();
		}
		
		public static function reset():void{
			initSettings();
			initGameState();
			push();
		}
		
		/* Overwrites matching variable names with source to target */
		public static function overwrite(target:Object, source:Object):void{
			for(var key:String in source){
				if(target[key]) target[key] = source[key];
			}
		}
		
		/* This is populated on the fly by com.robotacid.level.Content */
		public static function initGameState():void{
			var i:int, j:int, xml:XML;
			
			gameState = {
				player:{
					previousLevel:Map.OVERWORLD,
					previousPortalType:Portal.STAIRS,
					previousMapType:Map.AREA,
					currentLevel:1,
					currentMapType:Map.MAIN_DUNGEON
				},
				runeNames:[],
				storyCharCodes:[]
			};
			for(i = 0; i < Game.MAX_LEVEL; i++){
				gameState.runeNames.push("?");
			}
			// the identify rune's name is already known (obviously)
			gameState.runeNames[Item.IDENTIFY] = Item.stats["rune names"][Item.IDENTIFY];
		}
		
		public static function saveGameState():void{
			gameState.player.previousLevel = Player.previousLevel;
			gameState.player.previousPortalType = Player.previousPortalType;
			gameState.player.previousMapType = Player.previousMapType;
			gameState.player.currentLevel = game.map.level;
			gameState.player.currentMapType = game.map.type;
		}
		
		/* Create the default settings object to initialise the game from */
		public static function initSettings():void{
			settings = {
				customKeys:[Key.W, Key.S, Key.A, Key.D, Keyboard.SPACE, Key.F, Key.Z, Key.X, Key.C, Key.V, Key.M, Key.NUMBER_1, Key.NUMBER_2, Key.NUMBER_3, Key.NUMBER_4],
				sfx:true,
				music:true,
				autoSortInventory:true,
				menuMoveSpeed:4,
				consoleScrollDir: -1,
				randomSeed:0,
				dogmaticMode:false,
				multiplayer:false,
				hotKeyMaps:[
					<hotKey>
					  <branch selection="0" name="actions" context="null"/>
					  <branch selection="3" name="shoot" context="missile"/>
					</hotKey>,
					<hotKey>
					  <branch selection="0" name="actions" context="null"/>
					  <branch selection="0" name="search" context="null"/>
					</hotKey>,
					<hotKey>
					  <branch selection="0" name="actions" context="null"/>
					  <branch selection="2" name="disarm trap" context="null"/>
					</hotKey>,
					<hotKey>
					  <branch selection="0" name="actions" context="null"/>
					  <branch selection="1" name="summon" context="null"/>
					</hotKey>,
					<hotKey>
					  <branch selection="0" name="actions" context="null"/>
					  <branch selection="4" name="jump" context="null"/>
					</hotKey>,
					<hotKey>
					  <branch selection="3" name="options" context="null"/>
					  <branch selection="14" name="multiplayer" context="null"/>
					  <branch selection="1" name="minion shoot" context="minion missile"/>
					</hotKey>
				],
				loreUnlocked:{
					races:[],
					weapons:[],
					armour:[]
				},
				areaContent:[]
			};
			
			settings.areaContent = [];
			for(var level:int = 0; level < Content.TOTAL_AREAS; level++){
				settings.areaContent.push({
					chests:[],
					monsters:[],
					portals:[]
				});
			}
			if(settings.areaContent[Map.UNDERWORLD].portals.length == 0){
				Content.setUnderworldPortal(15, Map.MAIN_DUNGEON);
			}
		}
		
		/* Push settings data to the shared object */
		public static function saveSettings():void{
			settings = {
				customKeys:Key.custom.slice(),
				sfx:SoundManager.sfx,
				music:SoundManager.music,
				autoSortInventory:game.gameMenu.inventoryList.autoSort,
				menuMoveSpeed:Menu.moveDelay,
				consoleScrollDir:game.console.targetScrollDir,
				randomSeed:Map.seed,
				dogmaticMode:game.dogmaticMode,
				multiplayer:game.multiplayer,
				hotKeyMaps:[],
				loreUnlocked:{
					races:[],
					weapons:[],
					armour:[]
				}
			};
			
			// save the hotkeymaps
			for(i = 0; i < game.gameMenu.hotKeyMaps.length; i++){
				if(game.gameMenu.hotKeyMaps[i]) settings.hotKeyMaps.push(game.gameMenu.hotKeyMaps[i].toXML());
				else settings.hotKeyMaps.push(null);
			}
			// save lore
			var options:Vector.<MenuOption>;
			var record:Array;
			options = game.gameMenu.loreList.racesList.options;
			record = settings.loreUnlocked.races;
			for(i = 0; i < options.length; i++){
				record[i] = options[i].active;
			}
			options = game.gameMenu.loreList.weaponsList.options;
			record = settings.loreUnlocked.weapons;
			for(i = 0; i < options.length; i++){
				record[i] = options[i].active;
			}
			options = game.gameMenu.loreList.armourList.options;
			record = settings.loreUnlocked.armour;
			for(i = 0; i < options.length; i++){
				record[i] = options[i].active;
			}
		}
		
	}

}