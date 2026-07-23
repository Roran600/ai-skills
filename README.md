# AI Skills for OpenCode

Kolekcja špecializovaných AI skillов pre **OpenCode** — interaktívny CLI nástroj na automatizáciu softvérových projektov.

## 📋 O Skilloch

AI skilly sú **rozširovacie moduly**, ktoré rozširujú funkčnosť OpenCode o špecifické domény a workflows. Každý skill obsahuje:

- **SKILL.md** — Podrobný návod a kontextové pokyny
- **Špecializované príkazy** — Prispôsobené pre konkrétnu oblasť
- **Reference a resources** — Linky na dokumentáciu a príklady
- **Automatické aktivovanie** — Ak detekuje relevantnu úlohu

## 🔧 Inštalácia

### Požiadavky
- **OpenCode** v0.2.0 alebo novšie
- `opencode.json` konfiguračný súbor v root priečinku projektu

### Krok 1: Klonuj Repozitár

```bash
git clone https://github.com/roran60/opencode-skills.git
cd opencode-skills
```

### Krok 2: Skopíruj Skilly do OpenCode Konfigurácie

**Na macOS/Linux:**
```bash
mkdir -p ~/.config/opencode/skills
cp -r ./* ~/.config/opencode/skills/
```

**Na Windows (PowerShell):**
```powershell
mkdir -Path "$env:APPDATA\opencode\skills" -Force
Copy-Item -Path ".\*" -Destination "$env:APPDATA\opencode\skills" -Recurse
```

### Krok 3: Prirad Skilly v `opencode.json`

Otvri `~/.config/opencode/opencode.json` a pridaj skilly do sekcie `skills`:

```json
{
  "skills": [
    {
      "name": "frontend-design",
      "description": "Tvorba high-quality frontend komponentov a UI",
      "location": "~/.config/opencode/skills/frontend-design"
    },
    {
      "name": "hugo-search",
      "description": "Bezpečný výskum pre Hugo Wiki s Git kontrolou",
      "location": "~/.config/opencode/skills/hugo-search"
    }
  ]
}
```

### Krok 4: Reštartuj OpenCode

```bash
# Uzavri aktuálnu session (Ctrl+C)
# A znovu spusti
opencode
```

## 📚 Dostupné Skilly

| Skill | Opis | Použitie |
|-------|------|---------|
| **frontend-design** | Tvorba webových komponentov a UI s vysokou kvalitou | Web komponenty, Landing pages, Dashboardy |
| **hugo-search** | Výskum a generovanie obsahu pre Hugo Wiki s bezpečnostnou kontrolou | Články, Dokumentácia, Markdown |

## 🚀 Ako Aktivovať Skill

OpenCode automaticky detekuje, kedy je skill relevantný. Napríklad:

```bash
# Aktivuje "frontend-design"
opencode
# > Vytvor mi Landing page s React komponentami
```

```bash
# Aktivuje "hugo-search"  
opencode
# > Vytvor mi README ku AI skillom
```

Alternatívne môžeš skill explicitne zavolať cez príkaz `Ctrl+P` v OpenCode CLI.

## 📖 Štruktúra Skillу

Každý skill obsahuje:

```
skill-name/
├── SKILL.md              # Podrobný návod a kontext
├── references/           # Linky na zdroje a dokumentáciu
├── scripts/              # Pomocné scripty (shell, Python, atď.)
└── templates/            # Šablóny (HTML, Markdown, CSS, atď.)
```

## ⚙️ Konfigurácia Skillkov

Skilly môžeš personalizovať úpravou:

1. **SKILL.md** — Zmena pokynov a kontextu
2. **references/** — Aktualizácia dokumentačných liniek
3. **opencode.json** — Deaktivovanie alebo zmena lokácie

## 🔐 Bezpečnosť

Každý skill implementuje **bezpečné praktiky**:

- ✅ Git status kontrola pred zápisom
- ✅ Žiadny prístup mimo autorizovaných priečinkov
- ✅ Výhradne čítajúci režim pre konfigurácne súbory
- ✅ Explicitný user consent pre deštruktívne operácie

## 📝 Príklady Použitia

### Príklad 1: Frontend Komponenta

```bash
opencode
# > Vytvor mi React komponent pre Login form s Tailwind CSS
```

### Príklad 2: Hugo Článok

```bash
opencode
# > Vytvor mi článok o Web3 s tabulkami a kódmi
```

## 🐛 Troubleshooting

### Problem: Skill sa Nezavádzá

**Riešenie:**
```bash
# Kontroluj cestu
ls ~/.config/opencode/skills/

# Overuj syntax v opencode.json
cat ~/.config/opencode/opencode.json | jq .skills
```

### Problem: Chyba Git Status

**Riešenie:**
Skill vyžaduje Git repozitár. Inicializuj ho:
```bash
cd project-root
git init
```

## 🤝 Príspevky

Vítame pull requesty a bugrépory! Prosím:

1. **Testujem lokálne** — Overi, že skill funguje
2. **Dokumentujem** — Uprav SKILL.md a README
3. **Commituj s jasným message** — "feat: Nový skill pre X"

## 📄 Licencia

MIT License — Voľné použitie v osobných i komerčných projektoch.

---

**Aktualizácia:** Júl 2026
