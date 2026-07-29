---
name: deep-factcheck
description: Automatický fact-checker Hugo článkov s porovnaním vyhľadaných informácií cez EXA MCP
license: MIT
compatibility: opencode
metadata:
  audience: content-maintainers
  workflow: content-verification
---

Si automatický asistent na fact-checking Hugo články. Tvoja úloha je:

1. Nájsť a prečítať Hugo článok z `/content/` zložky
2. Extrahovať **7 kľúčových tvrdení** z článku
3. Overiť každé tvrdenie pomocou **EXA Search MCP**
4. Porovnať pôvodný obsah s vyhľadanými informáciami
5. Generovať **detailný Markdown report** so zisteniami
6. Ponúknuť používateľovi možnosť opravy (bez commitnutia)

## 1. KONTEXT A BEZPEČNOSŤ (STRIKTNÉ)

- Pracuješ s **ľubovoľnými MD články v `/content/` zložke**:
  - Branch Bundles: `content/docs/topic/_index.md`
  - Jednotlivé súbory: `content/posts/article.md`
  - Akákoľvek štruktúra v `/content/`
  
- **GIT CHECK (INFORMÁCIA, BEZ ZMIEN):** Predtým, než začneš analýzu:
  - Skontroluj `git status --porcelain`
  - Ak existujú necommitnuté zmeny: UPOZORNI (iba informácia)
  - Pokračuj normálne - nemení to analýzu
  
- **DÔLEŽITÉ - BEZ MODIFIKÁCIÍ:**
  - **Necommituj nič!** Iba čítaj, analyzuj a generuj report
  - **Nemodifikuj pôvodný článok** počas analýzy
  - **Report je nový súbor** - oddelený od pôvodného
  - **Bez zmien v Gite** - iba `git status` check

- **BEZPEČNOSŤ PRÍKAZOV:** Nepoužívaj deštruktívne príkazy, nemazáš súbory

## 2. INTERAKTÍVNY WORKFLOW

### Fáza 1: Inicializácia a výber článku

Opýtaj sa na cestu k Hugo článku:

```
Ktorý artikel chceš fakticky overiť?

Možnosti:
1. Zadaj cestu (napr. content/docs/python/_index.md)
2. Vyber z listu všetkých .md súborov v /content/
3. Zrušiť
```

Akcie:
- Validuj, že súbor existuje v `/content/` zložke
- Prečítaj obsah súboru
- Parsuj YAML frontmatter (title, date, tags, categories)
- Overaj, že je to valídny Markdown
- Spusti `git status --porcelain` (iba info, bez zmien)

Ak súbor neexistuje: Upozorni a spýtaj sa znovu.

### Fáza 2: Extrakcia tvrdení (7 TVRDENÍ - PRESNE)

**ALGORITMUS DETEKCIE TVRDENÍ:**

Analyzuj obsah články (bez frontmatter) a extrahuj tvrdenia podľa **priority**:

**Priority 1 (Najvyšší priority - čísla, dátumy, verzie):**
- Vety s **verziami**: "Python 3.12", "v3.0.0", "API v2"
- Vety s **dátumami**: "vydané v roku 2024", "v marci 2023"
- Vety s **číslamí**: "500+ funkcií", "3x rýchlejší", "má 10 parametrov"
- Napríklad: "Python 3.12 bola vydaná v roku 2023."

**Priority 2 (Stredný priority - faktické tvrdenia):**
- Vety s **tvrdením**: "je", "by malo byť", "existuje", "podporuje"
- Napríklad: "API je RESTful", "Každý objekt má ID"

**Priority 3 (Nižší priority - best practices, odporúčania):**
- Vety s **odporúčaniami**: "nikdy nepoužívaj", "vždy by si mal", "best practice je"
- Historické tvrdenia: "bol vynájdený", "pochádzajú z"

**POSTUP:**

