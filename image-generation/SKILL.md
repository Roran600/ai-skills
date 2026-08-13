---
name: image-generation
description: "Generovanie obrázkov cez OpenRouter MCP v bashi, s výberom modelu, aspektmi, batch a upscalingom"
license: MIT
compatibility:
  mcp: openrouter
metadata:
  audience: "OpenCode agent"
  workflow: "CLI / bash"
---

# Pokyny (slovensky)

Tento skill je **bash-only**. Všetko beží cez OpenRouter MCP (`tools/call generate-image`), bez REST API a bez SDK. Autentifikácia používa token, ktorý už má OpenCode uložený.

## Predpoklady
- Závislosti: `curl`, `jq`, `base64`, `awk`, `magick` (ImageMagick) – všetko je v prostredí.
- Token: automaticky sa načíta z `~/.local/share/opencode/mcp-auth.json` (`openrouter.tokens.accessToken`). Ak chýba, nastav `OPENROUTER_API_KEY` v env. Skript vypíše chybu, nikdy token nevypíše.

## Kroky použitia
1) **Schéma nástrojov (zadarmo)** – `./img.sh mcp tools/list | jq '.result.tools[] | select(.name=="generate-image")'`
   - Live stav (aktuálne): `model`, `prompt`, `size`. Žiadne `aspect_ratio`, `input_references`, `n`, `seed`.

2) **Výber modelu**
   - Auto: `./img.sh models` (live katalóg, `output_modalities=image`, sort podľa ceny). Navrhni lacný/populárny slug.
   - Manuál: slug od usera, ak treba over `./img.sh mcp get-model '{"request":{"model":"<slug>"}}'`.

3) **Pomer a veľkosť**
   - `./img.sh size <pomer> <tier>` → reťazec pre MCP `size`.
   - Tiers: `1K|2K|4K` (standard/high/ultra). Pri 1:1 sa vracia natívny tier (`1K`), inak explicitné pixely (area-preserving, /8).
   - Overené rozmery:
     - 16:9 → 1K `1368x768`, 2K `2728x1536`, 4K `5464x3072`
     - 9:16 → 1K `768x1368`, 2K `1536x2728`, 4K `3072x5464`
     - 4:3 → 1K `1184x888`, 2K `2368x1776`, 4K `4728x3544`
     - 3:4 → 1K `888x1184`, 2K `1776x2368`, 4K `3544x4728`
     - 21:9 → 1K `1568x672`, 2K `3128x1344`, 4K `6256x2680`

4) **Referenčné obrázky (MCP ich neprijíma)**
   - Prečítaj obrázok (Read tool) a vlož opis do promptu: subjekt + akcia, kompozícia/uhol, paleta + svetlo, médium/štýl/štruktúra. Uveď, že ide o štýlovú podobnosť, nie img2img.

5) **Generovanie (platené)**
   - `./img.sh gen -m <model> -r <pomer> -q <tier> -o <outdir> "prompt1" "prompt2"`
   - Alebo `-f prompts.txt` (1 prompt na riadok, prázdne riadky sa preskočia).
   - Každý prompt = jeden MCP call (MCP nemá `n`). Uloží `NN-<model>.png` + `NN-<model>.json` (model, prompt, size, čas).

6) **Extrakcia base64 → súbory**
   - `./img.sh extract <file|-> [outdir] [basename]`
   - Vie MCP `CallToolResult`, `ImageContent`, `b64_json`, data URL aj holý base64. Príponu určí podľa magic bytes.

7) **Upscaling (rezample)**
   - `./img.sh upscale img.png 2` (alebo `4`). Lanczos + unsharp. Nie je to generatívny super-res, len resampling.

## Obmedzenia MCP
- `generate-image` dnes prijíma iba: `model`, `prompt`, `size`. Aspect ratio rieš explicitnou veľkosťou, referencie opisom v prompte.
- Každý prompt = samostatný platený call. Pred batchom oznám userovi počet volaní a model.

## Rýchly workflow pre agenta
1. `./img.sh mcp tools/list` (raz na session) – over schému.
2. `./img.sh models | head` – vyber model.
3. `./img.sh size 16:9 2K` – získaj size.
4. Priprav prompt (vrátane opisu referencie, ak je).
5. `./img.sh gen -m <model> -r 16:9 -q 2K -o out "...prompt..."`
6. (Voliteľné) `./img.sh upscale out/01-<model>.png 2`

## Poznámka k autentifikácii
- Token z `mcp-auth.json` exp. po ~7 dňoch. Ak skript zahlási expiráciu, v OpenCode spusti ľubovoľný OpenRouter MCP tool a obnoví sa login.

## Licencia
MIT (pozri LICENSE.txt)
