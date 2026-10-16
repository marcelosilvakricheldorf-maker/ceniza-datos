-- ReplicatedStorage.CenizaJuego.Config: tablas de datos del modo zombis de Ceniza
local C = {}
C.Armas = require(script.Parent:WaitForChild("Armas")).Armas
C.Caja = require(script.Parent:WaitForChild("Armas")).Caja
C.ArmaInicial = "cobra45"
C.PrecioCaja = 950
C.PrecioPaP = 5000
C.PrecioRePaP = 2500
C.PrecioSobrecarga = 2000
C.MaxPerks = 4

-- Perks (Biblia de diseño) · sitio = lugar del mapa donde va la máquina
C.Perks = {
	FerroTonica = { Nombre = "Ferro-Tónica", Precio = 2500, Color = Color3.fromRGB(170, 50, 30), Modelo = "FerroTonica", Sitio = Vector3.new(-128, 0.6, 8), Energia = true,
		Efecto = "Vida de 100 a 250", Sobre = "Última Muralla: bajo 25 % de vida, 3 s invulnerable y empuje (recarga 90 s)",
		Reto = "Disparar los tres manómetros de la Gasolinera con menos de la mitad de la vida" },
	RitmoFantasma = { Nombre = "Ritmo Fantasma", Precio = 3000, Color = Color3.fromRGB(120, 60, 200), Modelo = "RitmoFantasma", Sitio = Vector3.new(60, 0.6, -112), Energia = true,
		Efecto = "Recarga 50 % más rápida", Sobre = "Recarga perfecta: +25 % de daño al siguiente cargador",
		Reto = "8 recargas perfectas seguidas dentro de la capilla" },
	SegundoLatido = { Nombre = "Segundo Latido", Precio = 500, PrecioCoop = 1500, Color = Color3.fromRGB(80, 200, 150), Modelo = "SegundoLatido", Sitio = Vector3.new(255, 0.6, -100), Energia = false,
		Efecto = "Reanimar el doble de rápido; en solitario, 3 autorreanimaciones", Sobre = "Al reanimar, +30 % de velocidad 5 s y conservas un perk",
		Reto = "Usar los 3 desfibriladores de las camillas en 20 s" },
	OjoDeCuervo = { Nombre = "Ojo de Cuervo", Precio = 2000, Color = Color3.fromRGB(255, 160, 40), Modelo = "OjoDeCuervo", Sitio = Vector3.new(108, 0.6, -110), Energia = true,
		Efecto = "Tiro a la cabeza marca zombis a 15 studs; +15 % daño a la cabeza", Sobre = "Matar a un marcado de un tiro a la cabeza rebota la bala",
		Reto = "Disparar los tres cuervos de latón de Villa Ceniza y 20 tiros a la cabeza seguidos" },
	ZancadaLunar = { Nombre = "Zancada Lunar", Precio = 2000, Color = Color3.fromRGB(150, 190, 240), Modelo = "ZancadaLunar", Sitio = Vector3.new(372, 0.6, 12), Energia = true,
		Efecto = "+12 % de velocidad y doble salto", Sobre = "Aterrizar del doble salto deja flotando a los zombis cercanos 1,5 s",
		Reto = "Tocar con doble salto las cuatro antenas de los techos en una sola vida" },
	BolsilloContrabando = { Nombre = "Bolsillo de Contrabando", Precio = 4000, Color = Color3.fromRGB(90, 110, 50), Modelo = "BolsilloContrabando", Sitio = Vector3.new(95, 0.6, 58), Energia = true,
		Efecto = "Tercera arma", Sobre = "El arma guardada recarga una bala cada segundo",
		Reto = "Devolver 5 objetos confiscados al armario de evidencias" },
	FiebreDeOro = { Nombre = "Fiebre de Oro", Precio = 2500, Color = Color3.fromRGB(240, 190, 50), Modelo = "FiebreDeOro", Sitio = Vector3.new(64, 0.6, 148), Energia = true,
		Efecto = "+20 % de puntos por baja", Sobre = "2 % de zombis salen dorados y sueltan un power-up",
		Reto = "Ganar 15.000 puntos en una sola ronda" },
	EcoNecrotico = { Nombre = "Eco Necrótico", Precio = 3500, Color = Color3.fromRGB(90, 230, 60), Modelo = "EcoNecrotico", Sitio = Vector3.new(292, 0.6, -110), Energia = true,
		Efecto = "15 % de los zombis muertos dejan un eco que ataca 5 s", Sobre = "Los ecos explotan al desaparecer",
		Reto = "Matar 3 Camilleros mientras reaniman" },
	EscarchaInterior = { Nombre = "Escarcha Interior", Precio = 2500, Color = Color3.fromRGB(80, 220, 240), Modelo = "EscarchaInterior", Sitio = Vector3.new(743, -33.9, 150), Energia = true,
		Efecto = "Al recibir un golpe ralentiza 50 % a los zombis en 8 studs (recarga 10 s)", Sobre = "Los ralentizados con menos de 20 % de vida se congelan y se rompen",
		Reto = "Congelar 40 zombis en una ronda" },
	PolvoraViva = { Nombre = "Pólvora Viva", Precio = 2000, Color = Color3.fromRGB(240, 120, 20), Modelo = "PolvoraViva", Sitio = Vector3.new(85, 0.6, 112), Energia = true,
		Efecto = "Inmune a tus explosiones; +1 granada por ronda", Sobre = "Caer desde 6 studs o más explota al aterrizar",
		Reto = "Matar 10 zombis con una sola explosión" },
}

