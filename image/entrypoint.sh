#!/bin/sh
# Экспорт агентских токенов из ~/.git-credentials (формат git-credential-store,
# смонтирован из ~/credentials/agents-credentials) в env для glab/gh.
# Git кормится credential.helper=store из хостового gitconfig сам — тут только env.
# Ограничение парсера: токены без '@' (glpat-*/github_pat_* — ок).
if [ ! -s /run/secrets/pi-git-credentials ]; then
  echo "entrypoint: /run/secrets/pi-git-credentials пуст или отсутствует" >&2
  exit 1
fi
install -m 600 /run/secrets/pi-git-credentials "$HOME/.git-credentials" \
  || { echo "entrypoint: не смог установить git-credentials" >&2; exit 1; }
f="$HOME/.git-credentials"
if [ -s "$f" ]; then
  while IFS= read -r line; do
    case "$line" in
      https://*github.com*) t=${line#https://*:}; t=${t%%@*} ;;
      https://*gitlab*) t=${line#https://*:}; t=${t%%@*} ;;
      *) continue ;;
    esac
    [ -n "$t" ] || continue
    case "$line" in
      https://*github.com*) GH_TOKEN="$t"; export GH_TOKEN ;;
      https://*gitlab*)
        GITLAB_HOST="${line#https://}"; GITLAB_HOST="${GITLAB_HOST%%/*}"
        GITLAB_TOKEN="$t"; export GITLAB_HOST GITLAB_TOKEN ;;
    esac
  done < "$f"
fi
# Опциональный срез kube/psql: пустой/отсутствующий файл - тихий пропуск, не ошибка;
# kubectl/psql читают дефолтные пути, env не нужен.
for cred_name in kubeconfig pgpass pg_service.conf; do
  cred_src="/run/secrets/pi-agent-creds/$cred_name"
  [ -s "$cred_src" ] || continue
  case "$cred_name" in
    kubeconfig) mkdir -p "$HOME/.kube"; cred_dest="$HOME/.kube/config" ;;
    pgpass) cred_dest="$HOME/.pgpass" ;;
    pg_service.conf) cred_dest="$HOME/.pg_service.conf" ;;
  esac
  install -m 600 "$cred_src" "$cred_dest" \
    || { echo "entrypoint: не смог установить $cred_name" >&2; exit 1; }
done
exec pi "$@"
