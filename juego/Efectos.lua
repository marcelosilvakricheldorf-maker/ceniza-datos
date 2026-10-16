-- ServerScriptService.CenizaServidor.Efectos: power-ups (DropManager + efectos), efectos de perks, Sobrecargas y sus retos, objetos interactivos del mapa
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TS = game:GetService("TweenService")
local N = require(script.Parent.Nucleo)
local Z = require(script.Parent.Zombis)
local A = require(script.Parent.ArmasServidor)
local J = require(script.Parent.Jugadores)
local M = require(script.Parent.Mapa)
local Config = N.Config
local Modelos = RS:WaitForChild("Ceniza"):WaitForChild("PowerUps")

local E = {}
local carpeta = Instance.new("Folder"); carpeta.Name = "PowerUps"; carpeta.Parent = workspace

-- ------------------------------------------------------------ DropManager (Biblia de diseño)
local MAX_POR_RONDA, PROB_BASE, PROB_MALDITO = 4, 0.03, 0.05
local dropsRonda, bolsa = 0, {}
local function rellenar(r)
	bolsa = { "Abastecimiento", "GolpeLetal", "BotinDoble", "Despertador", "Albanil", "Bobina", "ArenaNegra", "CeboDeCarne", "Sabana" }
	if r >= 5 then table.insert(bolsa, "MercadoNegro"); table.insert(bolsa, "TorretaDeBolsillo") end
	for i = #bolsa, 2, -1 do local j = math.random(1, i); bolsa[i], bolsa[j] = bolsa[j], bolsa[i] end
end
N.on("NuevaRonda", function(r) dropsRonda = 0; rellenar(r) end)
local function sortear(r, seguro)
	if not seguro then
		if dropsRonda >= MAX_POR_RONDA or math.random() > PROB_BASE then return nil end
	end
	dropsRonda += 1
	if r >= 15 and math.random() < PROB_MALDITO then return math.random() < 0.5 and "Apagon" or "Estampida" end
	if #bolsa == 0 then rellenar(r) end
	return table.remove(bolsa)
end

-- ------------------------------------------------------------ power-ups en el mapa
function E.soltar(nombre, pos)
	local def = Config.PowerUps[nombre]; if not def then return end
	local src = Modelos:FindFirstChild(nombre)
	local m = src and src:Clone() or Instance.new("Model")
	m.Name = nombre
	local color = Config.Familias[def.Familia]
	local halo = N.parte({ Name = "Halo", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Color = color, Material = Enum.Material.Neon, Transparency = 0.8, CanCollide = false, CanQuery = false, CastShadow = false })
	local luz = Instance.new("PointLight"); luz.Color = color; luz.Range = 10; luz.Brightness = 1.5; luz.Parent = halo
	halo.Parent = m
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false; p.CanQuery = false end end
	local suelo = N.suelo(pos, 4) or pos
	local centro = suelo + Vector3.new(0, 3, 0)
	local raiz = m.PrimaryPart
	local _, tam = m:GetBoundingBox()
	local cfModelo = m:GetPivot()
	halo.CFrame = cfModelo
	m:SetAttribute("Centro", centro)
	m.Parent = carpeta
	local nace = os.clock()
	task.spawn(function()
		local tomado = false
		while m.Parent and os.clock() - nace < 25 and not tomado do
			local t = os.clock() - nace
			m:PivotTo(CFrame.new(centro + Vector3.new(0, math.sin(t * 2) * 0.5, 0)) * CFrame.Angles(0, math.rad(90) * t, 0))
			if t > 20 then
				local vis = math.floor(t * 6) % 2 == 0
				for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.LocalTransparencyModifier = vis and 0 or 1 end end
			end
			for _, plr in N.vivos() do
				if (plr.Character.HumanoidRootPart.Position - centro).Magnitude < 4.5 then tomado = plr; break end
			end
			task.wait(0.05)
		end
		m:Destroy()
		if tomado then E.aplicar(nombre, tomado, centro) end
	end)
end

