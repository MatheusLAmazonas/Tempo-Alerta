import requests

DIAS = ["Segunda-Feira", "Terça-Feira", "Quarta-Feira", "Quinta-Feira",
        "Sexta-Feira", "Sábado", "Domingo"]

def geocodificar(nome: str):
    r = requests.get("https://geocoding-api.open-meteo.com/v1/search",
                     params={"name": nome, "count": 1, "language": "pt"}, timeout=10)
    res = r.json().get("results")
    if not res:
        return None
    x = res[0]
    return {"nome": x["name"], "lat": x["latitude"], "lon": x["longitude"]}

def previsao(lat: float, lon: float):
    from datetime import date
    r = requests.get("https://api.open-meteo.com/v1/forecast", params={
        "latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 8,
        "current": "temperature_2m,relative_humidity_2m,weather_code",
        "hourly": "temperature_2m,weather_code",
        "daily": "weather_code,temperature_2m_max,temperature_2m_min,"
                 "precipitation_sum,precipitation_probability_max",
    }, timeout=10)
    j = r.json()
    cur, h, d = j["current"], j["hourly"], j["daily"]
    i = h["time"].index(cur["time"][:13] + ":00") if cur["time"][:13] + ":00" in h["time"] else 0
    horas = [{"hora": h["time"][k][11:16], "temp": h["temperature_2m"][k],
              "codigo": h["weather_code"][k]} for k in range(i, i + 6)]
    dias = []
    for k, dt in enumerate(d["time"]):
        dias.append({
            "data": dt,
            "dia_semana": DIAS[date.fromisoformat(dt).weekday()],
            "codigo": d["weather_code"][k],
            "max": d["temperature_2m_max"][k], "min": d["temperature_2m_min"][k],
            "chuva_mm": d["precipitation_sum"][k] or 0,
            "chuva_prob": d["precipitation_probability_max"][k] or 0})
    return {"atual": {"temp": cur["temperature_2m"],
                      "umidade": cur["relative_humidity_2m"],
                      "codigo": cur["weather_code"]},
            "horas": horas, "dias": dias}

LIMITE_CHUVA_MM = 30.0   # chuva forte
LIMITE_GEADA_C = 3.0     # mínima <= 3°C favorece geada

def avaliar_alertas(dia: dict):
    out = []
    if dia["chuva_mm"] >= LIMITE_CHUVA_MM:
        out.append(("chuva", f"⚠️ Chuva forte prevista: {dia['chuva_mm']:.0f} mm."))
    if dia["min"] <= LIMITE_GEADA_C:
        out.append(("geada", f"❄️ Risco de geada: mínima de {dia['min']:.0f}°C."))
    return out

LIMITE_CHUVA_HORA = 10.0   # mm/h = chuva forte
LIMITE_CAPE = 2000         # J/kg, heurística para risco de granizo

def riscos(lat, lon, horas=12):
    """Procura chuva forte e risco de granizo nas próximas horas.
    Retorna lista de (tipo, mensagem, dia_do_evento)."""
    r = requests.get("https://api.open-meteo.com/v1/forecast", params={
        "latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 2,
        "current": "temperature_2m",
        "hourly": "precipitation,weather_code,cape"}, timeout=10)
    j = r.json()
    h = j["hourly"]
    agora = j["current"]["time"][:13] + ":00"
    i = h["time"].index(agora) if agora in h["time"] else 0
    janela = range(i, min(i + horas, len(h["time"])))
    out = []

    chuva = [k for k in janela if (h["precipitation"][k] or 0) >= LIMITE_CHUVA_HORA]
    if chuva:
        k = chuva[0]
        pico = max(h["precipitation"][x] or 0 for x in chuva)
        out.append(("chuva",
                    f"chuva forte prevista por volta das {h['time'][k][11:16]} "
                    f"(até {pico:.0f} mm/h).", h["time"][k][:10]))

    granizo = [k for k in janela
               if (h["weather_code"][k] or 0) in (96, 99)
               or ((h["weather_code"][k] or 0) == 95 and (h["cape"][k] or 0) >= LIMITE_CAPE)]
    if granizo:
        k = granizo[0]
        out.append(("granizo",
                    f"risco de tempestade com granizo por volta das {h['time'][k][11:16]}.",
                    h["time"][k][:10]))
    return out