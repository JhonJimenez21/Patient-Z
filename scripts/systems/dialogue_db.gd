extends RefCounted
## All dialogue lines of the game. Load it with:
## const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")

const BOSS_NAME := "Boss"

const BOSS_INTRO := [
	"Welcome, you must be the new assistant! Glad someone finally joined this floor—it gets boring around here.",
	"I need your help before we get started. Go search the first 4 rooms and bring me 5 syringes.",
]

const BOSS_ALARM := [
	"Patient Z has escaped! Take this Keycard and head straight to the Security Guard Room down the hall.",
	"That's where we keep the firearms. Get the rifle and stop the infection before it reaches the upper levels. Good luck!",
]

const BOSS_MISSING_SYRINGES := "You have %d of %d syringes. Check the cabinets in the first 4 rooms."
const BOSS_SURVIVE := "The Security Guard Room is down the hall. Get the rifle and stop Patient Z!"
const BOSS_CLEARED := "You actually did it... The stairs to Floor 2 are open. Go!"

# --- Floor 3: the wounded doctor in the Lab Office behind the Containment Core ---------
const DOCTOR_NAME := "Wounded Doctor"

const DOCTOR_DYING := [
	"Ugh... you actually did it... you killed it...",
	"Patient Z was never an accident. The government paid for all of this. Project LAZARUS: soldiers that don't die.",
	"Patient Z was the first one that worked... and the first one that got out. Everyone on these floors was a test subject. Even us.",
	"Listen... the rooftop exit is sealed, but I have the master key in my lab coat. Take it...",
	"The stairs behind me go up to the roof. There's a helicopter... they're running an evacuation...",
	"Tell them what they did here... promise me...",
]

# --- Rooftop: General Rex and his squad --------------------------------------------------
const REX_NAME := "General Rex"

const REX_AMBUSH := [
	"Hold it right there. Hands where I can see them.",
	"So you're the one who walked out of the lower levels. Alone. Through all of that.",
	"What happened in this building is TOP SECRET. Project Lazarus never existed, and neither did you.",
	"I can't leave any witnesses, son. Nothing personal.",
	"Squad... fire.",
]
