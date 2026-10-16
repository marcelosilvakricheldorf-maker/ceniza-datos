-- ReplicatedStorage.CenizaJuego.Anim: animaciones procedurales del visor (zombis, sobrevivientes y clips de armas) aplicadas a Motor6D.Transform
local HS = game:GetService("HttpService")
local Datos = script.Parent:WaitForChild("Datos")
local Anim = {}
local rad = math.rad

-- ---------------------------------------------------------------- utilidades
local function curva(e, t)
	if e == "in" then return t * t
	elseif e == "out" or e == "golpe" then return 1 - (1 - t) ^ 3
	elseif e == "inout" or e == "suave" then return t * t * (3 - 2 * t)
	elseif e == "resorte" then return 1 - math.cos(t * math.pi * 2.2) * math.exp(-4.5 * t)
	end
	return t
end
Anim.curva = curva

local function motores(modelo)
	local t = {}
	for _, m in modelo:GetDescendants() do
		if m:IsA("Motor6D") and m.Part1 then t[m.Part1.Name] = m end
	end
	return t
end
Anim.motores = motores

-- ---------------------------------------------------------------- zombis (claves con Euler YXZ en grados, 'o' en múltiplos de H)
local Z = {}
for _, v in Datos:GetChildren() do
	if string.sub(v.Name, 1, 2) == "Z_" then Z[string.sub(v.Name, 3)] = HS:JSONDecode(v.Value) end
end
Anim.Zombis = Z

-- devuelve {parte = CFrame} del clip en el tiempo t
function Anim.poseZombi(nombre, t)
	local c = Z[nombre]; if not c then return {} end
	local claves = c.claves
	local dur = c.duracion
	if c.bucle then t = t % dur else t = math.min(t, dur) end
	local i = 1
	while claves[i + 1] and claves[i + 1].t <= t do i += 1 end
	local a, b = claves[i], claves[i + 1] or claves[i]
	local f = 0
	if b ~= a and b.t > a.t then f = curva(a.e, (t - a.t) / (b.t - a.t)) end
	local out = {}
	for parte, pa in a.p do
		local pb = b.p[parte] or pa
		local ra, rb = pa.r or { 0, 0, 0 }, pb.r or { 0, 0, 0 }
		local x, y, z = ra[1] + (rb[1] - ra[1]) * f, ra[2] + (rb[2] - ra[2]) * f, ra[3] + (rb[3] - ra[3]) * f
		local cf = CFrame.fromEulerAnglesYXZ(rad(x), rad(y), rad(z))
		if pa.o then
			local oa, ob = pa.o, pb.o or pa.o
			out[parte] = { cf, Vector3.new(oa[1] + (ob[1] - oa[1]) * f, oa[2] + (ob[2] - oa[2]) * f, oa[3] + (ob[3] - oa[3]) * f) }
		else
			out[parte] = { cf }
		end
	end
	return out
end

-- ---------------------------------------------------------------- sobrevivientes (cuadros de cuaterniones a 30 fps)
local S = {}
for _, v in Datos:GetChildren() do
	if string.sub(v.Name, 1, 2) == "S_" then
		local d = HS:JSONDecode(v.Value)
		local por = {}
		for _, an in d.animaciones do por[an.nombre] = an end
		S[v.Name] = { fps = d.fps, clips = por }
	end
end
Anim.Sobrevivientes = S

local function cuadro(c)
	local t = {}
	for hueso, q in c do
		if hueso == "raiz" then t.raiz = Vector3.new(q[1], q[2], q[3])
		else t[hueso] = CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4]) end
	end
	return t
end
local cache = setmetatable({}, { __mode = "k" })
function Anim.poseSobreviviente(tipo, clip, t)
	local s = S[tipo] or S.S_Operador; if not s then return {} end
	local an = s.clips[clip]; if not an then return {} end
	local n = #an.cuadros
	local dur = an.dur
	if an.bucle then t = t % dur else t = math.min(t, dur) end
	local x = t / dur * (n - 1)
	local i = math.floor(x) + 1
	local f = x - (i - 1)
	local ca = an.cuadros[i]; local cb = an.cuadros[math.min(i + 1, n)]
	cache[ca] = cache[ca] or cuadro(ca); cache[cb] = cache[cb] or cuadro(cb)
	local A, B = cache[ca], cache[cb]
	local out = {}
	for k, v in A do
		if k == "raiz" then out.raiz = v:Lerp(B.raiz or v, f) else out[k] = v:Lerp(B[k] or v, f) end
	end
	return out, an
end

-- ---------------------------------------------------------------- clips de armas (ejes de la vista: X adelante, Y arriba, Z derecha)
local function v2r(p) return Vector3.new(p[3], p[2], -p[1]) end
Anim.v2r = v2r
local function rotVista(a)
	return CFrame.Angles(0, 0, rad(-a[1])) * CFrame.Angles(0, rad(a[2]), 0) * CFrame.Angles(rad(a[3]), 0, 0)
end
function Anim.muestraPista(pista, t)
	local k = pista.k
	local i = 1
	while k[i + 1] and k[i + 1].t <= t do i += 1 end
	local a, b = k[i], k[i + 1] or k[i]
	local f = 0
	if b ~= a and b.t > a.t then f = curva(a.e, math.clamp((t - a.t) / (b.t - a.t), 0, 1)) end
	local o = (a.o and b.o) and { a.o[1] + (b.o[1] - a.o[1]) * f, a.o[2] + (b.o[2] - a.o[2]) * f, a.o[3] + (b.o[3] - a.o[3]) * f } or { 0, 0, 0 }
	local r = (a.a and b.a) and { a.a[1] + (b.a[1] - a.a[1]) * f, a.a[2] + (b.a[2] - a.a[2]) * f, a.a[3] + (b.a[3] - a.a[3]) * f } or { 0, 0, 0 }
	local vis = (a.v == nil or a.v ~= 0)
	return CFrame.new(v2r(o)) * rotVista(r), vis
end

return Anim
