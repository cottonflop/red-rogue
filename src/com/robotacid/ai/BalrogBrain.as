package com.robotacid.ai {
	import com.robotacid.engine.Character;
	import com.robotacid.phys.Cast;
	import com.robotacid.phys.Collider;
	
	/**
	 * Lures the player and minion deeper into the dungeon
	 * 
	 * @author Aaron Steed, robotacid.com
	 */
	public class BalrogBrain extends Brain {
		
		// behavioural states
		//public static const PATROL:int = 0;
		//public static const PAUSE:int = 1;
		//public static const ATTACK:int = 2;
		//public static const FLEE:int = 3;
		public static const ESCAPE:int = 4;
		public static const TAUNT:int = 5;
		
		public static const ESCAPE_PAUSE_EDGE:Number = Game.SCALE * 6.5;
		public static const ESCAPE_MOVE_EDGE:Number = Game.SCALE * 4;
		public static const ESCAPE_PAUSE_EDGE_SQ:Number = ESCAPE_PAUSE_EDGE_SQ * ESCAPE_PAUSE_EDGE_SQ;
		public static const ESCAPE_MOVE_EDGE_SQ:Number = ESCAPE_MOVE_EDGE_SQ * ESCAPE_MOVE_EDGE_SQ;
		
		public function BalrogBrain(char:Character) {
			super(char, MONSTER, null);
			state = ESCAPE;
		}
		
		override public function main():void {
			
			charPos.x = char.collider.x + char.collider.width * 0.5;
			charPos.y = char.collider.y + char.collider.height * 0.5;
			var charContact:Character;
			if(char.collider.leftContact) charContact = char.collider.leftContact.userData as Character;
			if(!charContact && char.collider.rightContact) charContact = char.collider.rightContact.userData as Character;
			
			crossedTileCenter = (
				(prevCenter < char.tileCenter && charPos.x > char.tileCenter) ||
				(prevCenter > char.tileCenter && charPos.x < char.tileCenter)
			);
			
			// only random targets whilst confused
			if(confusedCount){
				confusedCount--;
				if(confusedCount == 0) clear();
				else if(confusedCount % 30 == 0) confusedBehaviour();
				
			} else {
				if(playerCharacters.length){
					sheduleIndex = (sheduleIndex + 1) % playerCharacters.length;
					scheduleTarget = playerCharacters[sheduleIndex];
				} else {
					scheduleTarget = null;
				}
				
				if(scheduleTarget){
					scheduleTargetPos.x = scheduleTarget.collider.x + scheduleTarget.collider.width * 0.5;
					scheduleTargetPos.y = scheduleTarget.collider.y + scheduleTarget.collider.height * 0.5;
				}
			}
			
			// monitor schedule targets for proximity
			var targetX:Number = scheduleTarget.collider.x + scheduleTarget.collider.width * 0.5;
			var targetY:Number = scheduleTarget.collider.y + scheduleTarget.collider.height * 0.5;
			
			var vx:Number = targetX - charPos.x;
			var vy:Number = targetY - charPos.y;
			var distSq:Number = vx * vx + vy * vy;
			
			// stand by the exit to the dungeon, waiting for the player or minion to attack, then exit
			if(state == TAUNT){
				if(game.player.mapX < char.mapX) char.looking = LEFT;
				else if(game.player.mapX > char.mapX) char.looking = RIGHT;
				
				// exit when any schedule target is too near or a missile weapon is directed at us
				if(distSq < ESCAPE_MOVE_EDGE_SQ){
					
					// stairs logic
					
				}
				
			// the balrog will run ahead, then wait for the player or minion - taunting them
			} else if(state == ESCAPE || state == PAUSE){
				
				if(state == ESCAPE){
					
					if(distSq > ESCAPE_PAUSE_EDGE_SQ){
						if(count-- <= 0){
							state = PAUSE;
							
						}
					} else {
						// we have found the exit - the player has lost this level
						if(char.mapX == game.map.stairsDown.x && char.mapY == game.map.stairsDown.y){
							state = TAUNT;
							return;
						}
						count = delay;
					}
					
				} else if(state == PAUSE){
					
					if(game.player.mapX < char.mapX) char.looking = LEFT;
					else if(game.player.mapX > char.mapX) char.looking = RIGHT;
					
					if(distSq < ESCAPE_MOVE_EDGE_SQ){
						
						state = ESCAPE;
						game.createDistSound(char.mapX, char.mapY, "voice", char.voice);
						
					}
				}
				
				// indifferent characters do not look for a fight
				if(char.indifferent) return;
				
				// only attack when attacked
				if(charContact && char.enemy(charContact)){
					attack(charContact);
					count = delay + game.random.range(delay);
				}
				
			} else if(state == ATTACK){
				
				
				
				
				// attack only for a short duration
				
				
				
				if(!target || !target.active){
					clear();
					
				} else if(
					char.collider.y >= target.collider.y + target.collider.height &&
					!(
						char.collider.x >= target.collider.x + target.collider.width ||
						char.collider.x + char.collider.width <= target.collider.x
					)
				){
					if(target.type == Character.GATE) clear();
					else flee(target);
					
				} else {
					if(char.throwable || (char.weapon && (char.weapon.range & Item.MISSILE))){
						snipe(target);
					} else {
						chase(target);
						// commute allies to the target
						if(charContact && target.active && !char.enemy(charContact) && charContact.brain) charContact.brain.copyState(this);
					}
				}
				
			} else if(state == FLEE){
				
				if(!target || !target.active){
					clear();
					
				} else {
					avoid(target);
					// commute allies away from the target
					if(charContact && target.active && !char.enemy(charContact) && charContact.brain) charContact.brain.copyState(this);
					if(count-- <= 0){
						if(char.inTheDark){
							// we want fleeing characters in the dark to go back to patrolling
							// but not if they're on a ladder
							if(char.collider.state == Collider.HOVER){
								count = 1 + game.random.range(delay);
							} else {
								clear();
							}
						} else {
							// is the target a gate?
							if(target.type == Character.GATE) clear();
							else attack(target);
						}
					}
					if(charContact && char.enemy(charContact)){
						attack(target);
					}
				}
			}
			
			prevCenter = charPos.x;
		}
		
		
		override public function clear():void{
			target = null;
			patrolAreaSet = false;
			state = ESCAPE;
			altNode = null;
			// drop from ladder
			if(char.collider.state == Collider.HOVER){
				char.collider.state = Collider.FALL;
				char.collider.divorce();
			}
		}
		
		/* Navigate towards the level's stairs down */
		public function gotoExit():void{
			
			char.actions = 0;
			
			var graph:MapGraph = wallWalker ? walkWalkGraph : mapGraph;
			
			// use the escape graph
			start = graph.escapeNodes[char.mapY][char.mapX];
			
			// no node means the character must be falling or clipping a ledge
			if(start){
				
				node = graph.getEscapeNode(start);
				
				if(node){
					// navigate to node
					if(node.y == char.mapY){
						if(node.x > char.mapX){
							char.actions |= RIGHT;
							// get to the top of a ladder before leaping off it
							if(char.collider.y + char.collider.height - Collider.INTERVAL_TOLERANCE > (char.mapY + 1) * SCALE){
								char.actions = UP;
							}
							// a rare situation occurs when walking off a ladder to a ledge, resulting falling short
							// so we get the character to climb higher, allowing them to leap onto the ledge
							else if(!char.collider.parent && char.canClimb() && char.collider.y + char.collider.height > (char.mapY + SCALE * 1.5) * SCALE){
								char.actions = UP;
							}
						} else if(node.x < char.mapX){
							char.actions |= LEFT;
							// get to the top of a ladder before leaping off it
							if(char.collider.y + char.collider.height - Collider.INTERVAL_TOLERANCE > (char.mapY + 1) * SCALE){
								char.actions = UP;
							}
							// a rare situation occurs when walking off a ladder to a ledge, resulting falling short
							// so we get the character to climb higher, allowing them to leap onto the ledge
							else if(!char.collider.parent && char.canClimb() && char.collider.y + char.collider.height > (char.mapY + SCALE * 1.5) * SCALE){
								char.actions = UP;
							}
						}
					} else if(node.x == char.mapX){
						// heading up or down it's best to center on a tile to avoid the confusion
						// in moving from horizontal to vertical movement
						if(node.y > char.mapY){
							// avoid climbing down in favour of dropping
							if(char.collider.state == Collider.HOVER){
								char.collider.state = Collider.FALL;
							}
							if(char.collider.parent) char.actions |= DOWN;
							
						} else if(node.y < char.mapY){
							if(char.canClimb()){
								char.actions |= UP;
							} else {
								if(charPos.x > char.tileCenter) char.actions |= LEFT;
								else if(charPos.x < char.tileCenter) char.actions |= RIGHT;
							}
						}
						
					// we must be looking at a dive node
					} else {
						if(node.x > char.mapX){
							char.actions |= RIGHT;
						} else if(node.x < char.mapX){
							char.actions |= LEFT;
						}
					}
				}
			}
			// no path data to work with
			if(!start || !node){
				// character might be standing on the edge of a ledge - outside of a node
				char.actions |= DOWN;
				// chase the target blindly
				if(game.map.stairsDown.x < char.mapX) char.actions |= LEFT;
				else if(game.map.stairsDown.x > char.mapX) char.actions |= RIGHT;
				
			}
			
			if(char.actions) char.looking = char.actions & (LEFT | RIGHT);
			char.dir = char.actions & (LEFT | RIGHT | UP | DOWN);
		}
		
	}

}