-- Power-ups: familia → color del halo
C.Familias = { Clasico = Color3.fromRGB(60, 255, 80), Tactico = Color3.fromRGB(60, 140, 255), Raro = Color3.fromRGB(255, 190, 50), Maldito = Color3.fromRGB(255, 40, 30) }
C.PowerUps = {
	Abastecimiento = { Nombre = "Abastecimiento", Familia = "Clasico", Duracion = 0 },
	GolpeLetal = { Nombre = "Golpe Letal", Familia = "Clasico", Duracion = 30 },
	BotinDoble = { Nombre = "Botín Doble", Familia = "Clasico", Duracion = 30 },
	Despertador = { Nombre = "Despertador", Familia = "Clasico", Duracion = 0 },
	Albanil = { Nombre = "Albañil", Familia = "Clasico", Duracion = 0 },
	Bobina = { Nombre = "Bobina", Familia = "Tactico", Duracion = 15 },
	ArenaNegra = { Nombre = "Arena Negra", Familia = "Tactico", Duracion = 20 },
	CeboDeCarne = { Nombre = "Cebo de Carne", Familia = "Tactico", Duracion = 10 },
	Sabana = { Nombre = "Sábana", Familia = "Tactico", Duracion = 10 },
	MercadoNegro = { Nombre = "Mercado Negro", Familia = "Raro", Duracion = 30 },
	TragoSorpresa = { Nombre = "Trago Sorpresa", Familia = "Raro", Duracion = 0 },
	TorretaDeBolsillo = { Nombre = "Torreta de Bolsillo", Familia = "Raro", Duracion = 20 },
	Apagon = { Nombre = "Apagón", Familia = "Maldito", Duracion = 20 },
	Estampida = { Nombre = "Estampida", Familia = "Maldito", Duracion = 15 },
}

