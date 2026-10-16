-- Instala los scripts del modo zombis (desde juego/ del repo) y los datos de animación
local C = _G.Ceniza
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer")
local REV = _G.CenizaREV
local function fuente(n) return HS:GetAsync("https://raw.githubusercontent.com/marcelosilvakricheldorf-maker/ceniza-datos/" .. REV .. "/juego/" .. n .. ".lua", true) end
local function script(clase, nombre, padre, src)
	local s = padre:FindFirstChild(nombre)
	if s and s.ClassName ~= clase then s:Destroy(); s = nil end
	if not s then s = Instance.new(clase); s.Name = nombre end
	s.Source = src
	s.Parent = padre
	return s
end
local J = RS:FindFirstChild("CenizaJuego") or Instance.new("Folder"); J.Name = "CenizaJuego"; J.Parent = RS
local rem = J:FindFirstChild("Remotes") or Instance.new("Folder", J); rem.Name = "Remotes"
for _, n in { "Evento", "Accion" } do if not rem:FindFirstChild(n) then local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = rem end end
for _, n in { "Config", "Armas", "Anim" } do script("ModuleScript", n, J, fuente(n)) end
-- datos de animación
local datos = J:FindFirstChild("Datos") or Instance.new("Folder", J); datos.Name = "Datos"
if _G.CenizaReDatos or #datos:GetChildren() == 0 then
	datos:ClearAllChildren()
	local A = C.jsonBin("animaciones.b64")
	for nombre, clip in A.zombis do
		if nombre ~= "_convencion" then
			local v = Instance.new("StringValue"); v.Name = "Z_" .. nombre; v.Value = HS:JSONEncode(clip); v.Parent = datos
		end
	end
	local nombres = { "S_Operador", "S_RiesgoBiologico", "S_FuerzasEspeciales", "S_Cientifico" }
	for i = 0, 3 do
		local v = Instance.new("StringValue"); v.Name = nombres[i + 1]; v.Value = HS:JSONEncode(A.sobrevivientes[tostring(i)]); v.Parent = datos
	end
end
local srv = script("Script", "CenizaServidor", SSS, fuente("Inicio"))
for _, n in { "Nucleo", "Zombis", "Jugadores", "ArmasServidor", "Rondas", "Mapa", "Efectos", "Mision" } do script("ModuleScript", n, srv, fuente(n)) end
script("LocalScript", "CenizaCliente", SP.StarterPlayerScripts, fuente("Cliente"))
SP.CameraMaxZoomDistance = 20
SP.CharacterWalkSpeed = 16
return "instalado"
