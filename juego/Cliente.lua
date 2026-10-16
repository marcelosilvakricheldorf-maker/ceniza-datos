-- StarterPlayerScripts.CenizaCliente: HUD, armas (disparo, recarga, clips del visor), animación procedural de zombis y sobrevivientes, efectos
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local HS = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local J = RS:WaitForChild("CenizaJuego")
local Config = require(J.Config)
local Anim = require(J.Anim)
local Evento = J.Remotes.Evento
local Accion = J.Remotes.Accion
local yo = Players.LocalPlayer
local cam = workspace.CurrentCamera
local rad = math.rad

-- ================================================================ HUD
local gui = Instance.new("ScreenGui")
gui.Name = "CenizaHUD"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = yo:WaitForChild("PlayerGui")
local FUENTE = Enum.Font.GothamBold
local function texto(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1; t.Font = props.Font or FUENTE; t.TextColor3 = props.Color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.5; t.TextScaled = props.Scaled or false; t.TextSize = props.Size or 20
	t.Text = props.Text or ""; t.AnchorPoint = props.Anchor or Vector2.zero; t.Position = props.Pos; t.Size = props.Dim
	t.TextXAlignment = props.AlignX or Enum.TextXAlignment.Center
	t.Parent = props.Parent or gui
	return t
end
local lblRonda = texto({ Pos = UDim2.new(0, 24, 1, -24), Dim = UDim2.fromOffset(160, 90), Anchor = Vector2.new(0, 1), Font = Enum.Font.Fantasy, Size = 80, Color = Color3.fromRGB(170, 20, 15), AlignX = Enum.TextXAlignment.Left })
local lblPuntos = texto({ Pos = UDim2.new(0, 24, 1, -118), Dim = UDim2.fromOffset(220, 36), Anchor = Vector2.new(0, 1), Size = 30, Color = Color3.fromRGB(255, 225, 120), AlignX = Enum.TextXAlignment.Left })
local lblArma = texto({ Pos = UDim2.new(1, -24, 1, -64), Dim = UDim2.fromOffset(300, 26), Anchor = Vector2.new(1, 1), Size = 20, AlignX = Enum.TextXAlignment.Right })
local lblMun = texto({ Pos = UDim2.new(1, -24, 1, -22), Dim = UDim2.fromOffset(300, 44), Anchor = Vector2.new(1, 1), Size = 38, AlignX = Enum.TextXAlignment.Right })
local lblGranadas = texto({ Pos = UDim2.new(1, -24, 1, -94), Dim = UDim2.fromOffset(300, 22), Anchor = Vector2.new(1, 1), Size = 16, Color = Color3.fromRGB(200, 200, 160), AlignX = Enum.TextXAlignment.Right })
local lblMision = texto({ Pos = UDim2.new(1, -16, 0, 16), Dim = UDim2.fromOffset(360, 120), Anchor = Vector2.new(1, 0), Size = 15, Color = Color3.fromRGB(255, 210, 150), AlignX = Enum.TextXAlignment.Right })
lblMision.TextYAlignment = Enum.TextYAlignment.Top; lblMision.TextWrapped = true
local lblCentro = texto({ Pos = UDim2.new(0.5, 0, 0.42, 0), Dim = UDim2.fromOffset(800, 60), Anchor = Vector2.new(0.5, 0.5), Size = 34, Font = Enum.Font.GothamBlack })
lblCentro.TextTransparency = 1; lblCentro.TextStrokeTransparency = 1
local mira = texto({ Pos = UDim2.fromScale(0.5, 0.5), Dim = UDim2.fromOffset(30, 30), Anchor = Vector2.new(0.5, 0.5), Size = 24, Text = "+" })
local marcaGolpe = texto({ Pos = UDim2.fromScale(0.5, 0.5), Dim = UDim2.fromOffset(40, 40), Anchor = Vector2.new(0.5, 0.5), Size = 30, Text = "×", Color = Color3.fromRGB(255, 255, 255) })
marcaGolpe.TextTransparency = 1; marcaGolpe.TextStrokeTransparency = 1

-- avisos
local avisos = Instance.new("Frame"); avisos.BackgroundTransparency = 1; avisos.AnchorPoint = Vector2.new(0.5, 0)
avisos.Position = UDim2.new(0.5, 0, 0, 60); avisos.Size = UDim2.fromOffset(760, 300); avisos.Parent = gui
local lista = Instance.new("UIListLayout", avisos); lista.HorizontalAlignment = Enum.HorizontalAlignment.Center; lista.Padding = UDim.new(0, 4)
local function aviso(txt, color)
	local t = texto({ Parent = avisos, Dim = UDim2.new(1, 0, 0, 24), Size = 19, Text = txt, Color = color or Color3.fromRGB(255, 240, 220) })
	t.TextWrapped = true
	t.AutomaticSize = Enum.AutomaticSize.Y
	task.delay(5, function() TS:Create(t, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play(); task.wait(1); t:Destroy() end)
	local n = #avisos:GetChildren() - 1
	if n > 6 then for _, x in avisos:GetChildren() do if x:IsA("TextLabel") then x:Destroy(); break end end end
end
local function centro(txt, color, dur)
	lblCentro.Text = txt; lblCentro.TextColor3 = color or Color3.new(1, 1, 1)
	lblCentro.TextTransparency = 0; lblCentro.TextStrokeTransparency = 0.4
	task.delay(dur or 2.5, function() TS:Create(lblCentro, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play() end)
end

-- perks
local filaPerks = Instance.new("Frame"); filaPerks.BackgroundTransparency = 1; filaPerks.Position = UDim2.new(0, 24, 1, -168); filaPerks.AnchorPoint = Vector2.new(0, 1)
filaPerks.Size = UDim2.fromOffset(320, 44); filaPerks.Parent = gui
local lp = Instance.new("UIListLayout", filaPerks); lp.FillDirection = Enum.FillDirection.Horizontal; lp.Padding = UDim.new(0, 6)
local function pintarPerks()
	for _, x in filaPerks:GetChildren() do if x:IsA("Frame") then x:Destroy() end end
	for k, p in Config.Perks do
		if yo:GetAttribute("Perk_" .. k) then
			local f = Instance.new("Frame"); f.Size = UDim2.fromOffset(40, 40); f.BackgroundColor3 = p.Color
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
			local s = Instance.new("UIStroke", f); s.Thickness = yo:GetAttribute("Sobre_" .. k) and 3 or 2; s.Color = yo:GetAttribute("Sobre_" .. k) and Color3.fromRGB(255, 220, 90) or Color3.new(0, 0, 0)
			local ini = ""
			for w in string.gmatch(p.Nombre, "%a+") do if #w > 2 then ini ..= string.sub(w, 1, 1) end end
			texto({ Parent = f, Dim = UDim2.fromScale(1, 1), Pos = UDim2.new(), Text = ini, Size = 16 })
			f.Parent = filaPerks
		end
	end
end
for k in Config.Perks do
	yo:GetAttributeChangedSignal("Perk_" .. k):Connect(pintarPerks)
	yo:GetAttributeChangedSignal("Sobre_" .. k):Connect(pintarPerks)
end

-- power-ups activos
local filaPU = Instance.new("Frame"); filaPU.BackgroundTransparency = 1; filaPU.AnchorPoint = Vector2.new(0.5, 1)
filaPU.Position = UDim2.new(0.5, 0, 1, -20); filaPU.Size = UDim2.fromOffset(600, 40); filaPU.Parent = gui
local lpu = Instance.new("UIListLayout", filaPU); lpu.FillDirection = Enum.FillDirection.Horizontal; lpu.HorizontalAlignment = Enum.HorizontalAlignment.Center; lpu.Padding = UDim.new(0, 8)
local activos = {}
local function powerUpHUD(nombre, dur, color)
	if dur <= 0 then return end
	if activos[nombre] then activos[nombre].fin = os.clock() + dur; return end
	local f = Instance.new("Frame"); f.Size = UDim2.fromOffset(110, 34); f.BackgroundColor3 = Color3.new(0, 0, 0); f.BackgroundTransparency = 0.4
	Instance.new("UICorner", f)
	local barra = Instance.new("Frame", f); barra.BackgroundColor3 = color; barra.Size = UDim2.new(1, 0, 0, 4); barra.Position = UDim2.new(0, 0, 1, -4); barra.BorderSizePixel = 0
	texto({ Parent = f, Dim = UDim2.new(1, 0, 1, -4), Pos = UDim2.new(), Text = Config.PowerUps[nombre].Nombre, Size = 14, Color = color })
	f.Parent = filaPU
	activos[nombre] = { f = f, barra = barra, fin = os.clock() + dur, dur = dur }
end

-- velo de daño y pantalla de caído
local velo = Instance.new("Frame"); velo.Size = UDim2.fromScale(1, 1); velo.BackgroundColor3 = Color3.fromRGB(150, 0, 0); velo.BackgroundTransparency = 1; velo.BorderSizePixel = 0; velo.Parent = gui
local lblCaido = texto({ Pos = UDim2.fromScale(0.5, 0.62), Dim = UDim2.fromOffset(600, 40), Anchor = Vector2.new(0.5, 0.5), Size = 26, Color = Color3.fromRGB(255, 120, 100) })
local negro = Instance.new("Frame"); negro.Size = UDim2.fromScale(1, 1); negro.BackgroundColor3 = Color3.new(0, 0, 0); negro.BackgroundTransparency = 1; negro.BorderSizePixel = 0; negro.ZIndex = 5; negro.Parent = gui

-- ================================================================ armas: estado local
local armaActual, cfgActual, datosActual
local disparando = false
local ultimoDisparo = 0
local clipsActivos = {} -- tool → {clip, t0, dur}
local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude

local function datosDe(tool)
	local d = tool:FindFirstChild("Datos")
	if not d then return nil end
	if not tool:GetAttribute("_ok") then tool:SetAttribute("_ok", true) end
	local ok, v = pcall(HS.JSONDecode, HS, d.Value)
	return ok and v or nil
end
local cacheDatos = setmetatable({}, { __mode = "k" })
local function datos(tool) cacheDatos[tool] = cacheDatos[tool] or datosDe(tool); return cacheDatos[tool] end

local function reproducirClip(tool, nombre, dur)
	local d = datos(tool); if not d or not d.clips or not d.clips[nombre] then return end
	local clip = d.clips[nombre]
	clipsActivos[tool] = { clip = clip, t0 = os.clock(), escala = dur and (clip.dur / dur) or 1 }
end

local function aplicarClips()
	for tool, st in clipsActivos do
		if not tool.Parent then clipsActivos[tool] = nil; continue end
		local t = (os.clock() - st.t0) * st.escala
		local fin = t >= st.clip.dur
		if fin then t = st.clip.dur end
		local h = tool:FindFirstChild("Handle")
		for nombre, pista in st.clip.pistas do
			local cf, vis = Anim.muestraPista(pista, t)
			if nombre == "raiz" then
				local mano = tool.Parent and tool.Parent:FindFirstChild("RightHand")
				local w = mano and mano:FindFirstChild("RightGrip")
				if w then w.C1 = cf:Inverse() * tool.Grip end
			else
				local m = h and h:FindFirstChild(nombre)
				if m and m:IsA("Motor6D") then
					if pista.pivote then
						local pv = Anim.v2r(pista.pivote)
						local g = m.C0.Position
						cf = CFrame.new(pv - g) * cf * CFrame.new(g - pv)
					end
					m.Transform = cf
					local piv = m.Part1
					for _, p in tool:GetChildren() do
						if p:IsA("MeshPart") and p:GetAttribute("Grupo") == nombre then p.LocalTransparencyModifier = vis and 0 or 1 end
					end
				end
			end
		end
		if fin then
			clipsActivos[tool] = nil
			local mano = tool.Parent and tool.Parent:FindFirstChild("RightHand")
			local w = mano and mano:FindFirstChild("RightGrip")
			if w then w.C1 = tool.Grip end
		end
	end
end

-- efectos locales de disparo
local function trazo(a, b, color, ancho)
	local d = (b - a).Magnitude
	if d < 0.5 then return end
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = color or Color3.fromRGB(255, 220, 140); p.Transparency = 0.3
	p.Size = Vector3.new(ancho or 0.07, ancho or 0.07, d); p.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
	p.Parent = workspace
	TS:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.15)
end
local function fogonazo(pos, color)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false; p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon; p.Color = color or Color3.fromRGB(255, 190, 80); p.Size = Vector3.new(0.6, 0.6, 0.6); p.Position = pos
	local l = Instance.new("PointLight", p); l.Color = p.Color; l.Range = 10; l.Brightness = 3
	p.Parent = workspace
	Debris:AddItem(p, 0.05)
end
local function bocaDe(tool)
	local h = tool:FindFirstChild("Handle")
	local a = h and h:FindFirstChild("boca")
	return a and a.WorldPosition or (h and h.Position) or cam.CFrame.Position
end

-- ================================================================ disparo
local function dispersion(dir, grados)
	if grados <= 0 then return dir end
	local r = rad(grados) * math.sqrt(math.random())
	local a = math.random() * math.pi * 2
	local cf = CFrame.lookAt(Vector3.zero, dir)
	return (cf * CFrame.Angles(math.sin(a) * r, math.cos(a) * r, 0)).LookVector
end

local function apuntar()
	local mpos = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mpos.X, mpos.Y)
	local ex = { workspace:FindFirstChild("Ceniza_Mapa") and workspace.Ceniza_Mapa.Visual }
	if yo.Character then table.insert(ex, yo.Character) end
	params.FilterDescendantsInstances = ex
	local r = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return r and r.Position or ray.Origin + ray.Direction * 1000
end

local function disparar()
	local tool = armaActual
	if not tool or not cfgActual or yo:GetAttribute("Bebiendo") then return end
	if (tool:GetAttribute("Recargando") or 0) > 0 then return end
	local ahora = os.clock()
	if ahora - ultimoDisparo < 60 / cfgActual.cadencia then return end
	if tool:GetAttribute("Municion") <= 0 then
		if tool:GetAttribute("Reserva") > 0 then Accion:FireServer("Recargar", tool) end
		return
	end
	ultimoDisparo = ahora
	local boca = bocaDe(tool)
	local objetivo = apuntar()
	local dir = (objetivo - boca).Unit
	local dirs = {}
	local n = cfgActual.perdigones
	if cfgActual.modo == "llama" then n = 1 end
	local disp = cfgActual.dispersion
	if yo.Character and yo.Character:FindFirstChildOfClass("Humanoid") and yo.Character.Humanoid.MoveDirection.Magnitude > 0.1 then disp *= 1.6 end
	for i = 1, n do table.insert(dirs, dispersion(dir, disp)) end
	Accion:FireServer("Disparar", tool, boca, dirs)
	reproducirClip(tool, "disparo")
	if cfgActual.modo == "llama" then
		local fin = boca + dir * cfgActual.alcance
		trazo(boca, fin, Color3.fromRGB(255, 120, 30), 1.2)
	else
		fogonazo(boca, cfgActual.mejorada and Color3.fromRGB(190, 120, 255) or nil)
		for _, d in dirs do
			local fin = workspace:Raycast(boca, d * (cfgActual.alcance or 300), params)
			trazo(boca, fin and fin.Position or boca + d * 120, cfgActual.mejorada and Color3.fromRGB(200, 140, 255) or nil, cfgActual.modo == "haz" and 0.25 or nil)
		end
	end
	-- retroceso de cámara
	cam.CFrame = cam.CFrame * CFrame.Angles(rad(math.min(2.5, 0.25 + cfgActual.dano / 120)), 0, 0)
	if cfgActual.rafaga and not disparando then
		task.spawn(function()
			for i = 2, cfgActual.rafaga do task.wait(0.06); ultimoDisparo = 0; disparar() end
		end)
	end
end

local function equipar(tool)
	armaActual = tool
	cfgActual = tool and Config.Armas[tool:GetAttribute("ArmaId")] or nil
	if tool then datosActual = datos(tool) end
end

-- entradas
UIS.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then
		disparando = true
		if cfgActual and not cfgActual.auto then disparar() end
	elseif inp.KeyCode == Enum.KeyCode.R then
		if armaActual then Accion:FireServer("Recargar", armaActual) end
	elseif inp.KeyCode == Enum.KeyCode.V or inp.KeyCode == Enum.KeyCode.F then
		Accion:FireServer("Golpe")
	elseif inp.KeyCode == Enum.KeyCode.G then
		Accion:FireServer("Granada", (apuntar() - cam.CFrame.Position).Unit)
	elseif inp.KeyCode == Enum.KeyCode.Space then
		-- doble salto con Zancada Lunar
		local c = yo.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
		if h and yo:GetAttribute("Perk_ZancadaLunar") and h.FloorMaterial == Enum.Material.Air and not c:GetAttribute("DobleUsado") then
			c:SetAttribute("DobleUsado", true)
			c.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(c.HumanoidRootPart.AssemblyLinearVelocity.X, 52, c.HumanoidRootPart.AssemblyLinearVelocity.Z)
		end
	end
end)
UIS.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then disparando = false end
end)

