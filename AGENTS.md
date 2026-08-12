# AGENTS.md

This repository is a collection of OpenCode skills hosted at `Roran600/ai-skills` on GitHub.

## Repository Structure

```
ai-skills/
├── frontend-design/        # Visual design guidance skill
│   ├── SKILL.md           # Comprehensive design principles, process, writing guidance
│   └── LICENSE.txt
├── hugo-search/            # Hugo Wiki research assistant skill  
│   ├── SKILL.md           # Instructions for writing Hugo wiki content in Slovak
│   └── LICENSE.txt
├── markdown-formatter/     # TXT to Markdown converter skill
│   ├── SKILL.md           # Instructions for formatting .txt files to rich markdown
│   └── LICENSE.txt
├── deep-factcheck/         # Fact-checking assistant skill with EXA search
│   ├── SKILL.md           # Instructions for verifying Hugo articles with external sources
│   └── LICENSE.txt
├── deep-research/          # Research assistant skill with EXA search
│   ├── SKILL.md           # Instructions for conducting research and generating reports
│   └── LICENSE.txt
├── image-generation/       # Image generation skill with OpenRouter MCP
│   ├── SKILL.md           # Comprehensive instructions (17 sections, MCP integration)
│   ├── README.md          # User-friendly documentation and examples
│   ├── index.js           # Node.js implementation with 8-question workflow
│   ├── package.json       # Node.js dependencies
│   ├── test.js            # Unit tests for validation
│   └── LICENSE.txt        # MIT License
└── README.md              # Brief overview (Slovak)
```

Each skill is self-contained in its own directory. The entrypoint is always `SKILL.md` with YAML frontmatter.

## Important Conventions

**Language & Locale:**
- `hugo-search`: Writes content **exclusively in Slovak**. Use professional technical terminology (build, deploy, shortcode, front matter). Do not translate these terms.
- `markdown-formatter`: Slovenčina. Flexibilné formátovanie .txt súborov do bogatého markdownu.
- `deep-factcheck`: Slovenčina. Fact-checking Hugo článkov s prioritizáciou 7 tvrdení.
- `deep-research`: Slovenčina. Výskumný asistent s flexibilným výstupom a deduplikáciou.
- `image-generation`: Slovenčina. Generovanie obrázkov cez OpenRouter MCP s batch, upscaling, reference images.
- `frontend-design`: English. Emphasizes distinctive, opinionated design choices grounded in the subject matter.

**Skill Frontmatter:**
- Required fields: `name`, `description`, `license`
- Optional but used: `compatibility`, `metadata` (audience, workflow)
- No spaces in `name` values; use hyphens

**Content Guidelines:**
- **hugo-search:** Content goes to `content/docs/[slug]/_index.md` as Branch Bundles. Must have specific YAML frontmatter (title, date, description, nav_weight, nav_icon, series, categories, tags). Skill enforces git safety checks before writing.
- **markdown-formatter:** Converts plain `.txt` files to rich Markdown (.md or .md+frontmatter). Detects content type (articles, lists, mixed) and applies appropriate formatting. No file modifications - outputs new file.
- **deep-factcheck:** Fact-checks Hugo articles by extracting 7 key claims and verifying them via EXA Search MCP. Generates detailed report with sources and recommended corrections. No automatic commits.
- **deep-research:** Conducts research on any topic via EXA Search MCP. Generates flexible output (.txt, .md, or .md+frontmatter). Supports filtering (academic, technical, news), translation to Slovak, and detailed metadata. No automatic commits.
- **image-generation:** Generates images via OpenRouter MCP with batch support, upscaling (2x/4x), reference images (max 5), and dynamic model selection (ranking by price). Implemented in Node.js (index.js) with 8-question interactive workflow, security validation, and unit tests. Auto-discovery of models, saves PNG + JSON metadata. No automatic commits.
- **frontend-design:** No generated content; guidance only. Designed to be invoked as context, not output.

## Common Tasks

**Add a new skill:**
1. Create `{skillname}/` directory
2. Write `SKILL.md` with YAML frontmatter (required: name, description, license)
3. If using external code or assets, include appropriate LICENSE file
4. Commit and push to GitHub

**Update an existing skill:**
- Edit the `SKILL.md` directly; no registration step needed
- Changes are available to OpenCode users immediately after they pull latest

**Test a skill locally:**
- Copy to `~/.config/opencode/skills/` or add the repo path to `opencode.json` `skillsDir`
- Restart OpenCode and verify with `ctrl+p` → "Load Skill"

## Git Workflow

- Main branch is `main`
- Repository is public; skills are shared via public URLs
- No CI/CD; skills are consumed directly from `.pen` files or git clone
- Always test skill execution before pushing

## Key Files to Preserve

- `README.md`: Public-facing overview (currently Slovak, brief)
- Root `AGENTS.md` (this file): Agent guidance, not user-facing
- License files in each skill directory: Required for distribution

---

Last updated: August 12, 2026
