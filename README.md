# pi-sandbox

Контейнерное окружение кодинг-агента pi на Fedora: нативный docker без VM-слоя,
dind-сайдкар, docker-UX агента как на хосте (bind-маунты, localhost-порты стеков, тёплые
кэши) при сохранении границы "хост исполняет только свой код".

## Топология

```
host (Fedora 44 x86_64, docker 29 native, firewalld)
+-- pi-agent        image: pi-agent-base; netns dind (network_mode service:dind)
|                   DOCKER_HOST=unix:///var/run/dind/docker.sock
+-- dind            docker:29-dind (digest), privileged, mem_limit 4g,
|                   healthcheck docker info, restart: unless-stopped,
|                   dockerd --group=<AGENT_GID>; /var/lib/docker -> volume dind-data;
|                   same-path binds projects+researches+incidents;
|                   сеть pinet 172.28.0.0/24; ports 127.0.0.1:8600-8699
+-- herdr-bridge    systemd --user юнит -> bin/herdr-sock-bridge (python3):
|                   unix ~/tmp/pi-cache/herdr-bridge/herdr.sock -> unix
|                   ~/.config/herdr/herdr.sock (whitelist методов)
```

## Запуск

`pi` из проекта (функция в dotfiles-fedora -> `bin/pi-run`). `pi --unsafe` - хостовый pi.
Конфиг-подкоманды без сессии (update/mcp/auth/install/remove/uninstall/list/config) - тоже
хостовый pi: они правят хостовой ~/.pi/agent (в контейнере rsync-копия кэша, затираемая
каждым запуском), guard корней им не нужен. Guard корней сессий - `pi-mounts`.

## Ключевые решения

- Копии вместо маунтов: brain/dotfiles/gitconfig/nvim/токен/pi-рантайм - rsync-копии
  (tmp/pi-cache) при каждом запуске; poisoning отбрасывается синком. pi-рантайм берётся по
  ~/.pi/agent/install/current-version из releases, в контейнере ro через `~/.pi/runtime`;
  read-only хелпер токена - `bin/git-cred-read`; токен - ro-секрет /run/secrets ->
  entrypoint-копия в $HOME (fail-loud).
- dind в netns + агент рядом (service:dind): пути демона = пути агента (bind-инвариант),
  порты стеков = localhost агента. Не host-net: два dockerd в одном netns конфликтуют в
  iptables.
- Нативные бинды без VM: inotify работает, watch-стекам не нужны polling-флаги (в
  mac-варианте virtiofs требовал polling).
- herdr-мост без TCP: host-herdr слушает unix-сокет ~/.config/herdr/herdr.sock;
  python3-мост биндит второй unix-сокет ~/tmp/pi-cache/herdr-bridge/herdr.sock, общий с
  контейнером через bind tmp/pi-cache; whitelist методов; :4761 не существует.
- firewalld вместо pf+DOCKER-USER: compose-сеть (br-*) попадает в public-зону - NEW к
  хосту режется, established проходит; pinet закреплён 172.28.0.0/24; зона docker
  (docker0) переведена install.sh на %%REJECT%%. Контейнер -> хост идёт через INPUT,
  DOCKER-USER его не фильтрует - mac-правила не переносились.
- Публикация портов: только 127.0.0.1:8600-8699; docker держит docker-proxy на каждый
  порт - диапазон сжат со 180 до 100 под 8G RAM+zram.
- Сокет dind - volume outer-dind, группа = gid агента.

## Установка

`./install.sh`: депы (dnf-подсказки) -> firewalld (зона docker -> %%REJECT%%, verify
fail-loud; зоны нет - WARN и ре-ран после первого старта docker) -> docker (enable/info)
-> корни pi-mounts, симлинк sandbox-sync в ~/.local/bin -> systemd --user юнит
herdr-bridge -> guard живых сессий -> make image + seeds (WARN-фолбэк). Идемпотентен.
Проверка окружения: `sandbox-sync`.

## Security-инварианты

- S1 хост исполняет только свой код (копии; bind rw = рабочие данные:
  projects/sessions/missions/researches/incidents; кэши - named volumes с односторонними
  сидами).
- S2 хост-сервисы для контейнера: только whitelist-методы herdr через unix-сокет моста;
  NEW из pinet к хосту режет public-зона firewalld, зона docker - REJECT.
- S3 хостовые креды вне контейнера (.ssh/.kube/vault/dotfiles-секреты).
- S4 blast radius agent-root (через dind) = маунты контейнера = принятые rw-поверхности.

Хостовой git: gitlab-хосты используют `git-cred-read` (read-only store, approve = no-op) -
vault-файл единственный источник правды.

## Residuals (принятые)

- privileged dind на общем ядре = потенциальный root хоста - главная потеря против
  mac-варианта с VM;
- zram-своп: перегруз бьёт по интерактивности хоста;
- docker-proxy: по процессу на публикуемый порт (100 портов диапазона);
- GOSUMDB=off скопирован с mac (VPN): новые go-зависимости без проверки sum-db;
- ротация агентского токена действует со следующего запуска pi.

## Runbook

- docker неактивен: `sudo systemctl start docker`; "группа docker / re-login" -
  `sudo usermod -aG docker $USER` и перелогин;
- dind пересоздан при живых pi-sess -> "сессия осиротела" -> перезапуск pi (pi-run сверяет
  container:<id> перед reattach и не поднимает dind при живых сессиях);
- диск dind: pi-run делает ежедневный `docker system prune` (until=48h) и гасит контейнеры
  внутри dind старше 24ч; при сбое prune - WARN с кодом и хвостом ошибки (полный лог -
  ~/tmp/pi-cache/.dind-prune-last.log);
- запуск из вне-корневых путей -> guard откажет; pi-mounts - источник корней;
- обновление pi на хосте подхватывается контейнером при следующем запуске (rsync
  pi-runtime по current-version); pi в образе нет, пересборка не нужна;
- herdr-мост: `systemctl --user status herdr-bridge`; Restart=always; сокет моста -
  ~/tmp/pi-cache/herdr-bridge/herdr.sock, путь переопределяется первым аргументом скрипта.