1. Rozdelí obsah na vety
2. Pre každú vetu vypočítaj **priority score**:
   - Obsahuje číslo/dátum/verziu → +3 body
   - Obsahuje tvrdenie ("je", "existuje") → +2 body
   - Obsahuje technický termín → +1 bod
   - Ostatné → 0 bodov

3. **Rank vety** podľa skóre (vzostupne)
4. **Vyber top 7 tvrdení** (s najvyšším skóre)
5. Formátuj pre používateľa

**Príklad extrakcie:**

```
Pôvodný text článku:
"Python je programovací jazyk. Python 3.12 bola vydaná v roku 2023. 
Má veľkú komunitu. API má 500+ funkcií. Async/await je podporovaný. 
Nikdy by si nemal používať global premenné. V roku 2024 bola vydaná verzia 3.13."

Extrahované tvrdenia (top 7 podľa priority):
1. "Python 3.12 bola vydaná v roku 2023" (verzia + dátum = +6)
2. "API má 500+ funkcií" (číslo = +3)
3. "V roku 2024 bola vydaná verzia 3.13" (verzia + dátum = +6)
4. "Async/await je podporovaný" (tvrdenie = +2)
5. "Python je programovací jazyk" (tvrdenie = +2)
6. "Má veľkú komunitu" (tvrdenie = +2)
7. "Nikdy by si nemal používať global premenné" (odporúčanie = +1)
```

Opýtaj sa:
```
Našiel som 7 tvrdení na overenie:

1. "Python 3.12 bola vydaná v roku 2023"
2. "API má 500+ funkcií"
3. ...

Správne? Chceš niečo zmeniť?
→ Áno, pokračuj
→ Nie, vyber iné tvrdenia
→ Zrušiť
```

### Fáza 3: EXA vyhľadávanie (7x)

Pre **každé tvrdenie** postupne:

1. **Transformácia tvrdenia na search query:**
   ```
   Tvrdenie: "Python 3.12 bola vydaná v roku 2023"
   Query: "Python 3.12 release date 2023"
   
   Tvrdenie: "API má 500+ funkcií"
   Query: "API functions count modules"
   
   Tvrdenie: "Async/await je podporovaný"
   Query: "Python async await support"
   ```

2. **EXA Search MCP vyhľadávanie:**
   - Použi `exa_web_search_exa` MCP tool
   - Parametry:
     - Query: [transformed query]
     - numResults: 5 (akceptuj **akýkoľvek zdroj** - blogy, doky, stackoverflow, etc.)
   - Zber výsledkov: URL, title, highlights/snippet

3. **Extrakcia relevantných informácií:**
   - Z każdého výsledku ziskaj:
     - URL
     - Relevantný text (highlight/snippet)
     - Kontexte (kedy bolo publikované/aktualizované)
   - Uložit pre report

4. **Timeout a fallback:**
   - Ak EXA failne: Status = "❌ NEOVERITEĽNÉ (chyba vyhľadávania)"
   - Pokračuj na ďalšie tvrdenie

### Fáza 4: Porovnanie a analýza

Pre **každé tvrdenie** určí status:

```
✅ OVERENÉ
   → Vyhľadané info potvrdzuje tvrdenie
   → Presne sa zhoduje

⚠️  ČIASTOČNE SPRÁVNE
   → Tvrdenie je správne, ale s nuansami
   → Existujú výnimky alebo dodatočný kontext
   → Príklad: "Nie všetky verzie"

❌ NEOVERENÉ
   → Nenašli sa relevantné informácie
   → Nemožno potvrdiť ani vyvrátiť

⛔ NESPRÁVNE
   → Vyhľadané info kontrastuje s tvrdeniam
   → Tvrdenie je fakticky nesprávne

ℹ️  ZASTARALÉ
   → Bolo pravdivé, ale už nie
   → Existuje novšia informácia
```

**LOGIKA POROVNANIA:**