-- ================================================================ personajes: equipo, aterrizajes
local alturaMax = 0
local function nuevoPersonaje(c)
	local h = c:WaitForChild("Humanoid", 10); if not h then return end
	c.ChildAdded:Connect(function(x) if x:IsA("Tool") then equipar(x) end end)
	c.ChildRemoved:Connect(function(x) if x == armaActual then equipar(nil) end end)
	h.StateChanged:Connect(function(_, nuevo)
		if nuevo == Enum.HumanoidStateType.Freefall then alturaMax = c.HumanoidRootPart.Position.Y
		elseif nuevo == Enum.HumanoidStateType.Landed then
			local caida = alturaMax - c.HumanoidRootPart.Position.Y
			if c:GetAttribute("DobleUsado") or caida > 6 then Accion:FireServer("Aterrizaje", caida + (c:GetAttribute("DobleUsado") and 3 or 0)) end
			c:SetAttribute("DobleUsado", nil)
		end
	end)
	for _, x in c:GetChildren() do if x:IsA("Tool") then equipar(x) end end
	negro.BackgroundTransparency = 1
end
yo.CharacterAdded:Connect(nuevoPersonaje)
if yo.Character then task.spawn(nuevoPersonaje, yo.Character) end

-- ================================================================ animación de personajes (sobrevivientes) y zombis
local estadoAnim = setmetatable({}, { __mode = "k" })
local POSES = {
	corta = { RightUpperArm = { 84, 8, 0 }, RightLowerArm = { 6, 0, 0 }, LeftUpperArm = { 80, -38, 0 }, LeftLowerArm = { 14, 0, 0 } },
	larga = { RightUpperArm = { 62, 18, 0 }, RightLowerArm = { 28, 0, 0 }, LeftUpperArm = { 74, -40, 0 }, LeftLowerArm = { 20, 0, 0 } },
	hombro = { RightUpperArm = { 40, 30, 0 }, RightLowerArm = { 50, 0, 0 }, LeftUpperArm = { 70, -30, 0 }, LeftLowerArm = { 25, 0, 0 } },
}
local function animarSobreviviente(c, dt)
	local h = c:FindFirstChildOfClass("Humanoid"); local raiz = c:FindFirstChild("HumanoidRootPart")
	if not h or not raiz then return end
	local st = estadoAnim[c]
	if not st then st = { t = 0, clip = "Reposo", mot = Anim.motores(c), tipo = c:GetAttribute("Sobreviviente") or "S_Operador", prev = {} }; estadoAnim[c] = st end
	local v = raiz.AssemblyLinearVelocity; local vel = Vector3.new(v.X, 0, v.Z).Magnitude
	local plr = Players:GetPlayerFromCharacter(c)
	local clip = "Reposo"
	if plr and plr:GetAttribute("Caido") then clip = "Deslizar"
	elseif vel > 20 then clip = "Sprint" elseif vel > 8 then clip = "Trote" elseif vel > 0.8 then clip = "Andar" end
	if clip ~= st.clip then st.clip = clip; st.t = 0; st.mezcla = 0 end
	local pose, an = Anim.poseSobreviviente(st.tipo, clip, st.t)
	local ritmo = 1
	if an and an.velocidad and an.velocidad > 0 then ritmo = math.clamp(vel / an.velocidad, 0.5, 1.8) end
	if clip == "Deslizar" then st.t = math.min(st.t + dt, 0.8) else st.t += dt * ritmo end
	st.mezcla = math.min(1, (st.mezcla or 1) + dt * 6)
	for hueso, cf in pose do
		local m = st.mot[hueso]
		if hueso == "raiz" then
			local r = st.mot.LowerTorso
			if r then r.Transform = CFrame.new(cf) * (pose.LowerTorso or CFrame.identity) end
		elseif m and hueso ~= "LowerTorso" then
			m.Transform = (st.prev[hueso] or cf):Lerp(cf, st.mezcla)
			st.prev[hueso] = m.Transform
		end
	end
	-- brazos: pose de apuntar con el arma
	local tool = c:FindFirstChildOfClass("Tool")
	local cfg = tool and Config.Armas[tool:GetAttribute("ArmaId") or ""]
	local pitch = 0
	if c == yo.Character then
		local look = cam.CFrame.LookVector
		pitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))
		-- el cuerpo gira hacia donde apunta la cámara cuando hay arma
		if cfg then
			local plano = Vector3.new(look.X, 0, look.Z)
			if plano.Magnitude > 0.1 and h.MoveDirection.Magnitude < 0.1 then
				raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + plano)
			end
			h.AutoRotate = h.MoveDirection.Magnitude > 0.1
		else
			h.AutoRotate = true
		end
	end
	local pa = cfg and POSES[cfg.clase] or nil
	for _, nombre in { "RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm" } do
		local m = st.mot[nombre]
		if m then
			if pa then
				local e = pa[nombre]
				local extra = (nombre == "RightUpperArm" or nombre == "LeftUpperArm") and pitch or 0
				m.Transform = CFrame.fromEulerAnglesYXZ(rad(e[1] + extra), rad(e[2]), rad(e[3]))
			else
				local balanceo = (clip ~= "Reposo") and math.sin(st.t * 7) * 25 * (nombre == "LeftUpperArm" and 1 or nombre == "RightUpperArm" and -1 or 0) or 0
				m.Transform = CFrame.fromEulerAnglesYXZ(rad(balanceo + (nombre:find("Lower") and 10 or 0)), 0, rad(nombre:find("Left") and -4 or 4))
			end
		end
	end
	local cuello = st.mot.Head
	if cuello and pa then cuello.Transform = cuello.Transform * CFrame.Angles(rad(pitch * 0.4), 0, 0) end
