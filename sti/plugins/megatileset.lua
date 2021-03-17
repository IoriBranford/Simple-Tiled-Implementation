--- Megatileset plugin for STI
-- @module megatileset
-- @author Iori Branford
-- @copyright 2020
-- @license MIT/X11

local LG = love.graphics

local function newSpace(x, y, w, h)
	return {
		x = x, y = y, w = w, h = h
	}
end

local function findSubspace(space, w, h)
	for i = 1, #space do
		local subspace = findSubspace(space[i], w, h)
		if subspace then
			return subspace
		end
	end
	return w <= space.w and h <= space.h and not space.tile and space
end

local function splitSpace(space, w, h)
	local rightw = space.w - w
	local downh = space.h - h
	if rightw > 0 then
		space[#space+1] = newSpace(space.x + w, space.y, rightw, h)
	end
	if downh > 0 then
		space[#space+1] = newSpace(space.x, space.y + h, space.w, downh)
	end
end

local function growSpace(space, neww, newh)
	local newspace = space
	if space.w < neww then
		newspace = newSpace(0, 0, neww, newh)
		newspace[#newspace+1] = newSpace(space.w, 0, neww - space.w, space.h)
	else
		neww = space.w
	end
	if space.h < newh then
		if newspace==space then
			newspace = newSpace(0, 0, neww, newh)
		end
		newspace[#newspace+1] = newSpace(0, space.h, neww, newh - space.h)
	end
	if newspace ~= space then
		newspace[#newspace+1] = space
	end
	return newspace
end

return {
	megatileset_LICENSE     = "MIT/X11",
	megatileset_URL         = "https://github.com/IoriBranford/Simple-Tiled-Implementation",
	megatileset_VERSION     = "1.0",
	megatileset_DESCRIPTION = "Pack all tiles into a single texture. Enables batch drawing of tiles from different tilesets.",

	--- Make the megatileset.
	-- Do not use with gamma-correct rendering - tiles will be darkened.
	megatileset_init = function(map)
		if not LG then
			return false, "Megatileset requires love.graphics"
		end

		local tilesets = map.tilesets

		local megaimagearea = 0
		local maxtilewidth = 0
		local maxtileheight = 0
		for i = 1, #tilesets do
			local tileset = tilesets[i]
			local tilewidth = tileset.tilewidth + 2
			local tileheight = tileset.tileheight + 2
			if maxtilewidth < tilewidth then
				maxtilewidth = tilewidth
			end
			if maxtileheight < tileheight then
				maxtileheight = tileheight
			end
			local tilearea = tilewidth*tileheight
			megaimagearea = megaimagearea + tilearea*tileset.tilecount
		end

		local megaimagewidth = 1
		local megaimageheight = 1

		while megaimagearea > megaimagewidth*megaimageheight do
			if megaimageheight < megaimagewidth then
				megaimageheight = megaimageheight*2
			else
				megaimagewidth = megaimagewidth*2
			end
		end

		local tiles = {}
		for gid, tile in pairs(map.tiles) do
			tiles[#tiles+1] = tile
		end
		table.sort(tiles, function(a, b)
			return a.width*a.height > b.width*b.height
		end)

		local space = newSpace(0, 0, megaimagewidth, megaimageheight)

		local flippedtiles = {}

		local bit31   = 2147483648
		local bit30   = 1073741824
		local bit29   = 536870912

		for i = 1, #tiles do
			local tile = tiles[i]
			if tile.gid >= bit29 then
				flippedtiles[#flippedtiles + 1] = tile
			else
				local width = tile.width + 2
				local height = tile.height + 2
				local subspace = findSubspace(space, width, height)
				while not subspace do
					if megaimageheight < megaimagewidth then
						megaimageheight = megaimageheight*2
					else
						megaimagewidth = megaimagewidth*2
					end
					space = growSpace(space, megaimagewidth, megaimageheight)
					subspace = findSubspace(space, width, height)
				end
				subspace.tile = tile
				splitSpace(subspace, width, height)
			end
		end

		local limits = LG.getSystemLimits()
		if megaimagewidth > limits.texturesize
		or megaimageheight > limits.texturesize then
			return false, string.format("Megatileset exceeds texture size limit of %dpx", limits.texturesize)
		end

		local drawSpace_quad = LG.newQuad(0, 0, 1, 1, 1, 1)
		local function drawSpace(space)
			local quad = drawSpace_quad
			local tile = space.tile
			if tile then
				local tw, th = tile.width, tile.height
				local dx0, dy0 = space.x, space.y
				local dx1, dy1 = dx0+1, dy0+1
				local dx2, dy2 = dx1+tw, dy1+th
				local tileset = tilesets[tile.tileset]
				local qx, qy, qw, qh = tile.quad:getViewport()
				local qx2 = qx + qw - 1
				local qy2 = qy + qh - 1
				local drawrects = {
					dx0, dy0, qx, qy, 1, 1,
					dx1, dy0, qx, qy, qw, 1,
					dx2, dy0, qx2, qy, 1, 1,
					dx0, dy1, qx, qy, 1, qh,
					dx1, dy1, qx, qy, qw, qh,
					dx2, dy1, qx2, qy, 1, qh,
					dx0, dy2, qx, qy2, 1, 1,
					dx1, dy2, qx, qy2, qw, 1,
					dx2, dy2, qx2, qy2, 1, 1
				}
				local iw, ih = tileset.image:getWidth(), tileset.image:getHeight()
				for i = 6, #drawrects, 6 do
					local destx = drawrects[i-5]
					local desty = drawrects[i-4]
					local ex = drawrects[i-3]
					local ey = drawrects[i-2]
					local ew = drawrects[i-1]
					local eh = drawrects[i-0]
					quad:setViewport(ex, ey, ew, eh, iw, ih)
					LG.draw(tileset.image, quad, destx, desty)
				end
				tile.quad = LG.newQuad(dx1, dy1, tw, th,
					megaimagewidth, megaimageheight)
			end
			--DEBUG
			--LG.rectangle("line", space.x, space.y, space.w, space.h)
			for i = 1, #space do
				drawSpace(space[i])
			end
		end

		local canvas = LG.newCanvas(megaimagewidth, megaimageheight, {
				format = "rgba8"
			})
		LG.setCanvas(canvas)
		LG.setLineStyle("rough")
		drawSpace(space)
		LG.setCanvas()

		for i = 1, #flippedtiles do
			local tile = flippedtiles[i]
			local realgid = tile.gid

			if realgid >= bit31 then
				realgid = realgid - bit31
			end
			if realgid >= bit30 then
				realgid = realgid - bit30
			end
			if realgid >= bit29 then
				realgid = realgid - bit29
			end
			tile.quad = map.tiles[realgid].quad
		end

		--DEBUG
		--local megaimagedata = canvas:newImageData()
		--megaimagedata:encode("png", "megaimage.png")
		local megaimage = canvas -- once it's an image, you can't get the data again
		megaimage:setFilter("nearest", "nearest")
		for i = 1, #tilesets do
			local tileset = tilesets[i]
			tileset.image:release()
			tileset.image = megaimage
		end

		map:refreshSpriteBatches()

		return megaimage
	end,

	megatileset_save = function(map, mapfile)
		local tiles = map.tiles
		local megaimage = map.tilesets[1].image
		local megaimagedata = megaimage:newImageData()
		local megaimagepath = "megatileset_"..mapfile..".png"
		megaimagedata:encode("png", megaimagepath)

		local megatileset = {}
		megatileset.image = megaimagepath
		for gid, tile in pairs(tiles) do
			local x, y, w, h = tile.quad:getViewport()
			megatileset[gid] = { x, y, w, h }
		end
		local iw, ih = megaimage:getDimensions()

		local pl_pretty = require "pl.pretty"
		local megatilesetpath = "megatileset_"..mapfile
		love.filesystem.write(megatilesetpath, "return "..pl_pretty.write(megatileset, ""))
	end,

	megatileset_load = function(map, mapfile)
		local megatilesetpath = "megatileset_"..mapfile
		local f, err = love.filesystem.load(megatilesetpath)
		if not f then
			return false, err
		end
		local megatileset = f()

		local megaimage = love.graphics.newImage(megatileset.image)
		megaimage:setFilter("nearest", "nearest")
		local iw, ih = megaimage:getDimensions()
		megatileset.image = nil

		local tiles = map.tiles
		local tilesets = map.tilesets
		for i, tileset in pairs(tilesets) do
			tileset.image:release()
			tileset.image = megaimage
		end
		for gid, quad in pairs(megatileset) do
			local tile = tiles[gid]
			tile.quad = love.graphics.newQuad(quad[1], quad[2], quad[3], quad[4], iw, ih)
		end
		map:refreshSpriteBatches()
		return true
	end
}
