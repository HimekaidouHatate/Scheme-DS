local MakeGate = Class(function(self, inst)
    self.inst = inst
	self.onusefn = nil
    self.distance_controller = 7 
end)

function MakeGate:SpawnEffect(inst)
	local pt = inst:GetPosition()
	local fx = SpawnPrefab("small_puff")
	fx.Transform:SetPosition(pt.x, pt.y, pt.z)
end

function MakeGate:CanSpell(caster)
	if caster.components.power ~= nil and caster.components.power:GetCurrent() >= cost then
		if self.onusefn == nil then
			return false
		end
	elseif caster.prefab == "yakumoyukari" then
		return false
	end

	return true
end

function MakeGate:Teleport(pt, caster)
	self:SpawnEffect(caster)
	caster.SoundEmitter:PlaySound("dontstarve/common/staff_blink")
	caster:Hide()
	caster:DoTaskInTime(0.3, function() 
		self:SpawnEffect(caster)
		caster.Transform:SetPosition(pt.x, pt.y, pt.z)
		caster:Show()
	end)
	
	self.onusefn(self.inst, pt, caster)
	
	return true
end

function MakeGate:Create(pt, caster)
	local numalter, numstat = _G.GetGCost(caster, true)
	if caster.components.sanity ~= nil and math.ceil(caster.components.sanity.current) < numstat then caster.components.talker:Say(GetString(caster.prefab, "LOWCGSANITY")) return true end
	_G.ConsumeGateCost(caster, numalter, numstat, true)
	if self.inst:HasTag("schemetool") then
		self.inst.components.finiteuses:Use(6)
	end

	caster.SoundEmitter:PlaySound("dontstarve/common/staff_blink")
	if caster.components.health ~= nil then
		caster.components.health:SetInvincible(true)
	end
	caster:DoTaskInTime(0.5, function() 
		if caster.components.health ~= nil then
			caster.components.health:SetInvincible(false)
		end
		if caster ~= nil then
			caster.SoundEmitter:PlaySound("dontstarve/common/staff_dissassemble")
		end
		local scheme = SpawnPrefab("tunnel")
		scheme.components.scheme:InitGate()
		scheme.Transform:SetPosition(pt.x, pt.y, pt.z)
		self:Configurate(scheme, caster)
	end)
	
	return true
end

function MakeGate:Configurate(target, caster)
	target:PushEvent("tag", {spawner = caster})
	if self.inst:HasTag("schemetool") then
		self.inst.components.finiteuses:Use(1)
	end

	return true
end

function MakeGate:CollectEquippedActions(doer, target, actions, right)
	if right and target:HasTag("tunnel")then
		table.insert(actions, ACTIONS.CONFIGG)
	end
end

function MakeGate:CollectPointActions(doer, pos, actions, right)
    if right then
		if inst.prefab == "yukariumbre" and doer:HasTag("yakumoyukari") and doer.components.power ~= nil then
			if inst.isunfolded and doer.components.power:GetCurrent() >= TUNING.YUKARI.SPAWNG_POWER_COST then
				table.insert(actions, ACTIONS.SPAWNG)
			elseif not inst.isunfolded and doer.components.power:GetCurrent() >= TUNING.YUKARI.TELEPORT_POWER_COST then
				table.insert(actions, ACTIONS.YTELE)
			end
		else
			table.insert(actions, ACTIONS.SPAWNG)
		end
	end
end

return MakeGate