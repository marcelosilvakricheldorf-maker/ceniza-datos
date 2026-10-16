-- ServerScriptService.CenizaServidor.Mapa: puertas, energía, máquinas de perks (con Sobrecarga), caja misteriosa y Refinadora (Pack-a-Punch)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local TS = game:GetService("TweenService")
local N = require(script.Parent.Nucleo)
local Z = require(script.Parent.Zombis)
local A = require(script.Parent.ArmasServidor)
local J = require(script.Parent.Jugadores)
local Config = N.Config
local CenizaRS = RS:WaitForChild("Ceniza")

local M = {}
local objetos = Instance.new("Folder"); objetos.Name = "CenizaObjetos"; objetos.Parent = workspace
local objetivos = Instance.new("Folder"); objetivos.Name = "CenizaObjetivos"; objetivos.Parent = workspace
M.objetos = objetos; M.objetivos = objetivos
local guardado = Instance.new("Folder"); guardado.Name = "PuertasAbiertas"; guardado.Parent = SS

-- orienta un objeto hacia el lado más despejado
local function yawLibre(pos)
	local mejor, md = 0, -1
	for k = 0, 7 do
		local a = k * math.pi / 4
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), dir * 30, N.paramsSuelo)
		local d = r and r.Distance or 30
		if d > md then md = d; mejor = a end
	end
	return mejor
end
M.yawLibre = yawLibre

-- coloca un modelo apoyado en el piso, mirando (su -Z) hacia el lado libre
function M.ponerModelo(modelo, pos, tam)
	local s = N.colocar(pos, tam)
	local yaw = yawLibre(s)
	local cf, size = modelo:GetBoundingBox()
	local base = modelo.PrimaryPart and modelo.PrimaryPart.CFrame or cf
	local alto = cf.Position.Y - size.Y / 2
	local offset = base.Position.Y - alto
	modelo:PivotTo(CFrame.new(s + Vector3.new(0, offset + 0.05, 0)) * CFrame.Angles(0, yaw + math.pi, 0))
	return s, yaw
end

-- ------------------------------------------------------------ puertas
M.puertas = {}
local function abrirPuerta(m, plr)
	if m:GetAttribute("Abierta") then return end
	m:SetAttribute("Abierta", true)
	local carpeta = Instance.new("Folder"); carpeta.Name = m.Name; carpeta.Parent = guardado
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Ancla" then
			if p.Name == "ColPuerta" or p.Name == "Col" then p.CanCollide = false end
			if p:GetAttribute("T0") == nil then p:SetAttribute("T0", p.Transparency) end
			local t = TS:Create(p, TweenInfo.new(0.6), { Transparency = 1 })
			t:Play()
			task.delay(0.65, function() p.Parent = carpeta end)
		end
	end
	local a = m:FindFirstChild("Ancla"); if a then for _, x in a:GetChildren() do if x:IsA("ProximityPrompt") then x.Enabled = false end end end
	N.aviso(nil, (plr and plr.Name .. " abrió " or "Se abrió ") .. m:GetAttribute("Etiqueta"), Color3.fromRGB(255, 220, 120))
	N.emitir("PuertaAbierta", m:GetAttribute("Id"), plr)
end
M.abrirPuerta = abrirPuerta

local function prepararPuertas()
	for _, m in N.Mapa.Puertas:GetChildren() do
		local id = m:GetAttribute("Id")
		M.puertas[id] = m
		local ys, n = 0, 0
		for _, p in m:GetChildren() do if p:IsA("BasePart") then ys += p.Position.Y - p.Size.Y / 2; n += 1 end end
		local pos = m:GetAttribute("Posicion")
		local suelo = n > 0 and ys / n or 0
		local ancla = m:FindFirstChild("Ancla") or N.parte({ Name = "Ancla", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false })
		ancla.Position = Vector3.new(pos.X, suelo + 3, pos.Z)
		ancla.Parent = m
		for _, x in ancla:GetChildren() do x:Destroy() end
		local costo = m:GetAttribute("Costo")
		if id == 18 then
			N.prompt(ancla, "Requiere el Boleto Perforado", m:GetAttribute("Etiqueta"), 0, function(plr) N.aviso(plr, "La cerradura del Vagón Correo lee boletos: hace falta el Boleto Perforado del Revisor") end, 10)
		else
			N.prompt(ancla, "Abrir (" .. costo .. ")", m:GetAttribute("Etiqueta"), 0, function(plr)
				if N.pagar(plr, costo) then abrirPuerta(m, plr) end
			end, 10)
		end
	end
