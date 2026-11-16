"""Servidor local da AutoPrime. Execute: python servidor.py"""
import base64
import binascii
import struct
import zlib
import argparse
import getpass
from decimal import Decimal, InvalidOperation
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import os
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:
    psycopg = None
    dict_row = None


def senha_hash(senha, sal=None):
    sal = sal or secrets.token_hex(16)
    resumo = hashlib.pbkdf2_hmac('sha256', senha.encode(), bytes.fromhex(sal), 600000).hex()
    return f'{sal}${resumo}'


def conferir_senha(senha, salvo):
    return hmac.compare_digest(senha_hash(senha, salvo.split('$')[0]), salvo)


class ErroAPI(Exception):
    def __init__(self, mensagem, status=400):
        self.mensagem, self.status = mensagem, status


PRODUTOS_INICIAIS = [{'id': '1',
  'nome': 'Kit Farol LED',
  'categoria': 'Iluminação',
  'imagem': 'https://cdn.awsli.com.br/2500x2500/1079/1079314/produto/56262321/h4-ff0ak0pzzm.jpg',
  'descricao': 'Farol LED de alta potência com excelente iluminação e longa duração.',
  'preco_centavos': 18990},
 {'id': '2',
  'nome': 'Bateria Automotiva',
  'categoria': 'Elétrica',
  'imagem': 'https://acdn-us.mitiendanube.com/stores/007/239/898/products/3008-bateria-automotiva-moura-m40sd-40ah-f0d8a43a5d5390f69d17785030715336-1024-1024.webp',
  'descricao': 'Bateria de alta durabilidade e ótimo desempenho para seu veículo.',
  'preco_centavos': 45990},
 {'id': '3',
  'nome': 'Pneu Aro 15',
  'categoria': 'Pneus',
  'imagem': 'https://fortbras.vteximg.com.br/arquivos/ids/555434/kit-2-pneu-aro-15-185-65r15-continental-88h-tl-ultracontact-hipervarejo-1.jpg?v=638978592018100000',
  'descricao': 'Pneu resistente com excelente aderência, conforto e segurança.',
  'preco_centavos': 38990},
 {'id': '4',
  'nome': 'Câmera de Ré',
  'categoria': 'Acessórios',
  'imagem': 'https://someacessorios.com.br/media/catalog/product/cache/1/image/1800x/040ec09b1e35df139433887a97daa66f/1/9/19321_camera_de_re_universal_modelo_tartaruga_vis_o_160_graus_vo6_04_1.jpg',
  'descricao': 'Câmera para auxiliar nas manobras e aumentar a segurança.',
  'preco_centavos': 14990},
 {'id': '5',
  'nome': 'Central Multimídia',
  'categoria': 'Tecnologia',
  'imagem': 'https://images.tcdn.com.br/img/img_prod/594099/central_multimidia_android_10_7_2g_ram_32g_armazenamento_1000051_1_28074e23fe074b47311624b909284435.jpg',
  'descricao': 'Central multimídia com tela touchscreen, Bluetooth e USB.',
  'preco_centavos': 79990},
 {'id': '6',
  'nome': 'Óleo de Motor',
  'categoria': 'Manutenção',
  'imagem': 'https://agrosolo.fbitsstatic.net/img/p/oleo-lubrificante-do-motor-lubrax-essencial-sl-20w50-para-carros-1-litro-84522/279966-1.jpg?w=1000&h=1000&v=no-value',
  'descricao': 'Óleo lubrificante para ajudar a proteger e conservar seu motor.',
  'preco_centavos': 5990},
 {'id': '7',
  'nome': 'Capa para Bancos',
  'categoria': 'Interior',
  'imagem': 'https://abcdesignbrasil.fbitsstatic.net/img/p/capa-protetora-para-banco-de-carro-150208/336755-3.jpg?w=1000&h=1000&v=202609141415',
  'descricao': 'Kit de capas que protege e melhora o visual interno do veículo.',
  'preco_centavos': 21990},
 {'id': '8',
  'nome': 'Kit de Ferramentas',
  'categoria': 'Ferramentas',
  'imagem': 'https://images.tcdn.com.br/img/img_prod/659515/jogo_kit_maleta_de_ferramentas_110_pecas_completa_3309_1_aae8fc6f5436511c87b38c8a14324993.jpg',
  'descricao': 'Ferramentas essenciais para manutenção e pequenos reparos.',
  'preco_centavos': 29990}]


