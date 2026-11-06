from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db, weather, scheduler
from datetime import datetime
app = FastAPI(title="TempoAlerta API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.on_event("startup")
def startup():
    db.init()
    scheduler.start()

@app.get("/")
def raiz():
    return {"status": "TempoAlerta API no ar", "docs": "/docs"}

class Cadastro(BaseModel):
    nome: str
    email: str
    cidade: str
    horario: str = "07:00"       # HH:MM
    alerta_chuva: bool = True
    alerta_geada: bool = True

class NovaCidade(BaseModel):
    cidade: str

def salvar_cidade(c, g):
    c.execute("INSERT OR IGNORE INTO cidades(nome,lat,lon) VALUES(?,?,?)",
              (g["nome"], g["lat"], g["lon"]))
    return c.execute("SELECT id FROM cidades WHERE nome=? AND lat=? AND lon=?",
                     (g["nome"], g["lat"], g["lon"])).fetchone()["id"]

@app.post("/cadastro")
def cadastro(d: Cadastro):
    g = weather.geocodificar(d.cidade)
    if not g:
        raise HTTPException(404, "Cidade não encontrada")
    with db.conn() as c:
        c.execute("INSERT INTO usuarios(nome,email) VALUES(?,?) "
                  "ON CONFLICT(email) DO UPDATE SET nome=excluded.nome", (d.nome, d.email))
        uid = c.execute("SELECT id FROM usuarios WHERE email=?", (d.email,)).fetchone()["id"]
        cid = salvar_cidade(c, g)
        c.execute("""INSERT INTO preferencias(usuario_id,cidade_id,horario,alerta_chuva,alerta_geada)
                     VALUES(?,?,?,?,?) ON CONFLICT(usuario_id) DO UPDATE SET
                     cidade_id=excluded.cidade_id, horario=excluded.horario,
                     alerta_chuva=excluded.alerta_chuva, alerta_geada=excluded.alerta_geada""",
                  (uid, cid, d.horario, int(d.alerta_chuva), int(d.alerta_geada)))
        c.execute("INSERT OR IGNORE INTO usuario_cidades(usuario_id,cidade_id) VALUES(?,?)",
                  (uid, cid))
    return {"usuario_id": uid, "cidade": g["nome"]}

@app.get("/cidades/{uid}")
def listar_cidades(uid: int):
    with db.conn() as c:
        rows = c.execute("SELECT c.id, c.nome FROM usuario_cidades uc "
                         "JOIN cidades c ON c.id=uc.cidade_id "
                         "WHERE uc.usuario_id=? ORDER BY uc.rowid", (uid,)).fetchall()
    return [dict(r) for r in rows]

@app.post("/cidades/{uid}")
def adicionar_cidade(uid: int, d: NovaCidade):
    g = weather.geocodificar(d.cidade)
    if not g:
        raise HTTPException(404, "Cidade não encontrada")
    with db.conn() as c:
        if not c.execute("SELECT 1 FROM usuarios WHERE id=?", (uid,)).fetchone():
            raise HTTPException(404, "Usuário não encontrado")
        cid = salvar_cidade(c, g)
        c.execute("INSERT OR IGNORE INTO usuario_cidades(usuario_id,cidade_id) VALUES(?,?)",
                  (uid, cid))
    return {"id": cid, "nome": g["nome"]}

@app.delete("/cidades/{uid}/{cid}")
def remover_cidade(uid: int, cid: int):
    with db.conn() as c:
        total = c.execute("SELECT COUNT(*) AS n FROM usuario_cidades WHERE usuario_id=?",
                          (uid,)).fetchone()["n"]
        if total <= 1:
            raise HTTPException(400, "Mantenha ao menos uma cidade")
        c.execute("DELETE FROM usuario_cidades WHERE usuario_id=? AND cidade_id=?", (uid, cid))
        c.execute("UPDATE preferencias SET cidade_id="
                  "(SELECT cidade_id FROM usuario_cidades WHERE usuario_id=? LIMIT 1) "
                  "WHERE usuario_id=? AND cidade_id=?", (uid, uid, cid))
    return {"ok": True}

@app.get("/previsao/{uid}")
def previsao(uid: int, cidade_id: int | None = None):
    with db.conn() as c:
        pref = c.execute("SELECT horario FROM preferencias WHERE usuario_id=?",
                         (uid,)).fetchone()
        q = ("SELECT c.id, c.nome, c.lat, c.lon FROM usuario_cidades uc "
             "JOIN cidades c ON c.id=uc.cidade_id WHERE uc.usuario_id=?")
        args = [uid]
        if cidade_id:
            q += " AND c.id=?"
            args.append(cidade_id)
        cidade = c.execute(q + " ORDER BY uc.rowid LIMIT 1", args).fetchone()
    if not pref or not cidade:
        raise HTTPException(404, "Usuário sem cidade cadastrada")
    return {"cidade_id": cidade["id"], "cidade": cidade["nome"],
            "horario": pref["horario"],
            **weather.previsao(cidade["lat"], cidade["lon"])}

@app.get("/alertas/{uid}")
def alertas(uid: int):
    with db.conn() as c:
        rows = c.execute("SELECT id,tipo,mensagem,enviado_em FROM alertas_enviados "
                         "WHERE usuario_id=? ORDER BY id DESC LIMIT 50", (uid,)).fetchall()
    return [dict(r) for r in rows]

@app.post("/testar/{uid}")
def testar(uid: int):
    prefs = scheduler.preferencias(usuario_id=uid)
    if not prefs:
        raise HTTPException(404, "Usuário sem preferências")
    enviados = []
    for p in prefs:
        enviados += scheduler.enviar(p, forcar=True)
    return {"enviados": enviados}