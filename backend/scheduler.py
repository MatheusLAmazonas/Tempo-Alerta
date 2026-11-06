from datetime import datetime
from zoneinfo import ZoneInfo
from apscheduler.schedulers.background import BackgroundScheduler
import db, weather

TZ = ZoneInfo("America/Sao_Paulo")

def registrar(usuario_id, tipo, mensagem, ref):
    """Grava o alerta (o app o transforma em notificação). Evita duplicar pela ref."""
    with db.conn() as c:
        cur = c.execute("INSERT OR IGNORE INTO alertas_enviados"
                        "(usuario_id,tipo,mensagem,ref_data) VALUES(?,?,?,?)",
                        (usuario_id, tipo, mensagem, ref))
    if cur.rowcount:
        print(f"[ALERTA] usuario {usuario_id}: {mensagem}")
    return bool(cur.rowcount)

def enviar(pref, forcar=False):
    """Previsão diária + alertas do dia de UMA cidade (no horário escolhido)."""
    p = weather.previsao(pref["lat"], pref["lon"])
    hoje = p["dias"][0]
    msgs = [("diaria", f"{pref['cidade']}: {hoje['min']:.0f}° a {hoje['max']:.0f}°, "
                       f"chuva {hoje['chuva_prob']}% ({hoje['chuva_mm']:.0f} mm).")]
    for tipo, m in weather.avaliar_alertas(hoje):
        if (tipo == "chuva" and pref["alerta_chuva"]) or (tipo == "geada" and pref["alerta_geada"]):
            msgs.append((tipo, f"{pref['cidade']}: {m}"))
    novos = []
    for tipo, m in msgs:
        ref = f"{hoje['data']}:{pref['cidade']}"
        if forcar:
            ref += "-" + datetime.now(TZ).strftime("%H%M%S")
        if registrar(pref["usuario_id"], tipo, m, ref):
            novos.append(m)
    return novos

def preferencias(usuario_id=None, horario=None):
    """Uma linha por (usuário, cidade)."""
    q = ("SELECT p.usuario_id, p.horario, p.alerta_chuva, p.alerta_geada, "
         "c.nome AS cidade, c.lat, c.lon "
         "FROM preferencias p "
         "JOIN usuario_cidades uc ON uc.usuario_id=p.usuario_id "
         "JOIN cidades c ON c.id=uc.cidade_id WHERE 1=1")
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

def monitorar():
    """A cada 15 min: procura chuva forte / granizo nas próximas 12 h."""
    cache = {}
    for pref in preferencias():
        if not pref["alerta_chuva"]:
            continue
        try:
            chave = (pref["lat"], pref["lon"])
            if chave not in cache:
                cache[chave] = weather.riscos(pref["lat"], pref["lon"])
            for tipo, msg, dia in cache[chave]:
                icone = "🧊" if tipo == "granizo" else "⛈️"
                # no máximo 1 alerta de cada tipo, por cidade e por dia
                registrar(pref["usuario_id"], tipo, f"{icone} {pref['cidade']}: {msg}",
                          f"risco:{dia}:{pref['cidade']}")
        except Exception as e:
            print("erro monitorar:", e)

def start():
    s = BackgroundScheduler(timezone=TZ)
    s.add_job(tick, "cron", minute="*")
    s.add_job(monitorar, "interval", minutes=15, next_run_time=datetime.now(TZ))
    s.start()