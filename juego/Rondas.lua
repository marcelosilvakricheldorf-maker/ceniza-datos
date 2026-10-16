-- ServerScriptService.CenizaServidor.Rondas: bucle de rondas, aparición de especiales y jefes, fin de partida
local Players = game:GetService("Players")
local N = require(script.Parent.Nucleo)
local Z = require(script.Parent.Zombis)
local J = require(script.Parent.Jugadores)
local Config = N.Config

local R = {}
R.pendientes = 0
R.jefesPendientes = {}
local terminado = false

function R.totalRonda(r)
	local np = math.max(1, #Players:GetPlayers())
	local base = ({ 6, 8, 13, 18 })[r] or math.floor(24 * (1 + (r - 5) * 0.15))
	if np > 1 then base = math.floor(base * (1 + (np - 1) * 0.5)) end
	return base
end

function R.agregarJefe(tipo, pos) table.insert(R.jefesPendientes, { tipo = tipo, pos = pos }) end

local function elegirTipo(r)
	for nombre, e in Config.Especiales do
		if r >= e.Desde and math.random() < 0.05 + math.min(0.06, (r - e.Desde) * 0.005) then return nombre end
	end
	return "Comun"
end

local function partida()
	while true do
		-- espera jugadores
		while #N.vivos() == 0 do task.wait(1) end
		terminado = false
		N.Ronda = 0
		while not terminado do
			N.Ronda += 1
			local r = N.Ronda
			workspace:SetAttribute("Ronda", r)
			for _, p in Players:GetPlayers() do p:SetAttribute("PuntosRonda", 0) end
			N.emitir("NuevaRonda", r)
			N.Evento:FireAllClients("Ronda", r)
			-- reaparecen los muertos
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("Muerto") or not p.Character then J.aparecer(p) end
			end
			task.wait(r == 1 and 3 or 8)
			R.pendientes = R.totalRonda(r)
			local maxVivos = 24
			while not terminado and (R.pendientes > 0 or Z.vivos() > 0 or #R.jefesPendientes > 0) do
				if #R.jefesPendientes > 0 then
					local j = table.remove(R.jefesPendientes, 1)
					local s = j.pos and N.colocar(j.pos) or Z.puntoAparicion()
					if s then Z.crear(j.tipo, s); N.aviso(nil, "¡Mini jefe: " .. j.tipo .. "!", Color3.fromRGB(255, 120, 60)) end
				end
				if R.pendientes > 0 and Z.vivos() < maxVivos then
					local s = Z.puntoAparicion()
					if s then
						local tipo = elegirTipo(r)
						local dorado = false
						for _, p in Players:GetPlayers() do if p:GetAttribute("Sobre_FiebreDeOro") and math.random() < 0.02 then dorado = true end end
						Z.crear(tipo, s, { dorado = dorado })
						R.pendientes -= 1
					end
				end
				task.wait(math.max(0.35, 2 - r * 0.08))
			end
			if terminado then break end
			N.emitir("FinRonda", r)
			N.misaNegra = N.misaProxima; N.misaProxima = nil
			if N.misaNegra then N.aviso(nil, "Misa negra: zombis más rápidos y puntos ×2", Color3.fromRGB(200, 60, 255)) end
		end
		-- fin de partida
		local resumen = {}
		for _, p in Players:GetPlayers() do table.insert(resumen, { p.Name, p:GetAttribute("Bajas") or 0, p:GetAttribute("PuntosTotales") or 0 }) end
		N.Evento:FireAllClients("Fin", N.Ronda, resumen)
		Z.matarTodos(nil, true)
		task.wait(14)
		N.emitir("Reiniciar")
		for _, p in Players:GetPlayers() do
			for _, k in { "Puntos", "Bajas", "Cabezas", "PuntosTotales" } do p:SetAttribute(k, k == "Puntos" and 500 or 0) end
			for _, t in p.Backpack:GetChildren() do t:Destroy() end
			if p.Character then p.Character:Destroy() end
			J.aparecer(p)
		end
	end
end

N.on("TodosCaidos", function()
	task.wait(0.5)
	if #N.vivos() == 0 then terminado = true end
end)

task.spawn(partida)
return R