end

-- ------------------------------------------------------------ energía
function M.encender(plr)
	if N.Energia then return end
	N.Energia = true
	workspace:SetAttribute("Energia", true)
	N.aviso(nil, "¡Energía restablecida! Las máquinas Vitalix vuelven a funcionar", Color3.fromRGB(120, 220, 255))
	for _, m in objetos:GetChildren() do
		if m:GetAttribute("Perk") then
			for _, p in m:GetDescendants() do if p:IsA("PointLight") then p.Enabled = true end end
		end
	end
	N.emitir("Energia", plr)
end

local function crearPalanca()
	local pos = N.colocar(Config.EE.Palanca, Vector3.new(2, 4, 2))
	local caja = N.parte({ Name = "Palanca", Size = Vector3.new(2, 3, 0.8), Color = Color3.fromRGB(70, 75, 80), Material = Enum.Material.DiamondPlate })
	caja.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	local brazo = N.parte({ Name = "Brazo", Size = Vector3.new(0.3, 1.6, 0.3), Color = Color3.fromRGB(200, 40, 30), Material = Enum.Material.Metal })
	brazo.CFrame = caja.CFrame * CFrame.new(0, 0.3, -0.6) * CFrame.Angles(math.rad(40), 0, 0)
	local m = Instance.new("Model"); m.Name = "PalancaEnergia"; caja.Parent = m; brazo.Parent = m; m.Parent = objetos
	N.prompt(caja, "Encender energía", "Subestación", 1, function(plr, pp)
		pp.Enabled = false
		brazo.CFrame = caja.CFrame * CFrame.new(0, 0.3, -0.6) * CFrame.Angles(math.rad(-40), 0, 0)
		M.encender(plr)
	end)
end

-- ------------------------------------------------------------ perks
M.Perks = {}
local function perksDe(plr)
	local t = {}
	for k in Config.Perks do if plr:GetAttribute("Perk_" .. k) then table.insert(t, k) end end
	return t
end
M.perksDe = perksDe

function M.aplicarPerk(plr, k)
	plr:SetAttribute("Perk_" .. k, true)
	local c = plr.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if k == "FerroTonica" and h then h.MaxHealth = 250; h.Health = 250 end
	if k == "ZancadaLunar" and h then h.WalkSpeed = 16 * 1.12 end
	if k == "SegundoLatido" and #Players:GetPlayers() == 1 then plr:SetAttribute("AutoReanimaciones", 3) end
	if k == "PolvoraViva" then plr:SetAttribute("Granadas", (plr:GetAttribute("Granadas") or 0) + 1) end
	N.Evento:FireClient(plr, "Perk", k)
	N.emitir("PerkComprado", plr, k)
end

N.on("QuitarPerks", function(plr, conservar)
	for k in Config.Perks do
		if k ~= conservar then plr:SetAttribute("Perk_" .. k, nil); plr:SetAttribute("Sobre_" .. k, nil) end
	end
	local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if h then h.MaxHealth = J.vidaMax(plr); h.WalkSpeed = 16 end
end)

local function beber(plr, k, f)
	plr:SetAttribute("Bebiendo", true)
	N.Evento:FireClient(plr, "Beber", k)
	task.delay(1.8, function() plr:SetAttribute("Bebiendo", false); f() end)
end