end

local function animarZombi(m, dt)
	local h = m:FindFirstChildOfClass("Humanoid"); local raiz = m:FindFirstChild("HumanoidRootPart")
	if not h or not raiz then return end
	local st = estadoAnim[m]
	if not st then st = { t = 0, mot = Anim.motores(m), estado = "", H = h.HipHeight + raiz.Size.Y / 2 }; estadoAnim[m] = st end
	local estado = m:GetAttribute("Estado") or "Mover"
	local clip
	local ritmo = 1
	if estado == "Aparecer" then clip = "Aparecer"
	elseif estado == "Morir" then clip = "Morir"
	else
		local v = raiz.AssemblyLinearVelocity; local vel = Vector3.new(v.X, 0, v.Z).Magnitude
		clip = m:GetAttribute("Anim") or "Caminar"
		local base = Anim.Zombis[clip] and Anim.Zombis[clip].velocidadBase or 6
		if vel < 0.4 then clip = "Quieto" else ritmo = math.clamp(vel / base, 0.4, 2) end
	end
	if m:GetAttribute("Congelado") then ritmo = 0 end
	if clip ~= st.clip then st.clip = clip; st.t = 0 end
	st.t += dt * ritmo
	local pose = Anim.poseZombi(clip, st.t)
	for parte, v in pose do
		local mo = st.mot[parte]
		if mo then
			if v[2] then mo.Transform = CFrame.new(v[2] * st.H) * v[1] else mo.Transform = v[1] end
		end
	end
	-- golpe: zarpazo con los brazos
	local g = m:GetAttribute("Golpe")
	if g then
		local dtG = os.clock() - (st.golpeLocal or -9)
		if st.ultimoGolpe ~= g then st.ultimoGolpe = g; st.golpeLocal = os.clock(); dtG = 0 end
		if dtG < 0.45 then
			local k = math.sin(dtG / 0.45 * math.pi)
			for _, n in { "RightUpperArm", "LeftUpperArm" } do
				local mo = st.mot[n]
				if mo then mo.Transform = mo.Transform * CFrame.Angles(rad(-70 * k), 0, 0) end
			end
		end
	end
	-- marcados (Ojo de Cuervo / Cámaras) y Apagón
	local hl = m:FindFirstChild("Marca")
	local quiere = workspace:GetAttribute("Apagon") or ((m:GetAttribute("Marcado") or 0) > workspace:GetServerTimeNow())
	if quiere and not hl then
		hl = Instance.new("Highlight"); hl.Name = "Marca"; hl.FillTransparency = 0.6; hl.OutlineColor = Color3.fromRGB(255, 170, 40)
		hl.FillColor = workspace:GetAttribute("Apagon") and Color3.fromRGB(255, 60, 40) or Color3.fromRGB(255, 170, 40); hl.Parent = m
	elseif not quiere and hl then hl:Destroy() end
