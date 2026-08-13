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

## Kontrakt výstupu
- **stdout** = iba cesty k vytvoreným súborom (jedna na riadok). Preto `files=$(./img.sh gen ...)` funguje.
- **stderr** = UI, diagnostika, chyby, otázky.
- Výnimka: `menu --dry-run` dáva plán na stdout, lebo plán je požadovaný výstup.

## Kroky použitia

1) **Schéma nástrojov (zadarmo)** – `./img.sh mcp tools/list | jq '.result.tools[] | select(.name=="generate-image")'`
   - Live stav (overené): `model`, `prompt`, `size`. Žiadne `aspect_ratio`, `input_references`, `n`, `seed`.

2) **Výber modelu**
   - Auto: `./img.sh models` (živý katalóg, `output_modalities=image`).
   - Manuál: slug od usera, over cez `./img.sh mcp get-model '{"request":{"author":"<author>","slug":"<slug>"}}'`.
   - **Pozor na cenu:** stĺpec s cenou je `image_output` z katalógu a **nie je to cena za obrázok**. Reálny call na `flux.2-klein-4b` stál podľa MCP `$0.015`, katalóg uvádza `$0.0000034`. Nikdy neuvádzaj userovi katalógovú hodnotu ako cenu za obrázok. Skutočnú cenu vypíše `gen` po calle a uloží ju do sidecaru.
   - API sort `pricing-low-to-high` je pre image modely bezcenný (prompt price je `$0/M` u všetkých), preto `./img.sh models` triedi lokálne podľa rozparsovanej ceny.

3) **Pomer a veľkosť**
   - `./img.sh size <pomer> <tier>` → reťazec pre MCP `size`.
   - Tiers: `1K|2K|4K` (standard/high/ultra). Pri 1:1 sa vracia natívny tier (`1K`), inak explicitné pixely (area-preserving, /8).
   - Overené rozmery:
     - 16:9 → 1K `1368x768`, 2K `2728x1536`, 4K `5464x3072`
     - 9:16 → 1K `768x1368`, 2K `1536x2728`, 4K `3072x5464`
     - 4:3 → 1K `1184x888`, 2K `2368x1776`, 4K `4728x3544`
     - 3:4 → 1K `888x1184`, 2K `1776x2368`, 4K `3544x4728`
     - 21:9 → 1K `1568x672`, 2K `3128x1344`, 4K `6256x2680`
   - **Provider rozmer zaokrúhľuje.** Žiadané `1368x768` vrátilo `1360x768`. Neber požadovanú veľkosť ako garanciu.

4) **Referenčné obrázky (MCP ich neprijíma)**
   - `generate-image` nemá pole pre obrázok, takže referencia sa **musí** stať textom v prompte. Ide o **štýlovú podobnosť, nie img2img**.
   - Všetkých 40 image modelov v katalógu má `input_modalities: [text, image]` – blokuje to MCP surface, nie modely.
   - `send-message` berie iba text, takže skript si referenciu **nemôže** dať opísať vision modelom.
   - `./img.sh reffacts <obrázok>` vytiahne objektívne fakty (paleta, rozmer, aspect, orientácia, jasnosť `L`, saturácia `S`) ako JSON. Subjekt a štýl musí opísať človek alebo agent.
   - Ako agent: obrázok si prečítaj Read toolom a opis vlož do `--ref-desc`: subjekt + akcia, kompozícia/uhol, paleta + svetlo, médium/štýl.

5) **Generovanie (platené)**
   - `./img.sh gen -m <model> -r <pomer> -q <tier> -o <outdir> "prompt1" "prompt2"`
   - Alebo `-f prompts.txt` (1 prompt na riadok; posledný riadok bez newline sa **nestratí**).
   - `gen` je čisto neinteraktívny – na adresár sa **nepýta**, bez `-o` píše do `./out`. Interaktívny výber cesty rieši `menu`.
   - `--upscale 2|4` upscaluje aj každý vytvorený obrázok.
   - Každý prompt = jeden platený MCP call (MCP nemá `n`). Pred batchom oznám userovi počet callov a model.
   - Výstup v `<outdir>`:
     - `NN-<model>.<ext>` – obrázok. **Prípona podľa magic bytes**, nie vždy PNG (flux vracia JPEG). Pri viac obrázkoch z jednej odpovede `NN-<model>-01.<ext>`, `-02` atď.
     - `NN-<model>.json` – sidecar: model, prompt, size, created, cost, tokens, status, files, upscaled, refs.
     - `raw/NN-<model>.raw.json` – odpoveď MCP. Ukladá sa **pred** parsovaním, takže zaplatený obrázok sa nestratí. Po úspechu sa base64 vystrihne, zostanú metadáta. Pri chybe zostáva celá, aby sa obrázok dal zachrániť.
   - Raw je v podadresári, aby `<outdir>/*.json` matchovalo iba sidecary.
   - **Batch pokračuje po chybe.** Jedno zlyhanie nezhodí ostatné prompty; `gen` vráti nenulový kód a vypíše súhrn. Zlyhaný sidecar má `status: "failed"`.

6) **Extrakcia base64 → súbory**
   - `./img.sh extract <file|-> [outdir] [basename]`
   - Vie MCP `CallToolResult`, `ImageContent`, `b64_json`, data URL aj holý base64. Príponu určí podľa magic bytes, poradie viacerých obrázkov zachová.
   - Ak MCP vrátil chybu (`isError`), vypíše **skutočný text chyby**, nie „no image found".

7) **Upscaling (resample)**
   - `./img.sh upscale img.jpg 2` (alebo `4`). Lanczos + unsharp. Nie je to generatívny super-res, len resampling.

## Interaktívne menu

`./img.sh menu` – hub, ktorý drží stav a vracia sa doň po každej zmene.

