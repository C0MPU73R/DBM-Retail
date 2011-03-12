local mod	= DBM:NewMod("DarkIronGolemCouncil", "DBM-BlackwingDescent", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision$"):sub(12, -3))
mod:SetCreatureID(42180, 42178, 42179, 42166)
mod:SetZone()
mod:SetUsedIcons(1, 3, 6, 7)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REMOVED",
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_INTERRUPT"
)

--Magmatron
local warnIncineration			= mod:NewSpellAnnounce(79023, 2, nil, mod:IsHealer())
local warnBarrier				= mod:NewSpellAnnounce(79582, 4, nil, not mod:IsHealer())
local warnAcquiringTarget		= mod:NewTargetAnnounce(92036, 4)
--Electron
local warnUnstableShield		= mod:NewSpellAnnounce(79900, 4, nil, not mod:IsHealer())
local warnShadowConductorCast	= mod:NewPreWarnAnnounce(92048, 5, 4)--Heroic Ability
--Toxitron
local warnPoisonProtocol		= mod:NewSpellAnnounce(80053, 2)
local warnFixate				= mod:NewTargetAnnounce(80094, 3, nil, false)--Spammy, off by default. Raid leader can turn it on if they wanna yell at these people.
local warnChemicalBomb			= mod:NewTargetAnnounce(80157, 3)
local warnShell					= mod:NewSpellAnnounce(79835, 4, nil, not mod:IsHealer())
local warnGrip					= mod:NewCastAnnounce(91849, 4)--Heroic Ability
--Arcanotron
local warnGenerator				= mod:NewSpellAnnounce(79624, 3)
local warnConversion			= mod:NewSpellAnnounce(79729, 4, nil, not mod:IsHealer())
local warnOverchargedGenerator	= mod:NewSpellAnnounce(91857, 4)--Heroic Ability
--All
local warnActivated				= mod:NewTargetAnnounce(78740, 3)

--Magmatron
local specWarnBarrier			= mod:NewSpecialWarningSpell(79582, not mod:IsHealer())
local specWarnAcquiringTarget	= mod:NewSpecialWarningYou(92037)
local specWarnEncasingShadows	= mod:NewSpecialWarningTarget(92023, false)--Heroic Ability
--Electron
local specWarnUnstableShield	= mod:NewSpecialWarningSpell(79900, not mod:IsHealer())
local specWarnConductor			= mod:NewSpecialWarningYou(79888)
local specWarnShadowConductor	= mod:NewSpecialWarningTarget(92053)--Heroic Ability
--Toxitron
local specWarnShell				= mod:NewSpecialWarningSpell(79835, not mod:IsHealer())
local specWarnBombTarget		= mod:NewSpecialWarningRun(80094)
local specWarnPoisonProtocol	= mod:NewSpecialWarningSpell(80053, not mod:IsHealer())
local specWarnChemicalCloud		= mod:NewSpecialWarningMove(91473)
local specWarnGrip				= mod:NewSpecialWarningSpell(91849)--Heroic Ability
--Arcanotron
local specWarnConversion		= mod:NewSpecialWarningSpell(79729, not mod:IsHealer())
local specWarnGenerator			= mod:NewSpecialWarning("specWarnGenerator", mod:IsTank())
local specWarnAnnihilator		= mod:NewSpecialWarningInterrupt(91542, false)
local specWarnOvercharged		= mod:NewSpecialWarningSpell(91857, false)--Heroic Ability
--All
local specWarnActivated			= mod:NewSpecialWarning("SpecWarnActivated", not mod:IsHealer())--Good for target switches, but healers probably don't want an extra special warning for it.

