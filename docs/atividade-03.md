# Atividade 3 — Automatizar de verdade

Deploy do `ufla-devops-shop` como serviço Linux: instalado por um script
idempotente, gerenciado pelo `systemd`, com backup diário e o Nginx fazendo TLS
na frente.

Todas as saídas abaixo foram copiadas como texto de uma execução real, numa
**máquina limpa**. Ambiente usado:

```
Ubuntu 24.04.5 LTS | systemd 255 | nginx 1.24.0
```

> **Nota sobre a máquina de teste.** Meu computador é macOS, e o enunciado pede
> Linux com `systemd` (`launchd` não serve, e a correção roda em Linux). Validei
> tudo dentro de uma VM **Ubuntu 24.04** criada com `limactl`/QEMU, num diretório
> de disco próprio. A VM é uma instalação limpa do Ubuntu — nada do ambiente do
> macOS vaza para dentro dela.

## Arquivos entregues

| Arquivo | O que é |
|---|---|
| `scripts/deploy.sh` | instala tudo; idempotente; termina com healthcheck em `/ready` |
| `scripts/backup.sh` | `pg_dump` datado com rotação de 7 e código de saída correto |
| `systemd/ufla-shop.service` | a API como serviço, usuário não-root, `Restart=on-failure` |
| `systemd/ufla-shop-backup.service` | `Type=oneshot` que roda o `backup.sh` |
| `systemd/ufla-shop-backup.timer` | diário às 3h, `Persistent=true` |
| `nginx/loja.conf` | proxy reverso com TLS, redirect 301 e cabeçalhos de IP real |

---

## (a) Como rodar o `deploy.sh` numa máquina limpa

```bash
git clone git@github.com:<seu-usuario>/ufla-devops-shop.git
cd ufla-devops-shop
git switch atividade-03

sudo ./scripts/deploy.sh
```

O script precisa de `root` (ele cria usuário de sistema, instala pacotes e
escreve em `/etc/systemd/system`) e cuida sozinho do resto: instala
PostgreSQL, Redis, Nginx e Python, cria o usuário `ufla-shop`, o banco `loja`,
o venv em `/opt/ufla-shop/.venv`, as units do `systemd` e o certificado TLS.

A senha do banco **não está no script**. Na primeira execução ele gera uma
senha aleatória e escreve `/etc/ufla-shop.env` (modo `600`), que a unit carrega
com `EnvironmentFile`. Também deixa um `/etc/ufla-shop.env.example` como
referência. Nas execuções seguintes a senha é lida de lá e nada é regenerado.

Saída da primeira execução numa máquina limpa:

```
$ sudo ./scripts/deploy.sh
==> usuario ufla-shop ja existe
==> garantindo PostgreSQL, Redis, Nginx e Python
==> habilitando e iniciando PostgreSQL e Redis
Synchronizing state of postgresql.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable postgresql
Synchronizing state of redis-server.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable redis-server
==> gerando segredos em /etc/ufla-shop.env (primeira execucao)
==> garantindo usuario e banco 'loja'
==> sincronizando o codigo para /opt/ufla-shop
==> criando o venv em /opt/ufla-shop/.venv
==> instalando requirements.txt
==> preparando /var/backups/ufla-shop
==> instalando as units em /etc/systemd/system
==> instalando o Nginx e o certificado autoassinado
==> nginx 1.24: removendo a diretiva 'http2 on' (so existe no 1.25+)
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
==> healthcheck: http://localhost:8000/ready
==> aplicacao no ar: {"status":"ok","banco":"ok","cache":"ok"}
==> deploy concluido
EXIT CODE DA 1a EXECUCAO: 0
```

> **Uma ressalva de honestidade sobre essa transcrição.** A linha
> `usuario ufla-shop ja existe` aparece aí porque o usuário já tinha sido criado
> numa tentativa anterior na mesma VM. Numa máquina **de fato virgem** essa
> linha sai como `criando usuario de sistema ufla-shop`. O resto da saída é
> igual. Preferi deixar a transcrição como ela saiu de verdade a maquiar o
> texto.

