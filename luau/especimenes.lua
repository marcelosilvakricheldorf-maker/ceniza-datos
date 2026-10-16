-- Coloca los 5 zombis posados dentro de los frascos de Contención (requiere los rigs de Personajes ya construidos)
local C = _G.Ceniza
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local E = { fase = "bajando" }
C.estado.especimenes = E
task.spawn(function()
	local ok, err = pcall(function()
		local D = C.json("especimenes.json")
		local geo = C.bin("especimenes_geo.b64")
		local I = HS:JSONDecode(SS:GetAttribute("CenizaIdsEspecimenes") or "{}")
		local PJ = RS.Ceniza.Personajes
		local mapa = workspace:WaitForChild("Ceniza_Mapa")
		local f = mapa:FindFirstChild("Especimenes"); if f then f:Destroy() end
		f = Instance.new("Folder"); f.Name = "Especimenes"
		for i, e in D.especimenes do
			local rig = PJ[e.personaje]
			local m = Instance.new("Model"); m.Name = "Especimen_" .. e.personaje
			for pn, cf in e.partes do
				local src = rig[pn]
				local p
				local propia = e.propias[pn]
				if propia then
					local mk = tostring(propia)
					local em, centro, rg = C.malla(geo, D.mallas[propia + 1])
					if not I[mk] then I[mk] = C.subir(em, Enum.AssetType.Mesh, "Ceniza_Especimen_" .. pn); SS:SetAttribute("CenizaIdsEspecimenes", HS:JSONEncode(I)) end
					em:Destroy()
					p = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. I[mk]), { CollisionFidelity = Enum.CollisionFidelity.Box })
					p.Size = rg; p.TextureID = src.TextureID; p.Material = src.Material; p.Color = src.Color
				else
					p = src:Clone()
					for _, ch in p:GetChildren() do ch:Destroy() end
					p.Size = src.Size * e.esc
				end
				p.Name = pn
				p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
				p.CFrame = CFrame.new(cf[1], cf[2], cf[3], cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12])
				p.Parent = m
			end
			m.Parent = f
			task.wait()
		end
		f.Parent = mapa
	end)
	E.fase = ok and "listo" or ("error: " .. tostring(err))
end)
return "iniciado"
