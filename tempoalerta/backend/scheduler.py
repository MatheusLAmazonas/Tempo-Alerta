from datetime import datetime
from zoneinfo import ZoneInfo
from apscheduler.schedulers.background import BackgroundScheduler
import db, weather

TZ = ZoneInfo("America/Sao_Paulo")

def enviar(pref, forcar=False):
    """Gera (e registra) a previsão diária + alertas. 'Envio' = registro em
    alertas_enviados; troque o print por push/Telegram/e-mail se quiser."""
    p = weather.previsao(pref["lat"], pref["lon"])
    hoje = p["dias"][0]
    msgs = [("diaria", f"{pref['cidade']}: {hoje['min']:.0f}° a {hoje['max']:.0f}°, "
                       f"chuva {hoje['chuva_prob']}% ({hoje['chuva_mm']:.0f} mm).")]
    for tipo, m in weather.avaliar_alertas(hoje):
        if (tipo == "chuva" and pref["alerta_chuva"]) or (tipo == "geada" and pref["alerta_geada"]):
            msgs.append((tipo, m))
    novos = []
    with db.conn() as c:
        for tipo, m in msgs:
            ref = hoje["data"] + ("-" + datetime.now(TZ).strftime("%H%M%S") if forcar else "")
            cur = c.execute("INSERT OR IGNORE INTO alertas_enviados"
                            "(usuario_id,tipo,mensagem,ref_data) VALUES(?,?,?,?)",
                            (pref["usuario_id"], tipo, m, ref))
            if cur.rowcount:
                novos.append(m)
                print(f"[ENVIO] usuario {pref['usuario_id']}: {m}")
    return novos

def preferencias(usuario_id=None, horario=None):
    q = ("SELECT p.*, c.nome AS cidade, c.lat, c.lon FROM preferencias p "
         "JOIN cidades c ON c.id=p.cidade_id WHERE 1=1")
    args = []
    if usuario_id: q += " AND p.usuario_id=?"; args.append(usuario_id)
    if horario: q += " AND p.horario=?"; args.append(horario)
    with db.conn() as c:
        return c.execute(q, args).fetchall()

def tick():
    agora = datetime.now(TZ).strftime("%H:%M")
    for pref in preferencias(horario=agora):
        try: enviar(pref)
        except Exception as e: print("erro:", e)

def start():
    s = BackgroundScheduler(timezone=TZ)
    s.add_job(tick, "cron", minute="*")
    s.start()