---

## (e) Prova da idempotência — as duas execuções seguidas

Segunda execução, na mesma máquina, sem limpar nada. Repare que ela **reaproveita**
o que já existe em vez de recriar, e termina no mesmo healthcheck verde:

```
$ sudo ./scripts/deploy.sh
==> usuario ufla-shop ja existe
==> garantindo PostgreSQL, Redis, Nginx e Python
==> habilitando e iniciando PostgreSQL e Redis
==> lendo segredos de /etc/ufla-shop.env
==> garantindo usuario e banco 'loja'
==> sincronizando o codigo para /opt/ufla-shop
==> venv ja existe, reutilizando
==> instalando requirements.txt
==> preparando /var/backups/ufla-shop
==> instalando as units em /etc/systemd/system
==> instalando o Nginx e o certificado autoassinado
==> certificado ja existe, mantendo
==> nginx 1.24: removendo a diretiva 'http2 on' (so existe no 1.25+)
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
==> healthcheck: http://localhost:8000/ready
==> aplicacao no ar: {"status":"ok","banco":"ok","cache":"ok"}
==> deploy concluido
EXIT CODE DA 2a EXECUCAO: 0
```

O que muda entre a 1ª e a 2ª execução, e é exatamente o que se espera de um
script idempotente:

| Passo | 1ª execução | 2ª execução |
|---|---|---|
| usuário `ufla-shop` | (já existia nesta VM) | `id` confirma, não recria |
| segredos | `gerando segredos em /etc/ufla-shop.env` | `lendo segredos de /etc/ufla-shop.env` |
| venv | `criando o venv` | `venv ja existe, reutilizando` |
| certificado TLS | gerado com `openssl req -x509` | `certificado ja existe, mantendo` |
| banco/role | criados | `SELECT 1 FROM pg_roles` confirma, não recria |

O ponto que costuma quebrar a segunda execução é o `useradd`, que falha com
"user already exists" e, sob `set -e`, mataria o script. Por isso a criação é
guardada:

```bash
if id "$APP_USER" &>/dev/null; then
  log "usuario $APP_USER ja existe"
else
  useradd --system --no-create-home --home-dir "$APP_DIR" --shell /usr/sbin/nologin "$APP_USER"
fi
```

O mesmo padrão vale para o `CREATE USER`/`CREATE DATABASE` do PostgreSQL, que
são testados no catálogo antes de rodar.

---

## (b) `systemctl status ufla-shop` depois do `kill -9`

Prova de que `Restart=on-failure` funciona: mato o processo com `SIGKILL` (que
não dá chance de desligamento limpo) e o `systemd` o traz de volta sozinho,
com PID novo.

```
$ systemctl show -p MainPID --value ufla-shop
11406

$ sudo kill -9 11406

$ systemctl status ufla-shop   (6 segundos depois)
● ufla-shop.service - ufla-devops-shop --- API (FastAPI) da loja
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-11-16 20:18:40 -03; 2s ago
       Docs: https://github.com/rdurelli/ufla-devops-shop
   Main PID: 11672 (uvicorn)
      Tasks: 1 (limit: 3386)
     Memory: 42.0M (peak: 42.3M)
        CPU: 517ms
     CGroup: /system.slice/ufla-shop.service
             └─11672 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000

Nov 16 20:18:40 lima-ufla systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 1.
Nov 16 20:18:40 lima-ufla systemd[1]: Started ufla-devops-shop --- API (FastAPI) da loja.

PID antes: 11406  ->  PID depois: 11672
```

A linha `Scheduled restart job, restart counter is at 1` é o `systemd` contando
o reinício. E o `Main PID` diferente confirma que é um processo novo, não o
antigo que sobreviveu.

Detalhes da unit que fazem isso funcionar:

