-- Construye el mapa (piezas visibles, colisión, puertas, luces, iluminación) en segundo plano.
local C = _G.Ceniza
local E = { fase = "bajando", hechas = 0 }
C.estado.mapa = E
task.spawn(function()
	local ok, err = pcall(function()
		local b = C.bin("mapa.b64")
		local info = C.json("mapa_info.json")
		local nv, nc, nl = buffer.readu32(b, 0), buffer.readu32(b, 4), buffer.readu32(b, 8)
		E.total = nv + nc + nl
		local MATS = {}
		for i, n in info.mats do MATS[i - 1] = Enum.Material[n] end
		local viejo = workspace:FindFirstChild("Ceniza_Mapa"); if viejo then viejo:Destroy() end
		local raiz = Instance.new("Model"); raiz.Name = "Ceniza_Mapa"
		local fVis = Instance.new("Folder", raiz); fVis.Name = "Visual"
		local fCol = Instance.new("Folder", raiz); fCol.Name = "Colision"
		local fPue = Instance.new("Folder", raiz); fPue.Name = "Puertas"
		local fLuz = Instance.new("Folder", raiz); fLuz.Name = "Luces"
		local puertas = {}
		for i, p in info.puertas do
			local m = Instance.new("Model"); m.Name = p[1]
			m:SetAttribute("Id", i); m:SetAttribute("Etiqueta", p[2]); m:SetAttribute("Costo", p[3])
			m:SetAttribute("Posicion", Vector3.new(p[4], 0, p[5])); m:SetAttribute("Abierta", false)
			puertas[i] = m
		end
		raiz.Parent = workspace
		E.fase = "visual"
		local lote, n = nil, 0
		local function nuevoLote(dest)
			if lote then lote.Parent = dest end
			n += 1; lote = Instance.new("Folder"); lote.Name = string.format("Lote%03d", n)
			task.wait()
		end
		lote = Instance.new("Folder"); lote.Name = "Lote001"; n = 1
		for i = 0, nv - 1 do
			local o = 12 + i * 39
			local x, y, z = buffer.readf32(b, o), buffer.readf32(b, o + 4), buffer.readf32(b, o + 8)
			local qx, qy, qz, qw = buffer.readi16(b, o + 12) / 32767, buffer.readi16(b, o + 14) / 32767, buffer.readi16(b, o + 16) / 32767, buffer.readi16(b, o + 18) / 32767
			local sx, sy, sz = buffer.readf32(b, o + 20), buffer.readf32(b, o + 24), buffer.readf32(b, o + 28)
			local r, g, bl = buffer.readu8(b, o + 32), buffer.readu8(b, o + 33), buffer.readu8(b, o + 34)
			local forma, tr, puerta, mat = buffer.readu8(b, o + 35), buffer.readu8(b, o + 36), buffer.readu8(b, o + 37), buffer.readu8(b, o + 38)
			local pt
			if forma == 3 then pt = Instance.new("WedgePart") else pt = Instance.new("Part") end
			if forma == 1 then pt.Shape = Enum.PartType.Cylinder
			elseif forma == 2 then
				if math.abs(sx - sy) < 1e-3 and math.abs(sy - sz) < 1e-3 then pt.Shape = Enum.PartType.Ball
				else local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = pt end
			end
			pt.Anchored = true; pt.CanCollide = false; pt.CanTouch = false; pt.CanQuery = false
			pt.TopSurface = Enum.SurfaceType.Smooth; pt.BottomSurface = Enum.SurfaceType.Smooth
			pt.Size = Vector3.new(math.max(sx, 0.001), math.max(sy, 0.001), math.max(sz, 0.001))
			pt.CFrame = CFrame.new(x, y, z, qx, qy, qz, qw)
			pt.Color = Color3.fromRGB(r, g, bl)
			pt.Material = MATS[mat] or Enum.Material.SmoothPlastic
			pt.Transparency = tr / 100
			if mat == 30 or tr > 40 then pt.CastShadow = false end
			if puerta > 0 and puertas[puerta] then pt.Parent = puertas[puerta] else pt.Parent = lote end
			E.hechas += 1
			if (i + 1) % 700 == 0 then nuevoLote(fVis) end
		end
		nuevoLote(fVis)
		E.fase = "colision"
		local base = 12 + nv * 39
		for i = 0, nc - 1 do
			local o = base + i * 34
			local x, y, z = buffer.readf32(b, o), buffer.readf32(b, o + 4), buffer.readf32(b, o + 8)
			local qx, qy, qz, qw = buffer.readi16(b, o + 12) / 32767, buffer.readi16(b, o + 14) / 32767, buffer.readi16(b, o + 16) / 32767, buffer.readi16(b, o + 18) / 32767
			local sx, sy, sz = buffer.readf32(b, o + 20), buffer.readf32(b, o + 24), buffer.readf32(b, o + 28)
			local cuna, puerta = buffer.readu8(b, o + 32), buffer.readu8(b, o + 33)
			local pt = cuna == 1 and Instance.new("WedgePart") or Instance.new("Part")
			pt.Anchored = true; pt.Transparency = 1; pt.CastShadow = false; pt.CanTouch = false
			pt.Size = Vector3.new(math.max(sx, 0.05), math.max(sy, 0.05), math.max(sz, 0.05))
			pt.CFrame = CFrame.new(x, y, z, qx, qy, qz, qw)
			pt.Name = "Col"
			if puerta > 0 and puertas[puerta] then pt.Name = "ColPuerta"; pt.Parent = puertas[puerta] else pt.Parent = lote end
			E.hechas += 1
			if (i + 1) % 1000 == 0 then nuevoLote(fCol) end
		end
		nuevoLote(fCol)
		E.fase = "luces"
		base += nc * 34
		for i = 0, nl - 1 do
			local o = base + i * 36
			local f = {}
			for k = 0, 8 do f[k + 1] = buffer.readf32(b, o + k * 4) end
			local pt = Instance.new("Part"); pt.Name = "Luz"
			pt.Anchored = true; pt.CanCollide = false; pt.CanTouch = false; pt.CanQuery = false; pt.CastShadow = false
			pt.Transparency = 1; pt.Size = Vector3.new(0.2, 0.2, 0.2); pt.Position = Vector3.new(f[1], f[2], f[3])
			local l = Instance.new("PointLight")
			l.Color = Color3.new(f[4], f[5], f[6]); l.Range = math.min(f[7] * 1.5, 60)
			l.Brightness = f[8] * (f[9] > 0.5 and 1.6 or 1); l.Shadows = f[9] > 0.5
			l.Parent = pt; pt.Parent = lote
			E.hechas += 1
		end
		nuevoLote(fLuz); lote:Destroy()
		for _, m in puertas do m.Parent = fPue; task.wait() end
		-- spawns y lugares
		local fSp = Instance.new("Folder"); fSp.Name = "Spawns"
		for i, s in info.spawns do
			local a = Instance.new("Part"); a.Name = "Spawn" .. i; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1
			a.Size = Vector3.new(2, 0.2, 2); a.Position = Vector3.new(s[1], s[2], s[3]); a.Parent = fSp
		end
		fSp.Parent = raiz
		local sp = workspace:FindFirstChildOfClass("SpawnLocation")
		if not sp then sp = Instance.new("SpawnLocation"); sp.Parent = workspace end
		sp.Anchored = true; sp.Size = Vector3.new(4, 0.2, 4); sp.Transparency = 1; sp.CanCollide = false; sp.Neutral = true; sp.Duration = 0
		sp.Position = Vector3.new(info.spawns[1][1], info.spawns[1][2] + 0.1, info.spawns[1][3])
		local fLu = Instance.new("Folder"); fLu.Name = "Lugares"
		for _, l in info.lugares do
			local v = Instance.new("Vector3Value"); v.Name = l[1]; v.Value = Vector3.new(l[2], l[3], l[4]); v.Parent = fLu
		end
		fLu.Parent = raiz
		-- iluminación nocturna como en el visor
		local L = game:GetService("Lighting")
		L.Technology = Enum.Technology.Future
		L.ClockTime = 0; L.Brightness = 1.2; L.EnvironmentDiffuseScale = 0.3; L.EnvironmentSpecularScale = 0.4
		L.Ambient = Color3.fromRGB(26, 30, 42); L.OutdoorAmbient = Color3.fromRGB(46, 52, 74)
		L.ColorShift_Top = Color3.fromRGB(128, 144, 192); L.FogEnd = 100000
		local at = L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", L)
		at.Density = 0.42; at.Offset = 0.1; at.Color = Color3.fromRGB(20, 21, 27); at.Decay = Color3.fromRGB(11, 12, 17); at.Glare = 0; at.Haze = 2.5
		local bp = workspace:FindFirstChild("Baseplate"); if bp then bp:Destroy() end
		local pm = workspace:FindFirstChild("PruebaMalla"); if pm then pm:Destroy() end
	end)
	E.fase = ok and "listo" or ("error: " .. tostring(err))
end)
return "iniciado"
