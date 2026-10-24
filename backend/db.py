import sqlite3

DB = "tempoalerta.db"

def conn():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c

def init():
    with conn() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS usuarios(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL);
        CREATE TABLE IF NOT EXISTS cidades(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL, lat REAL NOT NULL, lon REAL NOT NULL,
            UNIQUE(nome, lat, lon));
        CREATE TABLE IF NOT EXISTS preferencias(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER UNIQUE NOT NULL REFERENCES usuarios(id),
            cidade_id INTEGER NOT NULL REFERENCES cidades(id),
            horario TEXT NOT NULL,
            alerta_chuva INTEGER DEFAULT 1,
            alerta_geada INTEGER DEFAULT 1);
        CREATE TABLE IF NOT EXISTS alertas_enviados(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
            tipo TEXT NOT NULL,          -- diaria | chuva | geada
            mensagem TEXT NOT NULL,
            ref_data TEXT NOT NULL,      -- dia da previsão (evita duplicar)
            enviado_em TEXT DEFAULT (datetime('now','localtime')),
            UNIQUE(usuario_id, tipo, ref_data));
        """)