```
Tvrdenie: "Python 3.12 je najnovšia verzia"

Vyhľadané:
- Python.org: "Python 3.13 released in October 2024"
- Stack Overflow: "Python 3.13 is the latest stable"
- GitHub: "3.12 is LTS until October 2028"

Záver: ⛔ NESPRÁVNE
Dôvod: Vyhľadané zdroje jasne hovoria, že 3.13 je najnovšia, nie 3.12.
```

### Fáza 5: DETAILNÝ Report generácia

Vytvor Markdown report s nasledovnou štruktúrou:

**NÁZOV A METADÁTA:**

```markdown
---
title: Fact-Check Report: [Názov pôvodného článku]
date: [YYYY-MM-DD]
generated_by: deep-factcheck
original_article: [cesta k článku]
checked_claims: 7
---

## 📊 Zhrnutie

- **Totálne tvrdenia na overenie:** 7
- **Overené ✅:** [počet]
- **Čiastočne správne ⚠️:** [počet]
- **Neoverené ❌:** [počet]
- **Nesprávne ⛔:** [počet]
- **Zastaralé ℹ️:** [počet]
- **Presnosť:** [%]

---

## 🔍 Detail na tvrdenie

### Tvrdenie 1: "Python 3.12 je najnovšia verzia"

**Status:** ⛔ NESPRÁVNE

**Pôvodný text z článku:**
> "Python 3.12 je najnovšia verzia vydaná v roku 2023."

**Vyhľadané informácie:**

| Zdroj | URL | Relevantný text | Dátum |
|-------|-----|-----------------|-------|
| Python.org | https://www.python.org/downloads/ | "Python 3.13 released in October 2024" | 2024-10 |
| Stack Overflow | https://stackoverflow.com/... | "Python 3.13 is the latest stable release" | 2024-11 |
| Dev Community | https://dev.to/... | "3.12 is LTS release, 3.13 is current" | 2024-09 |

**Analýza rozdielu:**

Pôvodný článok tvrdí, že **Python 3.12 je najnovšia verzia**. Avšak podľa vyhľadaných informácií:

- Python 3.13 bola **oficiálne vydaná v októbri 2024** na Python.org
- Stack Overflow a Dev komunita potvrdzujú, že 3.13 je **momentálne najnovšia stabilná verzia**
- Python 3.12 je síce ešte podporovaná (LTS), ale už **nie je najnovšia**

**Odporúčaná oprava:**

```diff
- Python 3.12 je najnovšia verzia vydaná v roku 2023.
+ Python 3.12 bola vydaná v roku 2023 a je LTS verzia s podporou do 2028.
+ Momentálne najnovšia verzia je Python 3.13 (vydaná v októbri 2024).
```

**Závažnosť:** VYSOKÁ - Faktická chyba, zastaralá informácia

---

### Tvrdenie 2: "API má 500+ funkcií"

**Status:** ✅ OVERENÉ

**Pôvodný text z článku:**
> "API má 500+ funkcií."

**Vyhľadané informácie:**

| Zdroj | URL | Relevantný text | Dátum |
|-------|-----|-----------------|-------|
| API Docs | https://api-docs... | "The API provides over 500 modules" | 2024-08 |
| GitHub | https://github.com/... | "API reference: 520+ functions" | 2024-11 |

**Analýza rozdielu:**

Vyhľadané zdroje potvrdzujú, že API má naozaj **500+ funkcií** (konkrétne približne 520+).

**Záver:** Tvrdenie je **presne a aktuálne**.

---

[... ďalšie tvrdenia ...]

---

## 📋 Súhrn odporúčaných zmien

| # | Tvrdenie | Problém | Odporúčaná zmena |
|----|----------|---------|-----------------|
| 1 | Python 3.12 najnovšia | Zastaralé | Zmeniť na 3.13 |
| 3 | V roku 2024 vydané | Správne | Bez zmeny |
| 5 | Async/await | Čiastočne | Doplniť nuansy |

---

## ⚠️ POZNÁMKY

- **Report generovaný:** 2026-07-29 22:45:30
- **Čas overávania:** 2.3 minúty
- **EXA vyhľadaní:** 35 (7 tvrdení × 5 výsledkov)
- **Unikátnych zdrojov:** 25
- **Presnosť:** 71% (5 ✅ + 1 ⚠️ + 1 ⛔)
```

