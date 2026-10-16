-- ServerScriptService.CenizaServidor (Script): arranca todos los servicios del modo zombis
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
local carpeta = script
local N = require(carpeta.Nucleo)
local Z = require(carpeta.Zombis)
local J = require(carpeta.Jugadores)
local A = require(carpeta.ArmasServidor)
local M = require(carpeta.Mapa)
local E = require(carpeta.Efectos)
local R = require(carpeta.Rondas)
local S = require(carpeta.Mision)

workspace:SetAttribute("Ronda", 0)
workspace:SetAttribute("Energia", false)
for _, f in { M.iniciar, E.crearRetos, E.crearObjetos, S.iniciar } do
	local ok, e = pcall(f)
	if not ok then warn("Ceniza inicio: " .. tostring(e)) end
end
-- comandos de prueba (solo con ModoPrueba): workspace:SetAttribute("Comando", json)
workspace:GetAttributeChangedSignal("Comando"):Connect(function()
	if not workspace:GetAttribute("ModoPrueba") then return end
	local ok, c = pcall(N.dejson, workspace:GetAttribute("Comando") or "")
	if not ok or type(c) ~= "table" then return end
	local plr = Players:GetPlayers()[1]
	if c.zombi then
		local d = Z.crear(c.zombi, Vector3.new(c.pos[1], c.pos[2], c.pos[3]), { sinAparecer = c.quieto })
		if c.quieto then d.vel = 0 end
	end
	if c.arma and plr then A.dar(plr, c.arma) end
	if c.puntos and plr then N.sumar(plr, c.puntos) end
	if c.energia then M.encender(plr) end
	if c.matar then Z.matarTodos(nil, true) end
	if c.ronda then N.Ronda = c.ronda - 1 end
	if c.powerup then E.soltar(c.powerup, Vector3.new(c.pos[1], c.pos[2], c.pos[3])) end
	if c.perk and plr then M.aplicarPerk(plr, c.perk) end
	if c.pausa ~= nil then R.pausa = c.pausa end
end)
workspace:SetAttribute("CenizaListo", true)
print("[Ceniza] servidor listo")
