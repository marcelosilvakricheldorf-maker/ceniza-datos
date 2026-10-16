-- ServerScriptService.CenizaServidor.ArmasServidor: herramientas (modelos del arsenal), disparos validados en el servidor, recargas y granadas
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local N = require(script.Parent.Nucleo)
local Z = require(script.Parent.Zombis)
local Config = N.Config
local Modelos = RS:WaitForChild("Ceniza"):WaitForChild("Armas")

local A = {}
local estado = {} -- tool → {ultimo, recargando}

local function v2r(p) return Vector3.new(p[3], p[2], -p[1]) end

function A.datos(id) return Config.Armas[id] end

function A.crearTool(id)
	local cfg = Config.Armas[id]
	local src = Modelos:FindFirstChild(id)
	if not src or not cfg then warn("arma desconocida " .. tostring(id)); return nil end
	local m = src:Clone()
	local tool = Instance.new("Tool")
	tool.Name = cfg.nombre
	tool.CanBeDropped = false
	tool.ToolTip = cfg.nombre
	tool:SetAttribute("ArmaId", id)
	tool:SetAttribute("Municion", cfg.cargador)
	tool:SetAttribute("Reserva", cfg.reserva)
	tool:SetAttribute("Mejorada", cfg.mejorada == true)
	local raiz = m.Raiz
	local datos = HS:JSONDecode(m.Datos.Value)
	local agarre = datos.puntos and datos.puntos.agarre and v2r(datos.puntos.agarre) or Vector3.zero
	for _, ch in m:GetChildren() do ch.Parent = tool end
	raiz.Name = "Handle"
	for _, p in tool:GetDescendants() do
		if p:IsA("BasePart") then p.Anchored = false; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true end
	end
	tool.Grip = CFrame.new(agarre) * CFrame.Angles(math.rad(90), 0, 0)
	m:Destroy()
	return tool
end

local function armasDe(plr)
	local t = {}
	for _, cont in { plr.Backpack, plr.Character } do
		if cont then for _, x in cont:GetChildren() do if x:IsA("Tool") and x:GetAttribute("ArmaId") then table.insert(t, x) end end end
	end
	return t
end
A.armasDe = armasDe

function A.tieneArma(plr, id)
	for _, t in armasDe(plr) do
		local a = t:GetAttribute("ArmaId")
		if a == id or Config.Armas[a].base == id or Config.Armas[id] and Config.Armas[id].base == a then return t end
	end
	return nil
end

-- da un arma; si los espacios están llenos reemplaza la equipada
function A.dar(plr, id, reemplazar)
	local tool = A.crearTool(id); if not tool then return end
	local lista = armasDe(plr)
	local max = plr:GetAttribute("Perk_BolsilloContrabando") and 3 or 2
	if reemplazar then reemplazar:Destroy()
	elseif #lista >= max then
		local eq = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
		if eq and eq:GetAttribute("ArmaId") then eq:Destroy() else lista[1]:Destroy() end
	end
	tool.Parent = plr.Backpack
	local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if h then h:EquipTool(tool) end
	return tool
end

function A.municionMaxima(plr)
	for _, t in armasDe(plr) do
		local cfg = Config.Armas[t:GetAttribute("ArmaId")]
		t:SetAttribute("Reserva", cfg.reserva)
		t:SetAttribute("Municion", cfg.cargador)
	end
	plr:SetAttribute("Granadas", 4)
end

-- ------------------------------------------------------------ disparo
local function paramsDe(plr, perfora)
	local p = RaycastParams.new()
	if perfora then
		p.FilterType = Enum.RaycastFilterType.Include
		p.FilterDescendantsInstances = { Z.carpeta, workspace:FindFirstChild("CenizaObjetivos") }
	else
		p.FilterType = Enum.RaycastFilterType.Exclude
		local ex = { N.Mapa.Visual, N.Mapa.Luces }
		for _, o in Players:GetPlayers() do if o.Character then table.insert(ex, o.Character) end end
		p.FilterDescendantsInstances = ex
	end
	return p
end

local function zombiDe(parte)
	local m = parte and parte:FindFirstAncestorOfClass("Model")
	while m and m.Parent ~= Z.carpeta do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
	return m
end

local function encadenar(desde, n, dano, plr, ya)
	for m, d in Z.lista do
		if n <= 0 then break end
		if not ya[m] and (d.raiz.Position - desde).Magnitude < 14 then
			ya[m] = true; n -= 1
			N.fx("Rayo", desde, d.raiz.Position)
			Z.danar(m, dano, plr, nil, "rayo")
		end
	end
end

