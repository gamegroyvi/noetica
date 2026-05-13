"""Portfolio API — FastAPI + SQLite backend for managing portfolio content."""
import os
import sqlite3
import json
import hashlib
import secrets
from datetime import datetime
from pathlib import Path
from contextlib import contextmanager

from fastapi import FastAPI, HTTPException, Depends, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional

DB_PATH = os.environ.get("PORTFOLIO_DB", str(Path(__file__).parent / "portfolio.db"))
UPLOAD_DIR = Path(__file__).parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "admin")

app = FastAPI(title="Portfolio API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- DB ----------
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    conn = get_db()
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        author TEXT NOT NULL,
        text TEXT NOT NULL,
        order_title TEXT DEFAULT '',
        date TEXT DEFAULT '',
        rating INTEGER DEFAULT 5,
        visible INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS portfolio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        image_url TEXT DEFAULT '',
        link TEXT DEFAULT '',
        tags TEXT DEFAULT '[]',
        visible INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subtitle TEXT DEFAULT '',
        description TEXT DEFAULT '',
        tags TEXT DEFAULT '[]',
        link TEXT DEFAULT '',
        icon TEXT DEFAULT 'code',
        visible INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
        token TEXT PRIMARY KEY,
        created_at TEXT DEFAULT (datetime('now'))
    );
    """)
    conn.commit()
    conn.close()

init_db()


def seed_data():
    conn = get_db()
    count = conn.execute("SELECT COUNT(*) FROM reviews").fetchone()[0]
    if count > 0:
        conn.close()
        return

    reviews = [
        ("Slyness", "Как всегда - 5+! Великолепный специалист, профессионал своего дела. Продолжаем работать с Михаилом и развивать проекты!", "Доработка тг бота AI повар", "2026-04-10", 5),
        ("Slyness", "Превосходный специалист! Продолжаю с Михаилом работать над проектами и рассчитываю, что наше сотрудничество будет продолжительным и максимально эффективным. Михаил, жму руку!", "Доработка ТГ бота", "2026-04-10", 5),
        ("Slyness", "Выражаю бесконечный респект Михаилу! Пожалуй, лучший специалист из тех, с кем у меня получалось сотрудничать, уже не один проект с ним проработали. На этот раз стояла задача, оптимизировать и проработать ТГ-бот, с онлайн-оплатой, управлением контентом и прочими премудростями. Михаил, сделал всё на высшем уровне, на отлично с плюсом. Всегда на связи, с полным погружением в задачу и в проект в целом, код выдаёт чистейший и красивейший. Работать с Михаилом, без преувеличения, удовольствие!", "Доработка ТГ бота", "2026-02-10", 5),
        ("brothertin1", "гений гений гений гений гений гений гений гений гений гений", "Добавление поддержки арабского языка и rtl на сайт", "2026-02-05", 5),
        ("Patronium", "всё чётко сделал предложил несколько вариантов очень понравилось обратная связь очень адекватный парень точка Там где другие можете попросили бы какую-то дополнительную плату отказался. сказал что это всё входит в заказ сказал что если будут какие-то там баги или какие-то недочёты там за в ближайшее время выявлены он на безвозмездной основе всё отладит. Всем рекомендую исполнителя", "Веб сервис AI", "2026-01-20", 5),
    ]
    for i, (author, text, order_title, date, rating) in enumerate(reviews):
        conn.execute(
            "INSERT INTO reviews (author, text, order_title, date, rating, sort_order) VALUES (?,?,?,?,?,?)",
            (author, text, order_title, date, rating, i)
        )

    portfolio_images = [
        "https://cdn-edge.kwork.ru/files/portfolio/t0/68/3529bd3f665802316962291cf1994a7040559ea8-1733925268.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/23/c153a914e06dceee0abf2c76ab10b83f4d5f6377-1735904523.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/83/7e613aa867b9a369ead9d1a6b19676014da5d615-1772878383.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/57/1d873414aad9d779f1dec638ef8d42b4daabc38c-1750665657.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/42/e3e74ac2a5b9022fe027811e9389f67b4a42b739-1750028842.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/85/b92ff94a1e430bd35a6dd4a1b7dcf6710e317a4d-1746548585.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/32/395ad4ebee9d11c56848a34d37731207f685318b-1745849833.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/86/0b04f4e482c751add86923145d6a7cd0a8b959e6-1736434086.jpg",
        "https://cdn-edge.kwork.ru/files/portfolio/t0/94/7a5c78b5b70a0763d957bc6b9cdccd93be431f55-1735904594.jpg",
    ]
    for i, url in enumerate(portfolio_images):
        conn.execute(
            "INSERT INTO portfolio (title, image_url, sort_order) VALUES (?,?,?)",
            (f"Работа {i+1}", url, i)
        )

    projects = [
        ("Noetica", "Трекер личного развития", 'Приложение «второй мозг» с пентагоном осей роста, XP-системой, AI-коучем и мемуарной лентой.', '["Flutter","Dart","FastAPI","SQLite"]', "https://github.com/gamegroyvi/noetica", "rocket"),
        ("Telegram Mini Apps", "Веб-приложения в Telegram", "Разработка функциональных Mini Apps: интерфейсы, платежи, интеграции с ботами.", '["React","TypeScript","Node.js","TG API"]', "", "message"),
        ("Лендинги и веб-сайты", "Pixel-perfect вёрстка", "Адаптивные лендинги, мультиязычные сайты, email-шаблоны. Кроссбраузерность и pixel-perfect.", '["Next.js","React","Tailwind","SCSS"]', "", "monitor"),
        ("REST API и бэкенд", "Серверная разработка", "Проектирование API, базы данных, авторизация, документация, деплой на Linux/Nginx.", '["FastAPI","Flask","PostgreSQL","Express"]', "", "server"),
    ]
    for i, (title, subtitle, desc, tags, link, icon) in enumerate(projects):
        conn.execute(
            "INSERT INTO projects (title, subtitle, description, tags, link, icon, sort_order) VALUES (?,?,?,?,?,?,?)",
            (title, subtitle, desc, tags, link, icon, i)
        )

    conn.commit()
    conn.close()

seed_data()


# ---------- AUTH ----------
def check_auth(request: Request):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    if not token:
        raise HTTPException(status_code=401, detail="Unauthorized")
    conn = get_db()
    row = conn.execute("SELECT token FROM sessions WHERE token=?", (token,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid token")
    return token


class LoginRequest(BaseModel):
    password: str

@app.post("/api/login")
def login(req: LoginRequest):
    if req.password != ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Wrong password")
    token = secrets.token_hex(32)
    conn = get_db()
    conn.execute("INSERT INTO sessions (token) VALUES (?)", (token,))
    conn.commit()
    conn.close()
    return {"token": token}


# ---------- PUBLIC API ----------
@app.get("/api/reviews")
def get_reviews():
    conn = get_db()
    rows = conn.execute("SELECT * FROM reviews WHERE visible=1 ORDER BY sort_order, id").fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get("/api/portfolio")
def get_portfolio():
    conn = get_db()
    rows = conn.execute("SELECT * FROM portfolio WHERE visible=1 ORDER BY sort_order, id").fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get("/api/projects")
def get_projects():
    conn = get_db()
    rows = conn.execute("SELECT * FROM projects WHERE visible=1 ORDER BY sort_order, id").fetchall()
    conn.close()
    result = []
    for r in rows:
        d = dict(r)
        d["tags"] = json.loads(d["tags"]) if d["tags"] else []
        result.append(d)
    return result


# ---------- ADMIN API ----------
# Reviews CRUD
class ReviewData(BaseModel):
    author: str
    text: str
    order_title: str = ""
    date: str = ""
    rating: int = 5
    visible: int = 1
    sort_order: int = 0

@app.get("/api/admin/reviews")
def admin_get_reviews(_=Depends(check_auth)):
    conn = get_db()
    rows = conn.execute("SELECT * FROM reviews ORDER BY sort_order, id").fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.post("/api/admin/reviews")
def admin_create_review(data: ReviewData, _=Depends(check_auth)):
    conn = get_db()
    cur = conn.execute(
        "INSERT INTO reviews (author, text, order_title, date, rating, visible, sort_order) VALUES (?,?,?,?,?,?,?)",
        (data.author, data.text, data.order_title, data.date, data.rating, data.visible, data.sort_order)
    )
    conn.commit()
    rid = cur.lastrowid
    conn.close()
    return {"id": rid}

@app.put("/api/admin/reviews/{rid}")
def admin_update_review(rid: int, data: ReviewData, _=Depends(check_auth)):
    conn = get_db()
    conn.execute(
        "UPDATE reviews SET author=?, text=?, order_title=?, date=?, rating=?, visible=?, sort_order=? WHERE id=?",
        (data.author, data.text, data.order_title, data.date, data.rating, data.visible, data.sort_order, rid)
    )
    conn.commit()
    conn.close()
    return {"ok": True}

@app.delete("/api/admin/reviews/{rid}")
def admin_delete_review(rid: int, _=Depends(check_auth)):
    conn = get_db()
    conn.execute("DELETE FROM reviews WHERE id=?", (rid,))
    conn.commit()
    conn.close()
    return {"ok": True}


# Portfolio CRUD
class PortfolioData(BaseModel):
    title: str
    description: str = ""
    image_url: str = ""
    link: str = ""
    tags: str = "[]"
    visible: int = 1
    sort_order: int = 0

@app.get("/api/admin/portfolio")
def admin_get_portfolio(_=Depends(check_auth)):
    conn = get_db()
    rows = conn.execute("SELECT * FROM portfolio ORDER BY sort_order, id").fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.post("/api/admin/portfolio")
def admin_create_portfolio(data: PortfolioData, _=Depends(check_auth)):
    conn = get_db()
    cur = conn.execute(
        "INSERT INTO portfolio (title, description, image_url, link, tags, visible, sort_order) VALUES (?,?,?,?,?,?,?)",
        (data.title, data.description, data.image_url, data.link, data.tags, data.visible, data.sort_order)
    )
    conn.commit()
    pid = cur.lastrowid
    conn.close()
    return {"id": pid}

@app.put("/api/admin/portfolio/{pid}")
def admin_update_portfolio(pid: int, data: PortfolioData, _=Depends(check_auth)):
    conn = get_db()
    conn.execute(
        "UPDATE portfolio SET title=?, description=?, image_url=?, link=?, tags=?, visible=?, sort_order=? WHERE id=?",
        (data.title, data.description, data.image_url, data.link, data.tags, data.visible, data.sort_order, pid)
    )
    conn.commit()
    conn.close()
    return {"ok": True}

@app.delete("/api/admin/portfolio/{pid}")
def admin_delete_portfolio(pid: int, _=Depends(check_auth)):
    conn = get_db()
    conn.execute("DELETE FROM portfolio WHERE id=?", (pid,))
    conn.commit()
    conn.close()
    return {"ok": True}


# Projects CRUD
class ProjectData(BaseModel):
    title: str
    subtitle: str = ""
    description: str = ""
    tags: str = "[]"
    link: str = ""
    icon: str = "code"
    visible: int = 1
    sort_order: int = 0

@app.get("/api/admin/projects")
def admin_get_projects(_=Depends(check_auth)):
    conn = get_db()
    rows = conn.execute("SELECT * FROM projects ORDER BY sort_order, id").fetchall()
    conn.close()
    result = []
    for r in rows:
        d = dict(r)
        d["tags"] = json.loads(d["tags"]) if d["tags"] else []
        result.append(d)
    return result

@app.post("/api/admin/projects")
def admin_create_project(data: ProjectData, _=Depends(check_auth)):
    conn = get_db()
    cur = conn.execute(
        "INSERT INTO projects (title, subtitle, description, tags, link, icon, visible, sort_order) VALUES (?,?,?,?,?,?,?,?)",
        (data.title, data.subtitle, data.description, data.tags, data.link, data.icon, data.visible, data.sort_order)
    )
    conn.commit()
    pid = cur.lastrowid
    conn.close()
    return {"id": pid}

@app.put("/api/admin/projects/{pid}")
def admin_update_project(pid: int, data: ProjectData, _=Depends(check_auth)):
    conn = get_db()
    conn.execute(
        "UPDATE projects SET title=?, subtitle=?, description=?, tags=?, link=?, icon=?, visible=?, sort_order=? WHERE id=?",
        (data.title, data.subtitle, data.description, data.tags, data.link, data.icon, data.visible, data.sort_order, pid)
    )
    conn.commit()
    conn.close()
    return {"ok": True}

@app.delete("/api/admin/projects/{pid}")
def admin_delete_project(pid: int, _=Depends(check_auth)):
    conn = get_db()
    conn.execute("DELETE FROM projects WHERE id=?", (pid,))
    conn.commit()
    conn.close()
    return {"ok": True}


# ---------- SERVE STATIC FILES ----------
PORTFOLIO_DIR = Path(__file__).parent.parent

@app.get("/admin")
@app.get("/admin/")
def serve_admin():
    return FileResponse(PORTFOLIO_DIR / "admin" / "index.html")

# Mount admin static files
if (PORTFOLIO_DIR / "admin").exists():
    app.mount("/admin", StaticFiles(directory=str(PORTFOLIO_DIR / "admin"), html=True), name="admin_static")

# Serve main site
@app.get("/")
def serve_index():
    return FileResponse(PORTFOLIO_DIR / "index.html")

@app.get("/{path:path}")
def serve_static(path: str):
    if path.startswith("api/"):
        raise HTTPException(status_code=404)
    file_path = PORTFOLIO_DIR / path
    if file_path.is_file():
        return FileResponse(file_path)
    raise HTTPException(status_code=404)
