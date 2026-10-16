-- ServerScriptService.CenizaServidor.Mision: easter egg «Último Recorrido» (9 pasos + final), misiones de la Crio-Lanza y el Cremador, eventos de mini jefes
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local N = require(script.Parent.Nucleo)
local Z = require(script.Parent.Zombis)
local A = require(script.Parent.ArmasServidor)
local M = require(script.Parent.Mapa)
local R = require(script.Parent.Rondas)
local Config = N.Config
local EE = Config.EE

local S = { paso = 0, hoja = nil, hojaImpresa = false, varillas = {}, llave = false, semaforos = {}, consolas = {}, nucleo = false, final = false }
N.mision = S
local carpeta = Instance.new("Folder"); carpeta.Name = "Mision"; carpeta.Parent = workspace

local function hud()
	local t = {
		paso = S.paso, hoja = S.hojaImpresa and S.hoja or nil,
		varillas = { S.varillas.Ceniza and true or false, S.varillas.Escarcha and true or false, S.varillas.Llama and true or false },
		llave = S.llave, semaforos = 0,
	}
	for _ in S.semaforos do t.semaforos += 1 end
	workspace:SetAttribute("Mision", N.json(t))
end
local function avanzar(n, texto)
	if n > S.paso then S.paso = n end
	if texto then N.aviso(nil, texto, Color3.fromRGB(255, 200, 120)) end
	hud()
