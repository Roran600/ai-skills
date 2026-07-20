# Moje AI skilly



NÁVOD NA INŠTALÁCIU SKILLU DO OPENCODE.AI

Tento návod predpokladá, že už máte nainštalované základné prostredie OpenCode a vytvoreného alebo stiahnutého agenta.

1. VÝBER A STIAHNUTIE SKILLU
Skilly pre OpenCode sú zvyčajne dostupné v oficiálnom repozitári alebo na GitHube.
- Nájdite URL adresu repozitára skillu (napr. https://github.com/opencode-ai/skill-weather).
- Otvorte si terminál v priečinku, kde máte uložené svoje prostredie OpenCode.

2. INŠTALÁCIA POMOCOU CLI
Najjednoduchší spôsob je použiť priamo príkazovú riadku OpenCode:

Príkaz: opencode install skill [URL_ADRESA_SKILLU]
Príklad: opencode install skill https://github.com/opencode-ai/skill-weather

3. MANUÁLNA INŠTALÁCIA (ak CLI nefunguje)
- Vstúpte do priečinka 'skills' vo vašom projekte: cd my-agent/skills
- Klonujte repozitár skillu: git clone https://github.com/opencode-ai/skill-weather.git
- Inštalácia závislostí: 
  cd skill-weather
  pip install -r requirements.txt
  (alebo npm install pri JS skilloch)

4. KONFIGURÁCIA SKILLU
- Skontrolujte súbor config.yaml alebo .env v priečinku skillu.
- Ak existuje .env.example, premenujte ho na .env a doplňte svoje API kľúče.

5. AKTIVÁCIA V AGENTOVI
V hlavnom konfiguračnom súbore agenta (agent.yaml alebo settings.json) pridajte názov skillu do sekcie skills:

skills:
  - communication
  - web_search
  - skill-weather

6. REŠTART A TESTOVANIE
Reštartujte agenta príkazmi:
opencode stop
opencode start

Overenie funkčnosti: V chate s agentom zadajte príkaz prislúchajúci skillu (napr. "Aké je počasie?").

TIPY:
- Aktualizácia: V priečinku skillu spustite 'git pull'.
- Logy: Ak niečo nefunguje, použite 'opencode logs'.
"""

with open("/mnt/data/instalacia_opencode.txt", "w", encoding="utf-8") as f:
    f.write(content)