local function crearMaquina(k)
	local p = Config.Perks[k]
	local src = CenizaRS.Perks:FindFirstChild(p.Modelo)
	local m = src and src:Clone() or Instance.new("Model")
	m.Name = "Perk_" .. k
	m:SetAttribute("Perk", k)
	local _, tam = m:GetBoundingBox()
	M.ponerModelo(m, p.Sitio, Vector3.new(math.max(tam.X, tam.Z) + 0.5, tam.Y, math.max(tam.X, tam.Z) + 0.5))
	for _, x in m:GetDescendants() do
		if x:IsA("PointLight") then x.Color = p.Color; x.Enabled = (not p.Energia) or N.Energia end
		if x:IsA("BasePart") then x.Anchored = true end
	end
	m.Parent = objetos
	local raiz = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
	local pp = N.prompt(raiz, "Comprar (" .. p.Precio .. ")", p.Nombre, 0, function(plr, pp)
		if p.Energia and not N.Energia then N.aviso(plr, "Sin energía: hay que bajar la palanca de la Subestación", Color3.fromRGB(255, 180, 80)) return end
		if plr:GetAttribute("Caido") or plr:GetAttribute("Bebiendo") then return end
		local tiene = plr:GetAttribute("Perk_" .. k)
		if tiene then
			-- Sobrecarga
			if plr:GetAttribute("Sobre_" .. k) then N.aviso(plr, "Ya tenés la Sobrecarga de " .. p.Nombre) return end
			if not plr:GetAttribute("Reto_" .. k) then N.aviso(plr, "Reto de Sobrecarga: " .. p.Reto, p.Color) return end
			if N.pagar(plr, Config.PrecioSobrecarga) then
				beber(plr, k, function() plr:SetAttribute("Sobre_" .. k, true); N.aviso(plr, "Sobrecarga: " .. p.Sobre, p.Color); N.emitir("Sobrecarga", plr, k) end)
			end
			return
		end
		local max = plr:GetAttribute("PerkSlots") or Config.MaxPerks
		if #perksDe(plr) >= max then N.aviso(plr, "Ya tenés " .. max .. " perks") return end
		local precio = p.Precio
		if k == "SegundoLatido" and #Players:GetPlayers() > 1 then precio = p.PrecioCoop end
		if plr:GetAttribute("PerksGratis") then precio = 0 end
		if N.pagar(plr, precio) then beber(plr, k, function() M.aplicarPerk(plr, k) end) end
	end, 8)
	pp.Name = "Comprar"
	M.Perks[k] = m
	return m
end

-- ------------------------------------------------------------ caja misteriosa
M.caja = { sitio = 1, tiradas = 0, ocupada = false, modelos = {} }
local function modeloCaja()
	local m = Instance.new("Model"); m.Name = "CajaMisteriosa"
	local base = N.parte({ Name = "Base", Size = Vector3.new(5, 2, 2.6), Color = Color3.fromRGB(70, 45, 25), Material = Enum.Material.WoodPlanks })
	base.CFrame = CFrame.new(0, 1, 0); base.Parent = m
	local tapa = N.parte({ Name = "Tapa", Size = Vector3.new(5.1, 0.35, 2.7), Color = Color3.fromRGB(55, 35, 20), Material = Enum.Material.Wood })
	tapa.CFrame = CFrame.new(0, 2.18, 0); tapa.Parent = m
	for _, x in { -2.3, 2.3 } do
		local f = N.parte({ Name = "Fleje", Size = Vector3.new(0.25, 2.1, 2.7), Color = Color3.fromRGB(120, 100, 60), Material = Enum.Material.Metal })
		f.CFrame = CFrame.new(x, 1.05, 0); f.Parent = m
	end
	for _, z in { -1.32, 1.32 } do
		local q = Instance.new("SurfaceGui"); q.Face = z < 0 and Enum.NormalId.Front or Enum.NormalId.Back; q.LightInfluence = 0; q.Brightness = 3
		local t = Instance.new("TextLabel", q); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = "?"; t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 210, 90); t.Font = Enum.Font.GothamBlack
		q.Parent = base
	end
	local luz = Instance.new("PointLight"); luz.Color = Color3.fromRGB(255, 200, 100); luz.Range = 12; luz.Brightness = 1.2; luz.Parent = base
	local haz = N.parte({ Name = "Haz", Size = Vector3.new(1.2, 60, 1.2), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Transparency = 0.8, CanCollide = false, CanQuery = false, CastShadow = false })
	haz.CFrame = CFrame.new(0, 32, 0); haz.Parent = m
	m.PrimaryPart = base
	return m