end
local function item(nombre, pos, color, f)
	local p = N.parte({ Name = nombre, Size = Vector3.new(1, 1, 1), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	p.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	local luz = Instance.new("PointLight"); luz.Color = color; luz.Range = 8; luz.Parent = p
	p.Parent = carpeta
	N.prompt(p, "Recoger", nombre, 0, function(plr) p:Destroy(); f(plr) end)
	task.spawn(function() while p.Parent do p.CFrame *= CFrame.Angles(0, 0.1, 0); task.wait(0.03) end end)
	return p
end

-- ------------------------------------------------------------ eventos de mini jefes
N.on("NuevaRonda", function(r)
	if r == 8 or (r >= 18 and (r - 18) % 8 == 0) then
		N.aviso(nil, "Suena el silbato del «Último tren»: el Revisor está en la Estación", Color3.fromRGB(255, 140, 80))
		R.agregarJefe("Revisor", EE.Locomotora)
	end
	if r == 12 then
		N.aviso(nil, "La mina tiembla: el Capataz sale a cobrar", Color3.fromRGB(255, 140, 80))
		R.agregarJefe("Capataz", Vector3.new(594, 0.6, -88))
	end
	if r >= 16 and r % 6 == 4 and M.puertas[5] and M.puertas[5]:GetAttribute("Abierta") then R.agregarJefe("Centinela", Vector3.new(416, 0.6, 0)) end
end)
N.on("PuertaAbierta", function(id)
	if id == 5 then R.agregarJefe("Centinela", Vector3.new(420, 0.6, 0)) end
	if id == 8 then R.agregarJefe("Capataz", Vector3.new(650, 0.6, -50)) end
end)

N.on("ZombiMuerto", function(d, plr, pos, cabeza, causa)
	if d.tipo == "Revisor" and not S.boletoSuelto and not S.hojaImpresa then
		S.boletoSuelto = true
		item("Boleto Perforado", pos, Color3.fromRGB(255, 230, 150), function(quien)
			quien:SetAttribute("Boleto", true)
			N.aviso(nil, quien.Name .. " tiene el Boleto Perforado: llevalo a la expendedora de la Boletería", Color3.fromRGB(255, 230, 150))
		end)
	elseif d.tipo == "Capataz" then
		item("Fragmento de cinerita", pos + Vector3.new(2, 0, 0), Color3.fromRGB(255, 120, 40), function(quien)
			quien:SetAttribute("Fragmento", true)
			N.aviso(quien, "Fragmento de cinerita: la caja da el Cinerario con 25 % de probabilidad", Color3.fromRGB(255, 120, 40))
		end)
	elseif d.tipo == "Liniero" then
		for i, sem in S.semaforosModelos or {} do
			if not S.semaforos[i] and (sem.Position - pos).Magnitude < 8 and S.paso >= 6 then
				S.semaforos[i] = true
				sem.Luz.Color = Color3.fromRGB(40, 255, 80)
				local n = 0; for _ in S.semaforos do n += 1 end
				avanzar(6, "Semáforo en verde (" .. n .. "/4)")
				if n >= 4 then avanzar(7, "¡Todas las señales en verde! La locomotora puede salir desde la cabina") end
			end
		end
	end
end)

-- cristales del Capataz en el orden de la Hoja de ruta
N.on("CristalDisparado", function(plr, zm, cristal, dano)
	local d = Z.lista[zm]; if not d then return end
	local v = cristal:GetAttribute("Vida") - dano
	cristal:SetAttribute("Vida", v)
	if v > 0 then return end
	local sim = cristal:GetAttribute("Simbolo")
	cristal:Destroy()
	N.fx("Explosion", cristal.Position, 3)
	table.insert(d.cristalesRotos, sim)
	Z.danar(zm, d.hum.MaxHealth * 0.2, plr, nil, "bala")
	if #d.cristalesRotos == 3 and S.hojaImpresa and not S.llave then
		local bien = true
		for i = 1, 3 do if d.cristalesRotos[i] ~= S.hoja[i] then bien = false end end
		if bien then
			item("Llave de maniobra", d.raiz.Position, Color3.fromRGB(200, 200, 210), function(quien)
				S.llave = true; avanzar(5, quien.Name .. " tiene la Llave de maniobra")
			end)
		else
			N.aviso(nil, "Los cristales se rompieron en otro orden: el Capataz volverá a aparecer", Color3.fromRGB(255, 120, 80))
			task.delay(30, function() R.agregarJefe("Capataz", Vector3.new(594, 0.6, -88)) end)
		end
	end
end)

-- ------------------------------------------------------------ objetos de la misión
local function crearObjetos()
	-- expendedora de boletos (paso 1)
	local s = N.colocar(EE.Expendedora, Vector3.new(2, 5, 2))
	local exp = N.parte({ Name = "ExpendedoraBoletos", Size = Vector3.new(2.4, 5, 1.6), Color = Color3.fromRGB(110, 90, 60), Material = Enum.Material.Metal })
	exp.CFrame = CFrame.new(s + Vector3.new(0, 2.5, 0)); exp.Parent = carpeta
	local panel = Instance.new("SurfaceGui"); panel.Face = Enum.NormalId.Front; panel.LightInfluence = 0
	local tx = Instance.new("TextLabel", panel); tx.Size = UDim2.fromScale(1, 0.4); tx.BackgroundTransparency = 1; tx.TextScaled = true; tx.Font = Enum.Font.Code
	tx.TextColor3 = Color3.fromRGB(255, 200, 90); tx.Text = "00:00 · ÚLTIMO RECORRIDO · LABORATORIO N5"
	panel.Parent = exp
	N.prompt(exp, "Meter boleto", "Expendedora de la Boletería", 1, function(plr, pp)
		if S.hojaImpresa then N.aviso(plr, "Hoja de ruta: " .. table.concat(S.hoja, " → ")) return end
		if not plr:GetAttribute("Boleto") then N.aviso(plr, "La máquina pide un Boleto Perforado") return end
		plr:SetAttribute("Boleto", nil)
		S.hoja = table.clone(Config.Simbolos)
		for i = 3, 2, -1 do local j = math.random(i); S.hoja[i], S.hoja[j] = S.hoja[j], S.hoja[i] end
		S.hojaImpresa = true
		tx.Text = "HOJA DE RUTA: " .. table.concat(S.hoja, " → ")
		M.abrirPuerta(M.puertas[18], plr)
		avanzar(1, "Hoja de ruta impresa: " .. table.concat(S.hoja, " → ") .. ". Se abrió el Vagón Correo")
		-- la Crio-Lanza espera dentro del Vagón Correo
		local pc = M.puertas[18]:GetAttribute("Posicion")
		local caja = N.parte({ Name = "CajaCrioLanza", Size = Vector3.new(4, 1.4, 1.6), Color = Color3.fromRGB(60, 90, 110), Material = Enum.Material.Metal })
		caja.CFrame = CFrame.new(N.colocar(Vector3.new(pc.X, 0.6, pc.Z + 2), Vector3.new(4, 2, 2)) + Vector3.new(0, 0.7, 0)); caja.Parent = carpeta
		N.prompt(caja, "Tomar Crio-Lanza", "Vagón Correo", 1, function(q)
			if A.tieneArma(q, "criolanza") then return end
			A.dar(q, "criolanza")
		end)
	end)

	-- vetas de cinerita (paso 2): remolino del Cinerario sobre cada una
	S.vetas = {}
	for i, pos in EE.Vetas do
		local s2 = N.colocar(pos, Vector3.new(2, 3, 2))
		local v = N.parte({ Name = "Veta", Size = Vector3.new(2.2, 3, 1), Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false })
		v.CFrame = CFrame.new(s2 + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0.3, i, 0.2); v.Parent = carpeta
		S.vetas[i] = v
		task.spawn(function() local t = 0 while v.Parent do t += 0.05; v.Transparency = 0.25 + 0.25 * math.sin(t * 2); task.wait(0.05) end end)
	end
	N.on("Remolino", function(plr, pos, radio)
		local cerca, dmin = nil, radio
		for i, v in S.vetas do
			if v.Parent and (v.Position - pos).Magnitude < dmin then cerca = v; dmin = (v.Position - pos).Magnitude end
		end
		for i, v in S.vetas do
			if v == cerca then
				v:Destroy()
				local quedan = 0; for _, x in S.vetas do if x.Parent then quedan += 1 end end
				N.aviso(nil, "Veta de cinerita arrancada (" .. (3 - quedan) .. "/3)", Color3.fromRGB(255, 120, 40))
				if quedan == 0 then
					item("Varilla de ceniza", v.Position, Color3.fromRGB(255, 110, 30), function() S.varillas.Ceniza = true; avanzar(2, "Varilla de ceniza conseguida") end)
				end
			end
		end
	end)

	-- tanque de refrigerante (paso 3): Crio-Lanza y luego cuchillo antes de 3 s
	local s3 = N.colocar(EE.Tanque, Vector3.new(3, 6, 3))
	local tanque = N.parte({ Name = "TanqueRefrigerante", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 3, 3), Color = Color3.fromRGB(150, 160, 170), Material = Enum.Material.Metal })
	tanque.CFrame = CFrame.new(s3 + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tanque:SetAttribute("Disparable", true); tanque.Parent = carpeta
	local congeladoHasta = 0
	N.on("ObjetivoDisparado", function(plr, parte, cfg)
		if parte ~= tanque or not cfg.congela then return end
		congeladoHasta = os.clock() + 3
		tanque.Color = Color3.fromRGB(180, 230, 255); tanque.Material = Enum.Material.Ice
		N.aviso(plr, "¡El tanque se congeló! Rompelo con el cuchillo (V) ya", Color3.fromRGB(150, 220, 255))
		task.delay(3, function() if tanque.Parent then tanque.Color = Color3.fromRGB(150, 160, 170); tanque.Material = Enum.Material.Metal end end)
	end)
	N.on("Golpe", function(plr, pos)
		if tanque.Parent and (tanque.Position - pos).Magnitude < 6 and os.clock() < congeladoHasta then
			local p = tanque.Position; tanque:Destroy()
			N.fx("Explosion", p, 4)
			item("Varilla de escarcha", p, Color3.fromRGB(120, 220, 255), function() S.varillas.Escarcha = true; avanzar(3, "Varilla de escarcha conseguida") end)
		end
	end)
	task.spawn(function() while tanque.Parent do N.fx("Vapor", tanque.Position + Vector3.new(0, 2, 0)); task.wait(2) end end)

	-- contenedor con cuatro sellos (paso 4): 2 s de llama por sello
	local s4 = N.colocar(EE.Contenedor, Vector3.new(8, 6, 4))
	local cont = N.parte({ Name = "Contenedor", Size = Vector3.new(8, 5, 3.6), Color = Color3.fromRGB(60, 80, 100), Material = Enum.Material.CorrodedMetal })
	cont.CFrame = CFrame.new(s4 + Vector3.new(0, 2.5, 0)); cont.Parent = carpeta
	local sellos = {}
	for i = 1, 4 do
		local se = N.parte({ Name = "Sello", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.9, 0.9), Color = Color3.fromRGB(160, 20, 30), Material = Enum.Material.SmoothPlastic })
		se.CFrame = cont.CFrame * CFrame.new(-3 + (i - 1) * 2, 0, -1.9) * CFrame.Angles(0, math.rad(90), 0)
		se:SetAttribute("Calor", 0); se.Parent = carpeta
		sellos[i] = se
	end
	local ultimaLlama = 0
	N.on("Llama", function(plr, origen, dir, alcance)
		local alguno = false
		for _, se in sellos do
			if se.Parent then
				local v = se.Position - origen
				if v.Magnitude < alcance + 1 and v.Unit:Dot(dir) > 0.9 then
					alguno = true
					se:SetAttribute("Calor", se:GetAttribute("Calor") + 0.125)
					if se:GetAttribute("Calor") >= 2 then se:Destroy(); N.fx("Fuego", se.Position, 2) end
				end
			end
		end
		if alguno then ultimaLlama = os.clock() end
		local quedan = 0; for _, se in sellos do if se.Parent then quedan += 1 end end
		if quedan == 0 and not S.varillas.Llama and not S.llamaSuelta then
			S.llamaSuelta = true
			item("Varilla de llama", cont.Position + cont.CFrame.LookVector * -3, Color3.fromRGB(255, 80, 20), function() S.varillas.Llama = true; avanzar(4, "Varilla de llama conseguida") end)
		end
	end)
	-- si la llama se apaga, los sellos se enfrían
	task.spawn(function()
		while cont.Parent do
			task.wait(0.5)
			if os.clock() - ultimaLlama > 1 then for _, se in sellos do if se.Parent then se:SetAttribute("Calor", 0) end end end
		end
	end)

	-- misión del Cremador: «Combustible de Villa» (3 bidones → banco de la Comisaría)
	local bidones = 0
	for i, pos in { Vector3.new(69, 0.6, -28), Vector3.new(159, 0.6, -28), Vector3.new(209, 0.6, 28) } do
		local sb = N.colocar(pos, Vector3.new(1.5, 2, 1.5))
		local b = N.parte({ Name = "Bidon", Size = Vector3.new(1.2, 1.6, 0.8), Color = Color3.fromRGB(200, 40, 20), Material = Enum.Material.Metal })
		b.CFrame = CFrame.new(sb + Vector3.new(0, 0.8, 0)); b.Parent = carpeta
		N.prompt(b, "Recoger combustible", "Combustible de Villa", 0.5, function(plr) b:Destroy(); bidones += 1; N.aviso(nil, "Combustible " .. bidones .. "/3: armá el Cremador en el banco de la Comisaría", Color3.fromRGB(255, 140, 60)) end)
	end
	local sbanco = N.colocar(Vector3.new(100, 0.6, 50), Vector3.new(4, 3, 2))
	local banco = N.parte({ Name = "BancoComisaria", Size = Vector3.new(4, 2.6, 2), Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.WoodPlanks })
	banco.CFrame = CFrame.new(sbanco + Vector3.new(0, 1.3, 0)); banco.Parent = carpeta
	N.prompt(banco, "Armar Cremador", "Banco de la Comisaría", 2, function(plr)
		if bidones < 3 then N.aviso(plr, "Faltan bidones de combustible (" .. bidones .. "/3)") return end
		if A.tieneArma(plr, "cremador") then return end
		A.dar(plr, "cremador")
	end)

	-- locomotora «La Vitalix 07» (paso 6) y cabina (paso 8)
	local sl = N.colocar(EE.Locomotora, Vector3.new(6, 6, 12))
	local tren = Instance.new("Model"); tren.Name = "LaVitalix07"
	local chasis = N.parte({ Name = "Chasis", Size = Vector3.new(5, 1, 14), Color = Color3.fromRGB(30, 30, 32), Material = Enum.Material.Metal }); chasis.Parent = tren
	local caldera = N.parte({ Name = "Caldera", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 3.6, 3.6), Color = Color3.fromRGB(150, 30, 25), Material = Enum.Material.Metal }); caldera.Parent = tren
	local cabina = N.parte({ Name = "Cabina", Size = Vector3.new(4.8, 4.6, 4), Color = Color3.fromRGB(120, 25, 20), Material = Enum.Material.Metal }); cabina.Parent = tren
	local chimenea = N.parte({ Name = "Chimenea", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1, 1), Color = Color3.fromRGB(20, 20, 20), Material = Enum.Material.Metal }); chimenea.Parent = tren
	local plataforma = N.parte({ Name = "Plataforma", Size = Vector3.new(5, 0.6, 10), Color = Color3.fromRGB(70, 60, 50), Material = Enum.Material.WoodPlanks }); plataforma.Parent = tren
	local asientos = {}
	for i = 1, 4 do local a = Instance.new("Seat"); a.Anchored = true; a.Size = Vector3.new(2, 1, 2); a.Color = Color3.fromRGB(60, 40, 30); a.Name = "Asiento" .. i; a.Parent = tren; asientos[i] = a end
	local cartel = Instance.new("SurfaceGui"); cartel.Face = Enum.NormalId.Left; cartel.LightInfluence = 0.5
	local ct = Instance.new("TextLabel", cartel); ct.Size = UDim2.fromScale(1, 1); ct.BackgroundTransparency = 1; ct.Text = "LA VITALIX 07"; ct.TextScaled = true; ct.TextColor3 = Color3.fromRGB(255, 220, 150); ct.Font = Enum.Font.GothamBlack
	cartel.Parent = caldera
	local faro = Instance.new("SpotLight"); faro.Face = Enum.NormalId.Front; faro.Range = 40; faro.Brightness = 3; faro.Enabled = false; faro.Parent = chasis
	S.tren = tren
	local function ponerTren(cf)
		chasis.CFrame = cf * CFrame.new(0, 1, 0)
		caldera.CFrame = cf * CFrame.new(0, 3.3, -2) * CFrame.Angles(0, math.rad(90), 0)
		cabina.CFrame = cf * CFrame.new(0, 3.8, 3.5)
		chimenea.CFrame = cf * CFrame.new(0, 5.6, -4.5) * CFrame.Angles(0, 0, math.rad(90))
		plataforma.CFrame = cf * CFrame.new(0, 1.3, 12)
		for i, a in asientos do a.CFrame = cf * CFrame.new(i % 2 == 0 and 1.2 or -1.2, 2.1, 9 + (i > 2 and 3 or 0)) end
	end
	S.ponerTren = ponerTren
	S.cfTren = CFrame.lookAt(sl, sl + Vector3.new(1, 0, 0))
	ponerTren(S.cfTren)
	tren.Parent = carpeta
	N.prompt(caldera, "Poner varillas y llave", "La Vitalix 07", 1, function(plr)
		if S.paso >= 6 then return end
		if not (S.varillas.Ceniza and S.varillas.Escarcha and S.varillas.Llama and S.llave) then
			local falta = {}
			if not S.varillas.Ceniza then table.insert(falta, "varilla de ceniza") end
			if not S.varillas.Escarcha then table.insert(falta, "varilla de escarcha") end
			if not S.varillas.Llama then table.insert(falta, "varilla de llama") end
			if not S.llave then table.insert(falta, "llave de maniobra") end
			N.aviso(plr, "La caldera tiene tres ranuras (pico, copo y llama). Falta: " .. table.concat(falta, ", "))
			return
		end
		faro.Enabled = true
		N.fx("Humo", chimenea.Position)
		avanzar(6, "El motor de La Vitalix 07 arranca, pero las señales siguen en rojo: matá Linieros junto a los cuatro semáforos")
	end)
	N.prompt(cabina, "Arrancar el tren", "Cabina", 1, function(plr) S.recorrido(plr) end)

	-- semáforos (paso 7)
	S.semaforosModelos = {}
	for i, pos in EE.Semaforos do
		local ss = N.colocar(pos, Vector3.new(1, 6, 1))
		local poste = N.parte({ Name = "Semaforo", Size = Vector3.new(0.5, 7, 0.5), Color = Color3.fromRGB(40, 40, 40), Material = Enum.Material.Metal })
		poste.CFrame = CFrame.new(ss + Vector3.new(0, 3.5, 0)); poste.Parent = carpeta
		local luz = N.parte({ Name = "Luz", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = Color3.fromRGB(255, 30, 20), Material = Enum.Material.Neon })
		luz.CFrame = CFrame.new(ss + Vector3.new(0, 7.2, 0)); luz.Parent = poste
		S.semaforosModelos[i] = poste
	end

	-- consolas del Reactor (paso 9)
	for i, pos in EE.Consolas do
		local sc = N.colocar(pos, Vector3.new(2, 3, 2))
		local c = N.parte({ Name = "Consola" .. i, Size = Vector3.new(2, 3, 1.4), Color = Color3.fromRGB(50, 60, 70), Material = Enum.Material.DiamondPlate })
		c.CFrame = CFrame.new(sc + Vector3.new(0, 1.5, 0)); c.Parent = carpeta
		N.prompt(c, "Liberar núcleo", "Consola " .. i, 1, function(plr)
			if S.paso < 8 then N.aviso(plr, "La consola no responde: el tren todavía no llegó al Nivel 5") return end
			if S.nucleo then return end
			local ahora = os.clock()
			for k, t in S.consolas do if ahora - t > 12 then S.consolas[k] = nil end end
			S.consolas[i] = ahora
			c.Color = Color3.fromRGB(60, 200, 90)
			task.delay(12, function() if not S.nucleo and S.consolas[i] == ahora then c.Color = Color3.fromRGB(50, 60, 70) end end)
			local n = 0; for _ in S.consolas do n += 1 end
			N.aviso(nil, "Consola " .. n .. "/4", Color3.fromRGB(255, 120, 80))
			if n >= 4 then
				S.nucleo = true
				avanzar(9, "¡El núcleo de cinerita baja a la vagoneta! El Reactor entra en emergencia. Comprá la Bóveda Omega (2000)")
				for _, l in N.Mapa.Luces:GetDescendants() do
					if l:IsA("PointLight") and l.Parent.Position.Y < -20 then l.Color = Color3.fromRGB(255, 20, 10) end
				end
			end
		end)
	end
