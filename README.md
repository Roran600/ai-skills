# AI Skills for OpenCode

Zbierka špecializovaných AI skillов pre **OpenCode** — interaktívny CLI AI agent na automatizáciu a vývoj softvérových projektov.

## 📋 Čo sú OpenCode Skilly?

**Agent Skills** sú reusable sady pokynov a praktík, ktoré OpenCode automaticky zavádzajú na základe relevantnosti úlohy. Skilly fungujú ako:

- **Špecializované workflow** — Prispôsobené inštrukcie pre konkrétnu doménu
- **Composable bloky** — Modulárny systém na kombinovanie rôznych přístupov
- **On-demand loading** — Skilly sa zavádzajú len, keď ich agent potrebuje
- **Projekt alebo globálne skilly** — Umiestnenie lokálne v projekte alebo globálne pre všetky projekty

Keď napíšeš úlohu, OpenCode preskúma dostupné skilly a automaticky zavádzajú tie, ktorých popis sa zhoduje s tvojou úlohou.

## 🚀 Inštalácia Skillов

OpenCode skilly sú jednoducho **priečinky s `SKILL.md` súborom**. Inštalácia znamená, že ich umiesteš na správne miesto.

### Podporované Lokácie

Skilly sa hľadajú v týchto miestach (v poradí):

**Projekt-lokálne skilly:**
- `.opencode/skills/SKILL_MENO/SKILL.md` 
- `.claude/skills/SKILL_MENO/SKILL.md`
- `.agents/skills/SKILL_MENO/SKILL.md`

**Globálne skilly:**
- `~/.config/opencode/skills/SKILL_MENO/SKILL.md`
- `~/.claude/skills/SKILL_MENO/SKILL.md`
- `~/.agents/skills/SKILL_MENO/SKILL.md`

### Postup Inštalácie

#### Možnosť 1: Projekt-lokálne Skilly (odporúčané)

```bash
# 1. Vytvor priečinok pre skilly
mkdir -p .opencode/skills

# 2. Skopíruj skill do projektu
cp -r path/to/skill-folder .opencode/skills/

# 3. Overuj, že SKILL.md existuje
ls .opencode/skills/SKILL_MENO/SKILL.md
```

#### Možnosť 2: Globálne Skilly (dostupné vo všetkých projektoch)

```bash
# Na macOS/Linux:
mkdir -p ~/.config/opencode/skills
cp -r path/to/skill-folder ~/.config/opencode/skills/

# Na Windows (PowerShell):
mkdir -Path "$env:APPDATA\opencode\skills" -Force
Copy-Item -Path "skill-folder" -Destination "$env:APPDATA\opencode\skills" -Recurse
```

### Konfigurácia Oprávnení

V `opencode.json` môžeš nastaviť, ktoré skilly sú dostupné:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "hugo-search": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

**Oprávnenia:**
- `allow` — Skill sa zavádzajú okamžite
- `deny` — Skill je skrytý a nedostupný
- `ask` — Používateľ dostane upozornenie pred zavedením

### Štruktúra Skillu

```
skill-meno/
├── SKILL.md              # Povinný! YAML frontmatter + pokyny
├── scripts/              # Pomocné skripty (Python, Shell, atď.)
├── templates/            # Šablóny a príklady
└── resources/            # Dokumentácia a referencie
```

### SKILL.md Frontmatter

Každý `SKILL.md` musí začínať YAML frontmatter:

```yaml
---
name: skill-meno
description: Krátky opis čo skill robí (1-1024 znakov)
license: MIT
compatibility: opencode,claude
---

# Pokyny a kontextový obsah...
```

**Požiadavky na `name`:**
- 1–64 znakov
- Len malé písmená, čísla a jednoduchý pomlčka
- Nesmie začínať alebo končiť pomlčkou
- Musí sa zhodovať s názvom priečinku


## 🔍 Ako OpenCode Zavádzajú Skilly

Keď spustíš OpenCode:

1. **Skenuje** všetky dostupné skilly a načítava ich **názvy a popisy**
2. **Analyzuje** tvoju úlohu a podľa prikázaného popisu vyberie relevantné skilly
3. **Zavádzajú** plný obsah relevantného `SKILL.md` do kontextu agenta
4. **Vykonávajú** podľa pokynov v skilly

Ak tvoja úloha neodpovedá žiadnemu skilly, agent ju rieši bez skilly.

## 📚 Dostupné Skilly v Tomto Repozitári

| Skill | Opis | Aktivuje sa kedy |
|-------|------|-----------------|
| **hugo-search** | Bezpečný výskum a generovanie obsahu pre Hugo Wiki s Git kontrolou | Úlohy týkajúce sa Hugo Wiki, vyhľadávania, článkov |

## 🎯 Praktické Príklady

### Príklad 1: Automatické Aktivovanie Skillu

```bash
cd mojproject
opencode
# > Vytvor mi komponent React Login s Tailwind CSS
```

OpenCode automaticky detekuje frontálny vývoj a zavádzajú sa relevantné skilly.

### Príklad 2: Explicitné Zavolanie Skillu

Aj keď tu alebo ak chceš skilly manuálne:

```bash
opencode
# /skill hugo-search
```

## ⚙️ Troubleshooting

### Problem: Skill sa Nezobrazuje

**Kontrola:**
```bash
# Overuj, či SKILL.md existuje
ls -la .opencode/skills/SKILL_MENO/SKILL.md

# Overuj syntax YAML frontmatter
cat .opencode/skills/SKILL_MENO/SKILL.md | head -20

# Overuj oprávnenia v opencode.json
grep -A 10 "permission" ~/.config/opencode/opencode.json
```

**Požiadavky:**
- `SKILL.md` musí byť VEĽKÝMI písmenami
- Musí mať správne YAML frontmatter
- `name` v frontmatter musí zodpovedať mene priečinku
- Skilly s `deny` oprávnením sú skryté

## 📖 Zdroje a Referencie

- [OpenCode Dokumentácia — Skilly](https://opencode.ai/docs/skills/)
- [OpenCode GitHub](https://opencode.ai)
- [Claude-compatible Skills](https://claude-plugins.dev)

## 🤝 Príspevky

Vítame pull requesty a hlásenia chýb! Prosím:

1. Testujem skill lokálne pred submitnutím
2. Dokumentuj zmeny v SKILL.md
3. Commituj s jasným message: `feat: Nový skill pre X` alebo `fix: Skilly issue Y`

## 📄 Licencia

MIT License — Voľné použitie v osobných i komerčných projektoch.

---

**Aktualizácia:** Júl 2026
