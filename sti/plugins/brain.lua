--- Brain plugin for STI
--
-- Attach custom logic to map, layers, and objects.
--
-- A logic module consists of:
-- a "start" function called on map start or layer/object creation, and
-- a "think" function called before every Map:update.
--
-- @usage
--
-- map.tmx, map.lua:
--
-- map.properties.brain = "scripts.map"
-- layer.properties.brain = "scripts.layer"
-- object.properties.brain = "scripts.object"
--
-- scripts/map.lua:
--
-- return {
--     start = function(map)
--         -- start logic
--     end
--     think = function(map, dt)
--         -- update logic
--     end
-- }
--
-- scripts/layer.lua:
--
-- return {
--     start = function(layer, map)
--         -- start logic
--     end
--     think = function(layer, dt, map)
--         -- update logic
--     end
-- }
--
-- scripts/object.lua:
--
-- return {
--     start = function(object, map, objectlayer)
--         -- start logic
--     end
--     think = function(object, dt, map, objectlayer)
--         -- update logic
--     end
-- }
--
-- main.lua:
--
-- function love.load()
--     ...
--     map = sti("map.lua", { "brain" })
--     map:brain_init()
--     ...
-- end
--
-- @module brain
-- @author IoriBranford
-- @copyright 2019
-- @license MIT/X11

local require = require
local setmetatable = setmetatable

local map_default_brain = {
	start = function(map)
	end,
	think = function(map, dt)
		local layers = map.layers
		for l = 1, #map.layers do
			layers[l]:think(dt, map)
		end
	end
}

local layer_default_brain = {
	start = function(layer, map)
	end,
	think = function(layer, dt, map)
		local objects = layer.objects
		if objects then
			for o = 1, #layer.objects do
				objects[o]:think(dt, map, layer)
			end
		end
	end
}

local object_default_brain = {
	start = function(object, map, objectlayer)
	end,
	think = function(object, dt, map, objectlayer)
	end
}

local function brain_load(module, default)
	return module and require(module) or default
end

return {
	brain_LICENSE        = "MIT/X11",
	brain_URL            = "https://github.com/IoriBranford/Simple-Tiled-Implementation",
	brain_VERSION        = "0.1",
	brain_DESCRIPTION    = "Attach custom logic to map, layers, objects.",

	--- Load all logic modules for map, layers, and objects
	brain_init = function (map)
		local layers = map.layers
		for l = 1, #map.layers do
			local layer = layers[l]
			setmetatable(layer, {
				__index = brain_load(layer.properties.brain, layer_default_brain)
			})
			local objects = layer.objects
			if objects then
				for o = 1, #objects do
					local object = objects[o]
					setmetatable(object, {
						__index = brain_load(object.properties.brain, object_default_brain)
					})
				end
			end
		end

		local map_brain = brain_load(map.properties.brain) or map_default_brain
		for k,v in pairs(map_brain) do
			map[k] = v
		end

		local map_update = map.update
		map.update = function(m, dt)
			m:think(dt)
			map_update(m, dt)
		end

		map:start()
		for l = 1, #map.layers do
			local layer = layers[l]
			layer:start(map)
			local objects = layer.objects
			if objects then
				for o = 1, #objects do
					local object = objects[o]
					object:start(map, layer)
				end
			end
		end
	end
}

--- Custom Properties in Tiled are used to tell this plugin what to do.
-- @table Properties
-- @field think Lua require string of module that returns a think function