class BancoPostgres:
    def __init__(self, conexao): self.conexao = conexao
    def execute(self, sql, parametros=()): return self.conexao.execute(sql.replace('?', '%s'), parametros)
    def executemany(self, sql, parametros): return self.conexao.executemany(sql.replace('?', '%s'), parametros)


class Aplicacao:
    def __init__(self, caminho):
        self.caminho = str(caminho)
        self.database_url = os.getenv('DATABASE_URL', '').strip()
        if self.database_url:
            if psycopg is None:
                raise RuntimeError('Dependência psycopg não instalada. Execute pip install -r requirements.txt.')
            self._inicializar_postgres()
        else:
            self._inicializar_sqlite()

    @contextmanager
    def banco(self):
        if self.database_url:
            conn = psycopg.connect(self.database_url, row_factory=dict_row, connect_timeout=10)
            try:
                with conn:
                    yield BancoPostgres(conn)
            finally:
                conn.close()
        else:
            db = sqlite3.connect(self.caminho, timeout=10)
            db.row_factory = sqlite3.Row
            db.execute('PRAGMA foreign_keys=ON')
            try:
                with db:
                    yield db
            finally:
                db.close()

    def _inicializar_sqlite(self):
        with self.banco() as db:
            novos_usuarios = not db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='usuarios'").fetchone()
            db.executescript('''
                CREATE TABLE IF NOT EXISTS usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE, senha_hash TEXT, visitante INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS sessoes (token_hash TEXT PRIMARY KEY, usuario_id INTEGER NOT NULL REFERENCES usuarios(id), expira INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS carrinho (usuario_id INTEGER NOT NULL REFERENCES usuarios(id), produto_id TEXT NOT NULL, quantidade INTEGER NOT NULL CHECK(quantidade BETWEEN 1 AND 999), PRIMARY KEY(usuario_id, produto_id));
            ''')
            colunas = {r['name'] for r in db.execute('PRAGMA table_info(usuarios)')}
            if 'administrador' not in colunas: db.execute('ALTER TABLE usuarios ADD COLUMN administrador INTEGER NOT NULL DEFAULT 0')
            for coluna in ('nome', 'telefone', 'foto'):
                if coluna not in colunas: db.execute(f"ALTER TABLE usuarios ADD COLUMN {coluna} TEXT NOT NULL DEFAULT ''")
            nova_tabela = not db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='produtos'").fetchone()
            db.execute('''CREATE TABLE IF NOT EXISTS produtos (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, descricao TEXT NOT NULL, categoria TEXT NOT NULL, preco_centavos INTEGER NOT NULL CHECK(preco_centavos > 0), imagem TEXT NOT NULL, ativo INTEGER NOT NULL DEFAULT 1)''')
            if nova_tabela:
                db.executemany('INSERT INTO produtos(id,nome,descricao,categoria,preco_centavos,imagem) VALUES (?,?,?,?,?,?)', [(p['id'],p['nome'],p['descricao'],p['categoria'],p['preco_centavos'],p['imagem']) for p in PRODUTOS_INICIAIS])
            if novos_usuarios:
                db.execute('INSERT INTO usuarios(email, senha_hash) VALUES (?, ?)', ('hugo@gmail.com', senha_hash('123')))

    def _inicializar_postgres(self):
        with self.banco() as db:
            db.execute('''CREATE TABLE IF NOT EXISTS usuarios (id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, email TEXT UNIQUE, senha_hash TEXT, visitante INTEGER NOT NULL DEFAULT 0, administrador INTEGER NOT NULL DEFAULT 0, nome TEXT NOT NULL DEFAULT '', telefone TEXT NOT NULL DEFAULT '', foto TEXT NOT NULL DEFAULT '')''')
            db.execute('''CREATE TABLE IF NOT EXISTS sessoes (token_hash TEXT PRIMARY KEY, usuario_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE, expira BIGINT NOT NULL)''')
            db.execute('''CREATE TABLE IF NOT EXISTS produtos (id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, nome TEXT NOT NULL, descricao TEXT NOT NULL, categoria TEXT NOT NULL, preco_centavos BIGINT NOT NULL CHECK(preco_centavos > 0), imagem TEXT NOT NULL, ativo INTEGER NOT NULL DEFAULT 1)''')
            db.execute('''CREATE TABLE IF NOT EXISTS carrinho (usuario_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE, produto_id TEXT NOT NULL, quantidade INTEGER NOT NULL CHECK(quantidade BETWEEN 1 AND 999), PRIMARY KEY(usuario_id, produto_id))''')
            if not db.execute('SELECT id FROM produtos LIMIT 1').fetchone():
                for item in PRODUTOS_INICIAIS:
                    db.execute('INSERT INTO produtos(id,nome,descricao,categoria,preco_centavos,imagem) VALUES (?,?,?,?,?,?) ON CONFLICT (id) DO NOTHING', (int(item['id']),item['nome'],item['descricao'],item['categoria'],item['preco_centavos'],item['imagem']))

    def usuario(self, db, token):
        resumo = hashlib.sha256(token.encode()).hexdigest()
        registro = db.execute('''SELECT u.* FROM sessoes s
            JOIN usuarios u ON u.id=s.usuario_id
            WHERE s.token_hash=? AND s.expira>?''', (resumo, int(time.time()))).fetchone()
        if registro is None:
            raise ErroAPI('Sessão expirada. Entre novamente.', 401)
        return registro

    def sessao(self, db, usuario_id, visitante=False):
        token = secrets.token_urlsafe(32)
        dias = 365 if visitante else 30
        db.execute('INSERT INTO sessoes VALUES (?, ?, ?)',
                   (hashlib.sha256(token.encode()).hexdigest(), usuario_id,
                    int(time.time()) + dias * 86400))
        admin = db.execute('SELECT administrador FROM usuarios WHERE id=?', (usuario_id,)).fetchone()['administrador']
        return {'token': token, 'visitante': visitante, 'administrador': bool(admin)}

    def criar_admin(self, email, senha):
        email = email.strip().lower()
        if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email) or len(email) > 254:
            raise ErroAPI('Digite um e-mail válido.')
        if len(senha.strip()) < 8 or len(senha) > 128:
            raise ErroAPI('Use uma senha de 8 a 128 caracteres.')
        with self.banco() as db:
            # Somente o comando local pode conceder a permissão.
            db.execute('''INSERT INTO usuarios(email,senha_hash,administrador) VALUES (?,?,1)
                ON CONFLICT(email) DO UPDATE SET senha_hash=excluded.senha_hash, administrador=1''',
                (email, senha_hash(senha)))
            db.execute('DELETE FROM sessoes WHERE usuario_id=(SELECT id FROM usuarios WHERE email=?)', (email,))

    @staticmethod
    def produto_json(p):
        return {'id': str(p['id']), 'nome': p['nome'], 'descricao': p['descricao'],
                'categoria': p['categoria'], 'preco': p['preco_centavos'] / 100, 'imagem': p['imagem']}

    @staticmethod
    def validar_produto(dados):
        valores = []
        for chave, limite in [('nome',100), ('descricao',2000), ('categoria',60)]:
            valor = dados.get(chave)
            if not isinstance(valor, str) or not 1 <= len(valor.strip()) <= limite:
                raise ErroAPI(f'{chave.capitalize()} deve ter entre 1 e {limite} caracteres.')
            valores.append(valor.strip())
        preco = dados.get('preco')
        if isinstance(preco, bool) or not isinstance(preco, (int,float,str)):
            raise ErroAPI('Preço inválido.')
        try:
            numero = Decimal(str(preco))
            centavos = numero * 100
            if not numero.is_finite() or not 0 < numero <= 999999.99 or centavos != centavos.to_integral_value():
                raise ErroAPI('Preço deve ser positivo e ter até duas casas decimais.')
        except InvalidOperation:
            raise ErroAPI('Preço inválido.')
        imagem = dados.get('imagem', '')
        if not isinstance(imagem, str) or len(imagem) > 2000:
            raise ErroAPI('Link da imagem inválido.')
        imagem = imagem.strip()
        try:
            url = urlparse(imagem)
        except ValueError:
            raise ErroAPI('Link da imagem inválido.')
        if imagem and (url.scheme not in ('http','https') or not url.hostname or url.username or url.password):
            raise ErroAPI('Use um link de imagem começando com http:// ou https://.')
        return (*valores, int(centavos), imagem)

    @staticmethod
    def perfil_json(usuario):
        return {'nome': usuario['nome'], 'email': usuario['email'],
                'telefone': usuario['telefone'], 'foto': usuario['foto'], 'administrador': bool(usuario['administrador'])}

    @staticmethod
    def validar_foto(foto):
        # O Flutter converte a foto escolhida em PNG antes de enviar.
        if not isinstance(foto, str) or len(foto) > 700000:
            raise ErroAPI('Foto muito grande. Escolha uma imagem menor.')
        if not foto:
            return ''
        try:
            arquivo = base64.b64decode(foto, validate=True)
        except (ValueError, binascii.Error):
            raise ErroAPI('Foto inválida.')
        if len(arquivo) > 500 * 1024 or not arquivo.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ErroAPI('Envie uma foto PNG de até 500 KB pela tela de perfil.')
        pos, largura, altura, canais = 8, 0, 0, 0
        comprimido = bytearray()
        final = False
        while pos + 12 <= len(arquivo):
            tamanho = struct.unpack('>I',arquivo[pos:pos+4])[0]
            tipo = arquivo[pos+4:pos+8]
            fim = pos + 12 + tamanho
            if fim > len(arquivo):
                raise ErroAPI('Foto incompleta.')
            dados = arquivo[pos+8:pos+8+tamanho]
            crc = struct.unpack('>I',arquivo[pos+8+tamanho:fim])[0]
            if zlib.crc32(tipo+dados) & 0xffffffff != crc:
                raise ErroAPI('Foto corrompida.')
            if pos == 8 and tipo != b'IHDR':
                raise ErroAPI('Foto inválida.')
            if tipo == b'IHDR':
                if largura or tamanho != 13:
                    raise ErroAPI('Foto inválida.')
                largura,altura,profundidade,cor,compressao,filtro,interlace = struct.unpack('>IIBBBBB',dados)
                if not 1 <= largura <= 512 or not 1 <= altura <= 512 or profundidade != 8 or cor not in (2,6) or (compressao,filtro,interlace) != (0,0,0):
                    raise ErroAPI('Use a tela do perfil para preparar a foto.')
                canais = 3 if cor == 2 else 4
            elif tipo == b'IDAT':
                comprimido.extend(dados)
            elif tipo == b'IEND':
                if tamanho or fim != len(arquivo):
                    raise ErroAPI('Foto inválida.')
                final = True
                break
            elif tipo[:1].isupper():
                raise ErroAPI('Formato PNG não suportado.')
            pos = fim
        if not final or not largura or not comprimido:
            raise ErroAPI('Foto incompleta.')
        esperado = altura * (1 + largura * canais)
        try:
            decoder = zlib.decompressobj()
            pixels = decoder.decompress(bytes(comprimido), esperado + 1)
        except zlib.error:
            raise ErroAPI('Foto corrompida.')
        if len(pixels) != esperado or not decoder.eof or decoder.unused_data or any(pixels[i] > 4 for i in range(0,len(pixels),1+largura*canais)):
            raise ErroAPI('Foto inválida.')
        return base64.b64encode(arquivo).decode('ascii')

    def salvar_perfil(self, db, usuario, dados, token):
        permitidos = {'nome','email','telefone','senha_atual','nova_senha'}
        if set(dados) - permitidos:
            raise ErroAPI('Campo de perfil não permitido.')
        nome = dados.get('nome', usuario['nome'])
        telefone = dados.get('telefone', usuario['telefone'])
        email = dados.get('email', usuario['email'])
        if not isinstance(nome, str) or len(nome.strip()) > 100:
            raise ErroAPI('Nome deve ter até 100 caracteres.')
        if 'nome' in dados and not nome.strip():
            raise ErroAPI('Digite seu nome.')
        if not isinstance(telefone, str) or len(telefone.strip()) > 30:
            raise ErroAPI('Telefone inválido.')
        telefone = telefone.strip()
        if telefone and (not re.fullmatch(r'[+0-9()\s.-]+', telefone) or not 10 <= len(re.sub(r'\D','',telefone)) <= 15):
            raise ErroAPI('Use um telefone com 10 a 15 dígitos ou deixe o campo vazio.')
        if not isinstance(email, str):
            raise ErroAPI('Digite um e-mail válido.')
        email = email.strip().lower()
        if len(email) > 254 or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
            raise ErroAPI('Digite um e-mail válido.')
        senha_atual, nova_senha = dados.get('senha_atual',''), dados.get('nova_senha','')
        if not isinstance(senha_atual,str) or not isinstance(nova_senha,str) or len(senha_atual)>128 or len(nova_senha)>128:
            raise ErroAPI('Senha inválida ou maior que 128 caracteres.')
        trocar_acesso = email != usuario['email'] or bool(nova_senha)
        if trocar_acesso and (not senha_atual or not conferir_senha(senha_atual,usuario['senha_hash'])):
            raise ErroAPI('Digite corretamente sua senha atual para alterar e-mail ou senha.')
        minimo = 8 if usuario['administrador'] else 6
        if nova_senha and len(nova_senha.strip()) < minimo:
            raise ErroAPI(f'A nova senha deve ter pelo menos {minimo} caracteres.')
        resumo = senha_hash(nova_senha) if nova_senha else usuario['senha_hash']
        try:
            db.execute('UPDATE usuarios SET nome=?,telefone=?,email=?,senha_hash=? WHERE id=?',
                       (nome.strip(),telefone,email,resumo,usuario['id']))
        except (sqlite3.IntegrityError, psycopg.IntegrityError if psycopg else sqlite3.IntegrityError):
            raise ErroAPI('Este e-mail já está cadastrado em outra conta.',409)
        if trocar_acesso:
            # Mantém a sessão atual e encerra outros acessos desta conta.
            atual = hashlib.sha256(token.encode()).hexdigest()
            db.execute('DELETE FROM sessoes WHERE usuario_id=? AND token_hash<>?', (usuario['id'],atual))
        atualizado = db.execute('SELECT * FROM usuarios WHERE id=?', (usuario['id'],)).fetchone()
        return {'perfil': self.perfil_json(atualizado), 'mensagem': 'Perfil atualizado.'}

    def executar(self, metodo, caminho, dados, token=''):
        if metodo == 'GET' and caminho == '/health':
            return 200, {'mensagem': 'Servidor AutoPrime funcionando.'}
        with self.banco() as db:
            if caminho == '/products' and metodo == 'GET':
                return 200, {'produtos': [self.produto_json(p) for p in db.execute('SELECT * FROM produtos WHERE ativo=1 ORDER BY id')]}
            if caminho == '/products' or caminho.startswith('/products/'):
                usuario = self.usuario(db, token)
                if not usuario['administrador'] or usuario['visitante']:
                    raise ErroAPI('Acesso exclusivo para administradores.', 403)
                if caminho == '/products' and metodo == 'POST':
                    valores = self.validar_produto(dados)
                    cursor = db.execute('INSERT INTO produtos(nome,descricao,categoria,preco_centavos,imagem) VALUES (?,?,?,?,?) RETURNING id', valores)
                    novo_id = cursor.fetchone()['id']
                    p = db.execute('SELECT * FROM produtos WHERE id=?', (novo_id,)).fetchone()
                    return 201, {'produto': self.produto_json(p)}
                pid = caminho.removeprefix('/products/')
                if not re.fullmatch(r'[1-9][0-9]{0,17}', pid):
                    raise ErroAPI('Produto não encontrado.', 404)
                p = db.execute('SELECT * FROM produtos WHERE id=? AND ativo=1', (pid,)).fetchone()
                if p is None:
                    raise ErroAPI('Produto não encontrado.', 404)
                if metodo == 'PUT':
                    valores = self.validar_produto(dados)
                    db.execute('UPDATE produtos SET nome=?,descricao=?,categoria=?,preco_centavos=?,imagem=? WHERE id=?', (*valores,pid))
                    p = db.execute('SELECT * FROM produtos WHERE id=?', (pid,)).fetchone()
                    return 200, {'produto': self.produto_json(p)}
                if metodo == 'DELETE':
                    db.execute('UPDATE produtos SET ativo=0 WHERE id=?', (pid,))
                    db.execute('DELETE FROM carrinho WHERE produto_id=?', (pid,))
                    return 200, {'mensagem': 'Produto excluído.'}
                raise ErroAPI('Método não permitido.', 405)
            if metodo == 'POST' and caminho in ('/register', '/login'):
                email, senha = dados.get('email', ''), dados.get('senha', '')
                if not isinstance(email, str) or not isinstance(senha, str):
                    raise ErroAPI('E-mail e senha inválidos.')
                email = email.strip().lower()
                if len(email) > 254 or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
                    raise ErroAPI('Digite um e-mail válido.')
                if len(senha) > 128:
                    raise ErroAPI('Use uma senha de até 128 caracteres.')
                if caminho == '/register':
                    if len(senha.strip()) < 6:
                        raise ErroAPI('Use uma senha com pelo menos 6 caracteres.')
                    try:
                        db.execute('INSERT INTO usuarios(email, senha_hash) VALUES (?, ?)',
                                   (email, senha_hash(senha)))
                    except (sqlite3.IntegrityError, psycopg.IntegrityError if psycopg else sqlite3.IntegrityError):
                        raise ErroAPI('Este e-mail já está cadastrado.', 409)
                    return 201, {'mensagem': 'Conta criada com sucesso.'}
                usuario = db.execute('SELECT * FROM usuarios WHERE email=?', (email,)).fetchone()
                if usuario is None or not conferir_senha(senha, usuario['senha_hash']):
                    raise ErroAPI('E-mail ou senha incorretos.', 401)
                return 200, self.sessao(db, usuario['id'])
            if metodo == 'POST' and caminho == '/guest':
                cursor = db.execute('INSERT INTO usuarios(visitante) VALUES (1) RETURNING id')
                return 201, self.sessao(db, cursor.fetchone()['id'], True)
            if caminho not in ('/cart', '/logout', '/me', '/me/photo'):
                raise ErroAPI('Endereço não encontrado.', 404)
            usuario = self.usuario(db, token)
            if caminho == '/me/photo':
                if usuario['visitante']:
                    raise ErroAPI('Entre com uma conta para alterar a foto.',403)
                if metodo != 'PUT':
                    raise ErroAPI('Método não permitido.',405)
                if set(dados) != {'foto'}:
                    raise ErroAPI('Envie apenas a foto do perfil.')
                foto = self.validar_foto(dados['foto'])
                db.execute('UPDATE usuarios SET foto=? WHERE id=?', (foto,usuario['id']))
                return 200, {'foto': foto, 'mensagem': 'Foto atualizada.'}
            if caminho == '/me':
                if usuario['visitante']:
                    raise ErroAPI('Entre com uma conta para acessar o perfil.',403)
                if metodo == 'GET':
                    return 200, {'perfil': self.perfil_json(usuario)}
                if metodo == 'PUT':
                    return 200, self.salvar_perfil(db,usuario,dados,token)
                raise ErroAPI('Método não permitido.',405)
            if metodo == 'GET' and caminho == '/cart':
                itens = db.execute('SELECT produto_id, quantidade FROM carrinho WHERE usuario_id=?',
                                   (usuario['id'],)).fetchall()
                return 200, {'itens': [dict(i) for i in itens], 'visitante': bool(usuario['visitante'])}
            if metodo == 'PUT' and caminho == '/cart':
                itens = dados.get('itens')
                if not isinstance(itens, list) or len(itens) > 1000:
                    raise ErroAPI('Carrinho inválido.')
                vistos = set()
                for item in itens:
                    if not isinstance(item, dict):
                        raise ErroAPI('Produto inválido.')
                    pid, qtd = item.get('produto_id'), item.get('quantidade')
                    if not isinstance(pid, str) or not re.fullmatch(r'[1-9][0-9]{0,17}', pid) or not db.execute('SELECT id FROM produtos WHERE id=? AND ativo=1', (pid,)).fetchone():
                        raise ErroAPI('Produto não encontrado.')
                    if type(qtd) is not int or not 1 <= qtd <= 999 or pid in vistos:
                        raise ErroAPI('Quantidade inválida ou produto repetido.')
                    vistos.add(pid)
                db.execute('DELETE FROM carrinho WHERE usuario_id=?', (usuario['id'],))
                db.executemany('INSERT INTO carrinho VALUES (?, ?, ?)',
                               [(usuario['id'], i['produto_id'], i['quantidade']) for i in itens])
                return 200, {'mensagem': 'Carrinho salvo.'}
            if metodo == 'POST' and caminho == '/logout':
                db.execute('DELETE FROM sessoes WHERE token_hash=?',
                           (hashlib.sha256(token.encode()).hexdigest(),))
                return 200, {'mensagem': 'Sessão encerrada.'}
            raise ErroAPI('Método não permitido.', 405)


