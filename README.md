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

## Использование

Из проекта (корни запуска - pi-mounts):

```sh
pi
```

- pi --unsafe - хостовый pi; конфиг-подкоманды (update/mcp/auth/...) - тоже хостовые.
- Порты тест-стеков: 127.0.0.1:8600-8699.
- Проверка окружения: sandbox-sync.
- Живые сессии: docker ps --format '{{.Names}}' | grep pi-sess; при обрыве связи pi-run
  перецепляется сам; "сессия осиротела" (dind пересоздан) - перезапуск pi.
- Обновление скриптов/моста: git pull && ./install.sh (юнит перезапустится сам).
