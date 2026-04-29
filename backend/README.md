# Noetica backend

FastAPI service that turns a personal growth goal into a batch of trackable
tasks via Google Gemini (OpenAI-compatible endpoint).

## Endpoints

- `GET /healthz` — liveness probe.
- `GET /healthz/llm` — reports LLM provider/model/status.
- `POST /roadmap/generate` — goal + profile + axes → `{tasks, summary, model}`.

## Environment

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `GOOGLE_AI_KEY` | yes | — | Google AI Studio API key. |
| `LLM_BASE_URL` | no | `https://generativelanguage.googleapis.com/v1beta/openai` | Override to use a different OpenAI-compatible gateway. |
| `LLM_MODEL` | no | `gemini-2.0-flash` | Any model id supported by the gateway. |
| `CORS_ORIGINS` | no | `http://localhost:8080` | Comma-separated list. |
| `PORT` | no | `8080` | HTTP port (Fly.io sets this). |

Copy `.env.example` to `.env` for local dev.

## Local dev

```bash
cd backend
uv pip install -e .  # or: pip install -e .
export GOOGLE_AI_KEY=...
uvicorn app.main:app --reload --port 8080
```

## Deploy (Fly.io)

```bash
cd backend
fly launch --now --name noetica-backend --region fra
fly secrets set GOOGLE_AI_KEY=...
```
