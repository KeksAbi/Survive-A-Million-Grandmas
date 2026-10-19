--!nonstrict
-- The reusable comic prop library: one index over every prop builder (YardProps, StreetProps, GrandmaProps,
-- the Streets manholes and the Vehicles mobility scooter), sorted into categories, all callable the same way:
--   PropLibrary.Build(name, parent, groundCFrame, rng?) -> Model   (LookVector of the CFrame = prop front)
-- Houses uses it for the yard props in its garden lists, MapBuilder for the street and arena props.
-- PropLibrary.Showcase(parent) lays out one of everything in labelled rows (residential, street, grandma).
-- To look at the whole library in Studio (Edit mode, after Rojo synced), run in the command bar:
--   require(game.ServerScriptService.Server.World.PropLibrary).Showcase(workspace)

local ComicKit = require(script.Parent.ComicKit)
local GrandmaProps = require(script.Parent.GrandmaProps)
local StreetProps = require(script.Parent.StreetProps)
local Streets = require(script.Parent.Streets)
local Vehicles = require(script.Parent.Vehicles)
local YardProps = require(script.Parent.YardProps)

local K = ComicKit
local C = ComicKit.Colors

local PropLibrary = {}

type Builder = (parent: Instance, cframe: CFrame, rng: Random) -> Instance

local DOG_NAMES = { "FIDO", "REX", "BISCUIT", "MUFFIN", "PICKLE" }
local SIGNS = { "PRUNE ST", "SLIPPER AVE", "BINGO BLVD", "KNITTING WAY" }

