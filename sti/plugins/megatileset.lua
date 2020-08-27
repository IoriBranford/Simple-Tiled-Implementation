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
	if #space > 0 then
		return findSubspace(space[1], w, h) or findSubspace(space[2], w, h)
	end
	return w <= space.w and h <= space.h and space
end

local function splitSpace(space, w, h)
	local rightw = space.w - w
	local downh = space.h - h
	space[1] = newSpace(space.x + w, space.y, rightw, h)
	space[2] = newSpace(space.x, space.y + h, space.w, downh)
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

		local megaimagewidth = 1024
		local megaimageheight = 1024

		while megaimagearea > megaimagewidth*megaimageheight do
			megaimagewidth = megaimagewidth*2
			megaimageheight = megaimageheight*2
		end

		local limits = LG.getSystemLimits()
		if megaimagewidth > limits.texturesize
		or megaimageheight > limits.texturesize then
			return false, "Megatileset exceeds texture size limit"
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
				if not subspace then
					return false, "Megatileset could not fit all tiles"
				end
				subspace.tile = tile
				splitSpace(subspace, width, height)
			end
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
			--DEBUG LG.rectangle("line", space.x, space.y, space.w, space.h)
			if #space > 0 then
				drawSpace(space[1])
				drawSpace(space[2])
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

		local megaimagedata = canvas:newImageData()
		--DEBUG megaimagedata:encode("png", "megaimage.png")
		local megaimage = LG.newImage(megaimagedata)
		megaimage:setFilter("nearest", "nearest")
		for i = 1, #tilesets do
			local tileset = tilesets[i]
			tileset.image:release()
			tileset.image = megaimage
		end

		map:refreshSpriteBatches()

		return megaimage
	end
}
