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
			local tilewidth = tileset.tilewidth
			local tileheight = tileset.tileheight
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

		while maxtilewidth > megaimagewidth do
			megaimagewidth = megaimagewidth * 2
		end

		while maxtileheight > megaimageheight do
			megaimageheight = megaimageheight * 2
		end

		while megaimagearea > megaimagewidth*megaimageheight do
			megaimagewidth = megaimagewidth*2
			if megaimagearea > megaimagewidth*megaimageheight then
				megaimageheight = megaimageheight*2
			end
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

		for i = 1, #tiles do
			local tile = tiles[i]
			local width = tile.width
			local height = tile.height
			local subspace = findSubspace(space, width, height)
			if not subspace then
				return false, "Megatileset could not fit all tiles"
			end
			subspace.tile = tile
			splitSpace(subspace, width, height)
		end

		local function drawSpace(space)
			local tile = space.tile
			if tile then
				local destx, desty = space.x, space.y
				-- Don't draw flipped tiles to the megatileset,
				-- but do set their quads
				if tile.gid < 0x20000000 then
					local tileset = tilesets[tile.tileset]
					LG.draw(tileset.image, tile.quad, destx, desty)
				end
				tile.quad = LG.newQuad(destx, desty,
					tile.width, tile.height,
					megaimagewidth, megaimageheight)
			end
			--LG.rectangle("line", space.x, space.y, space.w, space.h)
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

		local megaimagedata = canvas:newImageData()
		--megaimagedata:encode("png", "megaimage.png")
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
