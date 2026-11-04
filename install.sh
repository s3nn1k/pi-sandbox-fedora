#!/usr/bin/env bash
set -euo pipefail
SBX="$(cd "$(dirname "$0")" && pwd)"

live_sess="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c '^pi-sess-' || true)"
if [ "${live_sess:-0}" -gt 0 ]; then
  echo "install: ${live_sess:-0} живых агент-сессий — останови pi или ре-ран позже" >&2
  exit 1
fi

dep_pkg() {
  case "${1}" in
    firewall-cmd) echo firewalld ;;
    nft) echo nftables ;;
    docker) echo docker-ce ;;
    *) echo "${1}" ;;
  esac
}
for dep in git make curl jq rsync python3 systemctl firewall-cmd nft docker; do
  command -v "${dep}" >/dev/null 2>&1 \
    || { echo "install: нет зависимости ${dep} — sudo dnf install $(dep_pkg "${dep}")" >&2; exit 1; }
done

chmod +x "${SBX}/bin/"*

sudo install -Dm 644 "${SBX}/polkit/49-pi-sandbox-firewalld-inspect.rules" \
  /etc/polkit-1/rules.d/49-pi-sandbox-firewalld-inspect.rules

if ! systemctl is-active --quiet firewalld; then
  echo "install: firewalld неактивен — sudo systemctl start firewalld" >&2
  exit 1
fi
if ! firewall-cmd --permanent --get-zones 2>/dev/null | grep -qw docker; then
  sudo firewall-cmd --permanent --new-zone=docker
  sudo firewall-cmd --permanent --zone=docker --set-target='%%REJECT%%'
  sudo firewall-cmd --reload
elif ! firewall-cmd --get-zones 2>/dev/null | grep -qw docker; then
  sudo firewall-cmd --reload
fi
if ! firewall-cmd --info-zone docker 2>/dev/null | grep -qE '^[[:space:]]*target: %%REJECT%%[[:space:]]*$'; then
  sudo firewall-cmd --permanent --zone=docker --set-target='%%REJECT%%'
  sudo firewall-cmd --reload
fi
firewall-cmd --info-zone docker 2>/dev/null | grep -qE '^[[:space:]]*target: %%REJECT%%[[:space:]]*$' \
  || { echo "install: target зоны docker не применился после reload" >&2; exit 1; }

sudo install -Dm 644 "${SBX}/nft/pi-sandbox-guard.nft" /etc/pi-sandbox/guard.nft
sudo install -m 644 "${SBX}/systemd/system/pi-sandbox-guard.service" /etc/systemd/system/pi-sandbox-guard.service
sudo systemctl daemon-reload
sudo systemctl enable pi-sandbox-guard
sudo systemctl restart pi-sandbox-guard
systemctl is-active --quiet pi-sandbox-guard \
  || { echo "install: юнит pi-sandbox-guard не активен (journalctl -u pi-sandbox-guard)" >&2; exit 1; }
guard_table="$(sudo nft list table inet pi_sandbox_guard 2>/dev/null || true)"
grep -q prerouting_guard <<<"$guard_table" \
  && grep -qF 'fib daddr type local' <<<"$guard_table" \
  && grep -qF 'priority dstnat - 10' <<<"$guard_table" \
  || { echo "install: в nft-таблице pi_sandbox_guard нет prerouting_guard / fib daddr type local / priority dstnat - 10" >&2; exit 1; }
[ -f /run/pi-sandbox-guard.active ] \
  || { echo "install: нет штампа /run/pi-sandbox-guard.active" >&2; exit 1; }

systemctl is-enabled --quiet docker \
  || { echo "install: docker не в автозапуске — sudo systemctl enable --now docker" >&2; exit 1; }
docker info >/dev/null 2>&1 \
  || { echo "install: docker недоступен (группа docker / re-login?)" >&2; exit 1; }

while IFS= read -r root; do
  case "${root}" in ""|"#"*) continue ;; esac
  mkdir -p "${HOME}/${root%% *}"
done < "${SBX}/pi-mounts"

mkdir -p "${HOME}/.local/bin"
ln -sfn "${SBX}/bin/sandbox-sync" "${HOME}/.local/bin/sandbox-sync"

mkdir -p "${HOME}/.config/systemd/user"
install -m 644 "${SBX}/systemd/user/herdr-bridge.service" "${HOME}/.config/systemd/user/herdr-bridge.service"
systemctl --user daemon-reload
systemctl --user enable --now herdr-bridge
systemctl --user try-restart herdr-bridge

make -C "${SBX}" image \
  || echo "install: WARN: make image не прошёл — догони вручную: make -C ${SBX} image" >&2
make -C "${SBX}" seeds \
  || echo "install: WARN: seeds не прошли — повтори: make -C ${SBX} seeds" >&2
