-- ServerScriptService.CenizaServidor.Nucleo: estado compartido, puntos, avisos y utilidades del servidor
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local J = RS:WaitForChild("CenizaJuego")
local Config = require(J.Config)

local N = {}
N.Config = Config
N.Evento = J.Remotes.Evento
N.Accion = J.Remotes.Accion
N.Mapa = workspace:WaitForChild("Ceniza_Mapa")
N.Ronda = 0
N.Energia = false
N.Activos = {} -- power-ups con tiempo: nombre → hora de fin
N.Senales = {} -- nombre → lista de funciones

function N.on(nombre, f)
	N.Senales[nombre] = N.Senales[nombre] or {}
	table.insert(N.Senales[nombre], f)
end
function N.emitir(nombre, ...)
	for _, f in N.Senales[nombre] or {} do
		task.spawn(f, ...)
	end
end

function N.aviso(destino, texto, color)
	if destino == nil then N.Evento:FireAllClients("Aviso", texto, color)
	else N.Evento:FireClient(destino, "Aviso", texto, color) end
end
function N.fx(...) N.Evento:FireAllClients("FX", ...) end

function N.activo(nombre) return (N.Activos[nombre] or 0) > os.clock() end

-- puntos
function N.puntos(plr) return plr:GetAttribute("Puntos") or 0 end
function N.sumar(plr, n, motivo)
	if not plr or not plr.Parent then return end
	if n > 0 then
		if N.activo("BotinDoble") then n *= 2 end
		if N.activo("Apagon") then n *= 3 end
		if N.misaNegra then n *= 2 end
		n = math.floor(n)
		plr:SetAttribute("PuntosRonda", (plr:GetAttribute("PuntosRonda") or 0) + n)
		plr:SetAttribute("PuntosTotales", (plr:GetAttribute("PuntosTotales") or 0) + n)
	end
	plr:SetAttribute("Puntos", N.puntos(plr) + n)
	N.Evento:FireClient(plr, "Puntos", n, motivo)
	N.emitir("Puntos", plr, n)
end
function N.pagar(plr, costo)
	if N.puntos(plr) < costo then
		N.aviso(plr, "No te alcanzan los puntos (" .. costo .. ")", Color3.fromRGB(255, 90, 80))
		return false
	end
	N.sumar(plr, -costo)
	return true
end

-- jugadores vivos (no caídos)
function N.vivos()
	local t = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and not p:GetAttribute("Caido") and c:FindFirstChild("HumanoidRootPart") then table.insert(t, p) end
	end
	return t
end

-- piso: raycast contra la colisión del mapa
local paramsSuelo = RaycastParams.new()
paramsSuelo.FilterType = Enum.RaycastFilterType.Include
paramsSuelo.FilterDescendantsInstances = { N.Mapa.Colision, N.Mapa.Puertas }
N.paramsSuelo = paramsSuelo
function N.suelo(pos, alto)
	local r = workspace:Raycast(pos + Vector3.new(0, alto or 6, 0), Vector3.new(0, -(alto or 6) - 30, 0), paramsSuelo)
	return r and r.Position or nil
end
-- busca un hueco libre cerca de pos (sin paredes en una caja tam)
function N.colocar(pos, tam)
	tam = tam or Vector3.new(3, 5, 3)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { N.Mapa.Colision }
	for radio = 0, 14, 2 do
		local pasos = radio == 0 and 1 or 10
		for k = 0, pasos - 1 do
			local a = k / pasos * math.pi * 2
			local p = pos + Vector3.new(math.cos(a) * radio, 0, math.sin(a) * radio)
			local s = N.suelo(p, 5)
			if s and math.abs(s.Y - pos.Y) < 6 then
				local libres = workspace:GetPartBoundsInBox(CFrame.new(s + Vector3.new(0, tam.Y / 2 + 0.3, 0)), tam, op)
				if #libres == 0 then return s end
			end
		end
	end
	return N.suelo(pos, 5) or pos
end

-- ProximityPrompt en una parte
N.prompts = setmetatable({}, { __mode = "k" })
function N.prompt(parte, accion, objeto, duracion, f, distancia)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = accion; pp.ObjectText = objeto or ""
	pp.HoldDuration = duracion or 0; pp.MaxActivationDistance = distancia or 8
	pp.RequiresLineOfSight = false
	pp.Parent = parte
	pp.Triggered:Connect(function(plr) f(plr, pp) end)
	N.prompts[pp] = f
	return pp
end

-- parte simple anclada
function N.parte(props)
	local p = Instance.new(props.Clase or "Part")
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do if k ~= "Clase" then p[k] = v end end
	return p
end

function N.json(v) return HS:JSONEncode(v) end
function N.dejson(s) return HS:JSONDecode(s) end
return N
