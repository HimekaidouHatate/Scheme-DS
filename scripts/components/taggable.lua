local taggables = require"taggables"

--V2C: NOTE: do not add "writeable" tag to pristine state because it is more
--           likely for players to encounter signs that are already written.
local Taggable = Class(function(self, inst)
    self.inst = inst
    self.text = nil

    self.screen = nil
	
    self.onclosepopups = function()
		self:EndAction()
    end

    self.generatorfn = nil

    self.inst:ListenForEvent("tag", self.BeginWriting)
    self.inst:ListenForEvent("select", onselected)
end)

function Taggable:OnSave()
    local data = {}

    data.text = self.text

    return data
end

function Taggable:OnLoad(data)
    self.text = data.text
	if IsXB1() then
		self.netid = data.netid
	end
end

function Taggable:GetText(viewer)
	if IsXB1() then
		if self.text and self.netid then
			return "\1"..self.text.."\1"..self.netid
		end
	end
    return self.text
end

function Taggable:SetText(text)
    self.text = text
end

function Taggable:BeginWriting(doer)
    self.inst:StartUpdatingComponent(self)

    self.writer = doer
--  self.inst:ListenForEvent("ms_closepopups", self.onclosepopups, doer)
--  self.inst:ListenForEvent("onremove", self.onclosepopups, doer)

    self.screen = taggables.makescreen(self.inst, doer)
end

local DANGER_RADIUS = 10
local function IsInDangerFromShadowCreatures(inst)
	-- Danger if:
	-- insane and near shadowcreature.
	-- ignore when shadowdominance
	-- being targetted but not ShouldSubmitToTarget.
	local ignoreshadowcreature = inst.components.inventory:EquipHasTag("shadowdominance") or inst.components.sanity:IsSane()

	local isdanger = false
	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, DANGER_RADIUS * 2, { "shadowcreature" })
	for k, v in ipairs(ents) do
		if ((not ignoreshadowcreature) or (v.components.combat ~= nil and v.components.combat.target == inst)) and not v.components.shadowsubmissive:ShouldSubmitToTarget(inst) then
			isdanger = true
			break
		end
	end

	return isdanger
end

local function IsNearDanger(inst)
	local isnearbosses = _G.SCHEME_IGNOREBOSS or FindEntity(inst, DANGER_RADIUS * 2, nil, { "epic" }, { "spiderqueen", "leif" }) ~= nil or false

	local isdanger = false
	if not _G.SCHEME_IGNOREDANGER then
		local x, y, z = inst.Transform:GetWorldPosition()
		local ents = TheSim:FindEntities(x, y, z, DANGER_RADIUS, { "_combat" }, { "shadowcreature" }) -- See entityreplica.lua (for _combat tag usage)

		if ents ~= nil then
			if inst:HasTag("realyoukai") then
				-- Danger if:
				-- being targetted
				-- OR near monster that is not player, spider, bat, 
				for k, v in ipairs(ents) do
					if v:HasTag("monster") and not (v:HasTag("player") or v:HasTag("spider") or v:HasTag("bat")) or (v.components.combat ~= nil and v.components.combat.target == inst) then
						isdanger = true
						break
					end
				end
			elseif inst:HasTag("youkai") then
				-- Danger if:
				-- being targetted
				-- OR near monster or pig or spider that is not player
				-- note that "pig" tag includes somewhat things like bunnymans.
				for k, v in ipairs(ents) do
					if (v:HasTag("monster") or v:HasTag("pig") or v:HasTag("spider")) and not v:HasTag("player") or (v.components.combat ~= nil and v.components.combat.target == inst) then
						isdanger = true
						break
					end
				end
			elseif inst:HasTag("spiderwhisperer") then
				-- Danger if:
				-- being targetted
				-- OR near monster or pig that is neither player nor spider
				for k, v in ipairs(ents) do
					if (v:HasTag("monster") or v:HasTag("pig")) and not (v:HasTag("player") or v:HasTag("spider")) or (v.components.combat ~= nil and v.components.combat.target == inst) then
						isdanger = true
						break
					end
				end
			else
				--Danger if:
				-- being targetted
				-- OR near monster that is not player
				for k, v in ipairs(ents) do
					if v:HasTag("monster") and not v:HasTag("player") or (v.components.combat ~= nil and v.components.combat.target == inst) then
						isdanger = true
						break
					end
				end
			end
		end

		local hounded = TheWorld.components.hounded
		if hounded ~= nil and (hounded:GetWarning() or hounded:GetAttacking()) then
			isdanger = true
		end

		local burnable = inst.components.burnable
		if burnable ~= nil and (burnable:IsBurning() or burnable:IsSmoldering()) then
			isdanger = true
		end

		isdanger = isdanger or IsInDangerFromShadowCreatures(inst)
	end
	
	return isdanger or isnearbosses