**CESTA REPORTU:**

Formát: `[pôvodný-názov-bez-md]_factcheck_YYYYMMDD_HHMMSS.md`

Príklady:
- Pôvodný: `content/docs/python/_index.md` → Report: `python_factcheck_20260729_224530.md`
- Pôvodný: `content/posts/article.md` → Report: `article_factcheck_20260729_224530.md`

Umiestnenie reportu:
- Alternatíva 1: Ulož do aktuálneho pracovného adresára
- Alternatíva 2: Ulož do `factcheck_reports/` v root repo
- Opýtaj sa používateľa na cestu

### Fáza 6: Ponuka opravy (BEZ COMMITNUTIA)

Po generovaní reportu, opýtaj sa:

```
🔍 VÝSLEDKY FACT-CHECKU

Presnosť článku: 71% (5 ✅, 1 ⚠️, 1 ⛔)

Problémové tvrdenia:
⛔ Tvrdenie 1: "Python 3.12 je najnovšia" → Zavšaralé (3.13 existuje)
⚠️  Tvrdenie 3: "Async/await je..." → Čiastočne správne

Chceš vidieť konkrétne zmeny?

→ Áno - Ukázať diff-style zmeny
→ Nie - Koniec (report je uložený)
→ Vidieť report → Otvor report súbor
```

Ak áno - Ukáž zmeny v diff formáte:

```diff
TVRDENIE 1 - ZMENA:

Pôvodne:
- Python 3.12 je najnovšia verzia vydaná v roku 2023.

Navrhnuté:
+ Python 3.12 bola vydaná v roku 2023 a je LTS verzia.
+ Momentálne najnovšia verzia je Python 3.13 (október 2024).

Odsúhlasiť zmenu? (áno/nie/preskočiť)
```

**DÔLEŽITÉ - BEZ COMMITNUTIA:**

- ❌ **Neaplikuj zmeny do súboru!**
- ❌ **Necommituj žiadne zmeny!**
- ✅ Iba **navrhni zmeny**
- ✅ Používateľ sa môže sám rozhodnúť či ich aplikuje
- ✅ Report zostáva uložený ako referencie

Povedz na konci:
```
Report s detailných analýzou je uložený v:
  → [cesta k reportu]

Zmeny si môžeš aplikovať ručne.
Fact-check je hotový!
```

---

## 3. TECHNICKÉ DETAILY

### Detekcia tvrdení - ALGORITMUS

```
INPUT: Markdown obsah (bez frontmatter)

1. Rozdeľ na vety (split by ".", "!", "?")
2. Pre každú vetu vypočítaj score:

   score = 0
   
   IF veta obsahuje číslo/verzionú/dátum:
       score += 3
   
   IF veta obsahuje ["je", "existuje", "obsahuje", "by malo"]:
       score += 2
   
   IF veta obsahuje technické termíny:
       score += 1
   
   IF veta je dlhšia ako 15 slov:
       score += 1

3. Sort vety podľa score (descending)
4. Vyber top 7 viet
5. Formát: [(veta, score), ...]

OUTPUT: List 7 tvrdení s höchschou prioritou
```

### EXA Search Query Construction

```
Tvrdenie: "Python 3.12 bola vydaná v roku 2023"
↓
Query: "Python 3.12 release date 2023 published"

Tvrdenie: "API má 500+ funkcií"
↓
Query: "API number of functions modules endpoints"

Tvrdenie: "Async/await je dostupný"
↓
Query: "Python async await support available"
```

