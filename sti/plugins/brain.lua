--- Brain plugin for STI
--
-- Attach custom logic to map, layers, and objects in the form of a "think" function which is called before
-- Map:update.
--
-- @usage
--
-- map.tmx, map.lua:
--  map.properties.think = "scripts.map.think"
--  layer.properties.think = "scripts.layer.think"
--  object.properties.think = "scripts.object.think"
--
-- scripts/map/think.lua:
--  return function(map, dt)
--      -- map logic
--  end
--
-- scripts/layer/think.lua:
--  return function(layer, dt, map)
--      -- layer logic
--  end
--
-- scripts/object/think.lua:
--  return function(object, dt, map, objectlayer)
--      -- object logic
--  end
--
-- main.lua:
--  function love.load()
--      ...
--      map = sti("map.lua", { "brain" })
--      map:brain_init()
--      ...
--  end
--
-- @module brain
-- @author IoriBranford
-- @copyright 2019
-- @license MIT/X11

return {
	brain_LICENSE        = "MIT/X11",
	brain_URL            = "https://github.com/IoriBranford/Simple-Tiled-Implementation",
	brain_VERSION        = "0.1",
	brain_DESCRIPTION    = "Attach custom logic to map, layers, objects.",

	--- Load all think functions for map, layers, and objects
	brain_init = function (map)
		local require = require

		local function brain_load(module)
			return module and require(module)
		end

		local function map_default_think(map, dt)
			local layers = map.layers
			for l = 1, #map.layers do
				layers[l]:think(dt, map)
			end
		end

		local function layer_default_think(layer, dt, map)
			local objects = layer.objects
			if objects then
				for o = 1, #layer.objects do
					objects[o]:think(dt, map, layer)
				end
			end
		end

		local function object_default_think(object, dt, map, objectlayer)
		end

		local funcs = {}
		map.brain_funcs = funcs

		map.think = brain_load(map.properties.think) or map_default_think
		local layers = map.layers
		for l = 1, #map.layers do
			local layer = layers[l]
			layer.think = brain_load(layer.properties.think) or layer_default_think
			local objects = layer.objects
			if objects then
				for o = 1, #objects do
					local object = objects[o]
					object.think = brain_load(object.properties.think) or object_default_think
				end
			end
		end

		local map_update = map.update
		map.update = function(m, dt)
			m:think(dt)
			map_update(m, dt)
		end
	end
}

--- Custom Properties in Tiled are used to tell this plugin what to do.
-- @table Properties
-- @field think Lua require string of module that returns a think function