local function impacto(plr, cfg, res, dano, origen)
	local parte = res.Instance
	-- objetivos del mapa (barriles, cuervos, manómetros, vetas...)
	if parte:GetAttribute("Disparable") then N.emitir("ObjetivoDisparado", plr, parte, cfg) end
	local zm = zombiDe(parte)
	if zm then
		local mult = 1
		if plr:GetAttribute("DanoExtra") then mult *= 1.25 end
		if parte.Name == "Cristal" then N.emitir("CristalDisparado", plr, zm, parte, dano * mult); return zm end
		local murio = Z.danar(zm, dano * mult, plr, parte, cfg.congela and "frio" or "bala")
		if cfg.congela then Z.congelar(zm, cfg.mejorada and 2.5 or 1.5) end
		if N.activo("Bobina") then encadenar(res.Position, 2, dano * 0.6, plr, { [zm] = true }) end
		if murio and parte.Name == "Head" then N.emitir("Cabeza", plr, zm, res.Position) end
		if not murio and parte.Name == "Head" then N.emitir("CabezaSinMatar", plr, zm) end
		return zm
	end
	return nil
end

function A.disparar(plr, tool, origen, dirs)
	local c = plr.Character
	if not c or tool.Parent ~= c then return end
	local id = tool:GetAttribute("ArmaId"); local cfg = Config.Armas[id]; if not cfg then return end
	local st = estado[tool] or {}; estado[tool] = st
	local ahora = os.clock()
	local intervalo = 60 / cfg.cadencia
	if cfg.rafaga then intervalo = 60 / cfg.cadencia end
	if st.recargando or ahora - (st.ultimo or 0) < intervalo * 0.7 then return end
	if plr:GetAttribute("Bebiendo") then return end
	local mun = tool:GetAttribute("Municion")
	if mun <= 0 then return end
	st.ultimo = ahora
	local gasto = cfg.modo == "llama" and 1 or 1
	tool:SetAttribute("Municion", mun - gasto)
	local raiz = c:FindFirstChild("HumanoidRootPart"); if not raiz then return end
	if typeof(origen) ~= "Vector3" or (origen - raiz.Position).Magnitude > 10 then origen = raiz.Position + Vector3.new(0, 1.5, 0) end
	local params = paramsDe(plr, cfg.perfora)
	local puntos = {}
	local dano = cfg.dano * (plr:GetAttribute("DanoExtra") and 1 or 1)
	if cfg.modo == "llama" then
		local dir = (typeof(dirs[1]) == "Vector3" and dirs[1].Unit) or raiz.CFrame.LookVector
		for m, d in Z.lista do
			local v = d.raiz.Position - origen
			if v.Magnitude < cfg.alcance and v.Unit:Dot(dir) > 0.88 then Z.danar(m, dano * 0.6, plr, nil, "fuego") end
		end
		N.emitir("Llama", plr, origen, dir, cfg.alcance)
		N.fx("Llama", plr, origen, dir, cfg.alcance)
		return
	end
	local n = math.min(#dirs, cfg.perdigones)
	for i = 1, n do
		local dir = dirs[i]
		if typeof(dir) ~= "Vector3" then continue end
		dir = dir.Unit
		local alcance = cfg.modo == "cohete" and 400 or cfg.alcance
		local res = workspace:Raycast(origen, dir * alcance, params)
		local fin = res and res.Position or origen + dir * alcance
		table.insert(puntos, fin)
		if cfg.modo == "cohete" or cfg.explosiva then
			if res then impacto(plr, cfg, res, cfg.explosiva and dano or 0, origen) end
			local explota = function()
				Z.explosion(fin, cfg.radio or 6, cfg.modo == "cohete" and dano or dano * 0.5, plr, "explosion")
			end
			if cfg.modo == "cohete" then task.delay((fin - origen).Magnitude / 120, explota) else explota() end
		elseif cfg.modo == "remolino" then
			task.delay((fin - origen).Magnitude / 90, function() A.remolino(plr, fin, cfg.radio or 14, cfg.duracion or 4, cfg.mejorada) end)
		elseif res then
			local zm = impacto(plr, cfg, res, dano, origen)
			if zm and cfg.modo == "dardo" then encadenar(res.Position, cfg.mejorada and 3 or 2, dano * 0.7, plr, { [zm] = true }) end
			if zm and cfg.modo == "haz" and not cfg.congela then
				-- el haz atraviesa hasta 3 zombis
				local ya = { [zm] = true }
				local p2 = RaycastParams.new(); p2.FilterType = Enum.RaycastFilterType.Exclude
				local ex = { N.Mapa.Visual, zm }
				for _, o in Players:GetPlayers() do if o.Character then table.insert(ex, o.Character) end end
				for k = 1, 2 do
					p2.FilterDescendantsInstances = ex
					local r2 = workspace:Raycast(res.Position, dir * alcance, p2)
					local z2 = r2 and impacto(plr, cfg, r2, dano, origen)
					if not z2 then break end
					table.insert(ex, z2)
				end
			end
		end
	end
	N.fx("Disparo", plr, origen, puntos, cfg.modo, id)
	if tool:GetAttribute("Municion") <= 0 and tool:GetAttribute("Reserva") > 0 then task.delay(0.15, A.recargar, plr, tool) end
end

function A.remolino(plr, pos, radio, dur, mejorado)
	N.fx("Remolino", pos, radio, dur)
	N.emitir("Remolino", plr, pos, radio)
	local fin = os.clock() + dur
	while os.clock() < fin do
		for m, d in Z.lista do
			local v = pos - d.raiz.Position
			if v.Magnitude < radio then
				if Config.Jefes[d.tipo] then Z.danar(m, Z.vidaRonda(N.Ronda) * 0.15, plr, nil, "remolino")
				else
					Z.ralentizar(m, 0.1, 0.5)
					d.raiz.CFrame = d.raiz.CFrame + v.Unit * math.min(v.Magnitude, 1.2)
					if v.Magnitude < radio * 0.45 then Z.danar(m, math.huge, plr, nil, "remolino") end
				end
			end
		end
		task.wait(0.2)
	end
end

function A.recargar(plr, tool)
	local c = plr.Character
	if not tool or not c or tool.Parent ~= c then return end
	local id = tool:GetAttribute("ArmaId"); local cfg = Config.Armas[id]
	local st = estado[tool] or {}; estado[tool] = st
	local mun, res = tool:GetAttribute("Municion"), tool:GetAttribute("Reserva")
	if st.recargando or mun >= cfg.cargador or res <= 0 then return end
	st.recargando = true
	local dur = cfg.recarga or 2.2
	local ok, d = pcall(function() return HS:JSONDecode(tool.Datos.Value).clips.recarga.dur end)
	if ok and d then dur = d end
	if plr:GetAttribute("Perk_RitmoFantasma") then dur *= 0.5 end
	tool:SetAttribute("Recargando", dur)
	N.Evento:FireAllClients("Recarga", plr, tool, dur)
	task.delay(dur, function()
		st.recargando = false
		if tool.Parent then
			tool:SetAttribute("Recargando", 0)
			local falta = cfg.cargador - tool:GetAttribute("Municion")
			local toma = math.min(falta, tool:GetAttribute("Reserva"))
			tool:SetAttribute("Municion", tool:GetAttribute("Municion") + toma)
			tool:SetAttribute("Reserva", tool:GetAttribute("Reserva") - toma)
			N.emitir("Recargo", plr, tool)
		end
	end)
end

function A.golpe(plr)
	local c = plr.Character; if not c or plr:GetAttribute("Caido") then return end
	local st = estado[plr] or {}; estado[plr] = st
	if os.clock() - (st.ultimoGolpe or 0) < 0.8 then return end
	st.ultimoGolpe = os.clock()
	local raiz = c.HumanoidRootPart
	N.fx("Cuchillo", plr)
	for m, d in Z.lista do
		local v = d.raiz.Position - raiz.Position
		if v.Magnitude < 6 and v.Unit:Dot(raiz.CFrame.LookVector) > 0.3 then
			Z.danar(m, 150 + N.Ronda * 10, plr, nil, "cuerpo")
			break
		end
	end
	N.emitir("Golpe", plr, raiz.Position + raiz.CFrame.LookVector * 3)
end

function A.granada(plr, dir)
	local c = plr.Character; if not c or plr:GetAttribute("Caido") then return end
	local g = plr:GetAttribute("Granadas") or 0
	if g <= 0 then return end
	plr:SetAttribute("Granadas", g - 1)
	local raiz = c.HumanoidRootPart
	dir = typeof(dir) == "Vector3" and dir.Unit or raiz.CFrame.LookVector
	local b = N.parte({ Name = "Granada", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = Color3.fromRGB(60, 70, 50), Material = Enum.Material.Metal, Anchored = false, CanCollide = true })
	b.CFrame = CFrame.new(raiz.Position + Vector3.new(0, 2, 0) + dir * 2)
	b.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 25, 0)
	b.Parent = workspace
	b:SetNetworkOwner(nil)
	task.delay(2.2, function()
		local pos = b.Position; b:Destroy()
		Z.explosion(pos, 12, 400 + N.Ronda * 60, plr, "explosion")
	end)
end

N.Accion.OnServerEvent:Connect(function(plr, tipo, a, b, cc)
	if tipo == "Disparar" then
		if typeof(a) == "Instance" and a:IsA("Tool") and typeof(cc) == "table" then A.disparar(plr, a, b, cc) end
	elseif tipo == "Recargar" and typeof(a) == "Instance" then A.recargar(plr, a)
	elseif tipo == "Golpe" then A.golpe(plr)
	elseif tipo == "Granada" then A.granada(plr, a)
	end
end)

-- nueva ronda: granadas
N.on("NuevaRonda", function(r)
	for _, p in Players:GetPlayers() do
		local g = p:GetAttribute("Granadas") or 0
		p:SetAttribute("Granadas", math.min(4 + (p:GetAttribute("Perk_PolvoraViva") and 1 or 0), g + 2 + (p:GetAttribute("Perk_PolvoraViva") and 1 or 0)))
	end
end)
N.on("Aparecio", function(plr)
	if #armasDe(plr) == 0 then A.dar(plr, Config.ArmaInicial) end
	plr:SetAttribute("Granadas", plr:GetAttribute("Granadas") or 2)
end)

return A