function E.aplicar(nombre, plr, pos)
	local def = Config.PowerUps[nombre]
	N.Evento:FireAllClients("PowerUp", nombre, def.Duracion, Config.Familias[def.Familia])
	N.aviso(nil, def.Nombre .. "!", Config.Familias[def.Familia])
	if def.Duracion > 0 then N.Activos[nombre] = os.clock() + def.Duracion end
	if nombre == "Abastecimiento" then
		for _, p in Players:GetPlayers() do A.municionMaxima(p) end
	elseif nombre == "Despertador" then
		Z.matarTodos(nil, true)
		for _, p in Players:GetPlayers() do N.sumar(p, 400, "Despertador") end
	elseif nombre == "Albanil" then
		for _, p in Players:GetPlayers() do N.sumar(p, 200, "Albañil") end
	elseif nombre == "CeboDeCarne" then
		Z.objetivoForzado = pos
		N.fx("Cebo", pos, 10)
		task.delay(10, function()
			Z.objetivoForzado = nil
			Z.explosion(pos, 16, math.huge, plr, "sinJugadores")
		end)
	elseif nombre == "Sabana" then
		plr:SetAttribute("Invisible", true)
		task.delay(10, function() plr:SetAttribute("Invisible", nil) end)
	elseif nombre == "MercadoNegro" then
		M.mercadoNegro(30)
	elseif nombre == "TragoSorpresa" then
		local libres = {}
		for k in Config.Perks do if not plr:GetAttribute("Perk_" .. k) then table.insert(libres, k) end end
		if #libres > 0 then M.aplicarPerk(plr, libres[math.random(#libres)]) end
	elseif nombre == "TorretaDeBolsillo" then
		E.torreta(pos, plr)
	elseif nombre == "Apagon" then
		local b, a = Lighting.Brightness, Lighting.OutdoorAmbient
		Lighting.Brightness = 0; Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
		workspace:SetAttribute("Apagon", true)
		task.delay(20, function() Lighting.Brightness = b; Lighting.OutdoorAmbient = a; workspace:SetAttribute("Apagon", nil) end)
	end
end

function E.torreta(pos, plr)
	local s = N.suelo(pos, 4) or pos
	local m = Instance.new("Model"); m.Name = "Torreta"
	local pata = N.parte({ Name = "Tripode", Size = Vector3.new(1.6, 2, 1.6), Color = Color3.fromRGB(50, 55, 45), Material = Enum.Material.Metal, CanCollide = false })
	pata.CFrame = CFrame.new(s + Vector3.new(0, 1, 0)); pata.Parent = m
	local cabeza = N.parte({ Name = "Cabeza", Size = Vector3.new(1.4, 1, 2.2), Color = Color3.fromRGB(70, 80, 60), Material = Enum.Material.Metal, CanCollide = false })
	cabeza.CFrame = CFrame.new(s + Vector3.new(0, 2.5, 0)); cabeza.Parent = m
	local ojo = N.parte({ Name = "Ojo", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = Color3.fromRGB(255, 30, 20), Material = Enum.Material.Neon, CanCollide = false })
	ojo.Parent = m
	m.Parent = workspace
	task.spawn(function()
		local fin = os.clock() + 20
		while os.clock() < fin do
			local mejor, md
			for zm, d in Z.lista do
				local dist = (d.raiz.Position - cabeza.Position).Magnitude
				if dist < 50 and (not md or dist < md) then md = dist; mejor = zm end
			end
			if mejor then
				local d = Z.lista[mejor]
				cabeza.CFrame = CFrame.lookAt(cabeza.Position, d.raiz.Position)
				ojo.CFrame = cabeza.CFrame * CFrame.new(0, 0.2, -1.1)
				N.fx("Disparo", nil, cabeza.Position, { d.raiz.Position + Vector3.new(0, 1, 0) }, "bala", "torreta")
				Z.danar(mejor, 60 + N.Ronda * 12, plr, mejor:FindFirstChild("UpperTorso"), "bala")
			end
			task.wait(0.15)
		end
		m:Destroy()
	end)
end

