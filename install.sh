#!/usr/bin/env bash
set -euo pipefail
SBX="$(cd "$(dirname "$0")" && pwd)"

dep_pkg() {
  case "$1" in
    nc) echo nmap-ncat ;;
    firewall-cmd) echo firewalld ;;
    *) echo "$1" ;;
  esac
}
for dep in git make curl jq rsync nc python3 systemctl firewall-cmd docker; do
  command -v "$dep" >/dev/null 2>&1 \
    || { echo "install: нет зависимости $dep — sudo dnf install $(dep_pkg "$dep")" >&2; exit 1; }
done

chmod +x "$SBX/bin/"*

if ! systemctl is-active --quiet firewalld; then
  echo "install: firewalld неактивен — sudo systemctl start firewalld" >&2
  exit 1
fi
if firewall-cmd --info-zone docker 2>/dev/null | grep -q '^target: %%REJECT%%$'; then
  echo "install: зона docker уже с target %%REJECT%%"
elif firewall-cmd --get-zones 2>/dev/null | grep -qw docker; then
  sudo firewall-cmd --permanent --zone=docker --set-target='%%REJECT%%'
  sudo firewall-cmd --reload
  firewall-cmd --info-zone docker 2>/dev/null | grep -q '^target: %%REJECT%%$' \
    || { echo "install: target зоны docker не применился после reload" >&2; exit 1; }
else
  echo "install: WARN: зоны docker нет — зона появится после первого старта docker; перезапусти install" >&2
fi

systemctl is-enabled --quiet docker \
  || { echo "install: docker не в автозапуске — sudo systemctl enable --now docker" >&2; exit 1; }
docker info >/dev/null 2>&1 \
  || { echo "install: docker недоступен (группа docker / re-login?)" >&2; exit 1; }

while IFS= read -r root; do
  case "$root" in ""|"#"*) continue ;; esac
  mkdir -p "$HOME/${root%% *}"
done < "$SBX/pi-mounts"

mkdir -p "$HOME/.local/bin"
ln -sfn "$SBX/bin/sandbox-sync" "$HOME/.local/bin/sandbox-sync"

mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$SBX/systemd/user/herdr-bridge.service" "$HOME/.config/systemd/user/herdr-bridge.service"
systemctl --user daemon-reload
systemctl --user enable --now herdr-bridge

live_sess="$(docker ps --format '{{.Names}}' | grep -c '^pi-sess-' || true)"
if [ "$live_sess" -gt 0 ]; then
  echo "install: $live_sess живых агент-сессий — останови pi или ре-ран позже" >&2
  exit 1
fi

make -C "$SBX" image \
  || echo "install: WARN: make image не прошёл — догони вручную: make -C $SBX image" >&2
make -C "$SBX" seeds \
  || echo "install: WARN: seeds не прошли — повтори: make -C $SBX seeds" >&2
