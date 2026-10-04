# dx-cluster-roku

A Roku channel that shows an amateur radio DX cluster feed as a scrolling
green-on-black "glass teletype". See [docs/SPEC.md](docs/SPEC.md).

## Setup

1. Put the Roku in developer mode and note its IP address and dev password.
2. Copy the settings template and fill it in (`.env` is git-ignored):

   ```bash
   cp .env.example .env
   ```

3. Build and sideload:

   ```bash
   tools/deploy.sh
   ```

   `tools/deploy.sh --package-only` builds `out/dx-cluster.zip` without installing.
   Any setting can be overridden for one build, e.g. `CLUSTER_HOST=192.168.1.20 tools/deploy.sh`.

4. Watch the debug console:

   ```bash
   telnet $ROKU_IP 8085
   ```

## Layout

- `app/` – the channel source (manifest, BrightScript, SceneGraph components, images)
- `tools/deploy.sh` – stages `app/`, writes `config.json` from `.env`, zips, sideloads
- `tools/make-images.py` – regenerates the icons and splash screens in `app/images/`
