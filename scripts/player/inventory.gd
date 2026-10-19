extends Node
## Player inventory: weapons with their ammo, and bandages.

var bandages := 2
var ammo := {}              # weapon id -> {"mag": int, "reserve": int}
var _pending_ammo := {}     # ammo found before having that weapon


func has_weapon(id: String) -> bool:
	return ammo.has(id)


## Returns true if the weapon is new.
func add_weapon(id: String, data: Dictionary) -> bool:
	if has_weapon(id):
		ammo[id]["reserve"] += data["mag_size"]
		return false
	ammo[id] = {"mag": data["start_mag"], "reserve": data["start_reserve"] + _pending_ammo.get(id, 0)}
	_pending_ammo.erase(id)
	return true


func add_ammo(id: String, amount: int, weapon_name: String) -> void:
	if not has_weapon(id):
		_pending_ammo[id] = _pending_ammo.get(id, 0) + amount
		GameManager.notify("%s ammo found (no weapon yet)" % weapon_name)
		return
	ammo[id]["reserve"] += amount
	GameManager.notify("+%d %s ammo" % [amount, weapon_name])


func add_bandages(amount: int) -> void:
	bandages += amount


func take_bandage() -> bool:
	if bandages <= 0:
		return false
	bandages -= 1
	return true