end

local function poolCaja(plr)
	local pool = {}
	for _, id in Config.Caja do
		if id ~= "criolanza" and id ~= "cremador" and id ~= "cinerario" and not A.tieneArma(plr, id) then table.insert(pool, id) end
	end
	return pool
end

local function tirar(plr, m, gratis)
	if M.caja.ocupada then return end
	local precio = N.activo("MercadoNegro") and 10 or Config.PrecioCaja
	if not gratis and not N.pagar(plr, precio) then return end
	M.caja.ocupada = true
	local base = m.Base
	m.Tapa.CFrame = base.CFrame * CFrame.new(0, 1.2, 1.2) * CFrame.Angles(math.rad(-70), 0, 0)
	N.fx("CajaGira", base.Position + Vector3.new(0, 3, 0))
	task.wait(4)
	M.caja.tiradas += 1
	local muda = not N.activo("MercadoNegro") and M.caja.tiradas >= math.random(4, 8)
	if muda then
		M.caja.tiradas = 0
		N.aviso(nil, "¡Vito se ríe y se lleva la caja!", Color3.fromRGB(255, 200, 80))
		local lata = CenizaRS.PowerUps:FindFirstChild("TragoSorpresa")
		if lata then
			local l = lata:Clone(); l:PivotTo(CFrame.new(base.Position + Vector3.new(0, 4, 0))); l.Parent = workspace
			for i = 1, 30 do l:PivotTo(l:GetPivot() * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0.4, 0)); task.wait(0.05) end
			l:Destroy()
		end
		N.sumar(plr, precio)
		M.caja.ocupada = false
		M.moverCaja()
		return
	end
	local pool = poolCaja(plr)
	local id = pool[math.random(#pool)]
	local probCin = plr:GetAttribute("Fragmento") and 0.25 or 0.03
	if not A.tieneArma(plr, "cinerario") and math.random() < probCin then id = "cinerario" end
	-- el arma flota sobre la caja
	local vista = A.crearTool(id)
	local muestra = Instance.new("Model"); muestra.Name = "Premio"
	for _, ch in vista:GetChildren() do if ch:IsA("BasePart") then ch.Anchored = true; ch.Parent = muestra end end
	vista:Destroy()
	muestra:PivotTo(CFrame.new(base.Position + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(90), 0))
	muestra.Parent = m
	local cfg = Config.Armas[id]
	local tomado = false
	local pp = N.prompt(base, "Tomar " .. cfg.nombre, "Caja misteriosa", 0, function(quien, pp)
		if quien ~= plr or tomado then return end
		tomado = true
		A.dar(plr, id)
	end, 8)
	local fin = os.clock() + 10
	while not tomado and os.clock() < fin do task.wait(0.1) end
	pp:Destroy(); muestra:Destroy()
	m.Tapa.CFrame = base.CFrame * CFrame.new(0, 1.18, 0)
	M.caja.ocupada = false
end

local function ponerCaja(i)
	local m = modeloCaja()
	M.ponerModelo(m, Config.SitiosCaja[i][2], Vector3.new(6, 3, 6))
	m:SetAttribute("Sitio", i)
	m.Parent = objetos
	local pp = N.prompt(m.Base, "Caja misteriosa (" .. Config.PrecioCaja .. ")", Config.SitiosCaja[i][1], 0, function(plr) task.spawn(tirar, plr, m) end, 8)
	pp.Name = "Tirar"
	table.insert(M.caja.modelos, m)
	return m
end

function M.moverCaja(destino)
	for _, m in M.caja.modelos do m:Destroy() end
	M.caja.modelos = {}
	local i
	repeat i = destino or math.random(#Config.SitiosCaja) until i ~= M.caja.sitio or destino or #Config.SitiosCaja == 1
	M.caja.sitio = i
	ponerCaja(i)
	N.aviso(nil, "La caja apareció en: " .. Config.SitiosCaja[i][1], Color3.fromRGB(255, 220, 120))
end

function M.mercadoNegro(dur)
	for _, m in M.caja.modelos do m:Destroy() end
	M.caja.modelos = {}
	for i = 1, #Config.SitiosCaja do ponerCaja(i) end
	task.delay(dur, function() M.moverCaja(M.caja.sitio) end)
end

-- ------------------------------------------------------------ Refinadora Vitalix (Pack-a-Punch)
M.pap = { activa = false, valvulas = {}, primera = nil }
local function crearRefinadora()
	local pos = Config.EE.Refinadora
	local s = N.colocar(pos, Vector3.new(6, 6, 6))
	local m = Instance.new("Model"); m.Name = "RefinadoraVitalix"
	local cuerpo = N.parte({ Name = "Cuerpo", Size = Vector3.new(5, 5, 4), Color = Color3.fromRGB(40, 44, 50), Material = Enum.Material.DiamondPlate }); cuerpo.Parent = m
	local tolva = N.parte({ Name = "Tolva", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 3.4, 3.4), Color = Color3.fromRGB(160, 120, 40), Material = Enum.Material.Metal }); tolva.Parent = m
	local neon = N.parte({ Name = "Neon", Size = Vector3.new(5.1, 0.4, 4.1), Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon }); neon.Parent = m
	local ranura = N.parte({ Name = "Ranura", Size = Vector3.new(3, 0.8, 0.2), Color = Color3.fromRGB(10, 10, 10), Material = Enum.Material.SmoothPlastic }); ranura.Parent = m
	local cartel = Instance.new("SurfaceGui"); cartel.Face = Enum.NormalId.Front; cartel.LightInfluence = 0
	local t = Instance.new("TextLabel", cartel); t.Size = UDim2.fromScale(1, 0.35); t.BackgroundTransparency = 1; t.Text = "VITALIX · REFINADORA"; t.TextScaled = true; t.TextColor3 = Color3.fromRGB(255, 160, 60); t.Font = Enum.Font.GothamBlack
	cartel.Parent = cuerpo
	local luz = Instance.new("PointLight"); luz.Color = Color3.fromRGB(255, 120, 40); luz.Range = 16; luz.Parent = neon
	m.PrimaryPart = cuerpo
	local function armar(cf)
		cuerpo.CFrame = cf * CFrame.new(0, 2.5, 0)
		tolva.CFrame = cf * CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, math.rad(90))
		neon.CFrame = cf * CFrame.new(0, 4.2, 0)
		ranura.CFrame = cf * CFrame.new(0, 2.8, -2.05)
	end
	local yaw = yawLibre(s)
	M.pap.abajo = CFrame.new(s) * CFrame.Angles(0, yaw + math.pi, 0)
	M.pap.arriba = M.pap.abajo * CFrame.new(0, 14, 0)
	armar(M.pap.arriba)
	M.pap.armar = armar
	m.Parent = objetos
	M.pap.modelo = m
	local pp = N.prompt(cuerpo, "Refinar arma (" .. Config.PrecioPaP .. ")", "Refinadora Vitalix", 0, function(plr)
		if not M.pap.activa then N.aviso(plr, "La Refinadora está colgada: abrí las tres válvulas de refrigeración en 90 s (con energía)") return end
		if M.pap.ocupada then return end
		local tool = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
		if not tool or not tool:GetAttribute("ArmaId") then N.aviso(plr, "Tené el arma en la mano") return end
		local id = tool:GetAttribute("ArmaId"); local cfg = Config.Armas[id]
		local gratis = plr:GetAttribute("RefinadoGratis")
		if cfg.mejorada then
			if gratis or N.pagar(plr, Config.PrecioRePaP) then A.municionMaxima(plr); N.aviso(plr, "Munición refinada recargada") end
			return
		end
		if not gratis and not N.pagar(plr, Config.PrecioPaP) then return end
		plr:SetAttribute("RefinadoGratis", nil)
		M.pap.ocupada = true
		tool:Destroy()
		N.fx("Refinar", cuerpo.Position)
		task.wait(3.5)
		M.pap.ocupada = false
		A.dar(plr, cfg.mejora)
		N.aviso(plr, "Refinada: " .. Config.Armas[cfg.mejora].nombre, Color3.fromRGB(255, 170, 60))
	end, 9)
	pp.Name = "Refinar"
end

local function crearValvulas()
	for i, pos in Config.EE.Valvulas do
		local s = N.colocar(pos, Vector3.new(2, 4, 2))
		local tubo = N.parte({ Name = "Valvula", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1, 1), Color = Color3.fromRGB(90, 110, 130), Material = Enum.Material.Metal })
		tubo.CFrame = CFrame.new(s + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local rueda = N.parte({ Name = "Rueda", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.8, 1.8), Color = Color3.fromRGB(200, 40, 30), Material = Enum.Material.Metal })
		rueda.CFrame = CFrame.new(s + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local m = Instance.new("Model"); m.Name = "Valvula" .. i; tubo.Parent = m; rueda.Parent = m; m.Parent = objetos
		N.prompt(tubo, "Abrir válvula de refrigeración", "Válvula " .. i, 1.5, function(plr, pp)
			if not N.Energia then N.aviso(plr, "Sin energía no hay presión en las válvulas") return end
			if M.pap.activa or M.pap.valvulas[i] then return end
			local ahora = os.clock()
			if M.pap.primera and ahora - M.pap.primera > 90 then M.pap.valvulas = {}; M.pap.primera = nil end
			M.pap.primera = M.pap.primera or ahora
			M.pap.valvulas[i] = true
			rueda.Color = Color3.fromRGB(60, 200, 90)
			local n = 0; for _ in M.pap.valvulas do n += 1 end
			N.aviso(nil, "Válvula abierta (" .. n .. "/3)", Color3.fromRGB(120, 220, 255))
			if n >= 3 then
				M.pap.activa = true
				N.aviso(nil, "¡La Refinadora Vitalix baja sobre el Reactor!", Color3.fromRGB(255, 160, 60))
				local v = Instance.new("NumberValue"); v.Value = 0
				v.Changed:Connect(function(a) M.pap.armar(M.pap.arriba:Lerp(M.pap.abajo, a)) end)
				TS:Create(v, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 }):Play()
			else
				task.delay(90, function()
					if not M.pap.activa and M.pap.primera == ahora then
						M.pap.valvulas = {}; M.pap.primera = nil
						for j = 1, 3 do local r = objetos:FindFirstChild("Valvula" .. j); if r then r.Rueda.Color = Color3.fromRGB(200, 40, 30) end end
						N.aviso(nil, "Se cerraron las válvulas: tardaron más de 90 s", Color3.fromRGB(255, 120, 80))
					end
				end)
			end
		end)
	end