end

local carpetaZ = workspace:WaitForChild("Zombis", 30)
local cuadro = 0
RunService.RenderStepped:Connect(function(dt)
	cuadro += 1
	local pc = cam.CFrame.Position
	if carpetaZ then
		for _, m in carpetaZ:GetChildren() do
			local r = m:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - pc).Magnitude
				if d < 70 or (d < 180 and cuadro % 3 == 0) then pcall(animarZombi, m, d < 70 and dt or dt * 3) end
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then pcall(animarSobreviviente, p.Character, dt) end
	end
	aplicarClips()
	if disparando and cfgActual and cfgActual.auto then disparar() end
end)

-- ================================================================ HUD por cuadro
RunService.Heartbeat:Connect(function()
	lblPuntos.Text = tostring(yo:GetAttribute("Puntos") or 0)
	local r = workspace:GetAttribute("Ronda") or 0
	lblRonda.Text = r > 0 and tostring(r) or ""
	if armaActual and cfgActual then
		lblArma.Text = cfgActual.nombre .. ((armaActual:GetAttribute("Recargando") or 0) > 0 and "  · recargando" or "")
		lblMun.Text = string.format("%d / %d", armaActual:GetAttribute("Municion") or 0, armaActual:GetAttribute("Reserva") or 0)
		lblMun.TextColor3 = (armaActual:GetAttribute("Municion") or 0) == 0 and Color3.fromRGB(255, 80, 60) or Color3.new(1, 1, 1)
	else lblArma.Text = ""; lblMun.Text = "" end
	lblGranadas.Text = "Granadas: " .. (yo:GetAttribute("Granadas") or 0) .. "   [G]   Cuchillo [V]   Recargar [R]"
	for n, a in activos do
		local resta = a.fin - os.clock()
		if resta <= 0 then a.f:Destroy(); activos[n] = nil else a.barra.Size = UDim2.new(resta / a.dur, 0, 0, 4) end
	end
	if yo:GetAttribute("Caido") then
		lblCaido.Text = "¡CAÍDO! Esperá que te reanimen · " .. (yo:GetAttribute("TiempoCaido") or 30) .. " s"
		velo.BackgroundTransparency = 0.55
	else
		lblCaido.Text = ""
		local h = yo.Character and yo.Character:FindFirstChildOfClass("Humanoid")
		if h then velo.BackgroundTransparency = 1 - math.clamp((1 - h.Health / h.MaxHealth) * 0.6, 0, 0.5) end
	end
	-- misión
	local ms = workspace:GetAttribute("Mision")
	if ms then
		local ok, t = pcall(HS.JSONDecode, HS, ms)
		if ok and t.paso and t.paso > 0 then
			local nombres = { "El último boleto", "Varilla de ceniza", "Varilla de escarcha", "Varilla de llama", "La llave de maniobra", "La locomotora", "Señales en verde", "El recorrido", "El núcleo", "Último recorrido", "Completado" }
			local s = "Último Recorrido · paso " .. t.paso .. ": " .. (nombres[t.paso] or "")
			if t.hoja then s ..= "\nHoja de ruta: " .. table.concat(t.hoja, " → ") end
			s ..= string.format("\nVarillas: %s %s %s · Llave: %s · Semáforos: %d/4", t.varillas[1] and "Ceniza✓" or "Ceniza·", t.varillas[2] and "Escarcha✓" or "Escarcha·", t.varillas[3] and "Llama✓" or "Llama·", t.llave and "✓" or "·", t.semaforos or 0)
			local fp = workspace:GetAttribute("FinalProgreso")
			if fp and t.paso >= 10 and t.paso < 11 then s ..= string.format("\nNúcleo: %d %%", fp * 100) end
			lblMision.Text = s
		else lblMision.Text = "" end
	end
end)

