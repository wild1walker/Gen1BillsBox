-- Gen1BillsBox -- which icons are full-colour art, and why it matters
--
-- Shared by the two screens this mod colours: the box, which gives every
-- POKeMON in it its own species palette, and the party menu, which now does
-- the same down its icon column.  Both ask the same question of the same
-- files, so they ask it in one place -- and cache the answer in one place
-- too, which is the whole of the cost: a file is read once per session
-- however many screens draw it.
--
-- The SGB pass those screens ask for remaps four DMG shades to four colours,
-- keyed off each pixel's RED channel.  Run authored full-colour art through
-- that and it does not come out recoloured, it comes out DESTROYED: an
-- orange pixel has red near 1.0, lands on shade 0, and is painted the
-- palette's white.  That is the whole of the reported bug -- BEEDRILL's
-- orange going white, IVYSAUR's teal going green.
--
-- The engine's answer is PaletteFX.markTrueColor: a marked rect is appended
-- to the zone list as a colours == false zone and re-blit with no shader
-- over the colourised pass (Renderer's withTrueColor).  But nothing in
-- PartyMenu.drawIcon marks anything -- the screens that draw full-colour art
-- mark it themselves (SummaryMenu, TrainerCard, HallOfFame all do), so a
-- screen that lays a palette zone over an icon has to mark that icon too.
--
-- So decide per icon, and decide it the only way that cannot be fooled by
-- HOW the art arrived (the icons registry, a species record's own `icon`, an
-- asset override, the pokemon.icon hook): resolve what drawIcon will resolve,
-- then look at the pixels.
--
-- A built-in icon CLASS is never full colour whatever file it points at,
-- because drawIcon bakes those through obpIcon, which flattens every pixel
-- to a grey keyed off its red channel.  Only a mod's own image -- an entry
-- table rather than an icon name -- reaches the screen untouched.

return function(mod)
  local Sprites = require("src.pokemon.Sprites")

  -- the frame drawIcon takes out of a sheet, and what the party menu and the
  -- box both leave room for
  local ICON = 16

  local Icons = { SIZE = ICON }

  local iconColour = setmetatable({}, { __mode = "k" })  -- mon -> info
  local pathColour = {}                                  -- path -> info

  local function defOf(game, mon)
    local pokemon = game.data and game.data.pokemon
    return mon and pokemon and pokemon[mon.species] or nil
  end

  -- The same resolution order as PartyMenu.drawIcon, from the same public
  -- tables, so this cannot disagree with what is actually drawn.
  local function resolveIcon(game, mon)
    local icons = game.data and game.data.icons
    if not icons then return nil, nil end
    local def = defOf(game, mon)
    local entry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    local name, path
    if type(entry) == "string" then
      name = entry
      path = icons.icons and icons.icons[entry]
    elseif type(entry) == "table" then
      path = entry.image
    end
    if not path then
      name = def and def.dex and icons.byDex and icons.byDex[def.dex]
      path = name and icons.icons and icons.icons[name]
    end
    -- Sprites.iconPath raises pokemon.icon with the live mon, which is how a
    -- shiny tells itself apart from an ordinary one of its species
    local ok, hooked = pcall(Sprites.iconPath, game.data, mon, path,
                             { name = name })
    if ok then path = hooked end
    return name, path
  end

  -- Does this file carry a colour a grey ramp cannot?  Read once per path and
  -- remembered, because it is a property of the file.
  local function scanPath(path)
    local info = pathColour[path]
    if info ~= nil then return info end
    info = { colour = false, w = ICON, h = ICON }
    pcall(function()
      local data = require("src.render.Assets").imageData(path)
      local w, h = data:getDimensions()
      info.w, info.h = w, h
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local r, g, b, a = data:getPixel(x, y)
          if a > 0 and (math.abs(r - g) > 0.02 or math.abs(g - b) > 0.02) then
            info.colour = true
            return
          end
        end
      end
    end)
    pathColour[path] = info
    return info
  end

  -- nil when the icon is ordinary DMG art (colour it with a species zone), or
  -- the rect drawIcon will cover when it is full colour (mark it and leave it
  -- alone).  drawIcon takes a 16x16 frame out of a taller sheet and draws
  -- anything shorter whole, at whatever size the file is.
  function Icons.fullColourRect(game, mon)
    if not mon then return nil end
    local hit = iconColour[mon]
    if hit == nil then
      local name, path = resolveIcon(game, mon)
      if not path or name then
        hit = false
      else
        local info = scanPath(path)
        hit = info.colour
          and { w = info.h > ICON and ICON or info.w,
                h = info.h > ICON and ICON or info.h }
          or false
      end
      iconColour[mon] = hit
    end
    return hit or nil
  end

  -- Draw an icon through the party menu's own renderer and claim it as full
  -- colour when it is one.  The two belong together: a screen that draws art
  -- this way and forgets the mark is the bug above, so there is one call that
  -- cannot forget.
  function Icons.draw(game, mon, x, y, alt)
    if not mon then return end
    love.graphics.setColor(1, 1, 1, 1)
    local PartyMenu = require("src.ui.PartyMenu")
    pcall(PartyMenu.drawIcon, game, mon, x, y, false, 0, alt or false)
    Icons.mark(game, mon, x, y)
  end

  -- full-colour art must sit out the shade remap, or the pass repaints it
  -- off its red channel and an orange POKeMON comes out white
  function Icons.mark(game, mon, x, y)
    local rect = Icons.fullColourRect(game, mon)
    if not rect then return false end
    pcall(function()
      require("src.render.PaletteFX").markTrueColor(x, y, rect.w, rect.h)
    end)
    return true
  end

  return Icons
end