end

-- ------------------------------------------------------------ inicio / reinicio
function M.iniciar()
	prepararPuertas()
	crearPalanca()
	for k in Config.Perks do
		local ok, e = pcall(crearMaquina, k)
		if not ok then warn("perk " .. k .. ": " .. tostring(e)) end
		task.wait()
	end
	M.moverCaja(1)
	crearRefinadora()
	crearValvulas()
end

N.on("Reiniciar", function()
	for _, carpeta in guardado:GetChildren() do
		local m = N.Mapa.Puertas:FindFirstChild(carpeta.Name)
		for _, p in carpeta:GetChildren() do
			p.Parent = m
			if p.Name ~= "Ancla" then p.Transparency = p:GetAttribute("T0") or 0 end
			if p.Name == "ColPuerta" then p.CanCollide = true; p.Transparency = 1 end
		end
		carpeta:Destroy()
		if m then
			m:SetAttribute("Abierta", false)
			for _, x in m.Ancla:GetChildren() do if x:IsA("ProximityPrompt") then x.Enabled = true end end
		end
	end
	N.Energia = false; workspace:SetAttribute("Energia", false)
	local pal = objetos:FindFirstChild("PalancaEnergia"); if pal then pal:Destroy() end
	crearPalanca()
	M.pap.activa = false; M.pap.valvulas = {}; M.pap.primera = nil
	if M.pap.armar then M.pap.armar(M.pap.arriba) end
	for j = 1, 3 do local r = objetos:FindFirstChild("Valvula" .. j); if r then r.Rueda.Color = Color3.fromRGB(200, 40, 30) end end
	M.moverCaja(1)
end)

return M
