# Antigravity 2.0 Quota Architecture & Reverse-Engineering Reference

This document details how Antigravity 2.0 tracks, stores, and fetches model usage so another assistant or engineer (e.g. Claude) can understand, maintain, or adapt this solution.

---

## 1. Process & Architecture Overview

Antigravity 2.0 is an Electron application that spawns a companion native Go binary named `language_server`.

- **Binary Path**: `/Applications/Antigravity.app/Contents/Resources/bin/language_server`
- **Execution Mode**: Runs locally as a child process when the app starts.
- **Protocol**: Exposes a Connect RPC (gRPC-web compatible over HTTP/1.1 and HTTP/2) endpoint on `127.0.0.1`.
- **Security**: Protected with an ephemeral `--csrf_token` CLI flag generated per application launch.

```
┌──────────────────────────────────────┐
│       Antigravity Electron App       │
│  (Renderer UI & Setting Panels)      │
└──────────────────┬───────────────────┘
                   │
                   │ Connect Protocol (JSON/Protobuf over HTTPS)
                   │ Header: X-Codeium-Csrf-Token: <token>
                   ▼
┌──────────────────────────────────────┐
│           language_server            │
│  (Local daemon at 127.0.0.1:<port>)  │
└──────────────────┬───────────────────┘
                   │
                   │ Authenticated Google Cloud API Calls
                   ▼
┌──────────────────────────────────────┐
│  Google Cloud Code / Gemini Backend  │
│  (https://daily-cloudcode-pa....)    │
└──────────────────────────────────────┘
```

---

## 2. Dynamic Discovery Without Hardcoded Ports

Because Antigravity allocates ports dynamically on launch (`--https_server_port 0`), never hardcode the port or the CSRF token.

### Discovery Steps
1. **Find Process and CSRF Token**:
   ```bash
   ps aux | grep language_server
   ```
   Extract `--csrf_token <UUID>` from arguments.

2. **Find Listening Ports**:
   Using the PID of `language_server`:
   ```bash
   lsof -Pan -p <PID> -i
   ```
   Filter for ports in the `LISTEN` state (typically 2 ports, e.g. `55072`, `55073`).

---

## 3. Quota RPC Specification

- **Target URL**: `https://127.0.0.1:<port>/exa.language_server_pb.LanguageServerService/GetUserStatus`
- **HTTP Method**: `POST`
- **TLS / SSL**: Self-signed internal certificate (verification must be disabled for `127.0.0.1`).
- **Required Headers**:
  - `Content-Type: application/json`
  - `Connect-Protocol-Version: 1`
  - `X-Codeium-Csrf-Token: <csrf_token>`
- **Request Body**: `{}` (Empty JSON object)

---

## 4. Response Payload Breakdown

The endpoint returns a JSON response containing `userStatus`:

```json
{
  "userStatus": {
    "name": "...",
    "email": "user@example.com",
    "userTier": {
      "name": "Antigravity Starter Quota",
      "description": "Antigravity Starter Quota"
    },
    "cascadeModelConfigData": {
      "clientModelConfigs": [
        {
          "label": "Gemini 3.8 Flash (Low)",
          "quotaInfo": {
            "remainingFraction": 0.75,
            "resetTime": "2026-10-12T18:28:49Z"
          }
        },
        {
          "label": "Claude Sonnet 4.6 (Thinking)",
          "quotaInfo": {
            "remainingFraction": 1.0,
            "resetTime": "2026-10-12T19:28:59Z"
          }
        }
      ]
    }
  }
}
```

### Metrics Extraction:
- **Gemini Pool**: Shared across all Gemini variations (Flash, Pro). Extracted from `remainingFraction` (e.g. `0.75` = `75% remaining`).
- **Claude & GPT Pool**: Shared across Claude Sonnet, Opus, and GPT models. If `remainingFraction` is omitted or `None`, it signifies 100% capacity.
- **Reset Time**: UTC timestamp string when the weekly quota resets.
