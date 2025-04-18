extends CharacterBody3D
var DEBUG = false

@onready var inventory_ui = $InventoryUI
@onready var settings_ui = $SettingsUI
@onready var animtree = $AnimationTree
@onready var states = animtree["parameters/playback"]
@onready var animationPlayer = $"PM 10-31-24/AnimationPlayer"

@onready var pistol = $"PM 10-31-24/Armature/Skeleton3D/Right Palm/Pistol"
@onready var grenade = get_tree().get_first_node_in_group("Grenade")
@onready var knife = get_tree().get_first_node_in_group("Knife")

@onready var hurtSFX = $HurtSFX
@onready var deathSFX = $DeathSFX

var grenadeScene = preload("res://Assets/Grenades/Grenade.tscn")
var equipped = "Pistol"


var current_ammo: int
var reserve_ammo: int

const FORWARD_SPEED = 5.5
const BACKWARD_SPEED = 3.5
const SPRINT_SPEED = 7.5
const TURNING_SPEED = 0.075
const GRAVITY_CONSTANT = 100
const MELEE_RANGE = 2.5

@export var turning_sensitivity: float = 1.0
var input = Vector3.ZERO

var canThrow = true
var canMelee = true
var turning = false
var targetTurn = null
var playerDead = false

var MAX_HEALTH: int = 100
var current_health: int

var bloodEffect = preload("res://Shaders/Blood/Blood_Effect.tscn")

#signal player_hit

func _ready() -> void:
	#Will initially grant max health to the player
	current_health = MAX_HEALTH
	InventoryManager.set_player_reference(self)
	pistol.add_starting_inventory()
	add_starting_inventory()



func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	
	if playerDead:
		return
	
	#Applies gravity if necessary
	animtree.advance(delta * 0)
	if not is_on_floor():
		velocity.y -= GRAVITY_CONSTANT*delta
	
	#Gets movement inputs
	character_movement(delta)

func character_movement(delta: float):
	var current_y_velocity = velocity.y
	current_ammo = pistol.current_ammo
	reserve_ammo = pistol.reserve_ammo
	
	if (turning):
		turn_around(delta, 0.15)
		return
	
	
	if Input.is_action_pressed("Move Forward") and Input.is_action_pressed("Move Backward"):
		velocity.x = 0
		velocity.z = 0
		states.travel("idlepose")

	elif Input.is_action_pressed("Move Forward"):
		var forwardVector = -Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
		velocity = -forwardVector * FORWARD_SPEED
		animtree.advance(delta * 1.5)
		
		if (Input.is_action_pressed("Sprint")):
			velocity *= 1.5
			animtree.advance(delta * 1.7)
		
		if (equipped == "Pistol"):
			states.travel("walkGun")
		else:
			states.travel("walkNoGun")
		
	elif Input.is_action_pressed("Move Backward"):
		var backwardVector = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
		velocity = -backwardVector * BACKWARD_SPEED
		animtree.advance(delta * 1)
		if (equipped == "Pistol"):
			states.travel("walkGunBackwards")
		else:
			states.travel("walkNoGunBackwards")
	elif Input.is_action_pressed("Secondary Fire (Aim)") and equipped == "Pistol":
		velocity.x = 0
		velocity.z = 0
		states.travel("PistolActionAim")
		if Input.is_action_pressed("Primary Fire") && current_ammo != 0 && !pistol.is_reloading:
			states.travel("pistolActionShootTimer")
		
		if Input.is_action_just_pressed("Target"):
			var nearest = get_nearest_enemy()
			
			#rotate_to(delta, nearest, 0.5)
			
			#await get_tree().create_timer(1).timeout
			if nearest != null:
				look_at(Vector3(nearest.global_position.x, global_position.y, nearest.global_position.z))
	else:
		velocity.x = 0
		velocity.z = 0
		states.travel("idlepose")
	
	velocity.y = current_y_velocity
	
	
	# If moving back while turning left, turn right
	if Input.is_action_pressed("Turn Left") and Input.is_action_pressed("Move Backward"):
		rotation.y -= input.y + TURNING_SPEED *turning_sensitivity
		velocity.y -= delta*GRAVITY_CONSTANT
	
	elif Input.is_action_pressed("Turn Left"):
		rotation.y += input.y + TURNING_SPEED *turning_sensitivity
		velocity.y -= delta*GRAVITY_CONSTANT

	# If moving back while turning right, turn left
	if Input.is_action_pressed("Turn Right") and Input.is_action_pressed("Move Backward"):
		rotation.y += input.y + TURNING_SPEED *turning_sensitivity
		velocity.y -= delta*GRAVITY_CONSTANT
		
		
	elif Input.is_action_pressed("Turn Right"):
		rotation.y -= input.y + TURNING_SPEED *turning_sensitivity
		velocity.y -= delta*GRAVITY_CONSTANT
	
	elif Input.is_action_just_pressed("Turn Around") and !turning:
		targetTurn = rotation.y + PI
		turning = true
		
		
	
	if Input.is_action_pressed("Secondary Fire (Aim)") && equipped == "Knife":
		states.travel("Knife Ready")
		
		if (Input.is_action_just_pressed("Primary Fire") && canMelee):
			states.travel("KnifeSwing")
			
	elif Input.is_action_just_pressed("Primary Fire") && equipped == "Grenade" && canThrow:
		canThrow = false
		$ThrowTimer.start()
		states.travel("LobThrowGrenade")
	elif Input.is_action_just_pressed("Secondary Fire (Aim)") && equipped == "Grenade" && canThrow:
		canThrow = false
		$ThrowTimer.start()
		states.travel("UnderGrenadeThrow")
	else:
		move_and_slide()

