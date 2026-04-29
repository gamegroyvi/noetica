# Noetica backend

FastAPI service that turns a personal growth goal into a batch of trackable
tasks via Groq (OpenAI-compatible endpoint, Llama 3.3 70B).

## Endpoints

- `GET /healthz` — liveness probe.
- `GET /healthz/llm` — reports LLM provider/model/status.
- `POST /roadmap/generate` — goal + profile + axes → `{tasks, summary, model}`.

## Environment

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `GROQ_API_KEY` | yes | — | Groq API key (https://console.groq.com/keys). |
| `LLM_BASE_URL` | no | `https://api.groq.com/openai/v1` | Override to use a different OpenAI-compatible gateway. |
| `LLM_MODEL` | no | `llama-3.3-70b-versatile` | Any model id supported by the gateway. |
| `CORS_ORIGINS` | no | `http://localhost:8080` | Comma-separated list. |
| `PORT` | no | `8080` | HTTP port (Fly.io sets this). |

Copy `.env.example` to `.env` for local dev.

## Local dev

```bash
cd backend
uv pip install -e .  # or: pip install -e .
export GROQ_API_KEY=...
uvicorn app.main:app --reload --port 8080
```

## Deploy (Fly.io)

```bash
cd backend
fly launch --now --name noetica-backend --region fra
fly secrets set GROQ_API_KEY=...
```