--Magmatron
local timerAcquiringTarget		= mod:NewNextTimer(40, 79501)
local timerBarrier				= mod:NewBuffActiveTimer(11.5, 79582, nil, false)	-- 10 + 1.5 cast time
local timerIncinerationCD   	= mod:NewNextTimer(26.5, 79023, nil, mod:IsHealer())--Timer Series, 10, 27, 32 (on normal) from activate til shutdown.
--Electron
local timerLightningConductor	= mod:NewTargetTimer(10, 79888, nil, false)
local timerLightningConductorCD	= mod:NewNextTimer(25, 79888)
local timerUnstableShield		= mod:NewBuffActiveTimer(11.5, 79900, nil, false)	-- 10 + 1.5 cast time
local timerShadowConductor		= mod:NewTargetTimer(10, 92053, nil, false)			--Heroic Ability
local timerShadowConductorCast	= mod:NewTimer(5, "timerShadowConductorCast", 92048)--Heroic Ability
--Toxitron
local timerChemicalBomb			= mod:NewCDTimer(30, 80157)							--Timer Series, 11, 30, 36 (on normal) from activate til shutdown.
local timerShell				= mod:NewBuffActiveTimer(11.5, 79835, nil, false)	-- 10 + 1.5 cast time
local timerPoisonProtocolCD		= mod:NewNextTimer(45, 80053)
--Arcanotron
local timerGeneratorCD			= mod:NewNextTimer(30, 79624)
local timerConversion			= mod:NewBuffActiveTimer(11.5, 79729, nil, false)		--10 + 1.5 cast time
local timerArcaneLockout		= mod:NewTimer(3, "timerArcaneLockout", 91542, false)	--How long arcanotron is locked out from casting another Arcane Annihilator
local timerArcaneBlowback		= mod:NewTimer(8, "timerArcaneBlowbackCast", 91879)		--what happens after the overcharged power generator explodes. 8 seconds after overcharge cast.
--All
local timerNextActivate			= mod:NewNextTimer(45, 78740)				--Activations are every 90 (60sec heroic) seconds but encounter staggers them in an alternating fassion so 45 (30 heroic) seconds between add switches
local timerNefAbilityCD			= mod:NewTimer(30, "timerNefAblity", 92048)--Huge variation on this, but shortest CD i've observed is 30.

local berserkTimer				= mod:NewBerserkTimer(600)

local soundBomb					= mod:NewSound(80094)