-- ------------------------------------------------------------ al morir un zombi: drops, perks y retos
N.on("ZombiMuerto", function(d, plr, pos, cabeza, causa)
	if d.modelo:GetAttribute("Dorado") then
		local n = sortear(N.Ronda, true); if n then E.soltar(n, pos) end
	elseif Config.Especiales[d.tipo] and math.random() < 0.25 then
		E.soltar("TragoSorpresa", pos)
	elseif not Config.Jefes[d.tipo] then
		local n = sortear(N.Ronda); if n then E.soltar(n, pos) end
	end
	-- objetos confiscados (reto de Bolsillo de Contrabando): uno por ronda desde la 5
	if N.Ronda >= 5 and not E.confiscadoRonda and math.random() < 0.08 then
		E.confiscadoRonda = true
		E.objetoConfiscado(pos)
	end
	if plr then
		-- Estampida: cada baja recarga un cargador del arma en mano
		if N.activo("Estampida") then
			local t = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
			if t and t:GetAttribute("ArmaId") then t:SetAttribute("Municion", Config.Armas[t:GetAttribute("ArmaId")].cargador) end
		end
		-- Eco Necrótico: 15 % deja un eco que ataca 5 s
		if plr:GetAttribute("Perk_EcoNecrotico") and math.random() < 0.15 then
			local explota = plr:GetAttribute("Sobre_EcoNecrotico")
			N.fx("Eco", pos, 5)
			task.spawn(function()
				for i = 1, 10 do
					for m2, d2 in Z.lista do
						if (d2.raiz.Position - pos).Magnitude < 7 then Z.danar(m2, Z.vidaRonda(N.Ronda) * 0.12, plr, nil, "eco") end
					end
					task.wait(0.5)
				end
				if explota then Z.explosion(pos, 10, Z.vidaRonda(N.Ronda) * 0.8, plr, "sinJugadores") end
			end)
		end
		-- reto Eco Necrótico: Camilleros reanimando
		if d.tipo == "Camillero" and d.modelo:GetAttribute("Reanimando") then E.progreso(plr, "EcoNecrotico", 1, 3) end
	end
end)
N.on("NuevaRonda", function() E.confiscadoRonda = false; for _, p in Players:GetPlayers() do p:SetAttribute("Congelados", 0) end end)

-- Ojo de Cuervo: tiro a la cabeza marca zombis cercanos
N.on("Cabeza", function(plr, zm, pos)
	E.rachaCabeza(plr, true)
	if not plr:GetAttribute("Perk_OjoDeCuervo") then return end
	for m, d in Z.lista do
		if (d.raiz.Position - pos).Magnitude < 15 then m:SetAttribute("Marcado", workspace:GetServerTimeNow() + 4) end
	end
end)
N.on("ZombiDanado", function(d, dano, plr, parte, causa)
	if plr and causa == "bala" and parte and parte.Name ~= "Head" then E.rachaCabeza(plr, false) end
	-- Escarcha (sobrecarga): ralentizados con menos de 20 % se congelan y rompen
	if plr and plr:GetAttribute("Sobre_EscarchaInterior") and d.lento and d.hum.Health - dano < d.hum.MaxHealth * 0.2 then
		task.defer(function() if Z.lista[d.modelo] then Z.morir(d.modelo, plr, false, "frio") end end)
	end
end)
N.on("ZombiCongelado", function(d)
	for _, p in Players:GetPlayers() do
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and (p.Character.HumanoidRootPart.Position - d.raiz.Position).Magnitude < 200 then
			p:SetAttribute("Congelados", (p:GetAttribute("Congelados") or 0) + 1)
			if p:GetAttribute("Congelados") >= 40 then E.completar(p, "EscarchaInterior") end
		end
	end
end)

