# Noetica backend

FastAPI service that turns a personal growth goal into a batch of trackable
tasks via an OpenAI-compatible LLM gateway (OpenRouter by default).

## Endpoints

- `GET /healthz` — liveness probe.
- `POST /roadmap/generate` — goal + profile + axes → `{tasks, summary, model}`.

## Environment

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `OPENAI_API_KEY` / `OPENROUTER_API_KEY` / `LLM_API_KEY` | yes (one of) | — | Bearer token for the gateway. |
| `LLM_BASE_URL` | no | `https://api.openai.com/v1` | Point at OpenRouter, OmniRoute, self-hosted, etc. |
| `LLM_MODEL` | no | `gpt-4o-mini` | Any model id supported by the gateway. |
| `CORS_ORIGINS` | no | `http://localhost:8080,https://web-habzzjsv.devinapps.com` | Comma-separated list. |
| `PORT` | no | `8080` | HTTP port (Fly.io sets this). |

Copy `.env.example` to `.env` for local dev.

## Local dev

```bash
cd backend
uv pip install -e .  # or: pip install -e .
export OPENROUTER_API_KEY=...
uvicorn app.main:app --reload --port 8080
```

## Deploy (Fly.io)

```bash
cd backend
fly launch --now --name noetica-backend --region fra
fly secrets set OPENROUTER_API_KEY=...
```
