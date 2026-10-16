-- Sube texturas y mallas de los 17 personajes y arma rigs R15 en ReplicatedStorage.Ceniza.Personajes
local C = _G.Ceniza
local HS = game:GetService("HttpService")
local AS = game:GetService("AssetService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local SOLO = _G.CenizaSOLO_P
local E = { fase = "bajando", hechas = 0 }
C.estado.personajes = E
local function ids()
	local t = SS:GetAttribute("CenizaIdsPersonajes")
	return t and HS:JSONDecode(t) or {}
end
local function guardar(t) SS:SetAttribute("CenizaIdsPersonajes", HS:JSONEncode(t)) end
local R15 = {
	LowerTorso = { "HumanoidRootPart", "Root" }, UpperTorso = { "LowerTorso", "Waist" }, Head = { "UpperTorso", "Neck" },
	LeftUpperArm = { "UpperTorso", "LeftShoulder" }, LeftLowerArm = { "LeftUpperArm", "LeftElbow" }, LeftHand = { "LeftLowerArm", "LeftWrist" },
	RightUpperArm = { "UpperTorso", "RightShoulder" }, RightLowerArm = { "RightUpperArm", "RightElbow" }, RightHand = { "RightLowerArm", "RightWrist" },
	LeftUpperLeg = { "LowerTorso", "LeftHip" }, LeftLowerLeg = { "LeftUpperLeg", "LeftKnee" }, LeftFoot = { "LeftLowerLeg", "LeftAnkle" },
	RightUpperLeg = { "LowerTorso", "RightHip" }, RightLowerLeg = { "RightUpperLeg", "RightKnee" }, RightFoot = { "RightLowerLeg", "RightAnkle" },
}
local ORDEN = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
task.spawn(function()
	local ok, err = pcall(function()
		local P = C.json("personajes.json")
		local geo = C.bin("personajes_geo.b64")
		local I = ids(); I.malla = I.malla or {}; I.tex = I.tex or {}
		local carpeta = RS:FindFirstChild("Ceniza") or Instance.new("Folder"); carpeta.Name = "Ceniza"; carpeta.Parent = RS
		local fp = carpeta:FindFirstChild("Personajes") or Instance.new("Folder"); fp.Name = "Personajes"; fp.Parent = carpeta
		local texCache = {}
		E.fase = "construyendo"
		for nombre, d in P.personajes do
			if SOLO and not table.find(SOLO, nombre) then continue end
			E.actual = nombre
			-- textura
			local tk = tostring(d.textura)
			if not I.tex[tk] then
				local f = d.textura // 4
				texCache[f] = texCache[f] or C.bin(string.format("texturas_%02d.b64", f))
				local img = C.imagen(texCache[f], (d.textura % 4) * 512 * 512 * 3, 512, 512)
				I.tex[tk] = C.subir(img, Enum.AssetType.Image, "Ceniza_" .. nombre .. "_Textura")
				img:Destroy(); guardar(I)
			end
			local texId = "rbxassetid://" .. I.tex[tk]
			local modelo = Instance.new("Model"); modelo.Name = nombre
			local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2, 2, 1)
			hrp.Transparency = 1; hrp.CanCollide = false; hrp.CFrame = CFrame.new(0, 0, 0); hrp.Parent = modelo
			local partes = { HumanoidRootPart = hrp }
			local suelo = math.huge
			for _, pn in ORDEN do
				local pd = d.partes[pn]
				local m = P.mallas[pd.malla + 1]
				local mk = tostring(pd.malla)
				local em, centro, rg = C.malla(geo, m)
				if not I.malla[mk] then I.malla[mk] = C.subir(em, Enum.AssetType.Mesh, "Ceniza_" .. nombre .. "_" .. pn); guardar(I) end
				em:Destroy()
				local mp = AS:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. I.malla[mk]), { CollisionFidelity = Enum.CollisionFidelity.Box })
				mp.Name = pn; mp.TextureID = texId; mp.Material = Enum.Material.SmoothPlastic; mp.Color = Color3.new(1, 1, 1)
				mp.Size = Vector3.new(math.max(rg.X, 0.05), math.max(rg.Y, 0.05), math.max(rg.Z, 0.05))
				local J = Vector3.new(pd.junta[1], pd.junta[2], pd.junta[3])
				mp.CFrame = CFrame.new(J + centro); mp.CanCollide = false
				mp:SetAttribute("Junta", J)
				mp.Parent = modelo; partes[pn] = mp
				suelo = math.min(suelo, J.Y + centro.Y - rg.Y / 2)
				E.hechas += 1
				task.wait()
			end
			for _, pn in ORDEN do
				local p1 = partes[pn]; local p0 = partes[R15[pn][1]]
				local J = p1:GetAttribute("Junta")
				local m6 = Instance.new("Motor6D"); m6.Name = R15[pn][2]; m6.Part0 = p0; m6.Part1 = p1
				m6.C0 = p0.CFrame:Inverse() * CFrame.new(J); m6.C1 = p1.CFrame:Inverse() * CFrame.new(J)
				m6.Parent = p1
			end
			local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R15
			hum.HipHeight = math.max(-suelo - 1, 0.1); hum.Parent = modelo
			Instance.new("Animator", hum)
			modelo.PrimaryPart = hrp
			local viejo = fp:FindFirstChild(nombre); if viejo then viejo:Destroy() end
			modelo.Parent = fp
		end
	end)
	E.fase = ok and "listo" or ("error: " .. tostring(err))
end)
return "iniciado"