-- Escarcha Interior y Ferro-Tónica (sobrecarga) al recibir golpes
local cdEscarcha, cdMuralla = {}, {}
N.on("JugadorGolpeado", function(plr, dano, fuente)
	local c = plr.Character; if not c then return end
	local pos = c.HumanoidRootPart.Position
	if plr:GetAttribute("Perk_EscarchaInterior") and os.clock() - (cdEscarcha[plr] or -99) > 10 then
		cdEscarcha[plr] = os.clock()
		N.fx("Escarcha", pos, 8)
		for m, d in Z.lista do if (d.raiz.Position - pos).Magnitude < 8 then Z.ralentizar(m, 0.5, 3); N.emitir("ZombiCongelado", d) end end
	end
	local h = c.Humanoid
	if plr:GetAttribute("Sobre_FerroTonica") and (h.Health - dano) < h.MaxHealth * 0.25 and os.clock() - (cdMuralla[plr] or -999) > 90 then
		cdMuralla[plr] = os.clock()
		plr:SetAttribute("Invulnerable", true)
		N.fx("Muralla", pos, 10)
		for m, d in Z.lista do
			local v = d.raiz.Position - pos
			if v.Magnitude < 10 then d.raiz.AssemblyLinearVelocity = v.Unit * 60 + Vector3.new(0, 30, 0) end
		end
		task.delay(3, function() plr:SetAttribute("Invulnerable", nil) end)
	end
end)

-- Pólvora Viva: reto de 10 bajas con una explosión
N.on("Explosion", function(plr, n) if n >= 10 then E.completar(plr, "PolvoraViva") end end)

-- Fiebre de Oro: reto de 15.000 puntos en una ronda
N.on("Puntos", function(plr)
	if (plr:GetAttribute("PuntosRonda") or 0) >= 15000 then E.completar(plr, "FiebreDeOro") end
end)

-- Ritmo Fantasma: recargas dentro de la capilla; sobrecarga = +25 % de daño tras recargar
N.on("Recargo", function(plr, tool)
	if plr:GetAttribute("Sobre_RitmoFantasma") then
		plr:SetAttribute("DanoExtra", true)
		task.delay(6, function() plr:SetAttribute("DanoExtra", nil) end)
	end
	local c = plr.Character
	if c and (c.HumanoidRootPart.Position - Config.Perks.RitmoFantasma.Sitio).Magnitude < 22 then E.progreso(plr, "RitmoFantasma", 1, 8) end
end)

-- aterrizajes (Zancada Lunar y Pólvora Viva mejoradas), avisados por el cliente
N.Accion.OnServerEvent:Connect(function(plr, tipo, caida)
	if tipo ~= "Aterrizaje" or typeof(caida) ~= "number" then return end
	local c = plr.Character; if not c then return end
	local pos = c.HumanoidRootPart.Position
	if plr:GetAttribute("Sobre_ZancadaLunar") and caida > 2 then
		for m, d in Z.lista do if (d.raiz.Position - pos).Magnitude < 10 then d.flotarHasta = os.clock() + 1.5; d.raiz.AssemblyLinearVelocity = Vector3.new(0, 25, 0) end end
		N.fx("Luna", pos)
	end
	if plr:GetAttribute("Sobre_PolvoraViva") and caida >= 6 then Z.explosion(pos, 10, Z.vidaRonda(N.Ronda), plr, "explosion") end
end)

-- Bolsillo de Contrabando (sobrecarga): el arma guardada recarga una bala por segundo
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Sobre_BolsilloContrabando") then
				for _, t in p.Backpack:GetChildren() do
					local cfg = t:IsA("Tool") and Config.Armas[t:GetAttribute("ArmaId")]
					if cfg and t:GetAttribute("Municion") < cfg.cargador and t:GetAttribute("Reserva") > 0 then
						t:SetAttribute("Municion", t:GetAttribute("Municion") + 1); t:SetAttribute("Reserva", t:GetAttribute("Reserva") - 1)
					end
				end
			end
		end
	end
end)

-- ------------------------------------------------------------ retos de Sobrecarga
function E.completar(plr, k)
	if plr:GetAttribute("Reto_" .. k) then return end
	plr:SetAttribute("Reto_" .. k, true)
	N.aviso(plr, "Reto cumplido: la máquina de " .. Config.Perks[k].Nombre .. " ofrece la Sobrecarga (" .. Config.PrecioSobrecarga .. ")", Config.Perks[k].Color)
end
function E.progreso(plr, k, n, meta)
	local a = "Prog_" .. k
	local v = (plr:GetAttribute(a) or 0) + n
	plr:SetAttribute(a, v)
	if v >= meta then E.completar(plr, k) else N.aviso(plr, Config.Perks[k].Nombre .. ": " .. v .. "/" .. meta, Config.Perks[k].Color) end
