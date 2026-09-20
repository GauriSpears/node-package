# Contributing

- Matrix logic lives in `scripts/resolve-matrix.sh` (endoflife.date + fallbacks).
- Upstream revision logic: `scripts/detect-node-main.sh`, gate via Release tag `main-<sha12>`.
- If a new Debian codename image is missing on Docker Hub, extend `map_debian_image` and/or fallbacks.
