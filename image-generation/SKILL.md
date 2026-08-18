---
name: image-generation
description: "Vygeneruj obrázok / nakresli / ilustrácia / logo / banner / generate image – cez OpenRouter MCP bash skriptom img.sh (batch, upscaling, referencie)"
license: MIT
compatibility:
  mcp: openrouter
metadata:
  audience: "OpenCode agent"
  workflow: "CLI / bash"
---

# Generovanie obrázkov

## Agent: spusti presne toto

Pravidlá, ktoré platia nad všetkým ostatným v tomto súbore:

- **Toto nie je text na prerozprávanie ani na odkývanie.** Nevypisuj tieto pravidlá – konaj. Príkazy nižšie spusti Bash toolom.
- **Hotovo je až vtedy, keď na disku existuje súbor s obrázkom.** Nie keď vieš, ako by sa vygeneroval.
- **Nikdy neodovzdaj výstup `plan (nothing has been generated yet):` ako výsledok.** To je dry-run, obrázok pri ňom nevznikne.
- **Nikdy nevráť prácu userovi so slovami „spusti to v termináli“.** Ak `menu` zlyhá na TTY, postupuj podľa playbooku nižšie.

### Keď user povie „spusti menu“ / chce nastavenia

`menu` bez `--non-interactive` **nespúšťaj** – bez TTY vždy spadne (exit 2). Namiesto toho:

1. `"$IMG" menu --questions` – vypíše zoznam parametrov (nič nestojí, nepotrebuje TTY).
2. Ak user chce výber modelu, načítaj rebríčky a zobraz mu stručné možnosti:
   `"$IMG" models price 5`, `"$IMG" models speed 5`, `"$IMG" models quality 5`.
   Prvý stĺpec je slug modelu; pri `auto` použi najlacnejší model z `price`.
3. Polož userovi všetky potrebné otázky v **jednej** správe. Na čo už odpoveď máš, sa nepýtaj.
4. Po odpovedi zostav príkaz s vybranými parametrami a generuj cez
   `--non-interactive --yes`; menu nesmie skončiť iba dry-run plánom.

Plné interaktívne TUI vie spustiť len user vo vlastnom termináli (`"$IMG" menu`) – ponúkni to nanajvýš ako druhú možnosť, nie ako svoju odpoveď.

### 1. Nájdi skript (raz na session)

```bash
IMG=$(find ~/.config/opencode/skills ~/.claude/skills ~/.agents/skills \
  .opencode/skills .claude/skills .agents/skills \
  -maxdepth 2 -name img.sh -type f 2>/dev/null | head -1); echo "IMG=${IMG:-NOT FOUND}"
```

- Vypíše cestu → pokračuj krokom 2.
- Vypíše `IMG=NOT FOUND` → oznám userovi, že skript skillu sa nenašiel, a skonči. Nič si nevymýšľaj.
- `$IMG` drží hodnotu v tej istej bash session. Keď neskôr príkaz spadne na `No such file`, spusti tento resolve znova.
- **Nikdy nepíš `./img.sh`.** Skript nie je v pracovnom adresári usera ani na `PATH`; relatívna cesta vždy zlyhá.

### 2. Vygeneruj

```bash
"$IMG" menu --non-interactive --yes \
  -m black-forest-labs/flux.2-klein-4b -r 16:9 -q 2K -o . \
  --prompt "<prompt po anglicky, konkrétny: subjekt, kompozícia, svetlo, štýl>"
```

- `--yes` je **povinné**. Bez neho skript iba vypíše plán a nič nevygeneruje.
- `-o .` ukladá do aktuálneho adresára. Ak user povedal iný adresár, daj tam jeho cestu.
- Jeden prompt = jeden platený MCP call, reálne ≈ `$0.015`. **Pri jednom obrázku nerob dry-run, generuj hneď.**
- Model neriešiš, ak user nemá požiadavku – default vyššie je funkčný a lacný.

### 3. Ohlás výsledok

- Skript vypíše `IMAGE(S) CREATED:` a cesty k súborom. Tie cesty daj userovi.
- Skutočnú cenu vezmi z riadku `Done: ... Actual cost reported by MCP: $X`.
- Ak vypíše `NO IMAGE WAS CREATED` alebo sidecar má `status: "failed"`, povedz konkrétnu chybu. Nepredstieraj úspech.

## Viac obrázkov naraz (batch)

Pri **2 a viac** promptoch najprv over plán bez `--yes`:

```bash
"$IMG" menu --non-interactive -m <model> -r 16:9 -q 2K -o . \
  --prompt "prvý" --prompt "druhý"
```

Potom oznám userovi počet platených callov a model, a spusti ten istý príkaz s `--yes`.
`--max-calls N` (default **4**) je strop proti prepáleniu peňazí; viac promptov než limit skript odmietne.

## Výber modelu