end
function E.rachaCabeza(plr, acierto)
	if not acierto then plr:SetAttribute("RachaCabeza", 0) return end
	local v = (plr:GetAttribute("RachaCabeza") or 0) + 1
	plr:SetAttribute("RachaCabeza", v)
	if v >= 20 and (plr:GetAttribute("Prog_Cuervos") or 0) >= 3 then E.completar(plr, "OjoDeCuervo") end
end

local objetivos = M.objetivos
local function disparable(nombre, pos, tam, color, material, f)
	local p = N.parte({ Name = nombre, Size = tam, Color = color, Material = material or Enum.Material.Metal })
	p.CFrame = CFrame.new(pos)
	p:SetAttribute("Disparable", true)
	p.Parent = objetivos
	p:SetAttribute("Accion", nombre)
	E.acciones[p] = f
	return p
end
E.acciones = {}
N.on("ObjetivoDisparado", function(plr, parte, cfg)
	local f = E.acciones[parte]
	if f then f(plr, parte, cfg) end
end)

local function sobreTecho(pos)
	-- busca el techo más alto cerca de pos
	local r = workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -100, 0), N.paramsSuelo)
	return r and r.Position or pos
end

function E.crearRetos()
	-- Ferro-Tónica: tres manómetros en la Gasolinera
	for i, pos in { Vector3.new(-58, 0.6, -6), Vector3.new(-140, 0.6, 12), Vector3.new(-88, 0.6, -36) } do
		local s = N.colocar(pos, Vector3.new(1, 3, 1))
		disparable("Manometro", s + Vector3.new(0, 4.5, 0), Vector3.new(0.9, 0.9, 0.3), Color3.fromRGB(200, 170, 80), Enum.Material.Foil, function(plr, p)
			local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if p:GetAttribute("Roto") or not h or h.Health >= h.MaxHealth / 2 then return end
			p:SetAttribute("Roto", true); p.Color = Color3.fromRGB(40, 40, 40)
			N.fx("Vapor", p.Position)
			E.progreso(plr, "FerroTonica", 1, 3)
		end)
	end
	-- Ojo de Cuervo: tres cuervos de latón en Villa Ceniza
	for i, pos in { Vector3.new(69, 0, -33), Vector3.new(159, 0, -34), Vector3.new(209, 0, 33) } do
		local s = sobreTecho(pos)
		disparable("Cuervo", s + Vector3.new(0, 0.6, 0), Vector3.new(0.6, 1, 1.1), Color3.fromRGB(180, 130, 50), Enum.Material.Foil, function(plr, p)
			if p.Transparency > 0 then return end
			p.Transparency = 1; p.CanQuery = false
			plr:SetAttribute("Prog_Cuervos", (plr:GetAttribute("Prog_Cuervos") or 0) + 1)
			N.aviso(plr, "Cuervo de latón " .. plr:GetAttribute("Prog_Cuervos") .. "/3; ahora 20 tiros a la cabeza seguidos", Config.Perks.OjoDeCuervo.Color)
		end)
	end
	-- Zancada Lunar: cuatro antenas en techos (tocar en el aire)
	for i, pos in { Vector3.new(114, 0, -34), Vector3.new(164, 0, 34), Vector3.new(372, 0, -6), Vector3.new(380, 0, 16) } do
		local s = sobreTecho(pos)
		local a = N.parte({ Name = "Antena", Size = Vector3.new(0.3, 6, 0.3), Color = Color3.fromRGB(180, 180, 190), Material = Enum.Material.Metal, CanCollide = false })
		a.CFrame = CFrame.new(s + Vector3.new(0, 3, 0)); a.CanTouch = true; a.Parent = objetivos
		a.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			if not plr or not plr:GetAttribute("Perk_ZancadaLunar") then return end
			local h = hit.Parent:FindFirstChildOfClass("Humanoid")
			if not h or h.FloorMaterial ~= Enum.Material.Air then return end
			local clave = "Antena" .. i
			if plr:GetAttribute(clave) then return end
			plr:SetAttribute(clave, true)
			E.progreso(plr, "ZancadaLunar", 1, 4)
		end)
	end
	-- Segundo Latido: tres desfibriladores en 20 s
	for i, pos in { Vector3.new(250, 0.6, -96), Vector3.new(256, 0.6, -104), Vector3.new(262, 0.6, -96) } do
		local s = N.colocar(pos, Vector3.new(2, 3, 2))
		local d = N.parte({ Name = "Desfibrilador", Size = Vector3.new(1.2, 0.6, 0.9), Color = Color3.fromRGB(240, 200, 40), Material = Enum.Material.SmoothPlastic })
		d.CFrame = CFrame.new(s + Vector3.new(0, 2.6, 0)); d.Parent = objetivos
		N.prompt(d, "Usar desfibrilador", "Camilla", 0.5, function(plr)
			local t = plr:GetAttribute("DesfibInicio")
			if not t or os.clock() - t > 20 then plr:SetAttribute("DesfibInicio", os.clock()); plr:SetAttribute("Prog_SegundoLatido", 0) end
			local clave = "Desfib" .. i .. "_" .. math.floor(plr:GetAttribute("DesfibInicio"))
			if plr:GetAttribute(clave) then return end
			plr:SetAttribute(clave, true)
			E.progreso(plr, "SegundoLatido", 1, 3)
			if (plr:GetAttribute("Prog_SegundoLatido") or 0) >= 3 then
				for k = 1, 6 do local s2 = Z.puntoAparicion(d.Position); if s2 then Z.crear("Comun", s2) end end
			end
		end)
	end
	-- Bolsillo de Contrabando: armario de evidencias en la Comisaría
	local s = N.colocar(Vector3.new(90, 0.6, 60), Vector3.new(3, 5, 2))
	local arm = N.parte({ Name = "ArmarioEvidencias", Size = Vector3.new(3, 5, 1.6), Color = Color3.fromRGB(80, 90, 60), Material = Enum.Material.Metal })
	arm.CFrame = CFrame.new(s + Vector3.new(0, 2.5, 0)); arm.Parent = objetivos
	N.prompt(arm, "Devolver objeto confiscado", "Armario de evidencias", 0.5, function(plr)
		local n = plr:GetAttribute("Confiscados") or 0
		if n <= 0 then N.aviso(plr, "No llevás objetos confiscados (los sueltan los zombis desde la ronda 5)") return end
		plr:SetAttribute("Confiscados", n - 1)
		E.progreso(plr, "BolsilloContrabando", 1, 5)
	end)