#Returns enemy closest to the player's looking direction when called.
func get_nearest_enemy():
	var nearest = null
	var overlaps = $VisionArea.get_overlapping_bodies()
	if overlaps.size() > 0:
		for overlap in overlaps:
			if overlap.is_in_group("enemies"):
				if nearest == null:
					nearest = overlap
				elif (overlap.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position)):
					nearest = overlap
	return nearest

func rotate_to(delta, posit, time):
	var pos = Vector2(global_position.x, global_position.z)
	var objectPos = Vector2(posit.x, posit.z)
	var direction = (pos - objectPos)
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.y), delta / time)

#Turn around 180 degrees
func turn_around(delta, time):
	rotation.y += delta / time
	var rotation1 = rotation.y + 2*PI if rotation.y < 0 else rotation.y
	var rotation2 = targetTurn + 2*PI if targetTurn < 0 else targetTurn
	if abs(rotation1 - rotation2) < 0.05:
		turning = false

#Gain ammo
func increment_ammo():
	pistol.reserve_ammo += 20

#Gain health
func increment_health(amount):
	current_health = current_health + amount if MAX_HEALTH - amount >= current_health else MAX_HEALTH

#Take damage
func hit(damage):
	current_health -= damage
	
	if current_health <= 0:
		current_health = 0
		#Activate only on first instance of death
		if (!deathSFX.playing && playerDead == false):
			deathSFX.play()
			playerDead = true
			var bloodInstance = bloodEffect.instantiate()
			bloodInstance.position = $BloodPos.global_position
			get_tree().current_scene.add_child(bloodInstance)
			bloodInstance.explode("Explosion")
			$"PM 10-31-24".visible = false
			get_node("CollisionShape3D").disabled = true
			await get_tree().create_timer(4).timeout
			get_tree().change_scene_to_file("res://level/death_screen.tscn")
	else:
		if !hurtSFX.playing:
			hurtSFX.play()
	#
	#emit_signal("player_hit")

#Grenade Throwing
func throwGrenade(type):
	var grenadeInstance = grenadeScene.instantiate()
	grenadeInstance.position = grenade.global_position
	get_tree().current_scene.add_child(grenadeInstance)
		
	InventoryManager.remove_item("Weapons", "Grenade", 1)
		
	if (InventoryManager.get_item_quantity("Weapons", "Grenade") == 0):
		unequip("Grenade")
		
	
	#Drop Grenade
	if type == "underhand":
		var force = -3.5
		var upDirection = 0.0
			
		var playerRotation = global_transform.basis.z.normalized()
			
		grenadeInstance.apply_central_impulse(playerRotation * force + Vector3(0, upDirection, 0))
		
	
	#Throw Grenade
	elif type == "overhand":
		var force = -10
		var upDirection = 3.5
			
		var playerRotation = global_transform.basis.z.normalized()
			
		grenadeInstance.apply_central_impulse(playerRotation * force + Vector3(0, upDirection, 0))

#Melee Attack
func meleeAttack():
	$"Knife Sound".play()
	var nearest = get_nearest_enemy()
	if nearest != null:
		if global_position.distance_to(nearest.global_position) < MELEE_RANGE:
			nearest.hit(8)
		
	canMelee = false
	$MeleeTimer.start()

func equip(Equip):
	equipped = Equip
	if (equipped == "Pistol"):
		pistol.visible = true
		pistol.pistolEquipped = true
	
	if (equipped == "Grenade"):
		grenade.visible = true
	
	if (equipped == "Knife"):
		knife.visible = true

func unequip(unEquip):
	equipped = "None"
	
	pistol.visible = false
	pistol.pistolEquipped = false
	grenade.visible = false
	knife.visible = false
	


func _on_throw_timer_timeout() -> void:
	canThrow = true

func _on_melee_timer_timeout() -> void:
	canMelee = true

#Menu Handlers
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Inventory"):
		if !(get_tree().paused and !inventory_ui.visible):
			inventory_ui.visible = !inventory_ui.visible
			get_tree().paused = !get_tree().paused
	elif event.is_action_pressed("Escape"):
		if !(get_tree().paused and !settings_ui.visible):
			settings_ui.visible = !settings_ui.visible
			get_tree().paused = !get_tree().paused

func add_starting_inventory():
	$StartingGrenades.pickup_item()
	$StartingKnife.pickup_item()
