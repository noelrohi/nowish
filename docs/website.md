# Nowish website

Public URL: https://nowish.pages.dev

The static site is in `site/`. No build step, dependencies, analytics, or external fonts are required. The desktop demo (menu bar, Nowish menu, and Dock) is illustrative and never accesses real application activity. The Dock icons in `site/assets/apps/` are exported from the installed apps with `NSWorkspace.icon(forFile:)` at 256 px.

Preview locally:

```sh
python3 -m http.server 8766 --directory site
```

Deploy to the existing Cloudflare Pages project:

```sh
npx wrangler@4 pages deploy site --project-name nowish --branch main --commit-dirty=true
```

Nowish 1.0.0 is published and the CTA downloads its notarized DMG. For future releases, set `version` and `url` in `site/release.json` to the release version and its `https://github.com/noelrohi/nowish/releases/download/...` asset URL, then redeploy. The CTA will become Download for macOS. Do not advertise a download before the artifact exists.

Checked the 1440px desktop and 390px mobile layouts, the Dock switching (two-second settle, ignored apps clearing at once), and the release link.

The Open Graph image `site/assets/og.png` (1200×630) is a headless Chrome capture of the hero at 1600×838 and 1.5× scale, with the “Click an app” hint hidden and the clock set to 9:41 AM, resized with `sips`. Recapture it when the hero changes.