mod:AddBoolOption("AcquiringTargetIcon")
mod:AddBoolOption("ConductorIcon")
mod:AddBoolOption("ShadowConductorIcon")
mod:AddBoolOption("YellOnChemBomb", not mod:IsTank(), "announce")--Subject to accuracy flaws so off by for tanks(if you aren't a tank then it probably sin't wrong so it's on for everyone else.)
mod:AddBoolOption("YellBombTarget", false, "announce")
mod:AddBoolOption("YellOnLightning", true, "announce")
mod:AddBoolOption("YellOnShadowCast", true, "announce")
mod:AddBoolOption("YellOnTarget", true, "announce")
mod:AddBoolOption("YellOnTargetLock", true, "announce")

local pulled = false
local cloudSpam = 0
local lastInterrupt = 0
local encasing = false
--[[local bosses = {
	[42178] = "Magmatron",
	[42179] = "Electron",
	[42180] = "Toxitron",
	[42166] = "Arcanotron"
}--]]

function mod:ChemicalBombTarget()
	local targetname = self:GetBossTarget(42180)
	if not targetname then return end
	warnChemicalBomb:Show(targetname)
	if targetname == UnitName("player") then
		if self.Options.YellOnChemBomb then
			SendChatMessage(L.YellCloud, "SAY")
		end
	end
end

local bossActivate = function(boss)
	if boss == L.Magmatron or boss == 42178 then
		timerAcquiringTarget:Start(20)--These are same on heroic and normal
		timerIncinerationCD:Start(10)
	elseif boss == L.Electron or boss == 42179 then
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerLightningConductorCD:Start(15)--Probably also has a variation if it's like normal. Needs more logs to verify.
		else
			timerLightningConductorCD:Start(11)--11-15 variation confirmed for normal, only boss ability with an actual variation on timer. Strange.
		end
	elseif boss == L.Toxitron or boss == 42180 then
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerChemicalBomb:Start(25)
			timerPoisonProtocolCD:Start(15)
		else
			timerChemicalBomb:Start(11)
			timerPoisonProtocolCD:Start(21)
		end
	elseif boss == L.Arcanotron or boss == 42166 then
		timerGeneratorCD:Start(15)--These appear same on heroic and non heroic but will leave like this for now to await 25 man heroic confirmation.
	end
end

local bossInactive = function(boss)
	if boss == L.Magmatron then
		timerAcquiringTarget:Cancel()
		timerIncinerationCD:Cancel()
	elseif boss == L.Electron then
		timerLightningConductorCD:Cancel()
	elseif boss == L.Toxitron then
		timerChemicalBomb:Cancel()
		timerPoisonProtocolCD:Cancel()
	elseif boss == L.Arcanotron then
		timerGeneratorCD:Cancel()
	end
end

function mod:CheckEncasing() -- prevent two yells at a time
	if encasing and self.Options.YellOnTargetLock then
		SendChatMessage(L.YellTargetLock, "SAY")
	elseif not encasing and self.Options.YellOnTarget then
		SendChatMessage(L.YellTarget, "SAY")
	end
	encasing = false
end

function mod:OnCombatStart(delay)
	cloudSpam = 0
	lastInterrupt = 0
	encasing = false
	if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
		berserkTimer:Start(-delay)
	end
	DBM.BossHealth:Clear()
	DBM.BossHealth:AddBoss(42180, 42178, 42179, 42166, L.name)
end

function mod:OnCombatEnd()
	pulled = false
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(78740, 95016, 95017, 95018) then
		warnActivated:Show(args.destName)
		bossActivate(args.destName)
		if pulled then -- prevent show warning when first pulled.
			specWarnActivated:Show(args.destName)
		end
		if not pulled then
			pulled = true
		end
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerNextActivate:Start(30)
		else
			timerNextActivate:Start()
		end
	elseif args:IsSpellID(78726) then
		bossInactive(args.destName)
	elseif args:IsSpellID(79501, 92035, 92036, 92037) then
		warnAcquiringTarget:Show(args.destName)
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerAcquiringTarget:Start(27)
		else
			timerAcquiringTarget:Start()
		end
		if args:IsPlayer() then
			specWarnAcquiringTarget:Show()
			self:ScheduleMethod(1, "CheckEncasing")
		end
		if self.Options.AcquiringTargetIcon then
			self:SetIcon(args.destName, 7, 6)
		end
	elseif args:IsSpellID(79888, 91431, 91432, 91433) then
		if args:IsPlayer() then
			specWarnConductor:Show()
			if self.Options.YellOnLightning then
				SendChatMessage(L.YellLightning, "SAY")
			end
		end
		if self.Options.ConductorIcon then
			self:SetIcon(args.destName, 1)
		end
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerLightningConductor:Start(15, args.destName)
			timerLightningConductorCD:Start(20)
		else
			timerLightningConductor:Start(args.destName)
			timerLightningConductorCD:Start()
		end
	elseif args:IsSpellID(80094) then
		warnFixate:Show(args.destName)
		if args:IsPlayer() then
			specWarnBombTarget:Show()
			soundBomb:Play()
			if self.Options.YellBombTarget then
				SendChatMessage(L.SayBomb, "SAY")
			end
		end
	elseif args:IsSpellID(91472, 91473) and args:IsPlayer() and GetTime() - cloudSpam > 4 then
		specWarnChemicalCloud:Show()
		cloudSpam = GetTime()
	elseif args:IsSpellID(79629, 91555, 91556, 91557) and args:IsDestTypeHostile() then--Check if Generator buff is gained by a hostile.
--[[		local targetCID = GetUnitCreatureID("target")
		if args:GetDestCreatureID() == targetCID and bosses[targetCID] then --]]
		if (args:GetDestCreatureID() == 42166 and self:GetUnitCreatureId("target") == 42166) or (args:GetDestCreatureID() == 42178 and self:GetUnitCreatureId("target") == 42178) or (args:GetDestCreatureID() == 42179 and self:GetUnitCreatureId("target") == 42179) or (args:GetDestCreatureID() == 42180 and self:GetUnitCreatureId("target") == 42180) then--Filter it to only warn for 4 golems and only warn person tanking it. (other tank would be targeting a different golem)
			specWarnGenerator:Show(args.destName)--Show special warning to move him out of it.
		end
	elseif args:IsSpellID(92048) then--Shadow Infusion, debuff 5 seconds before shadow conductor.
		timerNefAbilityCD:Start()
		warnShadowConductorCast:Show()
		timerShadowConductorCast:Start()
	elseif args:IsSpellID(92023) then
		if args:IsPlayer() then
			encasing = true
		end
		if self.Options.AcquiringTargetIcon then
			self:SetIcon(args.destName, 6, 6)
		end
		specWarnEncasingShadows:Show(args.destName)
		timerNefAbilityCD:Start()
	elseif args:IsSpellID(92053) then
		specWarnShadowConductor:Show(args.destName)
		timerShadowConductor:Show(args.destName)
		timerLightningConductor:Cancel()
		if self.Options.ShadowConductorIcon then
			self:SetIcon(args.destName, 3)
		end
		if args:IsPlayer() and self.Options.YellOnShadowCast then
			SendChatMessage(L.YellShadowCast, "SAY")
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(79888, 91431, 91432, 91433) then
		if self.Options.ConductorIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(92053) then
		timerShadowConductor:Cancel(args.destName)
		if self.Options.ShadowConductorIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(79023, 91519, 91520, 91521) then
		warnIncineration:Show()
		timerIncinerationCD:Start()--appears same on heroic
	elseif args:IsSpellID(79582, 91516, 91517, 91518) then
		warnBarrier:Show()
		timerBarrier:Start()
		if self:GetUnitCreatureId("target") == 42178 then
			specWarnBarrier:Show()
		end
	elseif args:IsSpellID(79900, 91447, 91448, 91449) then
		warnUnstableShield:Show()
		timerUnstableShield:Start()
		if self:GetUnitCreatureId("target") == 42179 then
			specWarnUnstableShield:Show()
		end
	elseif args:IsSpellID(79835, 91501, 91502, 91503) then
		warnShell:Show()
		timerShell:Start()
		if self:GetUnitCreatureId("target") == 42180 then
			specWarnShell:Show()
		end
	elseif args:IsSpellID(79729, 91543, 91544, 91545) then
		warnConversion:Show()
		timerConversion:Start()
		if self:GetUnitCreatureId("target") == 42166 then
			specWarnConversion:Show()
		end
	elseif args:IsSpellID(91849) then--Grip
		warnGrip:Show()
		specWarnGrip:Show()
		timerNefAbilityCD:Start()
		cloudSpam = GetTime()
	elseif args:IsSpellID(79710, 91540, 91541, 91542) then
		specWarnAnnihilator:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(80157) then
		timerChemicalBomb:Start()--Appears same on heroic
		self:ScheduleMethod(0.1, "ChemicalBombTarget")--Since this is an instance cast scanning accurately is very hard.
	elseif args:IsSpellID(80053, 91513, 91514, 91515) then
		warnPoisonProtocol:Show()
		if not self:GetUnitCreatureId("target") == 42180 then--You're not targeting toxitron which means he's probably off in some corner somewhere out of sight out of mind.
			specWarnPoisonProtocol:Show()--MFers need to learn to switch so we give them a special warning to remember toxitron is still up.
		end
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerPoisonProtocolCD:Start(25)
		else
			timerPoisonProtocolCD:Start()
		end
	elseif args:IsSpellID(79624) then
		warnGenerator:Show()
		if mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25") then
			timerGeneratorCD:Start(20)
		else
			timerGeneratorCD:Start()
		end
	elseif args:IsSpellID(91857) then
		warnOverchargedGenerator:Show()
		specWarnOvercharged:Show()
		timerArcaneBlowback:Start()
		timerNefAbilityCD:Start()
	end
end

function mod:SPELL_INTERRUPT(args)--Pretty sure druids still don't show in log so if a druid kicks it won't be accurate.
	if (type(args.extraSpellId) == "number" and (args.extraSpellId == 79710 or args.extraSpellId == 91540 or args.extraSpellId == 91541 or args.extraSpellId == 91542)) and GetTime() - lastInterrupt > 2 then
		lastInterrupt = GetTime()--We only want the first interrupt, any extra won't count til next cast
		if args:IsSpellID(2139) then							--Counterspell
			timerArcaneLockout:Start(7.5)
		elseif args:IsSpellID(96231, 6552, 47528, 1766) then	--Rebuke, Pummel, Mind Freeze, Kick
			timerArcaneLockout:Start(5)
--[[		elseif args:IsSpellID(34490, 15487) then			--Silencing Shot, Silence
			timerArcaneLockout:Start(3.5)--]]
		elseif args:IsSpellID(57994) then						--Wind Shear
			timerArcaneLockout:Start(2.5)
		end
	end
end
