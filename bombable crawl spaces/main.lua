local mod = RegisterMod('Bombable Crawl Spaces', 1)
local json = require('json')
local game = Game()

-- only dealing with built-in rooms for now
-- swap out walls/blocks for rocks that we can blow up
-- use the item dungeon sprites
if REPENTOGON then
  mod.onGameStartHasRun = false
  mod.rngShiftIdx = 35
  
  mod.state = {}
  mod.state.percent = 50
  mod.state.blackMarketDoors = true -- crawlspaces rebuilt mod
  
  function mod:onGameStart()
    if mod:HasData() then
      local _, state = pcall(json.decode, mod:LoadData())
      
      if type(state) == 'table' then
        if math.type(state.percent) == 'integer' and state.percent >= 0 and state.percent <= 100 then
          mod.state.percent = state.percent
        end
        if type(state.blackMarketDoors) == 'boolean' then
          mod.state.blackMarketDoors = state.blackMarketDoors
        end
      end
    end
    
    mod.onGameStartHasRun = true
    mod:onNewRoom()
  end
  
  function mod:onGameExit()
    mod:save()
    mod.onGameStartHasRun = false
  end
  
  function mod:save()
    mod:SaveData(json.encode(mod.state))
  end
  
  -- MC_PRE_ROOM_ENTITY_SPAWN doesn't work for the outer walls
  function mod:onNewRoom()
    if not mod.onGameStartHasRun then
      return
    end
    
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    
    if room:GetType() == RoomType.ROOM_DUNGEON and
       room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 and
       roomDesc.Data.Subtype == RoomSubType.CRAWLSPACE_NORMAL and
       roomDesc.Data.StageID == StbType.SPECIAL_ROOMS
    then
      local gridIdxs = {}
      -- 1 already has black market access
      if mod:tblHasVal({ 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant) then
        table.insert(gridIdxs, 58)
        table.insert(gridIdxs, 59)
      end
      if mod:tblHasVal({ 0, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant) then
        table.insert(gridIdxs, 73)
        table.insert(gridIdxs, 74)
      end
      if mod:tblHasVal({ 3, 12 }, roomDesc.Data.Variant) then
        table.insert(gridIdxs, 43)
        table.insert(gridIdxs, 44)
      end
      if roomDesc.Data.Variant == 4 then
        table.insert(gridIdxs, 52)
        table.insert(gridIdxs, 67)
      end
      if roomDesc.Data.Variant == 8 then
        table.insert(gridIdxs, 57)
        table.insert(gridIdxs, 72)
      end
      if #gridIdxs > 0 then
        local rng = RNG(room:GetSpawnSeed(), mod.rngShiftIdx)
        local createRocks = rng:RandomInt(100) < mod.state.percent
        for _, v in ipairs(gridIdxs) do
          local gridEntity = room:GetGridEntity(v)
          if gridEntity then
            if createRocks and (room:IsFirstVisit() or roomDesc.GridIndex == GridRooms.ROOM_DEBUG_IDX) and mod:tblHasVal({ GridEntityType.GRID_ROCKB, GridEntityType.GRID_WALL }, gridEntity:GetType()) then
              room:RemoveGridEntityImmediate(v, 0, false)
              gridEntity = Isaac.GridSpawn(GridEntityType.GRID_ROCK, 0, gridEntity.Position, true)
            end
            if gridEntity:GetType() == GridEntityType.GRID_ROCK then
              gridEntity:GetSprite():Load('gfx/grid/tiles_itemdungeon.anm2', true)
              gridEntity:GetSprite():Play(mod:doBetterGridEntityRNG(room:GetDecorationSeed(), gridEntity:GetGridIndex(), { 'LowBrick1', 'LowBrick2' }), true)
              gridEntity:GetSprite().Color = Color(1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0.3) -- red
            end
          end
        end
        mod:doCrawlspacesRebuiltCompat()
      end
    end
  end
  
  -- do this 1 frame later than onNewRoom
  function mod:onUpdate()
    local room = game:GetRoom()
    
    if room:GetFrameCount() == 1 then
      mod:checkCanSeeEverything()
    end
  end
  
  -- filtered to COLLECTIBLE_DADS_KEY (includes get out of jail free card)
  function mod:onUseItem(collectible, rng, player, useFlags, activeSlot, varData)
    if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
      return
    end
    mod:onUseOpenDoorItem()
  end
  
  -- filtered to CARD_SOUL_CAIN
  function mod:onUseCard(card, player, useFlags)
    if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
      return
    end
    mod:onUseOpenDoorItem()
  end
  
  -- filtered to PILLEFFECT_SEE_FOREVER
  function mod:onUsePill(pillEffect, player, useFlags)
    if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
      return
    end
    mod:checkCanSeeEverything()
  end
  
  -- filtered to COLLECTIBLE_XRAY_VISION
  function mod:onAddCollectible()
    mod:checkCanSeeEverything()
  end
  
  -- pill or x-ray vision
  function mod:checkCanSeeEverything()
    local level = game:GetLevel()
    
    if level:GetCanSeeEverything() or PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_XRAY_VISION, false) then
      mod:onUseOpenDoorItem()
    end
  end
  
  function mod:onUseOpenDoorItem()
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    
    if room:GetType() == RoomType.ROOM_DUNGEON and
       room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 and
       roomDesc.Data.Subtype == RoomSubType.CRAWLSPACE_NORMAL and
       roomDesc.Data.StageID == StbType.SPECIAL_ROOMS and
       mod:tblHasVal({ 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant)
    then
      for _, v in ipairs({ 42, 43, 44, 57, 58, 59, 72, 73, 74 }) do
        local gridEntity = room:GetGridEntity(v)
        if gridEntity and gridEntity:GetType() == GridEntityType.GRID_ROCK then
          gridEntity:Destroy(true)
        end
      end
    end
  end
  
  -- by default, rock CollisionClass is set to COLLISION_WALL in crawl spaces
  -- rocks don't normally blow up with this class
  -- you can fight the game and constantly set the class to COLLISION_SOLID
  -- however, that also allows you to fly over the rocks which we don't want
  function mod:onBombDamage(pos, damage, radius, lineCheck, source, tearFlags, dmgFlags, dmgSource)
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    
    if room:GetType() == RoomType.ROOM_DUNGEON and
       room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 and
       roomDesc.Data.Subtype == RoomSubType.CRAWLSPACE_NORMAL and
       roomDesc.Data.StageID == StbType.SPECIAL_ROOMS and
       mod:tblHasVal({ 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant)
    then
      for i = 0, room:GetGridSize() - 1 do
        local gridEntity = room:GetGridEntity(i)
        if gridEntity and gridEntity:GetType() == GridEntityType.GRID_ROCK and gridEntity.Position:Distance(pos) < radius then
          gridEntity:Destroy(true)
        end
      end
    end
  end
  
  function mod:onGridRockDestroy(rock)
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    
    if room:GetType() == RoomType.ROOM_DUNGEON and
       room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 and
       roomDesc.Data.Subtype == RoomSubType.CRAWLSPACE_NORMAL and
       roomDesc.Data.StageID == StbType.SPECIAL_ROOMS and
       mod:tblHasVal({ 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant)
    then
      local i = rock:GetGridIndex()
      local w = room:GetGridWidth()
      
      -- swap out the rock/rubble with gravity so the space acts like a vertical room
      room:RemoveGridEntityImmediate(i, 0, false)
      local gravity = Isaac.GridSpawn(GridEntityType.GRID_GRAVITY, 0, rock.Position, true)
      local belowGravity = room:GetGridEntity(i + w)
      if belowGravity and mod:tblHasVal({ GridEntityType.GRID_ROCKB, GridEntityType.GRID_WALL }, belowGravity:GetType()) then
        gravity:GetSprite():Load('gfx/grid/tiles_itemdungeon.anm2', true)
        gravity:GetSprite():Play(mod:doBetterGridEntityRNG(room:GetDecorationSeed(), gravity:GetGridIndex(), { 'Floor1', 'Floor2', 'Floor3' }), true)
        belowGravity:GetSprite():Load('gfx/grid/tiles_itemdungeon.anm2', true)
        belowGravity:GetSprite():Play(mod:doBetterGridEntityRNG(room:GetDecorationSeed(), belowGravity:GetGridIndex(), { 'Brick1', 'Brick2', 'Brick3' }), true)
      end
      
      -- the game likes to teleport you out of the room sooner than you'd think (especially on your first visit)
      -- make sure all connected rocks get destroyed
      -- otherwise when you re-enter the room there might still be a layer of rocks that need to be destroyed
      for _, v in ipairs({
                          { cond = i % w ~= 0                , val = i - 1 },
                          { cond = (i + 1) % w ~= 0          , val = i + 1 },
                          { cond = i - w >= 0                , val = i - w },
                          { cond = i + w < room:GetGridSize(), val = i + w },
                        })
      do
        if v.cond then
          local gridEntity = room:GetGridEntity(v.val)
          if gridEntity and gridEntity:GetType() == GridEntityType.GRID_ROCK then
            gridEntity:Destroy(true)
          end
        end
      end
      mod:doCrawlspacesRebuiltCompat()
    end
  end
  
  function mod:onPreChangeRoom(targetRoomIdx, dimension)
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    
    if room:GetType() == RoomType.ROOM_DUNGEON and
       room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 and
       roomDesc.Data.Subtype == RoomSubType.CRAWLSPACE_NORMAL and
       roomDesc.Data.StageID == StbType.SPECIAL_ROOMS and
       mod:tblHasVal({ 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant) and
       targetRoomIdx == GridRooms.ROOM_ERROR_IDX
    then
      return { GridRooms.ROOM_BLACK_MARKET_IDX, dimension }
    end
  end
  
  -- gridEntity:GetRNG isn't very good rng, it always initializes the same
  function mod:doBetterGridEntityRNG(seed, gridIdx, options)
    local rng = RNG(seed, mod.rngShiftIdx)
    for i = 0, gridIdx do
      rng:Next()
    end
    return options[rng:RandomInt(#options) + 1]
  end
  
  function mod:doCrawlspacesRebuiltCompat()
    if not CrawlspacesRebuilt or not mod.state.blackMarketDoors then
      return
    end
    
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local roomDesc = level:GetCurrentRoomDesc()
    
    if room:GetType() == RoomType.ROOM_DUNGEON and
       room:GetRoomShape() == RoomShape.ROOMSHAPE_1x1 and
       roomDesc.Data.Subtype == RoomSubType.CRAWLSPACE_NORMAL and
       roomDesc.Data.StageID == StbType.SPECIAL_ROOMS
    then
      local gridIdx = nil
      if mod:tblHasVal({ 0, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, roomDesc.Data.Variant) then
        gridIdx = 74
      elseif roomDesc.Data.Variant == 3 then
        gridIdx = 59
      end
      
      if gridIdx then
        local gridEntity = room:GetGridEntity(gridIdx)
        if gridEntity and gridEntity:GetType() == GridEntityType.GRID_GRAVITY then
          gridEntity:GetSprite():Load('gfx/content/dungeon/hatch.anm2', true)
          gridEntity:GetSprite():Play('marketdoor', true)
        end
      end
    end
  end
  
  function mod:tblHasVal(tbl, val)
    for _, v in ipairs(tbl) do
      if v == val then
        return true
      end
    end
    return false
  end
  
  -- start ModConfigMenu --
  function mod:setupModConfigMenu()
    local category = 'Bomb Crawl Spaces'
    for _, v in ipairs({ 'Settings', 'Compat' }) do
      ModConfigMenu.RemoveSubcategory(category, v)
    end
    ModConfigMenu.AddText(category, 'Settings', 'Chance for a bombable crawl space:')
    ModConfigMenu.AddSetting(
      category,
      'Settings',
      {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
          return mod.state.percent
        end,
        Minimum = 0,
        Maximum = 100,
        Display = function()
          return mod.state.percent .. '%'
        end,
        OnChange = function(n)
          mod.state.percent = n
          mod:save()
        end,
        Info = { 'Default: 50%', 'Calculated on first room visit' }
      }
    )
    ModConfigMenu.AddTitle(category, 'Compat', 'Crawlspaces Rebuilt')
    ModConfigMenu.AddSetting(
      category,
      'Compat',
      {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
          return mod.state.blackMarketDoors
        end,
        Display = function()
          return 'Black market doors : ' .. (mod.state.blackMarketDoors and 'enabled' or 'disabled')
        end,
        OnChange = function(b)
          mod.state.blackMarketDoors = b
          mod:save()
        end,
        Info = { 'Default: enabled', 'Match the setting from crawlspaces rebuilt' }
      }
    )
  end
  -- end ModConfigMenu --
  
  mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
  mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
  mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
  mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
  mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.onUseItem, CollectibleType.COLLECTIBLE_DADS_KEY)
  mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.onUseCard, Card.CARD_SOUL_CAIN)
  mod:AddCallback(ModCallbacks.MC_USE_PILL, mod.onUsePill, PillEffect.PILLEFFECT_SEE_FOREVER)
  mod:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, mod.onAddCollectible, CollectibleType.COLLECTIBLE_XRAY_VISION)
  mod:AddCallback(ModCallbacks.MC_POST_BOMB_DAMAGE, mod.onBombDamage)
  mod:AddCallback(ModCallbacks.MC_POST_GRID_ROCK_DESTROY, mod.onGridRockDestroy)
  mod:AddCallback(ModCallbacks.MC_PRE_CHANGE_ROOM, mod.onPreChangeRoom)
  
  if ModConfigMenu then
    mod:setupModConfigMenu()
  end
end