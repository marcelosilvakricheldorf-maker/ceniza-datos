-- Máquinas de perks y power-ups (de Perks_PowerUps_Vitalix.blend) en ReplicatedStorage.Ceniza.Perks / PowerUps
local C = _G.Ceniza
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local E = { fase = "bajando", hechas = 0 }
C.estado.perks = E
task.spawn(function()
	local ok, err = pcall(function()
		local D = C.json("perks.json")
		local geo = C.bin("perks_geo.b64")
		local I = HS:JSONDecode(SS:GetAttribute("CenizaIdsPerks") or "{}")
		local carpeta = RS:FindFirstChild("Ceniza") or Instance.new("Folder"); carpeta.Name = "Ceniza"; carpeta.Parent = RS
		local fP = carpeta:FindFirstChild("Perks") or Instance.new("Folder", carpeta); fP.Name = "Perks"
		local fU = carpeta:FindFirstChild("PowerUps") or Instance.new("Folder", carpeta); fU.Name = "PowerUps"
		E.fase = "construyendo"
		for nombre, it in D.items do
			E.actual = nombre
			local modelo = Instance.new("Model")
			local esPerk = string.sub(nombre, 1, 5) == "Perk_"
			modelo.Name = esPerk and string.sub(nombre, 6) or string.sub(nombre, 4)
			local raiz = Instance.new("Part"); raiz.Name = "Raiz"; raiz.Transparency = 1; raiz.Anchored = true
			raiz.CanCollide = esPerk; raiz.CanQuery = true; raiz.CanTouch = true
			raiz.Size = Vector3.new(math.abs(it.tam[1]), math.abs(it.tam[2]), math.abs(it.tam[3]))
			raiz.CFrame = CFrame.new(0, math.abs(it.tam[2]) / 2, 0); raiz.Parent = modelo
			modelo.PrimaryPart = raiz
			for _, pz in it.piezas do
				local mk = tostring(pz.malla)
				local em, centro, rg = C.malla(geo, D.mallas[pz.malla + 1])
				if not I[mk] then I[mk] = C.subir(em, Enum.AssetType.Mesh, "Ceniza_" .. nombre .. "_" .. pz.mat); SS:SetAttribute("CenizaIdsPerks", HS:JSONEncode(I)) end
				em:Destroy()
				local mp = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. I[mk]), { CollisionFidelity = Enum.CollisionFidelity.Box })
				local mt = D.mats[pz.mat] or D.mats._ninguno
				mp.Name = pz.mat
				mp.Size = Vector3.new(math.max(rg.X, 0.01), math.max(rg.Y, 0.01), math.max(rg.Z, 0.01))
				mp.CFrame = CFrame.new(centro)
				mp.Color = Color3.fromRGB(mt.color[1], mt.color[2], mt.color[3])
				mp.Material = Enum.Material[mt.material]
				mp.Transparency = mt.transp or 0
				mp.Anchored = true; mp.CanCollide = false; mp.CanQuery = false; mp.CanTouch = false
				if mt.material == "Neon" or mt.transp > 0.5 then mp.CastShadow = false end
				mp.Parent = modelo
				E.hechas += 1
				task.wait()
			end
			if it.luz then
				local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(it.luz[1], it.luz[2], it.luz[3])
				l.Range = esPerk and 14 or 8; l.Brightness = esPerk and 1.6 or 1.2; l.Shadows = false; l.Parent = raiz
			end
			modelo:SetAttribute("Tipo", esPerk and "Perk" or "PowerUp")
			local dest = esPerk and fP or fU
			local viejo = dest:FindFirstChild(modelo.Name); if viejo then viejo:Destroy() end
			modelo.Parent = dest
		end
	end)
	E.fase = ok and "listo" or ("error: " .. tostring(err))
end)
return "iniciado"