- `User=ufla-shop` — o serviço **não roda como root**;
- `WorkingDirectory=/opt/ufla-shop` e `ExecStart` com **caminho absoluto**
  (`/opt/ufla-shop/.venv/bin/uvicorn`), porque o serviço não herda o `PATH`
  do shell nem o venv ativado;
- `EnvironmentFile=/etc/ufla-shop.env` — todas as variáveis vêm daqui;
- `After=network-online.target postgresql.service` — sem isso a API sobe antes
  do banco e o `/ready` devolve `503` nos primeiros segundos;
- `Restart=on-failure` com `RestartSec=3`.

---

## (c) Nginx — `curl -kI https://localhost` e `curl -I http://localhost`

```
$ curl -kI https://localhost
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Mon, 16 Nov 2026 23:18:43 GMT
Content-Type: text/html; charset=utf-8

$ curl -I http://localhost
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Mon, 16 Nov 2026 23:18:43 GMT
Content-Type: text/html
Content-Length: 178
```

`200` no HTTPS e `301` no HTTP, como o enunciado pede.

> O certificado é autoassinado, então o `-k` é necessário para o `curl` não
> recusar a cadeia. O `*.pem` e o `*.key` estão no `.gitignore` e o `deploy.sh`
> os gera com `openssl req -x509` — nada disso é versionado.

### Cabeçalhos de IP real

Para provar que `X-Real-IP`, `X-Forwarded-For` e `X-Forwarded-Proto` chegam
mesmo na aplicação, apontei o `proxy_pass` temporariamente para um servidorzinho
que devolve os cabeçalhos que recebeu:

```
$ curl -sk https://localhost
{
  "Host": "localhost",
  "X-Real-IP": "::1",
  "X-Forwarded-For": "::1",
  "X-Forwarded-Proto": "https",
  "User-Agent": "curl/8.5.0",
  "Accept": "*/*"
}
```

(`::1` porque o cliente de teste é o próprio `localhost`, via IPv6. Vindo de
outra máquina, `X-Real-IP` traz o IP de verdade do cliente.)

### A API continua fechada em `127.0.0.1:8000`

```
$ sudo ss -ltn
LISTEN 0      511          0.0.0.0:80         0.0.0.0:*
LISTEN 0      511          0.0.0.0:443        0.0.0.0:*
LISTEN 0      2048       127.0.0.1:8000       0.0.0.0:*
LISTEN 0      511             [::]:80            [::]:*
LISTEN 0      511             [::]:443           [::]:*
```

O `127.0.0.1:8000` só aceita conexão da própria máquina; de fora, quem atende é
o Nginx no 80/443.

### A diretiva `http2 on` e a versão do Nginx

O `nginx/loja.conf` do repositório traz `http2 on;` (a forma moderna). Essa
diretiva **só existe a partir do Nginx 1.25**. No 1.24 — que é o que o Ubuntu
24.04 instala — ela é desconhecida e faz o `nginx -t` recusar **a configuração
inteira**, derrubando o deploy. O `deploy.sh` detecta a versão e remove a linha
quando ela não é suportada, sem precisar de `bc`:

```bash
NGINX_VERSAO="$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
if [[ -n "$NGINX_VERSAO" ]] && ! printf '1.25\n%s\n' "$NGINX_VERSAO" | sort -V -C; then
  sed -i '/^\s*http2 on;\s*$/d' /etc/nginx/conf.d/loja.conf
fi
```

`sort -V -C` sai `0` quando a entrada já está em ordem de versão; se ordenar
`1.25 <versão>` não muda nada, então `1.25 <= versão`. Com HTTP/1.1 o teste do
enunciado também passa (a saída acima é de um Nginx 1.24).

---

## (d) `ls -la /var/backups/ufla-shop` depois de rodar o backup três vezes

O nome do arquivo tem granularidade de minuto (`loja-AAAA-MM-DD-HHMM.sql.gz`),
então as execuções foram espaçadas para gerar três arquivos distintos:

