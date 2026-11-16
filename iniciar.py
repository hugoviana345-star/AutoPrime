"""Coloque na pasta app, ao lado de pubspec.yaml. Execute: py iniciar.py"""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time
from urllib.request import urlopen

PASTA = Path(__file__).resolve().parent
SERVIDOR = PASTA / 'lib' / 'backend' / 'servidor.py'


def servidor_pronto():
    try:
        with urlopen('http://127.0.0.1:5000/health', timeout=1) as resposta:
            dados = json.load(resposta)
        return isinstance(dados, dict) and dados.get('mensagem') == 'Servidor AutoPrime funcionando.'
    except (OSError, ValueError):
        return False


def porta_ocupada():
    try:
        with socket.create_connection(('127.0.0.1', 5000), timeout=1):
            return True
    except OSError:
        return False


def abrir(comando):
    opcoes = {'cwd': str(PASTA)}
    if os.name == 'nt':
        opcoes['creationflags'] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        opcoes['start_new_session'] = True
    return subprocess.Popen(comando, **opcoes)


def parar(processo, flutter=False):
    if processo is None or processo.poll() is not None:
        return
    try:
        if flutter:
            if os.name == 'nt':
                processo.send_signal(signal.CTRL_BREAK_EVENT)
            else:
                os.killpg(processo.pid, signal.SIGTERM)
        else:
            processo.terminate()
        processo.wait(timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        if flutter and os.name == 'nt':
            # Encerra somente a arvore do Flutter aberto por este arquivo.
            subprocess.run(['taskkill', '/PID', str(processo.pid), '/T', '/F'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif flutter and os.name != 'nt':
            try:
                os.killpg(processo.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        else:
            processo.kill()
        try:
            processo.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass


def main():
    banco = site = None
    try:
        if not (PASTA / 'pubspec.yaml').is_file() or not SERVIDOR.is_file():
            raise RuntimeError('Coloque iniciar.py na pasta app, ao lado de pubspec.yaml. Confira lib/backend/servidor.py.')
        if not shutil.which('flutter'):
            raise RuntimeError('Flutter nao encontrado. Abra o terminal em que flutter run funciona.')
        if servidor_pronto():
            print('Servidor AutoPrime ja aberto; vou utilizar esse servidor.', flush=True)
            print('Se voce editou servidor.py, pare o servidor antigo antes de executar este comando.', flush=True)
        else:
            if porta_ocupada():
                raise RuntimeError('A porta 5000 esta ocupada por um servidor que nao respondeu como AutoPrime. Confira o terminal desse servidor.')
            print('Iniciando o servidor Python...', flush=True)
            banco = abrir([sys.executable, '-u', str(SERVIDOR)])
            prazo = time.monotonic() + 15
            while not servidor_pronto():
                if banco.poll() is not None:
                    raise RuntimeError('O servidor Python encerrou. Confira a mensagem acima.')
                if time.monotonic() > prazo:
                    raise RuntimeError('O servidor nao respondeu em 15 segundos. Confira a mensagem acima.')
                time.sleep(0.3)
        print('Iniciando o Flutter no Chrome. Para encerrar, pressione q no terminal.', flush=True)
        comando = ['flutter', 'run', '-d', 'chrome', '--web-port=3000']
        if os.name == 'nt':
            comando = ['cmd.exe', '/d', '/c'] + comando
        site = abrir(comando)
        while site.poll() is None:
            if banco is not None and banco.poll() is not None:
                raise RuntimeError('O servidor Python parou. Confira a mensagem acima.')
            time.sleep(0.3)
        return site.returncode
    except KeyboardInterrupt:
        print('\nEncerrando AutoPrime...', flush=True)
        return 0
    except (OSError, RuntimeError) as erro:
        print(f'\nNao foi possivel iniciar: {erro}', flush=True)
        return 1
    finally:
        parar(site, flutter=True)
        parar(banco)


if __name__ == '__main__':
    sys.exit(main())
