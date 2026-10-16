-- ServerScriptService.CenizaServidor.Zombis: aparición, IA, daño y muerte de zombis, especiales y mini jefes
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PFS = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local N = require(script.Parent.Nucleo)
local Config = N.Config
local Rigs = RS:WaitForChild("Ceniza"):WaitForChild("Personajes")

local Z = {}
Z.lista = {} -- modelo → datos
Z.carpeta = workspace:FindFirstChild("Zombis") or Instance.new("Folder")
Z.carpeta.Name = "Zombis"; Z.carpeta.Parent = workspace
Z.cadaveres = {} -- {pos, t}
Z.objetivoForzado = nil -- Vector3 (Cebo de Carne)

pcall(function() PhysicsService:RegisterCollisionGroup("Zombis") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Jugadores") end)
PhysicsService:CollisionGroupSetCollidable("Zombis", "Zombis", false)

function Z.vidaRonda(r)
	if r < 10 then return 150 + 100 * (r - 1) end
	return math.floor(950 * 1.1 ^ (r - 9))
end
function Z.vivos() local n = 0 for _ in Z.lista do n += 1 end return n end

local camino = { AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 5 }

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include
local function actualizarLos()
	losParams.FilterDescendantsInstances = { N.Mapa.Colision, N.Mapa.Puertas }
end
actualizarLos()
local function visible(a, b)
	return workspace:Raycast(a, b - a, losParams) == nil
end

-- punto de aparición: fuera de la vista de un jugador, con camino hasta él
function Z.puntoAparicion(cerca)
	local vivos = N.vivos()
	if #vivos == 0 and not cerca then return nil end
	for intento = 1, 14 do
		local base
		if cerca then base = cerca else
			local p = vivos[math.random(#vivos)]
			base = p.Character.HumanoidRootPart.Position
		end
		local a = math.random() * math.pi * 2
		local d = cerca and math.random(4, 14) or math.random(28, 60)
		local s = N.suelo(base + Vector3.new(math.cos(a) * d, 4, math.sin(a) * d), 8)
		if s and math.abs(s.Y - base.Y) < 7 then
			local cabeza = base + Vector3.new(0, 1.5, 0)
			local libre = #workspace:GetPartBoundsInBox(CFrame.new(s + Vector3.new(0, 3, 0)), Vector3.new(2, 4.5, 2), (function()
				local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = { N.Mapa.Colision }; return op end)()) == 0
			if libre and (cerca or intento > 9 or not visible(cabeza, s + Vector3.new(0, 2.5, 0))) then
				local path = PFS:CreatePath(camino)
				local ok = pcall(function() path:ComputeAsync(s + Vector3.new(0, 2, 0), base) end)
				if ok and (path.Status == Enum.PathStatus.Success or cerca) then return s end
			end
		end
	end
	return nil
end

local function prepararRig(nombre, escala)
	local m = Rigs[nombre]:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false; p.CollisionGroup = "Zombis"; p.CanTouch = false
			if p.Name == "HumanoidRootPart" then p.CanCollide = true; p.CanQuery = false
			else p.CanCollide = false; p.Massless = true end
		end
	end
	if escala and escala ~= 1 then m:ScaleTo(escala) end
	local h = m.Humanoid
	local an = h:FindFirstChildOfClass("Animator"); if an then an:Destroy() end
	h.BreakJointsOnDeath = false; h.RequiresNeck = false
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	return m
end

-- crea un zombi; tipo = "Comun" | nombre de especial | nombre de jefe
function Z.crear(tipo, pos, opc)
	opc = opc or {}
	local r = math.max(N.Ronda, 1)
	local rig, vida, puntos, escala = nil, Z.vidaRonda(r), 60, 1
	if tipo == "Comun" then rig = Config.Comunes[math.random(#Config.Comunes)]
	elseif Config.Especiales[tipo] then local e = Config.Especiales[tipo]; rig = e.Rig; vida *= e.Vida; puntos = e.Puntos
	elseif Config.Jefes[tipo] then local e = Config.Jefes[tipo]; rig = e.Rig; vida = Z.vidaRonda(math.max(r, 8)) * e.Vida * math.max(1, #Players:GetPlayers() * 0.75); puntos = e.Puntos; escala = e.Escala end
	local m = prepararRig(rig, escala)
	m.Name = tipo
	local h = m.Humanoid
	h.MaxHealth = vida; h.Health = vida
	local corredor = tipo ~= "Comun" or math.random() < math.clamp((r - 3) * 0.13, 0, 0.85)
	if N.misaNegra then corredor = true end
	local vel = corredor and (11 + math.min(r, 20) * 0.15) or (4 + math.min(r, 10) * 0.35)
	if Config.Jefes[tipo] then vel = 9 end
	if tipo == "Liniero" then vel = 14 end
	if opc.dorado then vel *= 0.9 end
	m:SetAttribute("Tipo", tipo)
	m:SetAttribute("VelBase", vel)
	m:SetAttribute("Estado", "Aparecer")
	m:SetAttribute("Anim", corredor and "Correr" or "Caminar")
	if opc.dorado then
		m:SetAttribute("Dorado", true)
		for _, p in m:GetDescendants() do if p:IsA("MeshPart") then p.Color = Color3.fromRGB(255, 205, 80); p.Material = Enum.Material.Foil end end
	end
	h.WalkSpeed = 0
	local hip = h.HipHeight + m.HumanoidRootPart.Size.Y / 2
	m:PivotTo(CFrame.new(pos + Vector3.new(0, hip, 0)) * CFrame.Angles(0, math.random() * 6.28, 0))
	m.Parent = Z.carpeta
	m.HumanoidRootPart:SetNetworkOwner(nil)
	local d = { modelo = m, hum = h, raiz = m.HumanoidRootPart, tipo = tipo, puntos = puntos, vel = vel, proxGolpe = 0, ultimaPos = pos, quieto = 0,
		path = nil, wp = nil, iwp = 0, proxCamino = 0, calculando = false, nace = os.clock() }
	Z.lista[m] = d
	-- especiales
	if tipo == "Capataz" then Z.armarCapataz(d) end
	if tipo == "Centinela" then Z.armarCentinela(d) end
	if Config.Jefes[tipo] then
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(220, 40); bb.StudsOffset = Vector3.new(0, 5, 0); bb.AlwaysOnTop = true; bb.MaxDistance = 120
		local t = Instance.new("TextLabel", bb); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.TextColor3 = Color3.fromRGB(255, 120, 80)
		t.Font = Enum.Font.GothamBlack; t.TextScaled = true; t.Text = ({ Capataz = "EL CAPATAZ", Centinela = "CENTINELA S7", Revisor = "EL REVISOR" })[tipo]
		bb.Parent = m.Head
	end
	task.delay(opc.sinAparecer and 0 or 1.2, function()
		if Z.lista[m] then m:SetAttribute("Estado", "Mover"); h.WalkSpeed = d.vel end
	end)
	N.emitir("ZombiCreado", d)
	return d
end

-- ---------------------------------------------------------------- daño
-- causa: "bala" | "explosion" | "cuerpo" | "frio" | "fuego" | "remolino" | "rayo" | "instakill"
function Z.danar(m, dano, plr, parte, causa)
	local d = Z.lista[m]
	if not d or d.muerto then return false end
	local cabeza = parte and parte.Name == "Head"
	if cabeza and plr and plr:GetAttribute("Perk_OjoDeCuervo") then dano *= 1.15 end
	if cabeza then dano *= (causa == "bala" and 2 or 1) end
	if parte and parte:GetAttribute("Multiplicador") then dano *= parte:GetAttribute("Multiplicador") end
	if N.activo("GolpeLetal") and not Config.Jefes[d.tipo] then dano = math.huge end
	if causa == "frio" then Z.ralentizar(m, 0.5, 2) end
	if plr and causa ~= "explosion" then N.sumar(plr, 10, nil) end
	N.emitir("ZombiDanado", d, dano, plr, parte, causa)
	d.hum.Health = math.max(0, d.hum.Health - dano)
	if d.hum.Health <= 0 then
		Z.morir(m, plr, cabeza, causa)
		return true
	end
	return false
end

function Z.morir(m, plr, cabeza, causa)
	local d = Z.lista[m]
	if not d or d.muerto then return end
	d.muerto = true
	Z.lista[m] = nil
	local pos = d.raiz.Position
	if plr then
		local p = d.puntos
		if d.tipo == "Comun" then p = cabeza and 100 or (causa == "cuerpo" and 130 or 60) end
		if plr:GetAttribute("Perk_FiebreDeOro") then p = math.floor(p * 1.2) end
		N.sumar(plr, p, cabeza and "¡Disparo a la cabeza!" or nil)
		plr:SetAttribute("Bajas", (plr:GetAttribute("Bajas") or 0) + 1)
		if cabeza then plr:SetAttribute("Cabezas", (plr:GetAttribute("Cabezas") or 0) + 1) end
	end
	table.insert(Z.cadaveres, { pos = pos, t = os.clock() })
	if #Z.cadaveres > 30 then table.remove(Z.cadaveres, 1) end
	m:SetAttribute("Estado", "Morir")
	d.hum.WalkSpeed = 0
	d.raiz.Anchored = true
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.CanQuery = false; p.CanCollide = false end end
	N.emitir("ZombiMuerto", d, plr, pos, cabeza, causa)
	task.delay(2.2, function() m:Destroy() end)
end

function Z.matarTodos(plr, sinPuntos)
	for m, d in Z.lista do
		if not Config.Jefes[d.tipo] then Z.morir(m, (not sinPuntos) and plr or nil, false, "instakill") end
	end
end

function Z.ralentizar(m, factor, dur)
	local d = Z.lista[m]; if not d then return end
	d.lento = math.min(d.lento or 1, factor)
	d.finLento = os.clock() + dur
	m:SetAttribute("Lento", true)
end
function Z.congelar(m, dur)
	local d = Z.lista[m]; if not d then return end
	d.congeladoHasta = os.clock() + dur
	m:SetAttribute("Congelado", true)
	N.emitir("ZombiCongelado", d)
end

-- explosión en área
function Z.explosion(pos, radio, dano, plr, causa)
	local n = 0
	for m, d in Z.lista do
		local dist = (d.raiz.Position - pos).Magnitude
		if dist <= radio then
			local f = 1 - 0.5 * dist / radio
			if Z.danar(m, dano * f, plr, nil, causa or "explosion") then n += 1 end
		end
	end
	N.fx("Explosion", pos, radio)
	-- daño a jugadores (salvo Pólvora Viva del que dispara)
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c and c:FindFirstChild("HumanoidRootPart") and (c.HumanoidRootPart.Position - pos).Magnitude < radio * 0.6 then
			if not (p == plr and p:GetAttribute("Perk_PolvoraViva")) and causa ~= "sinJugadores" then
				N.emitir("DanarJugador", p, 25, nil)
			end
		end
	end
	if plr then N.emitir("Explosion", plr, n) end
	return n
end

-- ---------------------------------------------------------------- IA
local function objetivoDe(d)
	if Z.objetivoForzado then return nil, Z.objetivoForzado end
	local mejor, md = nil, math.huge
	for _, p in N.vivos() do
		if not p:GetAttribute("Invisible") then
			local dist = (p.Character.HumanoidRootPart.Position - d.raiz.Position).Magnitude
			if dist < md then md = dist; mejor = p end
		end
	end
	if mejor then return mejor, mejor.Character.HumanoidRootPart.Position end
	return nil, nil
end

local function calcular(d, destino)
	if d.calculando then return end
	d.calculando = true
	task.spawn(function()
		local path = PFS:CreatePath(camino)
		local ok = pcall(function() path:ComputeAsync(d.raiz.Position, destino) end)
		if ok and path.Status == Enum.PathStatus.Success then
			d.wp = path:GetWaypoints(); d.iwp = 2
		else
			d.wp = nil
		end
		d.calculando = false
	end)
end

local function paso(d, ahora)
	local m = d.modelo
	if m:GetAttribute("Estado") ~= "Mover" then return end
	if d.congeladoHasta and ahora < d.congeladoHasta then d.hum.WalkSpeed = 0; return
	elseif d.congeladoHasta then d.congeladoHasta = nil; m:SetAttribute("Congelado", false) end
	local f = 1
	if d.finLento and ahora < d.finLento then f = d.lento else if d.finLento then d.finLento = nil; d.lento = nil; m:SetAttribute("Lento", false) end end
	if N.activo("ArenaNegra") then f *= 0.5 end
	if N.activo("Estampida") then f *= 1.3 end
	if N.misaNegra then f *= 1.2 end
	if d.flotarHasta and ahora < d.flotarHasta then f = 0 end
	d.hum.WalkSpeed = d.vel * f
	local plr, pos = objetivoDe(d)
	if not pos then d.hum:MoveTo(d.raiz.Position); return end
	local raiz = d.raiz.Position
	local dist = (pos - raiz).Magnitude
	-- ataque
	if plr and dist < 4 + (Config.Jefes[d.tipo] and 2 or 0) and ahora >= d.proxGolpe then
		d.proxGolpe = ahora + (Config.Jefes[d.tipo] and 1.6 or 1.1)
		m:SetAttribute("Golpe", ahora)
		task.delay(0.35, function()
			if Z.lista[m] and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and (plr.Character.HumanoidRootPart.Position - d.raiz.Position).Magnitude < 5.5 then
				N.emitir("DanarJugador", plr, Config.Jefes[d.tipo] and 70 or 50, d)
			end
		end)
	end
	-- movimiento
	if math.abs(pos.Y - raiz.Y) < 4 and dist < 60 and visible(raiz + Vector3.new(0, 1, 0), pos + Vector3.new(0, 1, 0)) then
		d.wp = nil
		d.hum:MoveTo(pos)
	else
		if not d.wp or ahora >= d.proxCamino then
			d.proxCamino = ahora + 1.5
			calcular(d, pos)
		end
		if d.wp and d.wp[d.iwp] then
			local w = d.wp[d.iwp]
			if w.Action == Enum.PathWaypointAction.Jump then d.hum.Jump = true end
			d.hum:MoveTo(w.Position)
			local plano = Vector3.new(w.Position.X - raiz.X, 0, w.Position.Z - raiz.Z).Magnitude
			if plano < 2.5 then d.iwp += 1 end
		else
			d.hum:MoveTo(pos)
		end
	end
	-- atascado → reaparece cerca de los jugadores
	if (raiz - d.ultimaPos).Magnitude > 1.5 then d.ultimaPos = raiz; d.quieto = ahora
	elseif ahora - d.quieto > 7 and dist > 12 and not Config.Jefes[d.tipo] then
		local s = Z.puntoAparicion()
		if s then
			d.modelo:PivotTo(CFrame.new(s + Vector3.new(0, d.hum.HipHeight + 1, 0)))
			d.ultimaPos = s; d.quieto = ahora; d.wp = nil
		end
	end
end

-- habilidades de especiales y jefes
local function habilidades(d, ahora)
	local m = d.modelo
	if m:GetAttribute("Estado") ~= "Mover" then return end
	if d.tipo == "Liniero" and ahora >= (d.proxRayo or 0) then
		d.proxRayo = ahora + 4
		for _, p in N.vivos() do
			local pr = p.Character.HumanoidRootPart.Position
			if (pr - d.raiz.Position).Magnitude < 26 and visible(d.raiz.Position + Vector3.new(0, 2, 0), pr) then
				N.fx("Rayo", m.Head.Position, pr)
				N.emitir("DanarJugador", p, 25, d)
				break
			end
		end
	elseif d.tipo == "Camillero" and ahora >= (d.proxReanimar or d.nace + 8) then
		d.proxReanimar = ahora + 12
		local c
		for i = #Z.cadaveres, 1, -1 do
			local k = Z.cadaveres[i]
			if ahora - k.t < 40 and (k.pos - d.raiz.Position).Magnitude < 35 and not k.quemado then c = k; table.remove(Z.cadaveres, i); break end
		end
		if c then
			m:SetAttribute("Reanimando", true)
			N.fx("Reanimar", c.pos)
			task.delay(2, function()
				if Z.lista[m] then m:SetAttribute("Reanimando", false); Z.crear("Comun", c.pos) end
			end)
		end
	elseif d.tipo == "Revisor" and ahora >= (d.proxSalto or d.nace + 6) then
		d.proxSalto = ahora + 8
		if not (d.congeladoHasta or d.finLento) then
			local s = Z.puntoAparicion()
			if s then N.fx("Humo", d.raiz.Position); d.modelo:PivotTo(CFrame.new(s + Vector3.new(0, d.hum.HipHeight + 1.5, 0))); N.fx("Humo", s) end
		end
	end
end

function Z.armarCapataz(d)
	local m = d.modelo
	local sims = N.mision and N.mision.hoja or Config.Simbolos
	for i = 1, 3 do
		local c = N.parte({ Name = "Cristal", Size = Vector3.new(0.7, 1.4, 0.7), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Anchored = false, CanCollide = false, Massless = true })
		c:SetAttribute("Simbolo", Config.Simbolos[i])
		c:SetAttribute("Vida", 600)
		c.CFrame = m.UpperTorso.CFrame * CFrame.new((i - 2) * 0.8, 0.5, 0.7) * CFrame.Angles(math.rad(20), 0, 0)
		local w = Instance.new("WeldConstraint"); w.Part0 = m.UpperTorso; w.Part1 = c; w.Parent = c
		if N.mision and N.mision.hojaImpresa then
			local g = Instance.new("BillboardGui"); g.Size = UDim2.fromOffset(60, 24); g.StudsOffset = Vector3.new(0, 1.2, 0); g.AlwaysOnTop = true
			local t = Instance.new("TextLabel", g); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = Config.Simbolos[i]; t.TextColor3 = Color3.new(1, 1, 1); t.TextScaled = true; t.Font = Enum.Font.GothamBold
			g.Parent = c
		end
		c.Parent = m
	end
	d.cristalesRotos = {}
end

function Z.armarCentinela(d)
	local m = d.modelo
	local c = N.parte({ Name = "Celda", Size = Vector3.new(1.4, 1.6, 0.6), Color = Color3.fromRGB(80, 200, 255), Material = Enum.Material.Neon, Anchored = false, CanCollide = false, Massless = true })
	c.CFrame = m.UpperTorso.CFrame * CFrame.new(0, 0.2, 0.9)
	c:SetAttribute("Multiplicador", 3)
	local w = Instance.new("WeldConstraint"); w.Part0 = m.UpperTorso; w.Part1 = c; w.Parent = c
	c.Parent = m
end

task.spawn(function()
	while true do
		local ahora = os.clock()
		actualizarLos()
		for m, d in Z.lista do
			if not m.Parent or d.hum.Health <= 0 and not d.muerto then
				if m.Parent and not d.muerto then Z.morir(m, nil, false, "instakill") else Z.lista[m] = nil end
			else
				local ok, e = pcall(paso, d, ahora)
				if not ok then warn("IA zombi: " .. tostring(e)) end
				pcall(habilidades, d, ahora)
			end
		end
		task.wait(0.15)
	end
end)

return Z
