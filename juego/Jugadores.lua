-- ServerScriptService.CenizaServidor.Jugadores: personajes (sobrevivientes del visor), vida, caídas y reanimación
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")
local N = require(script.Parent.Nucleo)
local Config = N.Config
local Rigs = RS:WaitForChild("Ceniza"):WaitForChild("Personajes")

local J = {}
J.ultimoGolpe = {}
local asignados = {}

local function sobrevivienteDe(plr)
	if asignados[plr] then return asignados[plr] end
	local usados = {}
	for _, v in asignados do usados[v] = true end
	for _, n in Config.Sobrevivientes do if not usados[n] then asignados[plr] = n; return n end end
	asignados[plr] = Config.Sobrevivientes[math.random(#Config.Sobrevivientes)]
	return asignados[plr]
end

function J.vidaMax(plr)
	return plr:GetAttribute("Perk_FerroTonica") and 250 or 100
end

function J.aparecer(plr, cf)
	local nombre = sobrevivienteDe(plr)
	local m = Rigs[nombre]:Clone()
	m.Name = plr.Name
	m:SetAttribute("Sobreviviente", nombre)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false; p.CollisionGroup = "Jugadores"
			if p.Name == "HumanoidRootPart" then p.CanCollide = true else p.CanCollide = false; p.Massless = true end
		end
	end
	-- punto de agarre para las armas
	local mano = m.RightHand
	local at = Instance.new("Attachment"); at.Name = "RightGripAttachment"; at.Position = Vector3.new(0, -mano.Size.Y * 0.3, 0); at.Parent = mano
	local at2 = Instance.new("Attachment"); at2.Name = "LeftGripAttachment"; at2.Position = Vector3.new(0, -m.LeftHand.Size.Y * 0.3, 0); at2.Parent = m.LeftHand
	local h = m.Humanoid
	h.BreakJointsOnDeath = false
	h.MaxHealth = J.vidaMax(plr); h.Health = h.MaxHealth
	h.WalkSpeed = 16 * (plr:GetAttribute("Perk_ZancadaLunar") and 1.12 or 1)
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	for _, s in SP.StarterCharacterScripts:GetChildren() do s:Clone().Parent = m end
	if not cf then
		local sp = N.Mapa.Spawns:GetChildren()
		cf = CFrame.new(sp[math.random(#sp)].Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
	end
	m:PivotTo(cf)
	plr:SetAttribute("Caido", false)
	plr:SetAttribute("Muerto", false)
	plr.Character = m
	m.Parent = workspace
	N.emitir("Aparecio", plr, m)
	return m
end

-- daño a un jugador (los zombis no matan: tumban)
function J.danar(plr, dano, fuente)
	local c = plr.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or plr:GetAttribute("Caido") or plr:GetAttribute("Invulnerable") then return end
	J.ultimoGolpe[plr] = os.clock()
	N.emitir("JugadorGolpeado", plr, dano, fuente)
	if h.Health - dano <= 0 then
		J.caer(plr)
	else
		h.Health -= dano
		N.Evento:FireClient(plr, "Golpe", dano)
	end
end
N.on("DanarJugador", J.danar)

function J.caer(plr)
	local c = plr.Character
	if not c then return end
	local h = c.Humanoid
	h.Health = 1
	plr:SetAttribute("Caido", true)
	h.WalkSpeed = 3; h.JumpPower = 0
	N.aviso(nil, plr.Name .. " cayó", Color3.fromRGB(255, 80, 60))
	N.emitir("JugadorCaido", plr)
	-- perks: se pierden (Segundo Latido mejorado conserva uno)
	local conservar
	if plr:GetAttribute("Sobre_SegundoLatido") then
		local tiene = {}
		for k in Config.Perks do if plr:GetAttribute("Perk_" .. k) then table.insert(tiene, k) end end
		if #tiene > 0 then conservar = tiene[math.random(#tiene)] end
	end
	local soloYConLatido = #Players:GetPlayers() == 1 and plr:GetAttribute("Perk_SegundoLatido") and (plr:GetAttribute("AutoReanimaciones") or 0) > 0
	N.emitir("QuitarPerks", plr, conservar)
	-- panel de reanimación
	local raiz = c.HumanoidRootPart
	local tiempo = 30
	local pp
	pp = N.prompt(raiz, "Reanimar", plr.Name, 4, function(quien)
		if quien == plr then return end
		J.levantar(plr, quien)
	end, 7)
	pp.Name = "Reanimar"
	task.spawn(function()
		if soloYConLatido then
			plr:SetAttribute("AutoReanimaciones", plr:GetAttribute("AutoReanimaciones") - 1)
			task.wait(3)
			if plr:GetAttribute("Caido") then J.levantar(plr, plr) end
			return
		end
		while plr.Parent and plr:GetAttribute("Caido") and tiempo > 0 do
			task.wait(1); tiempo -= 1
			plr:SetAttribute("TiempoCaido", tiempo)
			-- quien tenga Segundo Latido reanima el doble de rápido
			for _, o in Players:GetPlayers() do
				if o ~= plr and o:GetAttribute("Perk_SegundoLatido") then pp.HoldDuration = 2 end
			end
		end
		if plr.Parent and plr:GetAttribute("Caido") then J.morir(plr) end
	end)
	if #N.vivos() == 0 and not soloYConLatido then N.emitir("TodosCaidos") end
end

function J.levantar(plr, quien)
	local c = plr.Character
	if not c or not plr:GetAttribute("Caido") then return end
	local pp = c.HumanoidRootPart:FindFirstChild("Reanimar"); if pp then pp:Destroy() end
	plr:SetAttribute("Caido", false)
	local h = c.Humanoid
	h.MaxHealth = J.vidaMax(plr); h.Health = h.MaxHealth
	h.WalkSpeed = 16 * (plr:GetAttribute("Perk_ZancadaLunar") and 1.12 or 1); h.JumpPower = 50
	N.aviso(nil, plr.Name .. " volvió a la pelea", Color3.fromRGB(120, 255, 140))
	if quien and quien ~= plr then
		N.sumar(quien, 100, "Reanimación")
		N.emitir("Reanimo", quien, plr)
	end
end

function J.morir(plr)
	local c = plr.Character
	plr:SetAttribute("Caido", false)
	plr:SetAttribute("Muerto", true)
	if c then c:Destroy() end
	N.aviso(nil, plr.Name .. " murió; vuelve en la próxima ronda", Color3.fromRGB(255, 60, 60))
	N.emitir("JugadorMuerto", plr)
	if #N.vivos() == 0 then N.emitir("TodosCaidos") end
end

-- regeneración (3 s sin golpes)
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if h and not p:GetAttribute("Caido") and os.clock() - (J.ultimoGolpe[p] or 0) > 3 and h.Health < h.MaxHealth then
				h.Health = math.min(h.MaxHealth, h.Health + h.MaxHealth * 0.1)
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(plr)
	plr:SetAttribute("Puntos", 500)
	plr:SetAttribute("Bajas", 0)
	plr:SetAttribute("AutoReanimaciones", 0)
	task.wait(1)
	J.aparecer(plr)
end)
for _, plr in Players:GetPlayers() do
	task.spawn(function()
		if plr.Character then return end
		plr:SetAttribute("Puntos", plr:GetAttribute("Puntos") or 500)
		J.aparecer(plr)
	end)
end
Players.PlayerRemoving:Connect(function(plr) asignados[plr] = nil end)

return J
