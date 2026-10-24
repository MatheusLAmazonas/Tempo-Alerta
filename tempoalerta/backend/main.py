from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db, weather, scheduler

app = FastAPI(title="TempoAlerta API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
def startup():
    db.init()
    scheduler.start()

class Cadastro(BaseModel):
    nome: str
    email: str
    cidade: str
    horario: str = "07:00"       # HH:MM
    alerta_chuva: bool = True
    alerta_geada: bool = True

@app.post("/cadastro")
def cadastro(d: Cadastro):
    g = weather.geocodificar(d.cidade)
    if not g:
        raise HTTPException(404, "Cidade não encontrada")
    with db.conn() as c:
        c.execute("INSERT INTO usuarios(nome,email) VALUES(?,?) "
                  "ON CONFLICT(email) DO UPDATE SET nome=excluded.nome", (d.nome, d.email))
        uid = c.execute("SELECT id FROM usuarios WHERE email=?", (d.email,)).fetchone()["id"]
        c.execute("INSERT OR IGNORE INTO cidades(nome,lat,lon) VALUES(?,?,?)",
                  (g["nome"], g["lat"], g["lon"]))
        cid = c.execute("SELECT id FROM cidades WHERE nome=? AND lat=? AND lon=?",
                        (g["nome"], g["lat"], g["lon"])).fetchone()["id"]
        c.execute("""INSERT INTO preferencias(usuario_id,cidade_id,horario,alerta_chuva,alerta_geada)
                     VALUES(?,?,?,?,?) ON CONFLICT(usuario_id) DO UPDATE SET
                     cidade_id=excluded.cidade_id, horario=excluded.horario,
                     alerta_chuva=excluded.alerta_chuva, alerta_geada=excluded.alerta_geada""",
                  (uid, cid, d.horario, int(d.alerta_chuva), int(d.alerta_geada)))
    return {"usuario_id": uid, "cidade": g["nome"]}

@app.get("/previsao/{uid}")
def previsao(uid: int):
    prefs = scheduler.preferencias(usuario_id=uid)
    if not prefs:
        raise HTTPException(404, "Usuário sem preferências")
    p = prefs[0]
    return {"cidade": p["cidade"], "horario": p["horario"],
            **weather.previsao(p["lat"], p["lon"])}

@app.get("/alertas/{uid}")
def alertas(uid: int):
    with db.conn() as c:
        rows = c.execute("SELECT tipo,mensagem,enviado_em FROM alertas_enviados "
                         "WHERE usuario_id=? ORDER BY id DESC LIMIT 50", (uid,)).fetchall()
    return [dict(r) for r in rows]

@app.post("/testar/{uid}")
def testar(uid: int):
    prefs = scheduler.preferencias(usuario_id=uid)
    if not prefs:
        raise HTTPException(404, "Usuário sem preferências")
    return {"enviados": scheduler.enviar(prefs[0], forcar=True)}
