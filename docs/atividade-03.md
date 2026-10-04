# Atividade 3 -- deploy com systemd e nginx

Autor: Felipe Geraldo de Oliveira (@FelipeOliveira456)

## (a) Como rodar o deploy.sh numa maquina limpa

Linux com systemd (Ubuntu/Debian). Precisa de sudo. Sincronize o fork, confira que existem `app/`, `static/`, `tests/` e `docs/aplicacao.md`, e:

```bash
cd ufla-devops-shop
sudo ./scripts/deploy.sh
```

O script instala postgres, redis e nginx, cria o usuario `ufla-shop` se nao existir, copia o codigo para `/opt/ufla-shop`, sobe o servico, o timer de backup e o proxy TLS. Segredo fica em `/etc/ufla-shop.env` (criado do example na primeira vez). Certificado autoassinado em `/etc/ssl/ufla-shop/` -- nao vai pro git.

Rode de novo o mesmo comando. A segunda vez nao pode quebrar: usuario ja existe, banco ja existe, servico so reinicia.

Conferir:

```bash
curl -s http://127.0.0.1:8000/ready
sudo systemctl status ufla-shop
sudo systemctl list-timers ufla-shop-backup.timer
curl -kI https://localhost
curl -I http://localhost
```

`/ready` tem que vir 200 com banco e cache ok. HTTPS 200, HTTP 301.

Para gerar as evidencias abaixo (kill -9, curls, 3 backups, duas execucoes do deploy):

```bash
sudo ./scripts/coletar-evidencias-03.sh
```

<!-- EVIDENCIAS -->

## (b) Restart depois do kill -9

```
● ufla-shop.service - ufla-devops-shop (API)
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-10-04 19:25:52 -03; 6s ago
   Main PID: 58456 (uvicorn)
      Tasks: 2 (limit: 4177)
     Memory: 43.6M (peak: 63.0M)
        CPU: 572ms
     CGroup: /system.slice/ufla-shop.service
             └─58456 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000

Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 systemd[1]: Started ufla-shop.service - ufla-devops-shop (API).
Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: INFO:     Started server process [58456]
Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: INFO:     Waiting for application startup.
Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: 2026-10-04 19:25:52,781 INFO loja: ufla-devops-shop 1.0.0 subindo (banco=postgresql, cache=redis, instancia=felipe-IdeaPad-1-15IAU7)
Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: 2026-10-04 19:25:52,915 INFO loja.banco: banco pronto (modo postgresql)
Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: INFO:     Application startup complete.
Oct 04 19:25:52 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
Oct 04 19:25:53 felipe-IdeaPad-1-15IAU7 uvicorn[58456]: INFO:     127.0.0.1:46160 - "GET /ready HTTP/1.1" 200 OK
```

## (c) curl HTTPS e HTTP

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
  0    31    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
HTTP/2 405 
server: nginx/1.24.0 (Ubuntu)
date: Sun, 04 Oct 2026 22:25:59 GMT
content-type: application/json
content-length: 31
allow: GET

```

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
  0   178    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Sun, 04 Oct 2026 22:25:59 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/

```

## (d) Backups depois de rodar 3 vezes

```
total 16
drwxr-x--- 2 ufla-shop ufla-shop 4096 Oct  4 19:26 .
drwxr-xr-x 3 root      root      4096 Oct  4 19:25 ..
-rw-r--r-- 1 ufla-shop ufla-shop 1620 Oct  4 19:25 loja-2026-10-04-1925.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1621 Oct  4 19:26 loja-2026-10-04-1926.sql.gz
```

## (e) Idempotencia: final das duas execucoes seguidas

Primeira:

```
  libatk-bridge2.0-0t64:i386 libatk1.0-0t64:i386 libatspi2.0-0t64:i386
  libavahi-client3:i386 libavahi-common-data:i386 libavahi-common3:i386
  libbpfcc libclang-cpp18 libclang1-18 libcolord2:i386 libcups2t64:i386
  libdecor-0-0:i386 libdecor-0-plugin-1-gtk:i386 libepoxy0:i386
  libgssapi-krb5-2:i386 libgtk-3-0t64:i386 libk5crypto3:i386 libkeyutils1:i386
  libkrb5-3:i386 libkrb5support0:i386 liblcms2-2:i386 libllvm18
  libsdl2-2.0-0:i386 libusb-1.0-0:i386 libwayland-cursor0:i386
  libwayland-egl1:i386 libxcb-dri2-0:i386 libxcomposite1:i386 libxcursor1:i386
  libxdamage1:i386 libxi6:i386 libxrandr2:i386 python3-astroid python3-bpfcc
  python3-dill python3-isort python3-logilab-common python3-mccabe
  python3-mypy-extensions python3-netaddr python3-toml python3-tomlkit
  steam-libs:i386 thermald ubuntu-fan ubuntu-kernel-accessories
Use 'sudo apt autoremove' to remove them.
0 upgraded, 0 newly installed, 0 to remove and 168 not upgraded.
== servicos de banco e cache ==
== arquivo de ambiente ==
== usuario de sistema ==
== codigo em /opt/ufla-shop ==
== diretorio de backup ==
== certificado tls ==
== systemd ==
== nginx ==
== healthcheck /ready ==
ready ok na tentativa 1
deploy ok
```

Segunda:

```
  libatk-bridge2.0-0t64:i386 libatk1.0-0t64:i386 libatspi2.0-0t64:i386
  libavahi-client3:i386 libavahi-common-data:i386 libavahi-common3:i386
  libbpfcc libclang-cpp18 libclang1-18 libcolord2:i386 libcups2t64:i386
  libdecor-0-0:i386 libdecor-0-plugin-1-gtk:i386 libepoxy0:i386
  libgssapi-krb5-2:i386 libgtk-3-0t64:i386 libk5crypto3:i386 libkeyutils1:i386
  libkrb5-3:i386 libkrb5support0:i386 liblcms2-2:i386 libllvm18
  libsdl2-2.0-0:i386 libusb-1.0-0:i386 libwayland-cursor0:i386
  libwayland-egl1:i386 libxcb-dri2-0:i386 libxcomposite1:i386 libxcursor1:i386
  libxdamage1:i386 libxi6:i386 libxrandr2:i386 python3-astroid python3-bpfcc
  python3-dill python3-isort python3-logilab-common python3-mccabe
  python3-mypy-extensions python3-netaddr python3-toml python3-tomlkit
  steam-libs:i386 thermald ubuntu-fan ubuntu-kernel-accessories
Use 'sudo apt autoremove' to remove them.
0 upgraded, 0 newly installed, 0 to remove and 168 not upgraded.
== servicos de banco e cache ==
== arquivo de ambiente ==
== usuario de sistema ==
== codigo em /opt/ufla-shop ==
== diretorio de backup ==
== certificado tls ==
== systemd ==
== nginx ==
== healthcheck /ready ==
ready ok na tentativa 1
deploy ok
```

## Timer

```
NEXT                        LEFT LAST PASSED UNIT                   ACTIVATES
Mon 2026-10-05 03:00:00 -03   7h -         - ufla-shop-backup.timer ufla-shop-backup.service

1 timers listed.
Pass --all to see loaded but inactive timers, too.
```
