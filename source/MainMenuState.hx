package;

#if desktop
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import Achievements;
import editors.MasterEditorMenu;
import flixel.input.keyboard.FlxKey;
import haxe.Json;
import haxe.format.JsonParser;
import sys.io.File;
import sys.FileSystem;
import FunkinLua.MenuLua;

import flixel.graphics.FlxGraphic;
import flixel.FlxBasic;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.graphics.atlas.FlxAtlas;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import lime.utils.Assets;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import flixel.util.FlxSave;
import FunkinLua;

using StringTools;
typedef MenuItemJson =
{
	var position:Array<Float>;
	var offsets:Array<Int>;
	var image:String;
	var scale:Array<Float>;
	var anims:Array<String>;
	var type:String;
	var functionOnPress:String;
	var fps:Array<Int>;
}
class MenuItemSprite extends FlxSprite
{
	var file:MenuItemJson;
	var offsets:Array<Int> = [0,0,0,0];
	var positions:Array<Float> = [0,0];
	var image:String;
	var scaleArray:Array<Float> = [1,1];
	var anims:Array<String> = [" basic"," white"];
	var type:String = 'share';
	var fps:Array<Int> = [24,24];
	var onPress:String = 'https://ninja-muffin24.itch.io/funkin';
	public function new(name:String,x:Float,y:Float)
	{
		file = Json.parse(Paths.getTextFromFile('jsons/mainmenu/'+ name));
		positions = file.position;
		var xAdd:Float = x + positions[0];
		var yAdd:Float = y + positions[1];
		super(xAdd,yAdd);
		fps = file.fps;
		frames = Paths.getSparrowAtlas(file.image);
		type = file.type;
		onPress = file.functionOnPress;
		anims = file.anims;
		offsets = file.offsets;

		if (fps == null) fps = [24,24];
		if (frames == null) frames = Paths.getSparrowAtlas('mainmenu/menu_story_mode');
		if (type == null) type = 'state';
		if (onPress == null) onPress = '0';
		if (anims == null) anims = ["story_mode basic","story_mode white"];
		if (offsets == null) offsets = [0,0,0,0];

		animation.addByPrefix('idle', anims[0], fps[0], true);
		animation.addByPrefix('selected', anims[1], fps[1],true);
		//addOffset('idle', offsets[0],offsets[1]);
		//addOffset('selected', offsets[2],offsets[3]);
		idle();
	}
	public function select()
	{
		animation.play('selected');
		offset.set( offsets[2] , offsets[3] );
	}
	public function pressed()
	{
		switch(type)
		{
			case 'share':
				CoolUtil.browserLoad(onPress);
				MusicBeatState.switchState(new MainMenuState());
			case 'state':
			{
				switch(onPress)
				{
					case '0':
						MusicBeatState.switchState(new StoryMenuState());
					case '1':
						MusicBeatState.switchState(new FreeplayState());
					#if MODS_ALLOWED
					case '2':
						MusicBeatState.switchState(new ModsMenuState());
					#end
					case '3':
						MusicBeatState.switchState(new AchievementsMenuState());
					case '4':
						MusicBeatState.switchState(new CreditsState());
					case '5':
						LoadingState.loadAndSwitchState(new options.OptionsState());
					default:
						MusicBeatState.switchState(new StoryMenuState());
				}
			}
			//case 'lua state':


		}
	}
	public function idle()
	{
		animation.play('idle');
		offset.set( offsets[0] , offsets[1] );
	}
}
class MainMenuState extends MusicBeatState
{
	#if (haxe >= "4.0.0")
	public var variables:Map<String, Dynamic> = new Map();
	#else
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	#end

	public var hitBeat:Bool = false;

	public var debugAllowed:Bool = true;
	public var beatHitAllow:Bool = false;
	public var addZoomInBeatHit:Bool = true;
	public var zoomAdds:Float = 0.015;
	public var camZooming:Bool = true;
	public var defaultCamZoom:Float = 1;
	public var camZoomingDecay:Float = 1;

