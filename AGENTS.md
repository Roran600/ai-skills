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
├── hugo-link-indexer/      # URL verification and Hugo Markdown link indexer
│   ├── SKILL.md           # Instructions for categorized link tables with EXA
│   └── LICENSE.txt
├── hugo-article-creator/   # Safe creator for new Hugo articles and documentation cards
│   ├── SKILL.md           # Instructions for article creation with EXA and approval gates
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
│   ├── SKILL.md           # Agent happy path first, then reference sections
│   ├── img.sh             # Bash toolkit (menu/gen/models/size/extract/upscale/reffacts/mcp)
│   └── LICENSE.txt        # MIT License
├── gimp-mcp/               # Safe GIMP MCP editing workflow
├── inkscape-mcp/           # Safe Inkscape MCP vector workflow
└── README.md              # Brief overview (Slovak)
```

Each skill is self-contained in its own directory. The entrypoint is always `SKILL.md` with YAML frontmatter.

## Important Conventions

**Language & Locale:**
- `hugo-search`: Writes content **exclusively in Slovak**. Use professional technical terminology (build, deploy, shortcode, front matter). Do not translate these terms.
- `markdown-formatter`: Slovenčina. Flexibilné formátovanie .txt súborov do bogatého markdownu.
- `deep-factcheck`: Slovenčina. Fact-checking Hugo článkov s prioritizáciou 7 tvrdení.
- `deep-research`: Slovenčina. Výskumný asistent s flexibilným výstupom a deduplikáciou.
- `hugo-link-indexer`: Slovenčina. Overovanie URL cez EXA a bezpečné dopĺňanie kategorizovaných Markdown tabuliek bez zmeny front matter.
- `image-generation`: Slovenčina. Generovanie obrázkov cez OpenRouter MCP s batch, upscaling, reference images.
- `frontend-design`: English. Emphasizes distinctive, opinionated design choices grounded in the subject matter.

**Skill Frontmatter:**
- For portability, include `name` and `description`; use a lowercase hyphenated `name` matching the skill directory.
- `license`, `compatibility`, and `metadata` are optional in the Agent Skills specification. This repository includes a license file with each skill.
- When present, `compatibility` must be a text string and `metadata` a map of string keys and values for portable skills. OpenCode V2 may accept looser frontmatter; do not confuse portability guidance with its runtime requirements.
- Existing exceptions: `gimp-mcp` and `inkscape-mcp` currently use display names with spaces in frontmatter. Update them to match their directory names when working on skill portability.
- Reference: https://agentskills.io/specification and https://opencode.ai/docs/skills/

**MCP tool names:**
- Discover the tools exposed by the active client and server before use; prefixes and invocation syntax can differ between environments.
- The official EXA server names include `web_search_exa` and `web_fetch_exa`. Existing skills may refer to prefixed names such as `exa_web_search_exa`; verify availability rather than assuming either spelling works everywhere.
- References: https://github.com/exa-labs/exa-mcp-server and https://opencode.ai/docs/mcp-servers/

**Content Guidelines:**
- **hugo-search:** Content goes to `content/docs/[slug]/_index.md` as Branch Bundles. Must have specific YAML frontmatter (title, date, description, nav_weight, nav_icon, series, categories, tags). Skill enforces git safety checks before writing.
- **markdown-formatter:** Converts plain `.txt` files to rich Markdown (.md or .md+frontmatter). Detects content type (articles, lists, mixed) and applies appropriate formatting. No file modifications - outputs new file.
- **deep-factcheck:** Fact-checks Hugo articles by extracting 7 key claims and verifying them via EXA Search MCP. Generates detailed report with sources and recommended corrections. No automatic commits.
- **deep-research:** Conducts research on any topic via EXA Search MCP. Generates flexible output (.txt, .md, or .md+frontmatter). Supports filtering (academic, technical, news), translation to Slovak, and detailed metadata. No automatic commits.
- **hugo-link-indexer:** Verifies user-provided URLs via EXA, classifies them into category headings, and appends entries to Markdown tables only after confirmation. Never rewrites Hugo front matter or existing records without confirmation.
- **hugo-article-creator:** Creates new Blog and Docs Markdown content from approved front matter and type-specific skeletons; uses EXA for descriptions and device data, checks Git state, and never overwrites existing files.
- **image-generation:** Generates images via OpenRouter MCP (`tools/call generate-image`). Pure Bash: `img.sh` (~1150 lines) with subcommands `menu`, `gen`, `models`, `size`, `extract`, `upscale`, `reffacts`, `mcp`. Model ranking pulls three MCP sources (`list-models` for price, `list-models sort=throughput` as a speed proxy, `list-benchmarks source=design-arena` for measured elo/win-rate/generation-time); `models <price|speed|quality> [N]` and the interactive menu router expose them. Deps: curl, jq, base64, awk, file, magick. Interactive `menu` is for humans (asks where to save first, then model/ratio/resolution/prompts/upscale); agents must use `menu --non-interactive --yes` and address the script by absolute path, since it is neither in the user's cwd nor on PATH. When a user asks for the menu without a TTY, agents run `menu --questions` (a fixed questionnaire) and then generate non-interactively rather than handing the command back. MCP accepts only `model`, `prompt`, `size` – no input images, so references become text in the prompt. Saves image + JSON sidecar + raw MCP response. No automatic commits.
- **frontend-design:** No generated content; guidance only. Designed to be invoked as context, not output.
- **gimp-mcp:** Safe inspection, editing, and export of images through the configured GIMP MCP server; confirm destructive operations.
- **inkscape-mcp:** Safe SVG and vector editing, conversion, rendering, and validation through the configured Inkscape MCP server; confirm potentially destructive operations.

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
