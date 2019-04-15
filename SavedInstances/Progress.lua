local _, addon = ...
local P = addon.core:NewModule("Progress", "AceEvent-3.0")
local thisToon = UnitName("player") .. " - " .. GetRealmName()

-- Lua functions
local pairs = pairs

-- WoW API / Variables
local C_PvP_GetWeeklyChestInfo = C_PvP.GetWeeklyChestInfo
local GetQuestObjectiveInfo = GetQuestObjectiveInfo
local IsQuestFlaggedCompleted = IsQuestFlaggedCompleted
local QuestUtils_GetCurrentQuestLineQuest = QuestUtils_GetCurrentQuestLineQuest

local READY_CHECK_READY_TEXTURE = READY_CHECK_READY_TEXTURE
local READY_CHECK_WAITING_TEXTURE = READY_CHECK_WAITING_TEXTURE

local CONQUEST_QUESTLINE_ID = 782

local function ConquestUpdate(index)
  local tbl = addon.db.Toons[thisToon].Progress
  local currentQuestID = QuestUtils_GetCurrentQuestLineQuest(CONQUEST_QUESTLINE_ID)
  local rewardAchieved = C_PvP_GetWeeklyChestInfo()
  if currentQuestID == 0 then
    tbl[index] = {
      isComplete = true,
      isFinish = true,
      numFulfilled = 500,
      numRequired = 500,
      rewardAchieved = rewardAchieved,
    }
  else
    local text, _, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(currentQuestID, 1, false)
    if text then
      tbl[index] = {
        isComplete = false,
        isFinish = finished,
        numFulfilled = numFulfilled,
        numRequired = numRequired,
        rewardAchieved = rewardAchieved,
      }
    end
  end
end

local function ConquestShow(toon, index)
  local t = addon.db.Toons[toon]
  if not t or not t.Progress or not t.Progress[index] then return end
  local tbl = t.Progress[index]
  local text
  if tbl.isComplete then
    text = "\124T" .. READY_CHECK_READY_TEXTURE .. ":0|t"
  elseif tbl.isFinish then
    text = "\124T" .. READY_CHECK_WAITING_TEXTURE .. ":0|t"
  else
    text = tbl.numFulfilled .. "/" .. tbl.numRequired
  end
  if tbl.rewardAchieved then
    text = text .. "(\124T" .. READY_CHECK_READY_TEXTURE .. ":0|t)"
  end
  return text
end

local function KeepProgress(toon, index)
  local t = addon.db.Toons[toon]
  if not t or not t.Progress or not t.Progress[index] then return end
  local tbl = t.Progress[index]
  tbl = {
    isComplete = false,
    isFinish = false,
    numFulfilled = tbl.isComplete and 0 or tbl.numFulfilled,
    numRequired = tbl.numRequired,
  }
end

local trackedQuest = {
  -- Conquest
  {
    name = PVP_CONQUEST,
    func = ConquestUpdate,
    weekly = true,
    resetFunc = KeepProgress,
    showFunc = ConquestShow,
  },
  -- Island Expedition
  {
    name = ISLANDS_HEADER,
    quest = C_IslandsQueue.GetIslandsWeeklyQuestID(),
    weekly = true,
    resetFunc = KeepProgress,
    -- quest = {
    --   ["Alliance"] = 53436,
    --   ["Horde"]    = 53435,
    -- },
  },
}

function P:OnEnable()
  self:RegisterEvent("QUEST_LOG_UPDATE")
end

function P:QUEST_LOG_UPDATE()
  local t = addon.db.Toons[thisToon]
  if not t.Progress then t.Progress = {} end
  for i, tbl in pairs(trackedQuest) do
    if tbl.func then
      tbl.func(i)
    elseif tbl.quest then
      local questID = tbl.quest
      -- if type(questID) ~= "number" then
      --   questID = questID[t.Faction]
      -- end
      local result = {}
      if IsQuestFlaggedCompleted(questID) then
        result.isComplete = true
      else
        local _, _, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(questID, 1, false)
        result.isComplete = false
        result.isFinish = finished
        result.numFulfilled = numFulfilled
        result.numRequired = numRequired
      end
      t.Progress[i] = result
    end
  end
end

function P:OnDailyReset(toon)
  local t = addon.db.Toons[toon]
  if not t or not t.Progress then return end
  for i, tbl in pairs(trackedQuest) do
    if tbl.daily then
      if tbl.resetFunc then
        tbl.resetFunc(toon, i)
      else
        tbl = {
          isComplete = false,
          isFinish = false,
          numFulfilled = 0,
          numRequired = tbl.numRequired,
        }
      end
    end
  end
end

function P:OnWeeklyReset(toon)
  local t = addon.db.Toons[toon]
  if not t or not t.Progress then return end
  for i, tbl in pairs(trackedQuest) do
    if tbl.weekly then
      if tbl.resetFunc then
        tbl.resetFunc(toon, i)
      else
        tbl = {
          isComplete = false,
          isFinish = false,
          numFulfilled = 0,
          numRequired = tbl.numRequired,
        }
      end
    end
  end
end

function P:BuildConfig(order)
  local option = {}
  for index, tbl in pairs(trackedQuest) do
    option["Progress" .. index] = {
      type = "toggle",
      order = order + index * 0.01,
      name = tbl.name,
    }
  end
  return option
end

function P:ShowTooltip(columns, showall, preshow)
  local tooltip = addon.tooltip
  local cpairs = addon.cpairs
  local first = true
  for index, tbl in pairs(trackedQuest) do
    if addon.db.Tooltip["Progress" .. index] or showall then
      local show
      for toon, t in cpairs(addon.db.Toons, true) do
        if t.Progress and t.Progress[index] then
          show = true
        end
      end
      if show then
        if first == true then
          preshow()
          first = false
        end
        local line = tooltip:AddLine(tbl.name)
        for toon, t in cpairs(addon.db.Toons, true) do
          if t.Progress and t.Progress[index] then
            local text
            if tbl.showFunc then
              text = tbl.showFunc(index)
            elseif tbl.isComplete then
              text = "\124T" .. READY_CHECK_READY_TEXTURE .. ":0|t"
            elseif tbl.isFinish then
              text = "\124T" .. READY_CHECK_WAITING_TEXTURE .. ":0|t"
            else
              text = tbl.numFulfilled .. "/" .. tbl.numRequired
            end
            local col = columns[toon .. 1]
            tooltip:SetCell(line, col, text, "CENTER", 4)
          end
        end
      end
    end
  end
end
