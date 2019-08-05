--- objecttypes.xml plugin for STI
-- Apply properties from objecttypes xml file to map objects. There are two ways to use this.
-- - Copy type properties into object properties with copy/reset
-- - Set metatable on object properties so it will transparently fall back to type properties. Property precedence:
--   1. object's property
--   2. object type's property
--   3. object tile's property
--   4. object tile type's property
-- @module objecttypes
-- @author IoriBranford
-- @copyright 2019
-- @license MIT/X11

local love  = _G.love
local utils = require((...):gsub('plugins.objecttype', 'utils'))
local slaxml= require((...):gsub('objecttype', 'slaxml'))

return {
	objecttype_LICENSE     = "MIT/X11",
	objecttype_URL         = "https://github.com/karai17/Simple-Tiled-Implementation",
	objecttype_VERSION     = "0.1",
	objecttype_DESCRIPTION = "Object type XML for STI.",

	--- Initialize objecttypes.
	-- @param filename Object types XML file name
	objecttype_init = function(map, filename)
		local status, err
		local file = love.filesystem.newFile(filename)
		status, err = file and file:open("r")
		if not status then
			print(err)
			return
		end

		local xml = file:read()
		file:close()

		local objecttypes
		local objecttype
		local property_name
		local property_type

		local converters = {
			string = function(value)
				return value
			end,
			file = function(value)
				return value
			end,
			color = function(value)
				return value
			end,
			int = function(value)
				return tonumber(value)
			end,
			float = function(value)
				return tonumber(value)
			end,
			bool = function(value)
				return value=="true"
			end
		}

		local handlers = {
			objecttypes = function()
				objecttypes = {}
			end,
			objecttype = function()
				objecttype = {}
			end,
			objecttypename = function(name)
				objecttypes[name] = objecttype
			end,
			objecttypecolor = function(rgbstring)
			end,
			property = function()
			end,
			propertyname = function(name)
				property_name = name
			end,
			propertytype = function(t)
				property_type = t
			end,
			propertydefault = function(value)
				objecttype[property_name] = converters[property_type](value)
			end,
		}

		local callbacks = {}
		local element
		function callbacks.startElement(name)
			element = name
			handlers[name]()
		end
		function callbacks.attribute(name, value)
			handlers[element..name](value)
		end

		slaxml:parser(callbacks):parse(xml)

		map.objecttypes = objecttypes
	end,

	--- Copy objecttype properties to object without touching other object properties
	--@param object
	--@param type Defaults to type set in object
	objecttype_copy = function(map, object, type)
		type = type or object.type
		local properties = object and object.properties
		local objecttype = properties and map.objecttypes[type]
		if objecttype then
			for k,v in pairs(objecttype) do
				properties[k] = v
			end
		end
	end,

	--- Clear object properties then copy from objecttype
	--@param object
	--@param type Defaults to type set in object
	objecttype_reset = function(map, object, type)
		local properties = object and object.properties
		if properties then
			for k, v in pairs(properties) do
				properties[k] = nil
			end
			map:objecttype_copy(object, type)
		end
	end,

	--- Set object's properties to fall back to default properties
	-- Property precedence:
	-- 1. object's property
	-- 2. object type's property
	-- 3. object tile's property
	-- 4. object tile type's property
	--@param object
	objecttype_setMetatable = function(map, object)
		if not object.properties then
			return
		end
		local mt = {}
		local objecttypes = map.objecttypes
		function mt.__index(_, key)
			local defaults = objecttypes[object.type]
			if defaults then
				local value = defaults and defaults[key]
				if value ~= nil then return value end
			else
				local tile = object.tile
				return tile and tile.properties[key]
			end
		end
		setmetatable(object.properties, mt)
	end
}
