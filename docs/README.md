# Touch Grass — public site (GitHub Pages)

Static landing page for [Touch Grass](https://github.com/Thespaceblade/Touch-Grass). Source is copied from `DesignSystem/project/marketing/` (design prototypes stay local under `DesignSystem/`, which is gitignored).

## Enable GitHub Pages

1. Repo **Settings → Pages**
2. **Source:** Deploy from a branch
3. **Branch:** `main` → folder **`/docs`**
4. Save

Live URL: **https://thespaceblade.github.io/Touch-Grass/**

## Local preview

```bash
cd docs && python3 -m http.server 8080
```

Open http://localhost:8080

## Updating the site

Edit the marketing HTML/CSS in `DesignSystem/project/marketing/`, then copy into `docs/`:

```bash
./Scripts/sync_docs_site.sh
```

Or copy manually: `index.html`, `marketing.css`, `colors_and_type.css`, `cartoon.css`, `assets/`, and `assets/screenshots/`. Fix paths in `index.html` so shared assets use `assets/` (not `../assets/`).
