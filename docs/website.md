# Nowish website

Public URL: https://nowish.pages.dev

The static site is in `site/`. No build step, dependencies, analytics, or external fonts are required. The app-switching preview is illustrative and never accesses real application activity.

Preview locally:

```sh
python3 -m http.server 8766 --directory site
```

Deploy to the existing Cloudflare Pages project:

```sh
npx wrangler@4 pages deploy site --project-name nowish --branch main --commit-dirty=true
```

Nowish 1.0.0 is published and the CTA downloads its notarized DMG. For future releases, set `version` and `url` in `site/release.json` to the release version and its `https://github.com/noelrohi/nowish/releases/download/...` asset URL, then redeploy. The CTA will become Download for macOS. Do not advertise a download before the artifact exists.

Checked the desktop and 390px mobile layout, image loading, all four demo controls and their selected states, and the unpublished-release fallback.