end

function Taggable:SelectPopup(doer)
	if IsNearDanger(doer) then 
		doer.components.talker:Say(GetString(doer.prefab, "NODANGERSCHEME"))
		return 
	end
	self.inst.sg:GoToState("opening")

--    self.inst:ListenForEvent("ms_closepopups", self.onclosepopups, doer)
--    self.inst:ListenForEvent("onremove", self.onclosepopups, doer)
	doer:DoTaskInTime(14 * FRAMES, function()
		self.inst:StartUpdatingComponent(self)
		self.screen = doer.HUD:ShowSchemeUI(self.inst)
	end)
end

function Taggable:IsWritten()
    return self.text ~= nil
end

function Taggable:DoAction(doer, _text, index) --Some.. bad example of implementing overload
	if index ~= nil then
		doer.sg:GoToState("jumpin", { teleporter = doer })
		doer:DoTaskInTime(0.8, function()
			self.inst.components.scheme:Activate(doer, index)
		end)
		doer:DoTaskInTime(3, function() -- Move entities outside of map border inside
			if not doer:IsOnValidGround() then
				local dest = FindNearbyLand(doer:GetPosition(), 8)
				if dest ~= nil then
					if doer.Physics ~= nil then
						doer.Physics:Teleport(dest:Get())
					elseif act.doer.Transform ~= nil then
						doer.Transform:SetPosition(dest:Get())
					end
				end
			end
		end)
	else
		local text = _text or self.text
		if text == nil or text == "" then --set default text
			local index = self.inst.components.scheme.index
			if index ~= nil then
				text = "#"..index
			end
		end

		self:SetText(text)
	end

	self:EndAction()
end

function Taggable:EndAction()
    if self.writer ~= nil then
        self.inst:StopUpdatingComponent(self)

        if self.screen ~= nil then
            self.writer.HUD:CloseTaggableWidget()
            self.writer.HUD:CloseSchemeUI()
            self.screen = nil
        end

        self.inst:RemoveEventCallback("ms_closepopups", self.onclosepopups, self.writer)
        self.inst:RemoveEventCallback("onremove", self.onclosepopups, self.writer)

--		if IsXB1() then
--			if self.writer:HasTag("player") and self.writer:GetDisplayName() then
--				local ClientObjs = TheNet:GetClientTable()
--				if ClientObjs ~= nil and #ClientObjs > 0 then
--					for i, v in ipairs(ClientObjs) do
--						if self.writer:GetDisplayName() == v.name then
--							self.netid = v.netid
--							break
--						end
--					end
--				end
--			end
--		end

        self.writer = nil
    elseif self.screen ~= nil then
        --Should not have screen and no writer, but just in case...
        if self.screen.inst:IsValid() then
            self.screen:Kill()
        end
        self.screen = nil
    end
	self.inst:DoTaskInTime(1, function()
		self.inst.sg:GoToState("closing")
	end)
end

--------------------------------------------------------------------------
--Check for auto-closing conditions
--------------------------------------------------------------------------

function Taggable:OnUpdate(dt)
    if self.writer == nil then
        self.inst:StopUpdatingComponent(self)
    elseif (self.writer.components.rider ~= nil and
        self.writer.components.rider:IsRiding())
        or not (self.writer:IsNear(self.inst, 3) and
		CanEntitySeeTarget(self.writer, self.inst)) then
			self:EndAction()
    end
end

--------------------------------------------------------------------------

function Taggable:OnRemoveFromEntity()
    self:EndAction()
    self.inst:RemoveTag("writeable")
    self.inst:RemoveEventCallback("tag", onspawned)
	self.inst:RemoveEventCallback("select", onselected)
end

Taggable.OnRemoveEntity = Taggable.EndAction

return Taggable
