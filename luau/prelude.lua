-- Utilidades compartidas: descarga del repo, decodificación y creación de mallas/imágenes.
local HS = game:GetService("HttpService")
local ES = game:GetService("EncodingService")
local AS = game:GetService("AssetService")
local C = {}
C.BASE = "https://raw.githubusercontent.com/marcelosilvakricheldorf-maker/ceniza-datos/main/"
C.estado = C.estado or {}
function C.texto(n)
	for intento = 1, 4 do
		local ok, r = pcall(HS.GetAsync, HS, C.BASE .. n, true)
		if ok then return r end
		warn("descarga " .. n .. ": " .. tostring(r)); task.wait(2 * intento)
	end
	error("no se pudo bajar " .. n)
end
function C.json(n) return HS:JSONDecode(C.texto(n)) end
function C.bin(n)
	local b = ES:Base64Decode(buffer.fromstring(C.texto(n)))
	return ES:DecompressBuffer(b, Enum.CompressionAlgorithm.Zstd)
end
function C.jsonBin(n) return HS:JSONDecode(buffer.tostring(C.bin(n))) end

-- malla cuantizada → EditableMesh centrada en su caja; devuelve em y el centro (offset)
function C.malla(geo, m)
	local em = AS:CreateEditableMesh()
	local o, nv, nt = m.o, m.nv, m.nt
	local mn = Vector3.new(m.mn[1], m.mn[2], m.mn[3])
	local rg = Vector3.new(m.rg[1], m.rg[2], m.rg[3])
	local centro = mn + rg / 2
	local k = rg / 65535
	local ids = table.create(nv)
	for i = 0, nv - 1 do
		local p = o + i * 6
		local v = mn + Vector3.new(buffer.readu16(geo, p), buffer.readu16(geo, p + 2), buffer.readu16(geo, p + 4)) * k - centro
		ids[i + 1] = em:AddVertex(v)
	end
	local uvs
	local t0 = o + nv * 6
	if m.uv then
		uvs = table.create(nv)
		for i = 0, nv - 1 do
			local p = t0 + i * 4
			uvs[i + 1] = em:AddUV(Vector2.new(buffer.readu16(geo, p) / 65535, 1 - buffer.readu16(geo, p + 2) / 65535))
		end
		t0 += nv * 4
	end
	for t = 0, nt - 1 do
		local p = t0 + t * 6
		local a, b, c = buffer.readu16(geo, p) + 1, buffer.readu16(geo, p + 2) + 1, buffer.readu16(geo, p + 4) + 1
		local f = em:AddTriangle(ids[a], ids[b], ids[c])
		if uvs then em:SetFaceUVs(f, { uvs[a], uvs[b], uvs[c] }) end
	end
	return em, centro, rg
end

function C.subir(obj, tipo, nombre)
	nombre = string.sub(nombre, 1, 48)
	for intento = 1, 6 do
		local ok, res, id = pcall(AS.CreateAssetAsync, AS, obj, tipo, { Name = nombre, Description = "Ceniza" })
		if ok and res == Enum.CreateAssetResult.Success then return id end
		warn("subida " .. nombre .. ": " .. tostring(res) .. " " .. tostring(id)); task.wait(5 * intento)
	end
	error("no se pudo subir " .. nombre)
end

-- imagen RGB (bytes) → EditableImage
function C.imagen(buf, off, w, h)
	local px = buffer.create(w * h * 4)
	for i = 0, w * h - 1 do
		local s = off + i * 3
		buffer.writeu8(px, i * 4, buffer.readu8(buf, s))
		buffer.writeu8(px, i * 4 + 1, buffer.readu8(buf, s + 1))
		buffer.writeu8(px, i * 4 + 2, buffer.readu8(buf, s + 2))
		buffer.writeu8(px, i * 4 + 3, 255)
	end
	local img = AS:CreateEditableImage({ Size = Vector2.new(w, h) })
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), px)
	return img
end
_G.Ceniza = C
return "ok"
