-- Sube las mallas de las 50 armas y arma cada modelo en ReplicatedStorage.Ceniza.Armas
local C = _G.Ceniza
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local SOLO = _G.CenizaSOLO_A
local E = { fase = "bajando", hechas = 0 }
C.estado.armas = E
local function v2r(p) return Vector3.new(p[3], p[2], -p[1]) end -- ejes de la vista (X adelante) → Roblox (-Z adelante)
task.spawn(function()
	local ok, err = pcall(function()
		local A = C.jsonBin("armas.b64")
		local geo = C.bin("armas_geo.b64")
		local I = { arma = HS:JSONDecode(SS:GetAttribute("CenizaIdsArmas") or "{}") }
		local carpeta = RS:FindFirstChild("Ceniza") or Instance.new("Folder"); carpeta.Name = "Ceniza"; carpeta.Parent = RS
		local fa = carpeta:FindFirstChild("Armas") or Instance.new("Folder"); fa.Name = "Armas"; fa.Parent = carpeta
		E.fase = "construyendo"; E.total = 0
		for id, a in A.armas do if not SOLO or table.find(SOLO, id) then E.total += 1 end end
		local n = 0
		for id, a in A.armas do
			if SOLO and not table.find(SOLO, id) then continue end
			E.actual = id
			local L = a.luau
			local modelo = Instance.new("Model"); modelo.Name = id
			modelo:SetAttribute("Nombre", L.nombre); modelo:SetAttribute("Categoria", L.categoria); modelo:SetAttribute("Clase", L.clase)
			modelo:SetAttribute("Cargador", L.cargador); modelo:SetAttribute("Cadencia", L.cadencia)
			local raiz = Instance.new("Part"); raiz.Name = "Raiz"; raiz.Size = Vector3.new(0.2, 0.2, 0.2); raiz.Transparency = 1
			raiz.CanCollide = false; raiz.CanQuery = false; raiz.CanTouch = false; raiz.Massless = true; raiz.CFrame = CFrame.new(); raiz.Parent = modelo
			modelo.PrimaryPart = raiz
			for nombre, p in L.puntos do
				if typeof(p) == "table" and #p == 3 then
					local at = Instance.new("Attachment"); at.Name = nombre; at.Position = v2r(p); at.Parent = raiz
				end
			end
			local pivotes = {}
			local function pivote(g)
				if g == "Cuerpo" or not g then return raiz end
				if pivotes[g] then return pivotes[g] end
				local pp = (L.grupos and L.grupos[g]) and v2r(L.grupos[g]) or Vector3.zero
				local pv = Instance.new("Part"); pv.Name = "G_" .. g; pv.Size = Vector3.new(0.1, 0.1, 0.1); pv.Transparency = 1
				pv.CanCollide = false; pv.CanQuery = false; pv.CanTouch = false; pv.Massless = true; pv.CFrame = CFrame.new(pp); pv.Parent = modelo
				local m6 = Instance.new("Motor6D"); m6.Name = g; m6.Part0 = raiz; m6.Part1 = pv; m6.C0 = CFrame.new(pp); m6.Parent = raiz
				pivotes[g] = pv
				return pv
			end
			for _, pz in a.piezas do
				local mk = tostring(pz.malla)
				local m = A.mallas[pz.malla + 1]
				local em, centro, rg = C.malla(geo, m)
				if not I.arma[mk] then
					I.arma[mk] = C.subir(em, Enum.AssetType.Mesh, "Ceniza_" .. id .. "_" .. pz.nombre)
					SS:SetAttribute("CenizaIdsArmas", HS:JSONEncode(I.arma))
				end
				em:Destroy()
				local mp = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. I.arma[mk]), { CollisionFidelity = Enum.CollisionFidelity.Box })
				local mt = a.materiales[pz.mat]
				mp.Name = pz.nombre
				mp.Size = Vector3.new(math.max(rg.X, 0.01), math.max(rg.Y, 0.01), math.max(rg.Z, 0.01))
				mp.CFrame = CFrame.new(centro)
				mp.Color = Color3.new(mt.color[1], mt.color[2], mt.color[3])
				local ok2, matE = pcall(function() return Enum.Material[mt.material] end)
				mp.Material = ok2 and matE or Enum.Material.SmoothPlastic
				if (mt.brillo or 0) > 0.5 then mp.Material = Enum.Material.Neon end
				if mt.material == "Glass" then mp.Transparency = 0.4 end
				mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false; mp.Massless = true; mp.CastShadow = true
				mp:SetAttribute("Grupo", pz.grupo); mp:SetAttribute("Material", pz.mat)
				local pv = pivote(pz.grupo)
				local w = Instance.new("WeldConstraint"); w.Part0 = pv; w.Part1 = mp; w.Parent = mp
				mp.Parent = modelo
				E.hechas += 1
				task.wait()
			end
			local datos = Instance.new("StringValue"); datos.Name = "Datos"; datos.Value = HS:JSONEncode(L); datos.Parent = modelo
			local viejo = fa:FindFirstChild(id); if viejo then viejo:Destroy() end
			modelo.Parent = fa
			n += 1; E.armas = n
		end
	end)
	E.fase = ok and "listo" or ("error: " .. tostring(err))
end)
return "iniciado"