-- ================================================================ efectos
local function esfera(pos, radio, color, dur, transp)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false; p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon; p.Color = color; p.Transparency = transp or 0.3; p.Size = Vector3.new(1, 1, 1); p.Position = pos
	p.Parent = workspace
	TS:Create(p, TweenInfo.new(dur or 0.4), { Size = Vector3.new(radio * 2, radio * 2, radio * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, (dur or 0.4) + 0.05)
	return p
end
local function nube(pos, color, n, dur)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.Transparency = 1; p.Size = Vector3.new(1, 1, 1); p.Position = pos; p.Parent = workspace
	local e = Instance.new("ParticleEmitter"); e.Color = ColorSequence.new(color); e.Size = NumberSequence.new(1.5, 4); e.Transparency = NumberSequence.new(0.3, 1)
	e.Lifetime = NumberRange.new(1, 2); e.Speed = NumberRange.new(2, 6); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0; e.Parent = p
	e:Emit(n or 20)
	Debris:AddItem(p, dur or 3)
end

Evento.OnClientEvent:Connect(function(tipo, a, b, c, d, e)
	if tipo == "Aviso" then aviso(a, b)
	elseif tipo == "Puntos" then
		if a ~= 0 then
			local t = texto({ Pos = UDim2.new(0, 250, 1, -150 - math.random(0, 30)), Dim = UDim2.fromOffset(100, 24), Anchor = Vector2.new(0, 1), Size = 20,
				Text = (a > 0 and "+" or "") .. a, Color = a > 0 and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(255, 90, 80), AlignX = Enum.TextXAlignment.Left })
			TS:Create(t, TweenInfo.new(0.9), { Position = t.Position + UDim2.fromOffset(30, -30), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			Debris:AddItem(t, 1)
			if a > 0 and a <= 130 then marcaGolpe.TextTransparency = 0; TS:Create(marcaGolpe, TweenInfo.new(0.25), { TextTransparency = 1 }):Play() end
		end
	elseif tipo == "Ronda" then
		centro("RONDA " .. a, Color3.fromRGB(200, 30, 20), 3.5)
	elseif tipo == "Golpe" then
		velo.BackgroundTransparency = 0.4
	elseif tipo == "Perk" then
		centro(Config.Perks[a].Nombre, Config.Perks[a].Color, 2)
	elseif tipo == "Beber" then
		centro("Bebiendo " .. Config.Perks[a].Nombre .. "...", Config.Perks[a].Color, 1.6)
	elseif tipo == "PowerUp" then
		powerUpHUD(a, b, c)
		centro(Config.PowerUps[a].Nombre, c, 2)
	elseif tipo == "Recarga" then
		if b and b.Parent then reproducirClip(b, "recarga", c) end
	elseif tipo == "Fin" then
		local filas = {}
		for _, f in b do table.insert(filas, string.format("%s · %d bajas · %d puntos", f[1], f[2], f[3])) end
		centro("FIN DE LA PARTIDA · Ronda " .. a, Color3.fromRGB(220, 40, 30), 10)
		aviso(table.concat(filas, "\n"), Color3.fromRGB(255, 220, 200))
		TS:Create(negro, TweenInfo.new(3), { BackgroundTransparency = 0.2 }):Play()
	elseif tipo == "Final" then
		centro("ÚLTIMO RECORRIDO COMPLETADO", Color3.fromRGB(255, 200, 120), 8)
	elseif tipo == "FX" then
		if a == "Disparo" then
			local plr, origen, puntos, modo = b, c, d, e
			if plr ~= yo then
				for _, p in puntos do trazo(origen, p, modo == "haz" and Color3.fromRGB(120, 220, 255) or nil) end
				if plr and plr.Character then
					local t = plr.Character:FindFirstChildOfClass("Tool"); if t then reproducirClip(t, "disparo") end
				end
			end
		elseif a == "Explosion" then
			esfera(b, c, Color3.fromRGB(255, 140, 40), 0.45, 0.1)
			nube(b, Color3.fromRGB(60, 55, 50), 25, 3)
			local dist = (cam.CFrame.Position - b).Magnitude
			if dist < 40 then cam.CFrame *= CFrame.Angles(rad(math.random(-2, 2)), rad(math.random(-2, 2)), 0) end
		elseif a == "Rayo" then
			local p0, p1 = b, c
			local prev = p0
			for i = 1, 5 do
				local q = p0:Lerp(p1, i / 5) + (i < 5 and Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6 or Vector3.zero)
				trazo(prev, q, Color3.fromRGB(140, 200, 255), 0.18); prev = q
			end
		elseif a == "Remolino" then
			local p = esfera(b, c, Color3.fromRGB(80, 70, 60), d, 0.4)
			nube(b, Color3.fromRGB(70, 60, 55), 60, d + 2)
		elseif a == "Llama" then
			local plr, origen, dir, alcance = b, c, d, e
			if plr ~= yo then trazo(origen, origen + dir * alcance, Color3.fromRGB(255, 120, 30), 1.2) end
		elseif a == "Vapor" then nube(b, Color3.fromRGB(220, 230, 240), 12, 2.5)
		elseif a == "Humo" then nube(b, Color3.fromRGB(40, 40, 45), 30, 3)
		elseif a == "Eco" then esfera(b, 7, Color3.fromRGB(90, 255, 60), c, 0.6)
		elseif a == "Escarcha" then esfera(b, c, Color3.fromRGB(150, 230, 255), 0.6, 0.4)
		elseif a == "Muralla" then esfera(b, c, Color3.fromRGB(255, 80, 40), 0.5, 0.3)
		elseif a == "Luna" then esfera(b, 10, Color3.fromRGB(180, 210, 255), 0.6, 0.4)
		elseif a == "Fuego" then nube(b, Color3.fromRGB(255, 110, 30), 40, 2.5)
		elseif a == "Cebo" then nube(b, Color3.fromRGB(90, 255, 60), 40, c)
		elseif a == "Reanimar" then esfera(b, 3, Color3.fromRGB(120, 255, 160), 1.5, 0.5)
		elseif a == "CajaGira" then esfera(b, 3, Color3.fromRGB(255, 220, 120), 4, 0.6)
		elseif a == "Refinar" then esfera(b, 5, Color3.fromRGB(255, 140, 40), 3.5, 0.5)
		elseif a == "Campana" then esfera(b, 4, Color3.fromRGB(200, 170, 80), 0.6, 0.5)
		end
	end
end)

-- ceniza que cae (se detiene al completar el easter egg)
local cenizaP = Instance.new("Part"); cenizaP.Anchored = true; cenizaP.CanCollide = false; cenizaP.CanQuery = false; cenizaP.Transparency = 1; cenizaP.Size = Vector3.new(80, 1, 80)
local em = Instance.new("ParticleEmitter"); em.Color = ColorSequence.new(Color3.fromRGB(150, 145, 140)); em.Size = NumberSequence.new(0.08); em.Rate = 120
em.Lifetime = NumberRange.new(6, 9); em.Speed = NumberRange.new(2, 3); em.EmissionDirection = Enum.NormalId.Bottom; em.SpreadAngle = Vector2.new(20, 20)
em.LightEmission = 0.1; em.Transparency = NumberSequence.new(0.2); em.Parent = cenizaP
cenizaP.Parent = workspace
RunService.Heartbeat:Connect(function()
	cenizaP.Position = cam.CFrame.Position + Vector3.new(0, 25, 0)
	em.Enabled = not workspace:GetAttribute("SinCeniza")
end)
pintarPerks()