**Prvá otázka session je, kam sa obrázky uložia.** Padne pred menu, aby výstup nikdy neskončil v náhodnom adresári:

```
  Where should the images be saved?
    1) current directory  : /home/user/projekt
    2) custom path...
    3) ./out subdirectory : /home/user/projekt/out
  choice [1]:
```

- Enter = **1**, teda aktuálny adresár.
- `2` sa dopýta na cestu. Rozbalí `~`, adresár vytvorí (`mkdir -p`), overí zápis a uloží **absolútnu** cestu.
- Neplatná cesta (existuje ako súbor, nedá sa vytvoriť, nie je zapisovateľná) vypíše chybu a otázka sa zopakuje. Nič sa nezaplatilo.
- `q` tu skript ukončí.
- **Ak si dal `-o <cesta>` na príkazovej riadke, otázka sa preskočí.**

```
1) Model            : black-forest-labs/flux.2-klein-4b   [auto: lowest catalogue price]
2) References       : 1 (palette in brief: yes)
3) Aspect ratio     : 16:9
4) Resolution       : 2K   -> 2728x1536
5) Prompts          : 2
6) Upscale after gen: 2
7) Upscale an existing image...
8) Output dir       : /home/user/projekt
g) Generate         (2 paid call(s))
q) Quit
```

- **1 Model** – `a` auto (najnižšia katalógová cena), `l` výber zo zoznamu, `m` manuálny slug s validáciou cez `get-model` (zadarmo).
- **2 References** – pridanie cesty, `magick` fakty sa zobrazia a ty dopíšeš subjekt/štýl. `p` prepína, či ide paleta (hex kódy) do briefu – niektoré modely ich berú príliš doslovne.
- **3/4** – 6 pomerov × `1K/2K/4K`, hneď zobrazí výsledné pixely.
- **5 Prompts** – pridať, editovať v `$EDITOR`, načítať zo súboru, zmazať.
- **6** – upscale výstupov po generovaní (`off/2/4`).
- **7** – upscale existujúceho obrázka alebo globu, **bez** generovania.
- **8 Output dir** – ten istý picker ako pri štarte, plus `b` = ponechať súčasnú cestu. Rovnaká validácia.
- **g** – potvrdenie pred platbou. Zablokuje sa, ak nie je model alebo prompt. Cenu **pred** callom neodhaduje (katalóg je nepoužiteľný), po calle vypíše skutočnú. Po dobehnutí vypíše ekvivalentný `gen`/`menu` príkaz na reprodukciu.

## Neinteraktívny režim (pre agenta)

```
./img.sh menu --non-interactive -m <model> -r 16:9 -q 2K -o out \
  --prompt "..." [--prompt "..."] \
  [--ref path --ref-desc "opis"] [--no-palette] [--upscale 2|4] \
  [--max-calls N] [--yes]
```

- Bez `--yes` = **dry-run**: vypíše rozhodnutý plán vrátane finálnych promptov so vloženým ref briefom. Neplatí nič.
- S `--yes` generuje. Pred callmi vypíše počet a model.
- **Na výstupný adresár sa nikdy nepýta** – bez `-o` použije `./out`. Otázka o adresári je len v interaktívnom režime.
- `--max-calls N` (default **4**) je poistka proti prepáleniu peňazí v smyčke. Viac promptov než limit = odmietnutie.
- `--ref` a `--ref-desc` sa párujú **poradím**.

Exit kódy `menu`:

| kód | význam |
|-----|--------|
| 0 | ok / dry-run |
| 1 | chyba (napr. prekročené `--max-calls`, zlyhané generovanie) |
| 2 | nie je TTY a nebolo dané `--non-interactive` |
| 10 | `--ref` bez `--ref-desc`; zapísal `<outdir>/refs.pending.json`, **nič sa nezaplatilo** |

Pri exite 10: prečítaj obrázky Read toolom, doplň popisy a spusť znova s `--ref-desc` v rovnakom poradí.

Bez TTY a bez `--non-interactive` skript **odmietne** bežať (exit 2), aby agentovi nevisel bash call na stdin.

## Obmedzenia MCP
- `generate-image` prijíma iba: `model`, `prompt`, `size`. Aspect ratio rieš explicitnou veľkosťou, referencie opisom v prompte.
- Každý prompt = samostatný platený call.
- Katalógová cena ≠ cena za obrázok (viď bod 2).

## Rýchly workflow pre agenta
1. `./img.sh mcp tools/list` (raz na session) – over schému.
2. `./img.sh models | head` – vyber model.
3. `./img.sh size 16:9 2K` – over výslednú veľkosť.
4. Priprav prompt. Ak je referencia, prečítaj ju Read toolom a opíš do `--ref-desc`.
5. `./img.sh menu --non-interactive -m <model> -r 16:9 -q 2K -o out --prompt "..."` – dry-run, skontroluj plán.
6. To isté s `--yes` – generuj. Oznám userovi počet callov a model dopredu.
7. (Voliteľné) `--upscale 2` alebo `./img.sh upscale out/01-<model>.jpg 2`.

## Poznámka k autentifikácii
- Token z `mcp-auth.json` exp. po ~7 dňoch. Ak skript zahlási expiráciu, v OpenCode spusti ľubovoľný OpenRouter MCP tool a obnoví sa login.

## Testovací hook
- `IMG_ASSUME_TTY=1` obíde TTY guard, aby sa interaktívna smyčka dala testovať skriptovaným stdin. Nepoužívaj na generovanie.
- Pozor: prvý riadok skriptovaného stdin zhltne **otázka o výstupnom adresári**. Buď ju obsluž (`1` = cwd), alebo ju vynechaj cez `-o <cesta>`.

## Licencia
MIT (pozri LICENSE.txt)