	public static var psychEngineVersion:String = '0.6.2'; //This is also used for Discord RPC
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<MenuItemSprite>;
	public var camGame:FlxCamera;
	public var camAchievement:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;
	
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		#if ACHIEVEMENTS_ALLOWED 'awards', #end
		'credits',
		#if !switch 'donate', #end
		'options'
	];

	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;
	var debugKeys:Array<FlxKey>;

	public static var instance:MainMenuState;
	public var luaArray:Array<MenuLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var introSoundsSuffix:String = '';

	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();

	override function create()
	{
		instance = this;
		
		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end
		WeekData.loadTheFirstEnabledMod();

		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('jsons/mainmenu/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('jsons/mainmenu/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/jsons/mainmenu/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/jsons/mainmenu/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new MenuLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end

		optionShit = [];
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('jsons/mainmenu/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('jsons/mainmenu/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/jsons/mainmenu/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/jsons/mainmenu/'));// using push instead of insert because these should run after everything else
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.json') && !filesPushed.contains(file))
					{
						#if MODS_ALLOWED
						optionShit.push(file);
						filesPushed.push(file);
						#else
							if(file != 'mods.json') optionShit.push(file);
							filesPushed.push(file);
						#end
					}
				}
			}
		}

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camAchievement = new FlxCamera();
		camOther = new FlxCamera();
		camAchievement.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement);
		FlxG.cameras.add(camHUD);
		FlxG.cameras.add(camOther);
		FlxCamera.defaultCameras = [camGame];

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.antialiasing = ClientPrefs.globalAntialiasing;
		magenta.color = 0xFFfd719b;
		add(magenta);
		
		// magenta.scrollFactor.set();

		//menuItems = new FlxTypedGroup<FlxSprite>();
		menuItems = new FlxTypedGroup<MenuItemSprite>();
		add(menuItems);

		var scale:Float = 1;
		/*if(optionShit.length > 6) {
			scale = 6 / optionShit.length;
		}*/

		/*for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140)  + offset);
			menuItem.scale.x = scale;
			menuItem.scale.y = scale;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			var scr:Float = (optionShit.length - 4) * 0.135;
			if(optionShit.length < 6) scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = ClientPrefs.globalAntialiasing;
			//menuItem.setGraphicSize(Std.int(menuItem.width * 0.58));
			menuItem.updateHitbox();
		}*/
		for (i in 0...optionShit.length)
		{
			var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:MenuItemSprite = new MenuItemSprite(optionShit[i] ,0, (i * 140)  + offset);
			menuItem.scale.x = scale;
			menuItem.scale.y = scale;
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			var scr:Float = (optionShit.length - 4) * 0.135;
			if(optionShit.length < 6) scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.antialiasing = ClientPrefs.globalAntialiasing;
			//menuItem.setGraphicSize(Std.int(menuItem.width * 0.58));
			menuItem.updateHitbox();
		}


		FlxG.camera.follow(camFollowPos, null, 1);

		var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);
		var versionShit:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		// NG.core.calls.event.logEvent('swag').send();

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		Achievements.loadAchievements();
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18) {
			var achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
			if(!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) { //It's a friday night. WEEEEEEEEEEEEEEEEEE
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				giveAchievement();
				ClientPrefs.saveSettings();
			}
		}
		#end
		super.create();
		callOnLuas('onCreatePost', []);
		
	}

	#if ACHIEVEMENTS_ALLOWED
	// Unlocks "Freaky on a Friday Night" achievement
	function giveAchievement() {
		add(new AchievementObject('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		trace('Giving achievement "friday_night_play"');
	}
	#end

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		callOnLuas('onUpdate', [elapsed]);
		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
			if(FreeplayState.vocals != null) FreeplayState.vocals.volume += 0.5 * elapsed;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay), 0, 1));
		}

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeItem(1);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				callOnLuas('onAccepted', []);
				if (optionShit[curSelected] == 'donate')
				{
					CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
				}
				else
				{
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('confirmMenu'));

					if(ClientPrefs.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					menuItems.forEach(function(spr:MenuItemSprite)
					{
						if (curSelected != spr.ID)
						{
							FlxTween.tween(spr, {alpha: 0}, 0.4, {
								ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween)
								{
									spr.kill();
								}
							});
						}
						else
						{
							
							FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
							{
								//var daChoice:String = optionShit[curSelected];
								menuItems.forEach(function(spr:MenuItemSprite)
								{
									callOnLuas('onItemJustPressed', [spr.ID]);
									if (spr.ID == curSelected) spr.pressed();
								});
								//switch (daChoice)
								/*{
									case 'story_mode':
										MusicBeatState.switchState(new StoryMenuState());
									case 'freeplay':
										MusicBeatState.switchState(new FreeplayState());
									#if MODS_ALLOWED
									case 'mods':
										MusicBeatState.switchState(new ModsMenuState());
									#end
									case 'awards':
										MusicBeatState.switchState(new AchievementsMenuState());
									case 'credits':
										MusicBeatState.switchState(new CreditsState());
									case 'options':
										LoadingState.loadAndSwitchState(new options.OptionsState());
								}*/
							});
						}
					});
				}
				callOnLuas('onAcceptedPost', []);
			}
			#if desktop
			else if (FlxG.keys.anyJustPressed(debugKeys) && debugAllowed)
			{
				callOnLuas('onOpenDebug', []);
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}
		Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
		

		menuItems.forEach(function(spr:MenuItemSprite)
		{
			spr.screenCenter(X);
		});
		callOnLuas('onUpdatePost', [elapsed]);
	}
	var lastBeatHit:Int = -1;
	override public function beatHit()
	{
		super.beatHit();
		if(lastBeatHit == curBeat)
		{
			return;
		}
		callOnLuas('onBeatHit', []);
		if (beatHitAllow)
		{
			if (addZoomInBeatHit)
			{
				FlxG.camera.zoom += zoomAdds;
				camHUD.zoom += zoomAdds;
			}
		}
		setOnLuas('curBeat', curBeat); //DAWGG?????
		
		lastBeatHit = curBeat;
		callOnLuas('onBeatHitPost', []);
	}
	function changeItem(huh:Int = 0)
	{
		curSelected += huh;
		callOnLuas('onChangeItem', [huh,curSelected]);

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:MenuItemSprite)
		{
			//spr.animation.play('idle');
			spr.idle();
			spr.updateHitbox();

			if (spr.ID == curSelected)
			{
				//spr.animation.play('selected');
				spr.select();
				var add:Float = 0;
				if(menuItems.length > 4) {
					add = menuItems.length * 8;
				}
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
				//spr.centerOffsets();
			}
		});
		callOnLuas('onChangeItemPost', [huh,curSelected]);
	}
	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = true, exclusions:Array<String> = null):Dynamic {
		var returnVal:Dynamic = MenuLua.Function_Continue;
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			var ret:Dynamic = script.call(event, args);
			if(ret == MenuLua.Function_StopLua && !ignoreStops)
				break;
			
			if(ret != MenuLua.Function_Continue)
				returnVal = ret;
		}
		#end
		//trace(event, returnVal);
		return returnVal;
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		return null;
	}
	public function setOnLuas(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end
	}
	public function addCamZoom(cam:String = 'game',addZoomy:Float = 0.14)
	{
		switch(cam.toLowerCase())
		{
			case 'other' | 'camother': camOther.zoom += addZoomy;
			case 'hud' | 'camhud': camHUD.zoom += addZoomy;
			default: FlxG.camera.zoom += addZoomy;
		}
	}
}
