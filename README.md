# pi-sandbox-fedora

Контейнерное окружение кодинг-агента pi на нативном docker Fedora: агент в netns dind,
граница "хост исполняет только свой код". Инварианты и residuals - в коде (compose.yaml,
bin/pi-run, install.sh) и истории коммитов.

## Установка

Требования: docker-ce с юзером в группе docker, firewalld, ~/dotfiles-fedora и
~/credentials (источники синка - см. bin/pi-run).

```sh
./install.sh
```

Из сессии без группы docker (до re-login):

```sh
sg docker -c 'cd ~/pi-sandbox-fedora && ./install.sh'
```

Идемпотентен: зона firewalld docker -> target %%REJECT%%, systemd --user юнит
herdr-bridge, образ и сиды (make image seeds).

Границу хоста держит юнит pi-sandbox-guard: nft-таблица с pre-DNAT drop трафика из pi-sbx0
к локальным адресам хоста загружается до docker.

## Использование

Из проекта (корни запуска - pi-mounts):

```sh
pi
```

- pi --unsafe - хостовый pi; конфиг-подкоманды (update/mcp/auth/...) - тоже хостовые.
- Без активного nft-guard pi отказывает в запуске (stamp /run/pi-sandbox-guard.active) -
  прогони install.sh.
- Порты тест-стеков: 127.0.0.1:8600-8699.
- Проверка окружения: sandbox-sync.
- Живые сессии: docker ps --format '{{.Names}}' | grep pi-sess; при обрыве связи pi-run
  перецепляется сам; "сессия осиротела" (dind пересоздан) - перезапуск pi.
- Обновление скриптов/моста: git pull && ./install.sh (юнит перезапустится сам).
- Креды агента (kubectl/psql): kubeconfig / pgpass / pg_service.conf в
  ~/credentials/agents-credentials/ (рядом с git-credentials), затем перезапустить pi.
  kubectl port-forward - только с --address 0.0.0.0: без него слушатель только на loopback
  внутри netns dind и до опубликованных 127.0.0.1:8600-8699 не достаёт; psql - по
  ~/.pgpass и pg_service.conf (psql 'service=primary dbname=mydb'; флаг -d перебивает
  позиционный service=).
- Скилл окружения агента (kubectl/psql/docker) - skills/sandbox-environment, pi-run
  доставляет его агенту.