**Model neriešiš, ak to user výslovne nechce** – default `black-forest-labs/flux.2-klein-4b` je funkčný a lacný. Kategórie nižšie použi **iba** keď user povie „najlacnejší / najrýchlejší / najlepší / najkvalitnejší“.

Radenie beží cez OpenRouter MCP (žiadne REST/SDK). Slug je **vždy prvý stĺpec**, takže ber prvý stĺpec, nikdy nevkladaj celý riadok do `-m`:

```bash
"$IMG" models price   1 | cut -f1     # najlacnejší
"$IMG" models speed   1 | cut -f1     # najrýchlejší
"$IMG" models quality 1 | cut -f1     # najkvalitnejší (najvyššie design-arena elo)
```

Celý rebríček (TSV `slug  cena  elo  win%  rýchlosť`): `"$IMG" models <price|speed|quality> [N]` (N default 20).

- **price** – najlacnejšie prvé (dáta pre ~43/45 modelov).
- **speed** – 10 modelov s reálne meraným časom generovania, zvyšok proxy podľa throughputu, značený `~rN`. API `latency` sort sa **nepoužíva** – model s reálnymi 201 s v ňom vyjde ako 11. najrýchlejší z 45 (meria time-to-first-token, nie čas obrázka).
- **quality** – iba modely s meraným design-arena elo (~10).
- Ak `models` vypíše `NO RANKING DATA from MCP`, použi default model a pokračuj v generovaní – **nevypisuj namiesto toho vysvetlenie**.

Slug od usera over zadarmo: `"$IMG" mcp get-model '{"request":{"author":"<author>","slug":"<slug>"}}'`.

**Cena v katalógu nie je cena za obrázok.** Je to `image_output` za token. Reálny call na `flux.2-klein-4b` stál `$0.015`, katalóg uvádza `$0.0000034`. Userovi nikdy neuvádzaj katalógovú hodnotu ako cenu za obrázok – použi skutočnú cenu z výstupu `gen`.


## Pomer a veľkosť

`"$IMG" size <pomer> <tier>` vráti reťazec pre MCP `size`. Tiers `1K|2K|4K`, pomery `1:1 16:9 9:16 4:3 3:4 21:9`.

| pomer | 1K | 2K | 4K |
|-------|----|----|----|
| 16:9 | 1368x768 | 2728x1536 | 5464x3072 |
| 9:16 | 768x1368 | 1536x2728 | 3072x5464 |
| 4:3 | 1184x888 | 2368x1776 | 4728x3544 |
| 3:4 | 888x1184 | 1776x2368 | 3544x4728 |
| 21:9 | 1568x672 | 3128x1344 | 6256x2680 |

Pri `1:1` sa posiela natívny tier (`1K`). **Provider rozmer zaokrúhľuje** – žiadané `1368x768` vrátilo `1360x768`, neber požadovanú veľkosť ako garanciu.

## Referenčné obrázky

MCP `generate-image` **neprijíma obrázky**, iba `model`, `prompt`, `size`. Referencia sa preto musí stať textom v prompte – ide o **štýlovú podobnosť, nie img2img**.

```bash
"$IMG" reffacts <obrázok>        # objektívne fakty: paleta, rozmer, aspect, jasnosť, saturácia
"$IMG" menu --non-interactive --yes -m <model> -o . \
  --ref <obrázok> --ref-desc "subjekt + akcia, kompozícia/uhol, paleta + svetlo, médium/štýl" \
  --prompt "<prompt>"
```

- `--ref` a `--ref-desc` sa párujú **poradím**.
- `--ref` bez `--ref-desc` skončí exitom **10**, zapíše `<outdir>/refs.pending.json` a **nič nezaplatí**. Vtedy: obrázok si prečítaj Read toolom, doplň popis a spusti znova.
- Subjekt a štýl musí opísať človek alebo agent – `send-message` berie iba text, takže skript si referenciu nedá opísať vision modelom.
- `--no-palette` vynechá hex kódy z briefu; niektoré modely ich berú príliš doslovne.

## Upscaling

```bash
"$IMG" upscale <obrázok> 2       # alebo 4; Lanczos + unsharp
```

Alebo `--upscale 2|4` pri generovaní – upscaluje každý vytvorený obrázok. Nie je to generatívny super-res, len resampling.

## Interaktívne menu (iba pre človeka v termináli)

`img.sh menu` bez `--non-interactive` je hub pre **človeka**: drží stav a vracia sa doň po každej zmene.

**Agent ho nesmie spúšťať** – bez TTY skončí exitom **2**. Keď user chce nastavenia, agent postupuje podľa playbooku „Keď user povie »spusti menu«“ vyššie. Bez-TTY workflow musí zachovať rovnaké voľby ako picker: model, referencie, pomer, rozlíšenie, prompty, upscale a výstupný adresár.

Pre **človeka**: plný picker spustíš vo vlastnom termináli:

```bash
"$IMG" menu
```

Prvá otázka po štarte je, kam sa obrázky uložia:

```
  Where should the images be saved?
    1) current directory  : /home/user/projekt
    2) custom path...
    3) ./out subdirectory : /home/user/projekt/out
  choice [1]:
```

- Enter = **1**, aktuálny adresár. `2` sa dopýta na cestu (rozbalí `~`, vytvorí adresár, overí zápis, uloží absolútnu cestu). `q` ukončí.
- Neplatná cesta vypíše chybu a otázka sa zopakuje. `-o <cesta>` na príkazovej riadke otázku preskočí.

Potom nasleduje hub:

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

- **1** rozcestník `1) price  2) speed  3) quality  a) auto  m) manual  b) back`. Kategórie otvoria stránkovaný rebríček (5 na stranu, globálne číslovanie 1–20, `n`/`p` listovanie, `m` manuál, `b` späť) s cenou, elo/win % a rýchlosťou pri každom modeli. `a` auto = najlacnejší z katalógu, `m` manuálny slug s validáciou cez `get-model` (zadarmo).
- **2** pridanie cesty, `magick` fakty sa zobrazia a user dopíše subjekt/štýl; `p` prepína paletu v briefe.
- **3/4** 6 pomerov × `1K/2K/4K`, hneď zobrazí výsledné pixely.
- **5** pridať prompt, editovať v `$EDITOR`, načítať zo súboru, zmazať.
- **6** upscale výstupov po generovaní (`off/2/4`). **7** upscale existujúceho obrázka alebo globu **bez** generovania.
- **8** ten istý picker ako pri štarte, plus `b` = ponechať súčasnú cestu.
- **g** potvrdenie pred platbou; zablokuje sa bez modelu alebo promptu. Cenu pred callom neodhaduje (katalóg je nepoužiteľný), po calle vypíše skutočnú a ekvivalentný príkaz na reprodukciu.

## Referencia

**Kontrakt výstupu**
- **stdout** = iba cesty k vytvoreným súborom (jedna na riadok), takže `files=$("$IMG" gen ...)` funguje.
- **stderr** = UI, diagnostika, chyby, otázky.
- Výnimka: plán z `--non-interactive` bez `--yes` ide na stdout.

**Výstupné súbory v `<outdir>`**
- `NN-<model>.<ext>` – obrázok. **Prípona podľa magic bytes**, nie vždy PNG (flux vracia JPEG). Viac obrázkov z jednej odpovede: `NN-<model>-01.<ext>`, `-02`…
- `NN-<model>.json` – sidecar: model, prompt, size, created, cost, tokens, status, files, upscaled, refs.
- `raw/NN-<model>.raw.json` – odpoveď MCP, ukladá sa **pred** parsovaním, takže zaplatený obrázok sa nestratí. Po úspechu sa base64 vystrihne; pri chybe zostáva celá, aby sa obrázok dal zachrániť cez `"$IMG" extract <raw> <outdir> <base>`.
- Raw je v podadresári, aby `<outdir>/*.json` matchovalo iba sidecary.
- **Batch pokračuje po chybe**; `gen` vráti nenulový kód a vypíše súhrn.

**Obmedzenia MCP**
- `generate-image` prijíma iba `model`, `prompt`, `size`. Žiadne `aspect_ratio`, `n`, `seed`, ani vstupné obrázky. Schému over cez `"$IMG" mcp tools/list`.
- Každý prompt = samostatný platený call.

**Exit kódy `menu`**

| kód | význam |
|-----|--------|
| 0 | ok / dry-run |
| 1 | chyba (prekročené `--max-calls`, zlyhané generovanie) |
| 2 | nie je TTY a nebolo dané `--non-interactive` |
| 10 | `--ref` bez `--ref-desc`; zapísal `refs.pending.json`, nič sa nezaplatilo |

**Autentifikácia**
- Token sa načíta z `~/.local/share/opencode/mcp-auth.json` (`openrouter.tokens.accessToken`), inak z `OPENROUTER_API_KEY`. Skript token nikdy nevypíše.
- Token expiruje po ~7 dňoch. Pri hlásení o expirácii spusti v OpenCode ľubovoľný OpenRouter MCP tool a login sa obnoví.

**Závislosti**: `curl`, `jq`, `base64`, `awk`, `file`, `magick` (ImageMagick).

**Testovací hook**: `IMG_ASSUME_TTY=1` obíde TTY guard pre testovanie interaktívnej smyčky skriptovaným stdin. Prvý riadok stdin zhltne otázka o výstupnom adresári (alebo ju vynechaj cez `-o`). Voľba `g` (platené generovanie) je pri tomto hooku **zablokovaná**, takže z podvrhnutého TTY sa nedá minúť; na reálne generovanie použi `menu --non-interactive --yes`.

## Licencia
MIT (pozri LICENSE.txt)
</content>
