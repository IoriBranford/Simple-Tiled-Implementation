return function(layer, dt, map)
	layer.opacity = math.sin(love.timer.getTime()*math.pi*2)
end