end

function E.objetoConfiscado(pos)
	local p = N.parte({ Name = "Confiscado", Size = Vector3.new(1, 0.6, 0.7), Color = Color3.fromRGB(120, 100, 70), Material = Enum.Material.Cardboard, CanCollide = false })
	p.CFrame = CFrame.new((N.suelo(pos, 3) or pos) + Vector3.new(0, 0.8, 0))
	local g = Instance.new("BillboardGui"); g.Size = UDim2.fromOffset(120, 26); g.StudsOffset = Vector3.new(0, 1.3, 0); g.AlwaysOnTop = true; g.MaxDistance = 40
	local t = Instance.new("TextLabel", g); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = "CONFISCADO"; t.TextColor3 = Color3.fromRGB(255, 80, 60); t.TextScaled = true; t.Font = Enum.Font.GothamBlack
	g.Parent = p
	p.Parent = objetivos
	N.prompt(p, "Recoger", "Objeto confiscado", 0, function(plr)
		plr:SetAttribute("Confiscados", (plr:GetAttribute("Confiscados") or 0) + 1)
		p:Destroy()
	end)
	task.delay(60, function() if p.Parent then p:Destroy() end end)
end

-- ------------------------------------------------------------ objetos del mapa
function E.crearObjetos()
	local EE = Config.EE
	-- teléfonos de la Ruta
	local relatos = {
		"«Aquí Vitalix. Si escuchás esto, la cinerita ya llegó a la Ruta. No bebas nada que no venga sellado.»",
		"«Las latas de rendimiento llevaban una pizca de ceniza del Monte Gris. Los soldados no se cansaban... ni se morían.»",
		"«El tren de las 00:00 lleva la última carga al Laboratorio Nivel 5. El Revisor no deja subir a nadie sin boleto.»",
		"«El Reactor no fabrica energía. Fabrica ceniza. Y la ceniza cae sobre todo el valle.»",
		"«Si el núcleo vuelve a la Bóveda Omega, se apaga todo. Rearmen el último tren.»",
	}
	for i, pos in EE.Telefonos do
		local s = N.colocar(pos, Vector3.new(1, 3, 1))
		local t = N.parte({ Name = "Telefono", Size = Vector3.new(0.8, 1.2, 0.5), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.SmoothPlastic })
		t.CFrame = CFrame.new(s + Vector3.new(0, 3.5, 0)); t.Parent = objetivos
		N.prompt(t, "Atender", "Teléfono de la Ruta", 0, function(plr) N.aviso(nil, relatos[i], Color3.fromRGB(200, 220, 255)) end)
	end
	-- radio de la Comisaría
	local pistas = {
		"Revisor: «Boleto perforado, Hoja de ruta. Pico, copo y llama, en el orden que diga la máquina.»",
		"Revisor: «Tres varillas para la caldera: ceniza de la mina, escarcha del laboratorio, llama del desarmadero.»",
		"Revisor: «Las señales siguen en rojo. Que los Linieros se acerquen a los semáforos... y que no vuelvan a levantarse.»",
	}
	local frecuencia = 0
	local s = N.colocar(EE.Radio, Vector3.new(1, 3, 1))
	local radio = N.parte({ Name = "Radio", Size = Vector3.new(1.6, 1, 0.8), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
	radio.CFrame = CFrame.new(s + Vector3.new(0, 3, 0)); radio.Parent = objetivos
	N.prompt(radio, "Cambiar frecuencia", "Radio de la Comisaría", 0, function(plr) frecuencia = frecuencia % 3 + 1; N.aviso(plr, pistas[frecuencia], Color3.fromRGB(255, 200, 150)) end)
	-- expendedoras Vitalix rotas (golpe cuerpo a cuerpo)
	local expendedoras = {}
	for i, pos in EE.Expendedoras do
		local s2 = N.colocar(pos, Vector3.new(3, 6, 2))
		local e = N.parte({ Name = "ExpendedoraRota", Size = Vector3.new(3, 6, 2), Color = Color3.fromRGB(170, 40, 40), Material = Enum.Material.Metal })
		e.CFrame = CFrame.new(s2 + Vector3.new(0, 3, 0)); e.Parent = objetivos
		local g = Instance.new("SurfaceGui"); g.Face = Enum.NormalId.Front; g.LightInfluence = 0.3
		local t = Instance.new("TextLabel", g); t.Size = UDim2.fromScale(1, 0.3); t.BackgroundTransparency = 1; t.Text = "VITALIX"; t.TextScaled = true; t.TextColor3 = Color3.fromRGB(255, 230, 200); t.Font = Enum.Font.GothamBlack
		g.Parent = e
		table.insert(expendedoras, e)
	end
	N.on("Golpe", function(plr, pos)
		for _, e in expendedoras do
			if (e.Position - pos).Magnitude < 5 then
				N.sumar(plr, 10)
				if math.random(50) == 1 then E.soltar("TragoSorpresa", e.Position + e.CFrame.LookVector * 3) end
			end
		end
	end)
	-- barriles de combustible de la Gasolinera
	local function barril(pos)
		local s3 = N.colocar(pos, Vector3.new(2, 3, 2))
		disparable("Barril", s3 + Vector3.new(0, 1.5, 0), Vector3.new(2, 3, 2), Color3.fromRGB(200, 60, 20), Enum.Material.Metal, function(plr, p)
			if p:GetAttribute("Exploto") then return end
			p:SetAttribute("Exploto", true)
			local pos2 = p.Position; p:Destroy()
			Z.explosion(pos2, 14, math.huge, plr, "explosion")
		end)
	end
	for _, pos in EE.Barriles do barril(pos) end
	N.on("NuevaRonda", function(r)
		if r % 3 == 0 then
			for _, x in objetivos:GetChildren() do if x.Name == "Barril" then x:Destroy() end end
			for _, pos in EE.Barriles do barril(pos) end
		end
	end)
	-- respiradero del Reactor (trampa de vapor)
	local s4 = N.colocar(EE.Respiradero, Vector3.new(3, 3, 3))
	local resp = N.parte({ Name = "Respiradero", Size = Vector3.new(3, 1.2, 3), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.DiamondPlate })
	resp.CFrame = CFrame.new(s4 + Vector3.new(0, 0.6, 0)); resp.Parent = objetivos
	N.prompt(resp, "Trampa de vapor (1000)", "Respiradero del Reactor", 0, function(plr, pp)
		if not N.Energia then N.aviso(plr, "Sin energía") return end
		if not N.pagar(plr, 1000) then return end
		pp.Enabled = false
		local fin = os.clock() + 20
		while os.clock() < fin do
			N.fx("Vapor", resp.Position)
			for m, d in Z.lista do if (d.raiz.Position - resp.Position).Magnitude < 12 then Z.danar(m, Z.vidaRonda(N.Ronda) * 0.25, plr, nil, "vapor") end end
			task.wait(0.5)
		end
		task.wait(30); pp.Enabled = true
	end)
	-- campana de la capilla: tres disparos → misa negra
	local s5 = sobreTecho(Vector3.new(60, 0, -112))
	local golpes = 0
	disparable("Campana", s5 + Vector3.new(0, 1.2, 0), Vector3.new(1.4, 1.6, 1.4), Color3.fromRGB(170, 130, 60), Enum.Material.Foil, function(plr)
		golpes += 1
		N.fx("Campana", s5)
		if golpes >= 3 then golpes = 0; N.misaProxima = true; N.aviso(nil, "La campana tocó tres veces. La próxima ronda será una misa negra", Color3.fromRGB(200, 60, 255)) end
	end)
	-- cámaras del Puesto Militar
	local s6 = N.colocar(EE.Camaras, Vector3.new(2, 3, 2))
	local cam = N.parte({ Name = "Camaras", Size = Vector3.new(2.4, 1.6, 1), Color = Color3.fromRGB(40, 50, 40), Material = Enum.Material.Metal })
	cam.CFrame = CFrame.new(s6 + Vector3.new(0, 3, 0)); cam.Parent = objetivos
	N.prompt(cam, "Vigilar (500)", "Cámaras del Puesto Militar", 0, function(plr)
		if not N.pagar(plr, 500) then return end
		workspace:SetAttribute("Camaras", workspace:GetServerTimeNow() + 30)
		N.aviso(nil, "Cámaras: especiales y mini jefes marcados 30 s", Color3.fromRGB(150, 255, 150))
	end)
	-- pila de cadáveres de la Gasolinera (se quema con el Cremador)
	local s7 = N.colocar(EE.Pila, Vector3.new(4, 2, 4))
	local pila = N.parte({ Name = "PilaCadaveres", Size = Vector3.new(4, 1.5, 4), Transparency = 1, CanCollide = false })
	pila.CFrame = CFrame.new(s7 + Vector3.new(0, 0.8, 0)); pila.Parent = objetivos
	local quemadaRonda = 0
	N.on("Llama", function(plr, origen, dir, alcance)
		local v = pila.Position - origen
		if v.Magnitude < alcance + 2 and v.Unit:Dot(dir) > 0.8 and quemadaRonda ~= N.Ronda then
			quemadaRonda = N.Ronda
			N.sumar(plr, 500, "Pila quemada")
			N.fx("Fuego", pila.Position, 6)
			for _, k in Z.cadaveres do if (k.pos - pila.Position).Magnitude < 20 then k.quemado = true end end
		end
	end)
end

-- Cámaras: marca especiales y jefes
task.spawn(function()
	while true do
		task.wait(1)
		local hasta = workspace:GetAttribute("Camaras") or 0
		if hasta > workspace:GetServerTimeNow() then
			for m, d in Z.lista do if d.tipo ~= "Comun" then m:SetAttribute("Marcado", hasta) end end
		end
	end
end)

return E
