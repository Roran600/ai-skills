# [Názov tvojho Skillu]

[![OpenCode Skill](https://img.shields.io/badge/OpenCode-Skill-blue)](https://opencode.ai)

[Stručný popis jedným vetou: Čo tento skill robí a aký problém rieši?]

## 📋 Popis
Detailnejší popis funkcií tvojho skillu. Napríklad:
*   Integruje [názov služby] do OpenCode.
*   Umožňuje používateľom automatizovať [konkrétnu úlohu].
*   Poskytuje real-time dáta o [niečom].

## 🚀 Inštalácia

Pre lokálny vývoj alebo manuálne pridanie skillu postupuj nasledovne:

1.  Klonuj repozitár:
    ```bash
    git clone https://github.com/tvoje-meno/tvoj-repozitar.git
    cd tvoj-repozitar
    ```

2.  Nainštaluj závislosti:
    ```bash
    npm install
    ```
    *(alebo `pip install -r requirements.txt` ak používaš Python)*

## ⚙️ Konfigurácia

Tento skill vyžaduje nasledujúce premenné prostredia (v súbore `.env` alebo v nastaveniach OpenCode):

| Premenná | Popis | Povinné |
| :--- | :--- | :--- |
| `API_KEY` | Tvoj kľúč k externému API | Áno |
| `LANGUAGE` | Predvolený jazyk (napr. `sk`) | Nie |

## 🛠 Použitie

Popíš, ako môže používateľ vyvolať tento skill (napr. konverzačné frázy alebo triggery).

**Príklad interakcie:**
*   **Používateľ:** "Aktivuj [názov skillu] a zisti stav X."
*   **Asistent:** "Rozumiem, stav X je momentálne v poriadku."

## 🧩 Štruktúra Skillu (Manifest)

Skill je definovaný v súbore `skill.json` (alebo podľa tvojej štruktúry). Hlavné komponenty:

- **Intents:** [Zoznam úmyslov, ktoré skill spracováva]
- **Actions:** [Zoznam akcií, ktoré vykonáva]

## 🤝 Prispievanie

1. Forkni tento projekt.
2. Vytvor si vetvu pre tvoju funkciu (`git checkout -b feature/NovaFunkcia`).
3. Commitni svoje zmeny (`git commit -m 'Pridaná nová funkcia'`).
4. Pushni na vetvu (`git push origin feature/NovaFunkcia`).
5. Otvor Pull Request.

## 📄 Licencia

Tento projekt je licencovaný pod [vyber si licenciu, napr. MIT] licenciou - podrobnosti nájdeš v súbore `LICENSE`.
