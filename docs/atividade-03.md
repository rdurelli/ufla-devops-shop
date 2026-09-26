# Atividade 3 — Automatizar de verdade

Entrega da Atividade 3 da disciplina DevOps na Prática (DCC/UFLA).

**Autor:** Ana Clara Carvalho Nascimento (@anaclaracn)

## O que foi feito

A aplicação `ufla-devops-shop` agora roda como um serviço Linux de verdade:

| Artefato | Papel |
|---|---|
| `scripts/deploy.sh` | instala e opera a aplicação (idempotente) |
| `scripts/backup.sh` | dump datado do banco com rotação de 7 |
| `systemd/ufla-shop.service` | a API como serviço (não-root) |
| `systemd/ufla-shop-backup.service` + `.timer` | backup diário às 03:00 |
| `nginx/loja.conf` | proxy reverso com TLS autoassinado |

---

## (a) Como rodar o `deploy.sh` numa máquina limpa

Em um Ubuntu/Debian com systemd, clone o fork e rode:

```bash
git clone git@github.com:anaclaracn/ufla-devops-shop.git
cd ufla-devops-shop
git switch atividade-03
sudo ./scripts/deploy.sh
```

O script instala as dependências, cria o usuário de sistema `ufla-shop`, gera o
`/etc/ufla-shop.env` (senha aleatória do banco), sincroniza o código para
`/opt/ufla-shop`, instala as units do systemd, põe o Nginx à frente com TLS e
termina com um healthcheck em `/ready`.

> No macOS (que não tem systemd), usei uma VM Ubuntu via Multipass:
> `brew install --cask multipass && multipass launch --name devops`.

## (b) `systemctl status` depois do `kill -9`

O `pidof uvicorn` não acha o processo (o `uvicorn` é um script Python — o
processo se chama `python3`), então matei o `MainPID` do systemd:

```bash
sudo kill -9 "$(systemctl show -p MainPID --value ufla-shop)"
sleep 5
systemctl status ufla-shop --no-pager
```

```
MainPID antes: 19535
MainPID depois: 19924

● ufla-shop.service - ufla-devops-shop - API da loja virtual
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Sat 2026-09-26 16:25:12 -03; 1s ago
   Main PID: 19924 (uvicorn)
     CGroup: /system.slice/ufla-shop.service
             └─19924 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000

Sep 26 16:25:12 devops systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 1.
Sep 26 16:25:12 devops systemd[1]: Started ufla-shop.service - ufla-devops-shop - API da loja virtual.
```

O `Restart=on-failure` fez o serviço voltar sozinho (PID 19535 → 19924,
`restart counter is at 1`). O timer diário também está ativo:

```
NEXT                        LEFT     LAST  PASSED  UNIT                      ACTIVATES
Sun 2026-09-27 03:00:00 -03 10h left -      -       ufla-shop-backup.timer   ufla-shop-backup.service
```

## (c) Nginx: HTTPS e redirecionamento de HTTP

```bash
curl -I http://localhost
```

```
HTTP/1.1 301 Moved Permanently
Server: nginx/1.28.3 (Ubuntu)
Location: https://localhost/
```

```bash
curl -k https://localhost/health
curl -k -o /dev/null -w "%{http_code}\n" https://localhost/
```

```
{"status":"ok","versao":"1.0.0"}
200
```

> Observação: `curl -kI https://localhost` devolve **405**, não 200 — o `-I`
> envia HEAD, e as rotas do FastAPI são só GET (a resposta traz `allow: GET`).
> É comportamento esperado da aplicação; o GET via HTTPS (acima) devolve 200.
> A API segue ouvindo só em `127.0.0.1:8000`; de fora, só o Nginx.

## (d) Backup três vezes + rotação

```bash
sudo /opt/ufla-shop/scripts/backup.sh
sudo /opt/ufla-shop/scripts/backup.sh
sudo /opt/ufla-shop/scripts/backup.sh
ls -la /var/backups/ufla-shop/
```

```
/var/backups/ufla-shop/loja-2026-09-26-162836.sql.gz (1627 bytes)
/var/backups/ufla-shop/loja-2026-09-26-162837.sql.gz (1625 bytes)
/var/backups/ufla-shop/loja-2026-09-26-162838.sql.gz (1622 bytes)
```

Depois de ultrapassar 7 dumps, a rotação mantém só os 7 mais recentes:

```
-rw-r--r-- 1 root root 1622 Sep 26 16:28 loja-2026-09-26-162838.sql.gz
-rw-r--r-- 1 root root 1624 Sep 26 16:28 loja-2026-09-26-162839.sql.gz
-rw-r--r-- 1 root root 1626 Sep 26 16:28 loja-2026-09-26-162840.sql.gz
-rw-r--r-- 1 root root 1626 Sep 26 16:28 loja-2026-09-26-162841.sql.gz
-rw-r--r-- 1 root root 1628 Sep 26 16:28 loja-2026-09-26-162842.sql.gz
-rw-r--r-- 1 root root 1627 Sep 26 16:28 loja-2026-09-26-162843.sql.gz
-rw-r--r-- 1 root root 1623 Sep 26 16:28 loja-2026-09-26-162845.sql.gz
```

O `logger -t backup` registra cada dump no journal:

```
Sep 26 16:29:37 devops backup[21414]: backup gerado: /var/backups/ufla-shop/loja-2026-09-26-162937.sql.gz (1627 bytes)
```

## (e) Prova da idempotência (duas execuções do `deploy.sh`)

**1ª execução** — cria o arquivo de segredos e sobe tudo:

```
>> /etc/ufla-shop.env criado com senha de banco aleatoria
...
>> healthcheck em http://localhost:8000/ready
>> /ready respondeu 200 na tentativa 1
```

**2ª execução** — não recria nada e termina igual:

```
Synchronizing state of nginx.service ...
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
>> healthcheck em http://localhost:8000/ready
>> /ready respondeu 200 na tentativa 1
```

Na segunda vez não aparece mais `criado com senha de banco aleatoria` (o
`/etc/ufla-shop.env` já existia), e o script chega ao mesmo healthcheck 200 sem
quebrar nem duplicar nada.
