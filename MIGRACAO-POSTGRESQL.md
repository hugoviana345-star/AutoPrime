# AutoPrime — PostgreSQL e hospedagem

## Desenvolvimento local
Sem `DATABASE_URL`, o servidor continua usando `lib/backend/autoprime.db` (SQLite).

## Produção
Configure `DATABASE_URL` com a URL PostgreSQL do Neon. O servidor cria as tabelas e os produtos iniciais automaticamente. Configure `FRONTEND_HOST` com o domínio do Netlify, sem `https://`. O Render fornece `PORT` automaticamente.

Instalação: `pip install -r requirements.txt`
Inicialização: `python lib/backend/servidor.py`

Build Flutter Web: `flutter build web --release --dart-define=API_URL=https://SEU-SERVICO.onrender.com`
Publique o conteúdo de `build/web` no Netlify.

## Migrar os dados SQLite existentes
1. Faça backup de `lib/backend/autoprime.db`.
2. Configure `DATABASE_URL` no terminal com a URL do banco PostgreSQL.
3. Execute `python migrar_sqlite_postgres.py`.
4. O script copia usuários, sessões, produtos e carrinhos preservando IDs.

Não compartilhe a URL do banco: ela contém credenciais.
