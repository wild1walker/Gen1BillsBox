-- Gen1BillsBox -- the POKeMON screen wears the same colours
--
-- The box screen's rule is that EACH POKeMON GETS ITS OWN PALETTE: one SGB
-- zone per cell, carrying that species' colours, the way the battle screen
-- and the summary screen colour a mon.  The party menu is the one other
-- screen in the game that draws the same six POKeMON in the same 16x16 icons
-- -- and it is the screen you walk into the box FROM.  Twenty POKeMON in
-- twenty sets of colours on the right, six in one flat purple on the left, is
-- the only place this mod's own two screens disagree with each other.
--
-- So this is the box's colour rule, applied to the party menu, and nothing
-- else.  Not a new party screen: the vanilla one is already Gen 1 line art in
-- the Game Boy's own font, its cursor is already the $ED / $EC pair the box's
-- party pane borrows, and its layout is the cart's to the pixel.  There is
-- nothing here to redraw -- only four palettes where there could be six.
--
-- ------- what the cart did, and what is kept of it
--
-- SetPal_PartyMenu (engine/gfx/palettes.asm) splits this screen into blocks:
-- MEWMON over the icon column, GREENBAR everywhere else, and one block per HP
-- bar row whose palette follows that mon's health -- green, yellow, red.  The
-- engine reproduces all of it (src/ui/PartyMenu.lua:sgbPalettes).
--
-- Only the FIRST of those blocks is replaced here, one row at a time: tiles 1
-- and 2 of each entry, which is exactly the two-by-two the icon is drawn in.
-- The bars keep their own three colours, because that is health being read at
-- a glance and not decoration; the base stays GREENBAR; the names, the levels
-- and the text box are drawn in shade 3 and shade 3 is {0,0,0} in MEWMON, in
-- GREENBAR and in all 151 species palettes alike, so nothing outside the icon
-- column can tell the difference.
--
-- ------- and the icons that must NOT be recoloured
--
-- The same hazard the box screen has: authored full-colour art run through
-- the shade remap comes out destroyed, because the pass keys each pixel off
-- its red channel.  Under the vanilla MEWMON block that is already true of
-- this screen; a species palette in its place would be no better.  So an icon
-- whose file carries real colour is marked instead (iconart.lua), which takes
-- it out of the pass entirely and leaves it exactly as its author drew it.
--
-- ------- how it is attached
--
-- By DECORATING the engine's own party menu, not by replacing it.  The screen
-- is 886 lines of switching, field moves, item targeting, TM/HM and battle
-- entry points, all of which stay the engine's; what this adds is two methods
-- on the instance -- the palette list and a mark after the draw -- each of
-- which calls the engine's own first and falls back to it if anything at all
-- goes wrong.  A mod that has already taken the screen id keeps it, because a
-- second party menu over one save is worth more than this is.
return function(mod, Icons)
  local PartyMenu = require("src.ui.PartyMenu")

  -- Where PartyMenu:draw puts the icon: x = 8 (tile 1), 16 wide, at the top
  -- of each entry.  Read off the engine's own entryY so a row that ever moves
  -- takes its colours with it.
  local ICON_X = 8
  local ICON_TILES = 2

  local function option(key, fallback)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok or value == nil then return fallback end
    return value
  end

  -- The tile rect row i's icon covers, or nothing at all if that row is not
  -- tile-aligned -- a zone is ADDRESSED in tiles, so half a tile of icon is a
  -- row this cannot colour rather than a row it colours approximately.
  local function iconTiles(i)
    local ok, y = pcall(PartyMenu.entryY, i)
    if not ok or type(y) ~= "number" or y % 8 ~= 0 then return nil end
    local tx, ty = ICON_X / 8, y / 8
    return tx, ty, tx + ICON_TILES - 1, ty + ICON_TILES - 1
  end

  -- The list the screen is actually drawing: a link or scoped battle hands
  -- the party menu its own view (opts.party), and colouring save.party there
  -- would colour six POKeMON that are not on the screen.
  local function shownParty(self)
    return self.party or (self.game.save and self.game.save.party) or {}
  end

  local Screen = {}

  function Screen.new(game, opts)
    local self = PartyMenu.new(game, opts)

    -- the engine's own, reached through the instance so a mod that has
    -- already decorated the class is decorated in turn rather than dropped
    local basePalettes, baseDraw = self.sgbPalettes, self.draw

    -- Appended, never inserted: the renderer draws later zones on top, so a
    -- species zone laid over the MEWMON block wins on the two tiles it covers
    -- and leaves the rest of the block -- the rows with no POKeMON in them --
    -- as the cart had it.
    --
    -- A nil from the engine stays nil.  That is not the absence of an answer,
    -- it is the answer: no GREENBAR means no colour pass on this screen at
    -- all (a COLORS mode with no pack behind it), and six species zones on
    -- their own would be this mod colouring a screen the game has decided is
    -- grey.
    function self:sgbPalettes(g)
      local zones = basePalettes and basePalettes(self, g)
      if not zones or not option("partyColours", true) then return zones end
      local ok, out = pcall(function()
        local P = require("src.render.PaletteFX")
        for i, mon in ipairs(shownParty(self)) do
          -- full-colour art is re-blit unshaded over this pass, so a species
          -- palette under it would be paint nobody ever sees
          if not Icons.fullColourRect(g, mon) then
            local tx1, ty1, tx2, ty2 = iconTiles(i)
            local colors = tx1 and P.monPal(g.data, mon.species)
            local zone = colors and P.zone(colors, tx1, ty1, tx2, ty2)
            if zone then zones[#zones + 1] = zone end
          end
        end
        return zones
      end)
      return ok and out or zones
    end

    -- The engine draws the icons; this only claims the full-colour ones
    -- afterwards.  Marks are collected per frame and spliced into the zone
    -- list at the end of it, so claiming a rect after it was drawn is the
    -- normal order and not a race.
    function self:draw()
      baseDraw(self)
      if not option("partyColours", true) then return end
      pcall(function()
        for i, mon in ipairs(shownParty(self)) do
          local _, ty = iconTiles(i)
          if ty then Icons.mark(self.game, mon, ICON_X, ty * 8) end
        end
      end)
    end

    return self
  end

  return Screen
end
