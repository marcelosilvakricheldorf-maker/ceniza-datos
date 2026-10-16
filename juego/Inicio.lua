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
workspace:SetAttribute("CenizaListo", true)
print("[Ceniza] servidor listo")