end

-- ------------------------------------------------------------ paso 8: el recorrido
function S.recorrido(plr)
	if S.paso < 7 then N.aviso(plr, "Las señales siguen en rojo") return end
	if S.enViaje or S.paso >= 8 then return end
	S.enViaje = true
	N.aviso(nil, "Revisor (altavoz): «Último recorrido, destino Laboratorio Nivel 5. Suban al tren»", Color3.fromRGB(255, 200, 120))
	task.wait(6)
	local ruta = { S.cfTren.Position }
	for _, p in EE.Ruta do table.insert(ruta, p) end
	local paradas = { [3] = true, [4] = true }
	for i = 2, #ruta do
		local a, b = ruta[i - 1], ruta[i]
		local dur = (b - a).Magnitude / 9
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			local f = (os.clock() - t0) / dur
			local p = a:Lerp(b, f)
			S.ponerTren(CFrame.lookAt(p, p + (b - a) * Vector3.new(1, 0, 1)))
			task.wait(0.03)
		end
		if paradas[i] then
			-- cambio de agujas: dos palancas
			N.aviso(nil, "Revisor: «Cambio de agujas. Bajen las dos palancas»", Color3.fromRGB(255, 200, 120))
			local hechas = {}
			local partes = {}
			for k = 1, 2 do
				local pos = N.colocar(b + Vector3.new(k == 1 and -6 or 6, 0, 4), Vector3.new(1, 3, 1))
				local pa = N.parte({ Name = "Aguja" .. k, Size = Vector3.new(0.4, 2.4, 0.4), Color = Color3.fromRGB(230, 200, 40), Material = Enum.Material.Metal })
				pa.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)); pa.Parent = carpeta
				partes[k] = pa
				N.prompt(pa, "Bajar palanca", "Cambio de agujas", 0.5, function(q)
					hechas[k] = os.clock(); pa.Color = Color3.fromRGB(60, 200, 90)
				end, 8)
			end
			for k = 1, 4 do local s = Z.puntoAparicion(b); if s then Z.crear(k == 1 and "Camillero" or "Comun", s) end end
			if i == 4 then R.agregarJefe("Centinela", b + Vector3.new(0, 0, 8)); N.aviso(nil, "¡El Centinela S7 bloquea la vía! Rompé su celda trasera", Color3.fromRGB(80, 200, 255)) end
			local limite = #Players:GetPlayers() == 1 and 3 or 1
			while true do
				task.wait(0.2)
				if hechas[1] and hechas[2] and math.abs(hechas[1] - hechas[2]) <= limite then
					local jefe = false
					for _, d in Z.lista do if d.tipo == "Centinela" then jefe = true end end
					if not jefe or i ~= 4 then break end
				elseif hechas[1] and hechas[2] then
					hechas = {}; for _, pa in partes do pa.Color = Color3.fromRGB(230, 200, 40) end
					N.aviso(nil, "Las palancas tienen que bajarse a la vez", Color3.fromRGB(255, 140, 80))
				end
			end
			for _, pa in partes do pa:Destroy() end
		end
	end
	S.enViaje = false
	S.cfTren = CFrame.lookAt(ruta[#ruta], ruta[#ruta] + Vector3.new(1, 0, 0))
	avanzar(8, "Revisor: «Andén del laboratorio». Liberen el núcleo en las cuatro consolas del Reactor")
end

-- ------------------------------------------------------------ final: la Bóveda Omega
N.on("PuertaAbierta", function(id, plr)
	if id ~= 21 or not S.nucleo or S.final then
		if id == 21 and not S.nucleo then N.aviso(nil, "La Bóveda Omega está abierta, pero falta el núcleo") end
		return
	end
	S.final = true
	avanzar(10, "Último recorrido: empujen el núcleo hasta el fondo de la Bóveda (4 minutos). Suelten los frenos con E")
	local frenos = {}
	for i, pos in EE.Frenos do
		local s = N.colocar(pos, Vector3.new(1, 3, 1))
		local f = N.parte({ Name = "Freno" .. i, Size = Vector3.new(1.2, 1, 2.4), Color = Color3.fromRGB(200, 40, 30), Material = Enum.Material.Metal })
		f.CFrame = CFrame.new(s + Vector3.new(0, 0.5, 0)); f:SetAttribute("Trabado", false); f.Parent = carpeta
		N.prompt(f, "Soltar freno", "Freno de vía", 1, function() f:SetAttribute("Trabado", false); f.Color = Color3.fromRGB(60, 200, 90) end)
		frenos[i] = f
		f.Color = Color3.fromRGB(60, 200, 90)
	end
	local nucleo = N.parte({ Name = "Nucleo", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon, CanCollide = false })
	local inicio = N.colocar(EE.Boveda - Vector3.new(0, 0, 26), Vector3.new(3, 3, 3)) + Vector3.new(0, 1.5, 0)
	local fondo = N.colocar(EE.Boveda + Vector3.new(0, 0, 8), Vector3.new(3, 3, 3)) + Vector3.new(0, 1.5, 0)
	nucleo.Position = inicio; nucleo.Parent = carpeta
	local luz = Instance.new("PointLight"); luz.Color = Color3.fromRGB(255, 120, 30); luz.Range = 20; luz.Brightness = 3; luz.Parent = nucleo
	local progreso, total = 0, 240
	local minuto = 0
	local ultima = os.clock()
	while progreso < total do
		task.wait(0.5)
		local dt = os.clock() - ultima; ultima = os.clock()
		local cerca = false
		for _, p in N.vivos() do if (p.Character.HumanoidRootPart.Position - nucleo.Position).Magnitude < 14 then cerca = true end end
		local libres = true
		for _, f in frenos do if f:GetAttribute("Trabado") then libres = false end end
		if cerca and libres then progreso = math.min(total, progreso + dt) end
		nucleo.Position = inicio:Lerp(fondo, progreso / total)
		workspace:SetAttribute("FinalProgreso", progreso / total)
		-- los zombis traban los frenos
		if math.random() < 0.06 * dt then local f = frenos[math.random(#frenos)]; f:SetAttribute("Trabado", true); f.Color = Color3.fromRGB(200, 40, 30); N.aviso(nil, "¡Un freno se trabó!", Color3.fromRGB(255, 80, 60)) end
		local m = math.floor(progreso / 60) + 1
		if m > minuto and m <= 4 then
			minuto = m
			if m == 1 then R.agregarJefe("Capataz", EE.Boveda); for k = 1, 3 do local s = Z.puntoAparicion(EE.Boveda); if s then Z.crear("Hollinero", s) end end end
			if m == 2 then R.agregarJefe("Centinela", EE.Boveda); for k = 1, 3 do local s = Z.puntoAparicion(EE.Boveda); if s then Z.crear("Liniero", s) end end end
			if m == 3 then R.agregarJefe("Revisor", EE.Boveda) end
			if m == 4 then for _, j in { "Capataz", "Centinela", "Revisor" } do R.agregarJefe(j, EE.Boveda) end; for k = 1, 3 do local s = Z.puntoAparicion(EE.Boveda); if s then Z.crear("Camillero", s) end end end
		end
		if #N.vivos() == 0 then return end
	end
	-- premio
	N.aviso(nil, "La Bóveda se cierra. El Reactor se apaga y la ceniza deja de caer.", Color3.fromRGB(255, 230, 180))
	workspace:SetAttribute("SinCeniza", true)
	Z.matarTodos(nil, true)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("PerkSlots", 5)
		p:SetAttribute("PerksGratis", true)
		p:SetAttribute("RefinadoGratis", true)
		p:SetAttribute("InsigniaUltimoRecorrido", true)
		for k in Config.Perks do if not p:GetAttribute("Perk_" .. k) then M.aplicarPerk(p, k) end end
		local t = p.Character and p.Character:FindFirstChildOfClass("Tool")
		if t and t:GetAttribute("ArmaId") and not Config.Armas[t:GetAttribute("ArmaId")].mejorada then
			local id = Config.Armas[t:GetAttribute("ArmaId")].mejora
			t:Destroy(); A.dar(p, id)
		end
	end
	N.Evento:FireAllClients("Final")
	avanzar(11)
end)

-- solo pruebas: deja la misión como si se hubieran completado los pasos hasta n
function S.debugPaso(n)
	if n >= 1 and not S.hojaImpresa then S.hoja = { "Copo", "Pico", "Llama" }; S.hojaImpresa = true end
	if n >= 2 then S.varillas.Ceniza = true end
	if n >= 3 then S.varillas.Escarcha = true end
	if n >= 4 then S.varillas.Llama = true end
	if n >= 5 then S.llave = true end
	if n >= 7 then for i = 1, 4 do S.semaforos[i] = true end end
	if n >= 9 then S.nucleo = true end
	S.paso = math.max(S.paso, n)
	hud()
end

function S.iniciar()
	crearObjetos()
	hud()
end
return S