```
--- backup 1 ---
exit status: 0
--- backup 2 ---
exit status: 0
--- backup 3 ---
exit status: 0

$ ls -la /var/backups/ufla-shop
total 20
drwxr-x--- 2 ufla-shop ufla-shop 4096 Nov 16  2026 .
drwxr-xr-x 3 root      root      4096 Nov 16 20:18 ..
-rw-r--r-- 1 ufla-shop ufla-shop 1590 Nov 16 20:18 loja-2026-11-16-2018.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1592 Nov 16 20:19 loja-2026-11-16-2019.sql.gz
-rw-r--r-- 1 ufla-shop ufla-shop 1592 Nov 16 20:20 loja-2026-11-16-2020.sql.gz
```

Os dumps são SQL de verdade, não arquivos vazios:

```
$ zcat /var/backups/ufla-shop/loja-2026-11-16-2020.sql.gz | head -3
--
-- PostgreSQL database dump
--
$ zcat /var/backups/ufla-shop/loja-2026-11-16-2020.sql.gz | grep -c 'CREATE TABLE'
4
```

### A rotação mantém os 7 mais recentes

Para provar a rotação sem esperar 8 dias, criei 8 dumps antigos com data de
2020 (total 11 arquivos) e rodei o backup:

```
arquivos antes: 11
arquivos depois: 7

--- journal do backup ---
Nov 16 20:20:47 lima-ufla backup[11846]: dump gerado: /var/backups/ufla-shop/loja-2026-11-16-2020.sql.gz (4.0K)
Nov 16 20:20:47 lima-ufla backup[11852]: dump antigo removido: loja-2020-01-04-0300.sql.gz
Nov 16 20:20:47 lima-ufla backup[11854]: dump antigo removido: loja-2020-01-03-0300.sql.gz
Nov 16 20:20:47 lima-ufla backup[11856]: dump antigo removido: loja-2020-01-02-0300.sql.gz
Nov 16 20:20:47 lima-ufla backup[11858]: dump antigo removido: loja-2020-01-01-0300.sql.gz
Nov 16 20:20:47 lima-ufla backup[11862]: backup concluido: 7 dumps retidos
```

Como o nome termina em `AAAA-MM-DD-HHMM`, a ordem alfabética **é** a
cronológica, então a rotação é um `sort` (sem `ls -t` nem `stat`):

```bash
find "$DESTINO" -maxdepth 1 -name 'loja-*.sql.gz' -printf '%f\n' | sort -r | tail -n +$((MANTER + 1))
```

### O código de saída quando o `pg_dump` falha

O ponto aqui é o `pipefail`. Sem ele, o status do pipeline
`pg_dump | gzip` seria o do `gzip`, que é `0` mesmo quando o `pg_dump` morre —
o script terminaria "com sucesso" deixando um dump truncado no disco.

```
$ pg_dump --no-owner --no-privileges | gzip -9 > "$ARQUIVO"   # DATABASE_URL numa porta sem banco
pg_dump: error: connection to server at "localhost" (127.0.0.1), port 5999 failed: Connection refused
	Is the server running on that host and accepting TCP/IP connections?
exit code: 1
```

Com o banco no ar, o mesmo comando sai `0` e gera o arquivo:

```
exit code: 0
-rw-rw-r-- 1 ufla-shop ufla-shop 1592 Nov 16 20:21 loja-2026-11-16-2021.sql.gz
```

### O `pg_dump` não pede senha

O enunciado avisa: *"pg_dump pede senha"*. A solução aqui é um `~/.pgpass` do
usuário que roda o backup, criado pelo `deploy.sh` em
`/opt/ufla-shop/.pgpass` (modo `600`, dono `ufla-shop`), apontado pela unit via
`PGPASSFILE`.