local function pick(list: { any }, rng: Random): any
	return list[rng:NextInteger(1, #list)]
end

-- Builders that add parts straight into a parent get their own Model.
local function wrapped(name: string, build: (model: Model, cframe: CFrame, rng: Random) -> ()): Builder
	return function(parent, cframe, rng)
		local model = K.Model(name)
		build(model, cframe, rng)
		model.Parent = parent
		return model
	end
end

local BUILDERS: { [string]: Builder } = {
	-- residential
	Mailbox = function(p, cf, rng)
		return YardProps.Mailbox(p, cf, pick(YardProps.Paints, rng), tostring(rng:NextInteger(2, 98)))
	end,
	HoseReel = function(p, cf)
		return YardProps.HoseReel(p, cf)
	end,
	LawnMower = function(p, cf)
		return YardProps.LawnMower(p, cf)
	end,
	Wheelbarrow = function(p, cf)
		return YardProps.Wheelbarrow(p, cf)
	end,
	Shovel = function(p, cf)
		return YardProps.Tool(p, cf, "Shovel")
	end,
	Rake = function(p, cf)
		return YardProps.Tool(p, cf, "Rake")
	end,
	Pitchfork = function(p, cf)
		return YardProps.Tool(p, cf, "Pitchfork")
	end,
	GardenTools = function(p, cf)
		return YardProps.GardenTools(p, cf)
	end,
	FlowerPot = function(p, cf, rng)
		return YardProps.FlowerPot(p, cf, rng)
	end,
	CeramicPot = function(p, cf, rng)
		return YardProps.FlowerPot(p, cf, rng, Color3.fromRGB(70, 120, 210), 1.3)
	end,
	WateringCan = function(p, cf)
		return YardProps.WateringCan(p, cf)
	end,
	Gnome = function(p, cf)
		return YardProps.Gnome(p, cf)
	end,
	Flamingo = function(p, cf)
		return YardProps.Flamingo(p, cf)
	end,
	OutdoorChair = function(p, cf, rng)
		return YardProps.OutdoorChair(p, cf, pick(YardProps.Paints, rng))
	end,
	PatioTable = function(p, cf)
		return YardProps.PatioTable(p, cf)
	end,
	UmbrellaTable = function(p, cf)
		return YardProps.PatioTable(p, cf, true)
	end,
	KettleGrill = function(p, cf)
		return YardProps.KettleGrill(p, cf)
	end,
	TrashBin = function(p, cf)
		return YardProps.WheelieBin(p, cf, "Trash")
	end,
	RecyclingBin = function(p, cf)
		return YardProps.WheelieBin(p, cf, "Recycling")
	end,
	WelcomeSign = function(p, cf)
		return YardProps.WelcomeSign(p, cf)
	end,
	HangingBasket = function(p, cf, rng)
		return YardProps.HangingBasket(p, cf, rng)
	end,
	Doghouse = function(p, cf, rng)
		return YardProps.Doghouse(p, cf, pick(DOG_NAMES, rng))
	end,
	Birdhouse = function(p, cf, rng)
		return YardProps.Birdhouse(p, cf, pick(YardProps.Paints, rng))
	end,
	Crate = function(p, cf)
		return YardProps.Crate(p, cf, "APPLES", 1.8)
	end,

	-- street
	NewspaperBox = function(p, cf)
		return StreetProps.NewspaperBox(p, cf)
	end,
	Hydrant = function(p, cf)
		return StreetProps.Hydrant(p, cf)
	end,
	StopSign = function(p, cf, rng)
		return StreetProps.StopSign(p, cf, { pick(SIGNS, rng), pick(SIGNS, rng) })
	end,
	TrafficCone = function(p, cf)
		return StreetProps.TrafficCone(p, cf)
	end,
	AFrameBarrier = function(p, cf)
		return StreetProps.ConstructionBarrier(p, cf, "AFrame")
	end,
	JerseyBarrier = function(p, cf)
		return StreetProps.ConstructionBarrier(p, cf, "Jersey")
	end,
	GarbageBags = function(p, cf, rng)
		return StreetProps.GarbageBags(p, cf, rng, 2)
	end,
	Bench = function(p, cf)
		return StreetProps.Bench(p, cf)
	end,
	TrashCan = function(p, cf)
		return StreetProps.TrashCan(p, cf.Position)
	end,
	UtilityBox = function(p, cf)
		return StreetProps.UtilityBox(p, cf)
	end,
	Manhole = wrapped("Manhole", function(model, cf)
		Streets.Manhole(model, cf.Position)
	end),
	OpenManhole = wrapped("OpenManhole", function(model, cf)
		Streets.OpenManhole(model, cf.Position, cf.LookVector)
	end),
	Lamp = function(p, cf)
		return StreetProps.Lamp(p, cf.Position)
	end,
	StreetLight = function(p, cf)
		return StreetProps.StreetLight(p, cf)
	end,
	BikeRack = function(p, cf)
		return StreetProps.BikeRack(p, cf)
	end,
	Bicycle = function(p, cf)
		return StreetProps.Bicycle(p, cf)
	end,
	Planter = wrapped("Planter", function(model, cf)
		StreetProps.Planter(model, cf, 3.2)
	end),

	-- grandma-themed
	YarnBall = function(p, cf, rng)
		return GrandmaProps.YarnBall(p, cf, 1.2, pick(GrandmaProps.YarnColors, rng))
	end,
	GiantYarnBall = function(p, cf, rng)
		return GrandmaProps.YarnBall(p, cf, 6, pick(GrandmaProps.YarnColors, rng), true)
	end,
	KnittingNeedles = function(p, cf)
		return GrandmaProps.KnittingNeedles(p, cf)
	end,
	KnittingBasket = function(p, cf)
		return GrandmaProps.KnittingBasket(p, cf)
	end,
	Slippers = function(p, cf)
		return GrandmaProps.Slippers(p, cf)
	end,
	RockingChair = function(p, cf)
		return GrandmaProps.RockingChair(p, cf)
	end,
	MobilityScooter = function(p, cf)
		local body = Vehicles.Build({ Body = p, Details = p }, "Scooter", cf)
		return body
	end,
	CookieStall = function(p, cf)
		return GrandmaProps.CookieStall(p, cf)
	end,
	BingoSign = function(p, cf)
		return GrandmaProps.BingoSign(p, cf)
	end,
	RetirementBillboard = function(p, cf)
		return GrandmaProps.RetirementBillboard(p, cf)
	end,
	GrandmaStatue = function(p, cf)
		return GrandmaProps.GrandmaStatue(p, cf)
	end,
	ShoppingCart = function(p, cf, rng)
		return GrandmaProps.ShoppingCart(p, cf, rng)
	end,
}

PropLibrary.Categories = {
	Residential = { "Mailbox", "HoseReel", "LawnMower", "Wheelbarrow", "Shovel", "Rake", "Pitchfork", "GardenTools", "FlowerPot", "CeramicPot", "WateringCan", "Gnome", "Flamingo", "OutdoorChair", "PatioTable", "UmbrellaTable", "KettleGrill", "TrashBin", "RecyclingBin", "WelcomeSign", "HangingBasket", "Doghouse", "Birdhouse", "Crate" },
	Street = { "NewspaperBox", "Hydrant", "StopSign", "TrafficCone", "AFrameBarrier", "JerseyBarrier", "GarbageBags", "Bench", "TrashCan", "UtilityBox", "Manhole", "OpenManhole", "Lamp", "StreetLight", "BikeRack", "Bicycle", "Planter" },
	Grandma = { "YarnBall", "GiantYarnBall", "KnittingNeedles", "KnittingBasket", "Slippers", "RockingChair", "MobilityScooter", "CookieStall", "BingoSign", "RetirementBillboard", "GrandmaStatue", "ShoppingCart" },
}
PropLibrary.CategoryOrder = { "Residential", "Street", "Grandma" }

-- Small clutter (yard props under knee height): Houses leaves these out when Config.Comic.SmallDetails is off.
PropLibrary.Small = { HoseReel = true, WateringCan = true, FlowerPot = true, Slippers = true, GardenTools = true, KnittingBasket = true, GarbageBags = true }

function PropLibrary.Has(name: string): boolean
	return BUILDERS[name] ~= nil
end

-- Builds prop `name` standing on `cframe` (LookVector = its front) into `parent`.
function PropLibrary.Build(name: string, parent: Instance, cframe: CFrame, rng: Random?): Instance
	local build = BUILDERS[name]
	assert(build, "PropLibrary: unknown prop " .. name)
	return build(parent, cframe, rng or Random.new(1))
end

-- Showcase layout: footprint width per prop (default 5) and lifts for props that hang from a hook.
local WIDTHS = { CookieStall = 12, RetirementBillboard = 24, GiantYarnBall = 9, KnittingNeedles = 9, JerseyBarrier = 7, AFrameBarrier = 6, Doghouse = 6, PatioTable = 6, UmbrellaTable = 7, GardenTools = 7, HoseReel = 6, BikeRack = 6, BingoSign = 9, ShoppingCart = 4, MobilityScooter = 6, GarbageBags = 4, StreetLight = 6 }
local LIFTS = { HangingBasket = 4.5 }

-- One of every prop in three labelled rows, each prop facing -Z of `origin` (default: the world origin).
function PropLibrary.Showcase(parent: Instance, origin: CFrame?): Model
	local root = K.Model("PropShowcase")
	local base = origin or CFrame.identity
	local rng = Random.new(7)
	for row, category in PropLibrary.CategoryOrder do
		local x = 0
		for _, name in PropLibrary.Categories[category] do
			local width = WIDTHS[name] or 5
			x += width / 2
			local spot = base * CFrame.new(x, 0, (row - 1) * 30)
			PropLibrary.Build(name, root, spot * CFrame.new(0, LIFTS[name] or 0, 0), rng)
			local plate = K.Block(root, Vector3.new(width - 0.6, 0.1, 1.2), spot * CFrame.new(0, 0.05, -4.5), C.Trim, true)
			K.Text(plate, name, C.Ink, false, Enum.NormalId.Top)
			x += width / 2 + 2
		end
	end
	root.Parent = parent
	return root
end

return PropLibrary
