# Godot 4.6.3 exports

Use the official Godot 4.6.3 editor and matching official templates. No external analytics, runtime CDN, or third-party script is included. Web uses Compatibility/WebGL 2 and `variant/thread_support=false`, so GitHub Pages does not need COOP/COEP headers. PWA is off to avoid stale service-worker caches.

## Local build

```sh
python3 tools/fetch_templates.py
GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64 bash tools/export.sh Web
GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64 bash tools/export.sh Linux
```

Optional pre-fetched templates: set `GODOT_TEMPLATE_DIR` to the directory containing `web_nothreads_release.zip` and `linux_release.x86_64`; the export script copies them into a project-local XDG data directory. In this workspace it is `/workspace/shared/hyouka/tools/templates/4.6.3.stable/`.

Serve Web over HTTP, rather than opening the file directly:

```sh
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. Linux output is `build/linux/hyouka.x86_64` with embedded PCK. A graphical session is required to play it.

## GitHub Pages

Commit this project as the repository root, including `.github/workflows/pages.yml`. In repository Settings → Pages, select GitHub Actions as the source. Pushes to `main` and manual workflow runs build and deploy `build/web`. The workflow deliberately does not create a repository or change its settings. Do not commit `build/`, `.godot/`, downloaded editor binaries, or export templates.

The download helper uses HTTP byte ranges to download only Web non-threaded and Linux x86_64 templates from the official 4.6.3 release's template archive and verifies each member's ZIP CRC. If a proxy does not support Range, download the entire official `.tpz` archive and extract its `templates/` contents into the Godot versioned export-template directory instead.

Sources:
- https://github.com/godotengine/godot/releases/tag/4.6.3-stable
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
