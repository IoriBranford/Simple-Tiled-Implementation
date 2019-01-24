return {
	start = function(layer, map)
		layer.properties.blinktime = 0
	end,
	think = function(layer, dt, map)
		local t = layer.properties.blinktime + dt
		layer.opacity = math.sin(t*math.pi*2)
		layer.properties.blinktime = t
	end
}