-- Zombis: comunes, especiales y mini jefes (personajes de ReplicatedStorage.Ceniza.Personajes)
C.Comunes = { "Z_Minero", "Z_Enfermera", "Z_Cientifico", "Z_Oficinista", "Z_Bombero", "Z_Policia", "Z_Militar" }
C.Especiales = {
	Hollinero = { Rig = "Z_Hollinero", Desde = 4, Vida = 2.0, Puntos = 200 },
	Liniero = { Rig = "Z_Liniero", Desde = 6, Vida = 1.8, Puntos = 250 },
	Camillero = { Rig = "Z_Camillero", Desde = 9, Vida = 2.5, Puntos = 300 },
}
C.Jefes = {
	Capataz = { Rig = "Z_ElCapataz", Vida = 40, Puntos = 1500, Escala = 1.35 },
	Centinela = { Rig = "Z_CentinelaS7", Vida = 50, Puntos = 2000, Escala = 1.3 },
	Revisor = { Rig = "Z_ElRevisor", Vida = 35, Puntos = 1500, Escala = 1.15 },
}
C.Sobrevivientes = { "S_Operador", "S_RiesgoBiologico", "S_FuerzasEspeciales", "S_Cientifico" }

-- Caja misteriosa: lugares posibles
C.SitiosCaja = {
	{ "Minimercado de la Gasolinera", Vector3.new(-122, 0.6, -4) },
	{ "Comisaría", Vector3.new(100, 0.6, 62) },
	{ "Ferretería", Vector3.new(260, 0.6, 28) },
	{ "Explanada del Hospital", Vector3.new(270, 0.6, -40) },
	{ "Boletería de la Estación", Vector3.new(70, 0.6, 152) },
	{ "Desarmadero", Vector3.new(240, 0.6, 100) },
	{ "Caverna de la mina", Vector3.new(524, 0.6, 8) },
	{ "Laboratorio Nivel 4", Vector3.new(630, 0.6, 4) },
}

-- Easter egg «Último Recorrido»: puntos del mapa
C.EE = {
	Palanca = Vector3.new(465, -33.9, 138),
	Valvulas = { Vector3.new(604, -33.9, 146), Vector3.new(680, -33.9, 104), Vector3.new(743, -33.9, 146) },
	Refinadora = Vector3.new(682, -33.9, 158),
	Expendedora = Vector3.new(64, 0.6, 144),
	Vetas = { Vector3.new(586, 0.6, -84), Vector3.new(596, 0.6, -94), Vector3.new(604, 0.6, -82) },
	Tanque = Vector3.new(612, -33.9, 166),
	Contenedor = Vector3.new(250, 0.6, 95),
	Locomotora = Vector3.new(175, 0.6, 174),
	Semaforos = { Vector3.new(160, 0.6, 168), Vector3.new(104, 0.6, 178), Vector3.new(366, 0.6, 96), Vector3.new(335, 0.6, 164) },
	Ruta = { Vector3.new(175, 0.6, 166), Vector3.new(335, 0.6, 166), Vector3.new(430, -33.9, 166), Vector3.new(465, -33.9, 166), Vector3.new(556, -33.9, 166) },
	Consolas = { Vector3.new(672, -33.9, 150), Vector3.new(692, -33.9, 150), Vector3.new(672, -33.9, 166), Vector3.new(692, -33.9, 166) },
	Boveda = Vector3.new(682, -33.9, 220),
	Frenos = { Vector3.new(678, -33.9, 200), Vector3.new(686, -33.9, 210), Vector3.new(678, -33.9, 220) },
	Telefonos = { Vector3.new(28, 0.6, -40), Vector3.new(28, 0.6, -10), Vector3.new(28, 0.6, 20), Vector3.new(28, 0.6, 50), Vector3.new(28, 0.6, 80) },
	Radio = Vector3.new(92, 0.6, 50),
	Expendedoras = { Vector3.new(-126, 0.6, 10), Vector3.new(262, 0.6, -46), Vector3.new(68, 0.6, 156) },
	Barriles = { Vector3.new(-70, 0.6, -12), Vector3.new(-50, 0.6, 12), Vector3.new(-80, 0.6, 20) },
	Respiradero = Vector3.new(690, -33.9, 170),
	Campana = Vector3.new(60, 12, -118),
	Camaras = Vector3.new(372, 0.6, -4),
	Pila = Vector3.new(-95, 0.6, -48),
}
C.Simbolos = { "Pico", "Copo", "Llama" }
return C
