class_name ConsumablesData
extends RefCounted
## Onguents et potions : objets du sac de genre « tool » (voir Loot) à usage unique. Le grade de qualité ne s'applique pas.
## `target` : "self" (celui qui l'utilise) ou "ally" (lui-même ou un allié au contact) ; `cure` : états retirés ; `heal` : PV rendus ;
## `fat` : fatigue retirée ; `morale` : crans de moral gagnés ; `ap` / `fat_cost` : coût de l'action.

const ITEMS: Dictionary = {
	"bandage": {"n": "Bandage", "price": 30, "ap": 3, "fat_cost": 2, "target": "ally", "cure": ["bleed"], "heal": 6,
		"note": "Arrête un saignement et rend 6 PV. Usage unique, à soi-même ou à un allié au contact (3 PA)."},
	"antidote": {"n": "Antidote", "price": 45, "ap": 3, "fat_cost": 2, "target": "ally", "cure": ["poison"], "heal": 0,
		"note": "Guérit le poison. Usage unique, à soi-même ou à un allié au contact (3 PA)."},
	"onguent": {"n": "Onguent de brûlure", "price": 40, "ap": 3, "fat_cost": 2, "target": "ally", "cure": ["burn"], "heal": 8,
		"note": "Éteint la brûlure et rend 8 PV. Usage unique, à soi-même ou à un allié au contact (3 PA)."},
	"tonique": {"n": "Tonique de vigueur", "price": 55, "ap": 3, "fat_cost": 0, "target": "self", "cure": ["frost"], "fat": 40,
		"note": "Retire 40 de fatigue et dégourdit les membres. Usage unique, pour soi (3 PA)."},
	"fiole_courage": {"n": "Fiole de courage", "price": 60, "ap": 4, "fat_cost": 0, "target": "ally", "cure": [], "morale": 1,
		"note": "Gagne un cran de moral (un fuyard se ressaisit). Usage unique, à soi-même ou à un allié au contact (4 PA)."},
}

## Stock des boutiques selon le type de lieu : [clé, présence en %, quantité min, quantité max].
const SHOP: Dictionary = {
	"village": [["bandage", 85, 2, 5], ["onguent", 40, 1, 3]],
	"city": [["bandage", 95, 3, 6], ["antidote", 80, 2, 4], ["onguent", 80, 2, 4], ["tonique", 70, 1, 3], ["fiole_courage", 60, 1, 3], ["venin", 55, 1, 3]],
}

## Butin : chance par ennemi tué (côté "e") qu'il porte un consommable, et lequel [clé, poids].
const DROP_CHANCE: float = 0.07
const DROP_CHANCE_LEADER: float = 0.35
const DROP_TABLE: Array = [["bandage", 5], ["antidote", 2], ["onguent", 2], ["tonique", 2], ["fiole_courage", 1]]