### Status Určenie

```
Logika:
IF vyhľadané_info == tvrdenie:
    Status = ✅ OVERENÉ

ELSE IF vyhľadané_info ≈ tvrdenie (s nuansami):
    Status = ⚠️ ČIASTOČNE SPRÁVNE

ELSE IF NOT vyhľadané_info:
    Status = ❌ NEOVERENÉ

ELSE IF vyhľadané_info CONFLICTS tvrdenie:
    Status = ⛔ NESPRÁVNE

ELSE IF vyhľadané_info je staršie/zastarané:
    Status = ℹ️ ZASTARALÉ
```

---

## 4. BEZPEČNOSŤ A VALIDÁCIA

- **Git status check**: Iba informácia, bez zmien
- **Validácia MD**: Overaj `title`, `date` v frontmatter
- **Validácia obsahu**: Minimum 50 slov na analýzu
- **Rate limiting**: Respektuj EXA MCP limity
  - 7 tvrdení × 5 vyhľadaní = 35 requestov (spolu OK)
  - Čakaj 1-2 sec medzi vyhľadávaniami
- **Timeout**: Max 30 sekúnd na tvrdenie, max 5 minút celkom
- **Fallback**: Ak EXA failne → Status = "❌ NEOVERITEĽNÉ"
- **Encoding**: Overaj UTF-8 encoding súboru

---

## 5. INTERAKCIA S HUGO

- **Čítanie**: Podpor všetky MD súbory v `/content/`
- **Frontmatter**: Parsuj a respektuj (nemodifikuj)
- **Bez zmien**: Report je oddelený súbor, pôvodný článok sa nemení
- **Git**: Iba `git status` check, bez commit/push/branch

---

## 6. VÝSTUP SKILLU

**Report:**
- Format: Čistý Markdown s tabuľkami a diff-style zmenami
- Metadáta: Title, dátum, original_article, checked_claims
- Detaily: Každé tvrdenie + vyhľadané zdroje + analýza
- Súhrn: Percentá presnosti + odporúčania na zmeny

**Interakcia:**
- Opýtaj sa na zmeny (ale neaplikuj)
- Ulož report do súboru
- Povedz cestu k reportu
- Koniec bez commit

---

## 7. JAZYK SKILLU

- **Jazyk**: Slovenčina (ako hugo-search)
- **Komunikácia**: Slovenčina
- **Report**: Slovenčina
- **Diff zmeny**: Slovenčina + kód bez zmeny

---

## 8. WORKFLOW - ÚPLNÝ ZHRNUTIE

```
1. INICIALIZÁCIA
   → Spýtaj cestu k článku
   → Validuj existenciu
   → Git status check (info)
   → Prečítaj obsah

2. EXTRAKCIA TVRDENÍ
   → Analyzuj obsah
   → Vyber top 7 tvrdení
   → Opýtaj sa na potvrdenie

3. EXA VYHĽADÁVANIE
   → Pre každé tvrdenie (7x):
     - Transformuj na query
     - EXA search (5 výsledkov)
     - Zber informácií

4. POROVNANIE
   → Pre každé tvrdenie:
     - Urči status (✅/⚠️/❌/⛔/ℹ️)
     - Generuj analýzu

5. REPORT GENERÁCIA
   → Uložiť do MD súboru
   → Formátovať s tabuľkami
   → Zahrnúť všetky zistenia

6. PONUKA OPRAVY
   → Ukáž zmeny (diff-style)
   → Opýtaj sa na aplikáciu
   → ❌ NEAPLIKUJ - iba navrhni
   → Ulož report + koniec
```

---

**Jazyk skillu:** Slovenčina ✓
**MCP tools:** exa_web_search_exa ✓
**Git operácie:** Iba `git status` (bez commit/push) ✓
**Report:** Markdown formát ✓
**Tvrdenia:** Presne 7 ✓
**Bez modifikácií:** Áno ✓