Além disso, o `backup.sh` **quebra a `DATABASE_URL` em variáveis `PG*`** em vez
de passar `--dbname="$DATABASE_URL"`. O motivo é o `ps`: a URL completa, com a
senha dentro, ficaria visível para qualquer usuário da máquina enquanto o dump
roda. A variável de ambiente do processo, não.

---

## O timer diário

O `ufla-shop-backup.timer` roda todo dia às 3h, com `Persistent=true` (se a
máquina estiver desligada na hora marcada, o `systemd` roda o backup assim que
ela voltar, em vez de pular o dia) e um `RandomizedDelaySec=300` para não
coincidir com outros timers da máquina.

```
$ systemctl list-timers ufla-shop-backup.timer
NEXT                        LEFT LAST                        PASSED UNIT                   ACTIVATES
Tue 2026-11-17 03:04:46 -03   6h Mon 2026-11-16 20:06:02 -03      - ufla-shop-backup.timer ufla-shop-backup.service

1 timers listed.
```

E o `ufla-shop-backup.service`, disparado pelo timer, também roda bem na mão
(é assim que gerei os três dumps acima):

```
$ systemctl start ufla-shop-backup.service
$ systemctl status ufla-shop-backup.service
○ ufla-shop-backup.service - Backup do banco loja (ufla-devops-shop)
     Loaded: loaded (/etc/systemd/system/ufla-shop-backup.service; static)
     Active: inactive (dead) since Mon 2026-11-16 20:14:49 -03; 1s ago
TriggeredBy: ● ufla-shop-backup.timer
    Process: 9808 ExecStart=/opt/ufla-shop/scripts/backup.sh (code=exited, status=0/SUCCESS)
   Main PID: 9808 (code=exited, status=0/SUCCESS)
```

`Active: inactive (dead)` é o esperado para um `Type=oneshot`: ele roda até o
fim e sai. O que importa é `status=0/SUCCESS`.

---

## Um ajuste que o teste do enunciado exigiu

O teste pedido é `curl -kI https://localhost`, e o `-I` manda **HEAD**. O
FastAPI responde `GET` mas não implementa `HEAD` nas rotas do `app/principal.py`,
então a API devolve `405`:

```
$ curl -s -o /dev/null -w '%{http_code}\n' -I http://127.0.0.1:8000/
405
```

O Nginx repassava esse `405` ao cliente e o teste falhava mesmo com o TLS
perfeito. Como não faz sentido mexer na aplicação (que está correta: ela só
anuncia `GET`), a correção ficou no Nginx, convertendo o método que sobe para o
backend:

```nginx
map $request_method $metodo_upstream {
    default $request_method;
    HEAD    GET;
}

# ... dentro do location /
proxy_method $metodo_upstream;
```

O Nginx descarta o corpo ao devolver a resposta, então o cliente recebe só os
cabeçalhos — que é o que um `HEAD` deve fazer. Resultado: `HTTP/1.1 200 OK`.

---

## Onde eu travei (e o que aprendi)

- **`rsync -a` estragando o dono do `/opt/ufla-shop`.** O `-a` implica `-o -g`
  e preserva o dono da origem. Como o deploy roda de dentro do clone, o
  `/opt/ufla-shop` ficava com o dono do *meu* usuário, e o `ufla-shop` não
  conseguia criar o venv (`Permission denied`). Troquei por
  `rsync -rlptD --no-owner --no-group`, que preserva permissões e symlinks mas
  deixa o dono para o `chown` seguinte.
- **`useradd` na segunda execução.** Resolvido com o teste `id ... ||`, como o
  próprio enunciado sugere.
- **`http2 on` no Nginx 1.24.** A diretiva derruba a configuração inteira numa
  versão que o Ubuntu 24.04 ainda instala. Ver a seção (c).
- **`TYPE=oneshot` no backup e não `simple`.** Um script que termina não deve
  ficar "de pé", e um `Type=simple` faria o `systemd` considerar o serviço
  falho ao ver o processo sair.