class Servidor(BaseHTTPRequestHandler):
    aplicacao = None

    def log_message(self, formato, *args):
        # Registra apenas método, endereço e status; nunca credenciais.
        super().log_message(formato, *args)

    def origem_permitida(self):
        origem = self.headers.get('Origin')
        if origem is None:
            return True
        partes = urlparse(origem)
        return partes.scheme in ('http', 'https') and (partes.hostname in ('localhost', '127.0.0.1') or partes.hostname == os.getenv('FRONTEND_HOST'))

    def responder(self, status, dados):
        corpo = json.dumps(dados, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(corpo)))
        self.send_header('Cache-Control', 'no-store')
        origem = self.headers.get('Origin')
        if origem and self.origem_permitida():
            self.send_header('Access-Control-Allow-Origin', origem)
            self.send_header('Vary', 'Origin')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.end_headers()
        self.wfile.write(corpo)

    def do_OPTIONS(self):
        self.responder(200 if self.origem_permitida() else 403, {})

    def atender(self):
        try:
            if not self.origem_permitida():
                raise ErroAPI('Origem não permitida.', 403)
            try:
                tamanho = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                raise ErroAPI('Tamanho inválido.')
            limite = 750000 if urlparse(self.path).path == '/me/photo' else 65536
            if not 0 <= tamanho <= limite:
                raise ErroAPI('Pedido muito grande.', 413)
            try:
                dados = json.loads(self.rfile.read(tamanho)) if tamanho else {}
            except (ValueError, UnicodeDecodeError):
                raise ErroAPI('JSON inválido.')
            if not isinstance(dados, dict):
                raise ErroAPI('Pedido inválido.')
            auth = self.headers.get('Authorization', '')
            token = auth[7:] if auth.startswith('Bearer ') else ''
            status, resultado = self.aplicacao.executar(
                self.command, urlparse(self.path).path, dados, token)
            self.responder(status, resultado)
        except ErroAPI as erro:
            self.responder(erro.status, {'erro': erro.mensagem})
        except Exception:
            self.responder(500, {'erro': 'Erro interno ao acessar o banco.'})

    do_GET = atender
    do_POST = atender
    do_PUT = atender
    do_DELETE = atender


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Servidor e administrador da AutoPrime')
    parser.add_argument('--criar-admin', metavar='EMAIL', help='Criar administrador ou redefinir a senha de uma conta como administrador')
    args = parser.parse_args()
    banco = Path(__file__).with_name('autoprime.db')
    aplicacao = Aplicacao(banco)
    if args.criar_admin:
        try:
            senha = getpass.getpass('Nova senha (mínimo 8 caracteres): ')
            repetir = getpass.getpass('Repita a senha: ')
            if senha != repetir:
                raise ErroAPI('As senhas não são iguais.')
            aplicacao.criar_admin(args.criar_admin, senha)
            print('Administrador configurado. Entre no site com este e-mail e senha.')
        except (ErroAPI, EOFError, KeyboardInterrupt) as erro:
            parser.exit(1, f'Não foi possível configurar: {erro}\n')
    else:
        Servidor.aplicacao = aplicacao
        host = '0.0.0.0' if os.getenv('DATABASE_URL') else '127.0.0.1'
        porta = int(os.getenv('PORT', '5000'))
        print(f"Banco: {'PostgreSQL' if os.getenv('DATABASE_URL') else banco}")
        print(f'Servidor: http://{host}:{porta}/health')
        ThreadingHTTPServer((host, porta), Servidor).serve_forever()
