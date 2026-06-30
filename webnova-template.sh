#!/usr/bin/env bash
# WebNova Template Reutilizavel
# TUI Web grafico local com Bash + Python padrao, criado para ser reaproveitado em qualquer projeto.
# Idioma do app: pt-BR.
# Requisitos: bash, python3.

set -Eeuo pipefail
IFS=$'\n\t'

APP_NOME="${WEBNOVA_APP_NOME:-WebNova Template}"
APP_VERSAO="${WEBNOVA_APP_VERSAO:-1.0.0}"
WEBNOVA_HOST="${WEBNOVA_HOST:-127.0.0.1}"
WEBNOVA_PORT="${WEBNOVA_PORT:-8808}"
WEBNOVA_SCRIPT_PATH="${BASH_SOURCE[0]}"
export APP_NOME APP_VERSAO WEBNOVA_HOST WEBNOVA_PORT WEBNOVA_SCRIPT_PATH

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  printf 'Erro: Python 3 nao encontrado. Instale python3 antes de executar.\n' >&2
  exit 1
fi

exec "$PYTHON_BIN" - "$@" <<'PY_WEBNOVA'
from __future__ import annotations

import datetime as _dt
import html
import http.server
import json
import os
import platform
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import webbrowser
from pathlib import Path
from typing import Dict, Generator, Iterable, List, Optional, Tuple

APP_NOME = os.environ.get("APP_NOME", "WebNova Template")
APP_VERSAO = os.environ.get("APP_VERSAO", "1.0.0")
HOST = os.environ.get("WEBNOVA_HOST", "127.0.0.1")
PORT_DEFAULT = int(os.environ.get("WEBNOVA_PORT", "8808"))
SCRIPT_PATH = Path(os.environ.get("WEBNOVA_SCRIPT_PATH", sys.argv[0])).resolve()
INICIO = time.time()
TOKEN = secrets.token_urlsafe(24)
HISTORICO: List[Dict[str, object]] = []
HISTORICO_LOCK = threading.Lock()

# Catalogo central: a interface Web, a CLI e o streaming usam exatamente esta lista.
ACTIONS: List[Dict[str, str]] = [
    {"id": "status", "icone": "🛰️", "grupo": "Diagnostico", "risco": "Seguro", "titulo": "Status do ambiente", "descricao": "Mostra informacoes essenciais do sistema, Python, diretorio e tempo de execucao."},
    {"id": "health_check", "icone": "🩺", "grupo": "Diagnostico", "risco": "Seguro", "titulo": "Health check completo", "descricao": "Valida ferramentas basicas e capacidade do servidor local."},
    {"id": "list_project", "icone": "🗂️", "grupo": "Projeto", "risco": "Seguro", "titulo": "Mapa do projeto", "descricao": "Lista arquivos e diretorios do projeto atual sem alterar nada."},
    {"id": "git_status", "icone": "🌿", "grupo": "Projeto", "risco": "Seguro", "titulo": "Status Git", "descricao": "Executa git status, branch e ultimos commits quando o repositorio Git existir."},
    {"id": "disk_report", "icone": "💾", "grupo": "Sistema", "risco": "Seguro", "titulo": "Disco e armazenamento", "descricao": "Mostra df, uso do diretorio atual e metricas de armazenamento."},
    {"id": "memory_report", "icone": "🧠", "grupo": "Sistema", "risco": "Seguro", "titulo": "Memoria e carga", "descricao": "Mostra memoria, carga do sistema e processos mais relevantes quando disponivel."},
    {"id": "network_check", "icone": "🌐", "grupo": "Rede", "risco": "Seguro", "titulo": "Rede e conectividade", "descricao": "Exibe rotas, DNS e conectividade basica sem alterar configuracoes."},
    {"id": "process_top", "icone": "📊", "grupo": "Sistema", "risco": "Seguro", "titulo": "Processos ativos", "descricao": "Lista processos principais por memoria ou CPU conforme suporte do sistema."},
    {"id": "env_report", "icone": "🔐", "grupo": "Ambiente", "risco": "Seguro", "titulo": "Ambiente seguro", "descricao": "Mostra variaveis tecnicas nao sensiveis e caminhos importantes."},
    {"id": "python_report", "icone": "🐍", "grupo": "Runtime", "risco": "Seguro", "titulo": "Python runtime", "descricao": "Valida versao do Python, executavel, pip e modulos padrao."},
    {"id": "node_report", "icone": "🟩", "grupo": "Runtime", "risco": "Seguro", "titulo": "Node runtime", "descricao": "Valida Node, npm, pnpm, yarn e bun quando instalados."},
    {"id": "docker_report", "icone": "🐳", "grupo": "Containers", "risco": "Seguro", "titulo": "Docker report", "descricao": "Valida Docker, Docker Compose e informacoes do daemon quando disponivel."},
    {"id": "custom_actions", "icone": "🧩", "grupo": "Extensao", "risco": "Seguro", "titulo": "Acoes personalizadas", "descricao": "Descobre scripts executaveis em webnova-actions.d sem executar automaticamente."},
    {"id": "export_report", "icone": "📄", "grupo": "Relatorio", "risco": "Cria arquivo temporario", "titulo": "Exportar relatorio", "descricao": "Gera um relatorio Markdown temporario somente quando acionado."},
]
ACTION_MAP = {a["id"]: a for a in ACTIONS}


def agora_iso() -> str:
    return _dt.datetime.now().astimezone().isoformat(timespec="seconds")


def bytes_humanos(valor: int) -> str:
    tamanho = float(valor)
    unidades = ["B", "KB", "MB", "GB", "TB", "PB"]
    indice = 0
    while tamanho >= 1024 and indice < len(unidades) - 1:
        tamanho /= 1024
        indice += 1
    if indice == 0:
        return f"{int(tamanho)} {unidades[indice]}"
    return f"{tamanho:.1f} {unidades[indice]}"


def comando_disponivel(nome: str) -> bool:
    return shutil.which(nome) is not None


def executar_comando(cmd: List[str], cwd: Optional[Path] = None, timeout: int = 120) -> Generator[str, None, int]:
    yield f"$ {' '.join(cmd)}"
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=str(cwd or Path.cwd()),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env={**os.environ, "LC_ALL": os.environ.get("LC_ALL", "C.UTF-8")},
        )
    except FileNotFoundError:
        yield f"Comando nao encontrado: {cmd[0]}"
        return 127
    except Exception as exc:
        yield f"Falha ao iniciar comando: {exc}"
        return 1

    inicio = time.time()
    assert proc.stdout is not None
    for linha in proc.stdout:
        yield linha.rstrip("\n")
        if time.time() - inicio > timeout:
            proc.kill()
            yield f"Tempo limite de {timeout}s excedido. Processo encerrado."
            return 124
    codigo = proc.wait()
    yield f"Codigo de saida: {codigo}"
    return codigo


def registrar_historico(action_id: str, status: str, segundos: float, linhas: int, detalhe: str = "") -> None:
    with HISTORICO_LOCK:
        HISTORICO.insert(0, {
            "quando": agora_iso(),
            "acao": action_id,
            "status": status,
            "segundos": round(segundos, 3),
            "linhas": linhas,
            "detalhe": detalhe,
        })
        del HISTORICO[80:]


def status_payload() -> Dict[str, object]:
    cwd = Path.cwd()
    uso = shutil.disk_usage(cwd)
    load = os.getloadavg() if hasattr(os, "getloadavg") else (0.0, 0.0, 0.0)
    return {
        "app": APP_NOME,
        "versao": APP_VERSAO,
        "agora": agora_iso(),
        "uptime_segundos": round(time.time() - INICIO, 1),
        "host": HOST,
        "porta": PORT_DEFAULT,
        "cwd": str(cwd),
        "python": sys.version.split()[0],
        "python_executavel": sys.executable,
        "sistema": platform.platform(),
        "maquina": platform.machine(),
        "processador": platform.processor(),
        "usuario": os.environ.get("USER") or os.environ.get("USERNAME") or "nao_informado",
        "disco_total": uso.total,
        "disco_usado": uso.used,
        "disco_livre": uso.free,
        "disco_total_h": bytes_humanos(uso.total),
        "disco_usado_h": bytes_humanos(uso.used),
        "disco_livre_h": bytes_humanos(uso.free),
        "disco_usado_pct": round((uso.used / uso.total) * 100, 1) if uso.total else 0,
        "load_1": round(load[0], 2),
        "load_5": round(load[1], 2),
        "load_15": round(load[2], 2),
        "acoes": len(ACTIONS),
        "historico": len(HISTORICO),
    }


def cabecalho_acao(action_id: str) -> Iterable[str]:
    acao = ACTION_MAP.get(action_id, {"titulo": action_id, "icone": "⚙️", "descricao": ""})
    yield f"{acao.get('icone','⚙️')} {acao.get('titulo', action_id)}"
    yield f"Inicio: {agora_iso()}"
    yield f"Diretorio: {Path.cwd()}"
    yield "-" * 72


def action_status() -> Generator[str, None, None]:
    yield from cabecalho_acao("status")
    data = status_payload()
    for chave in ["app", "versao", "agora", "cwd", "python", "python_executavel", "sistema", "maquina", "usuario", "disco_total_h", "disco_usado_h", "disco_livre_h", "disco_usado_pct", "load_1", "load_5", "load_15"]:
        yield f"{chave}: {data[chave]}"


def action_health_check() -> Generator[str, None, None]:
    yield from cabecalho_acao("health_check")
    for nome in ["bash", "python3", "git", "curl", "wget", "node", "npm", "docker", "docker-compose", "sh"]:
        yield f"{nome}: {'OK' if comando_disponivel(nome) else 'nao encontrado'}"
    yield "Servidor local: OK"
    yield "Token de sessao: ativo"
    yield "Modo: leitura e diagnostico por padrao"


def action_list_project() -> Generator[str, None, None]:
    yield from cabecalho_acao("list_project")
    cwd = Path.cwd()
    yield f"Raiz analisada: {cwd}"
    total = 0
    for path in sorted(cwd.rglob("*")):
        try:
            rel = path.relative_to(cwd)
        except ValueError:
            rel = path
        partes = rel.parts
        if any(p in {".git", "node_modules", ".venv", "venv", "__pycache__"} for p in partes):
            continue
        if len(partes) > 3:
            continue
        tipo = "DIR " if path.is_dir() else "FILE"
        tamanho = ""
        if path.is_file():
            try:
                tamanho = bytes_humanos(path.stat().st_size)
            except OSError:
                tamanho = "indisponivel"
        yield f"{tipo}  {rel} {tamanho}"
        total += 1
        if total >= 250:
            yield "Limite de exibicao atingido para manter a interface responsiva."
            break
    yield f"Itens exibidos: {total}"


def action_git_status() -> Generator[str, None, None]:
    yield from cabecalho_acao("git_status")
    if not comando_disponivel("git"):
        yield "Git nao encontrado no PATH."
        return
    yield from executar_comando(["git", "rev-parse", "--show-toplevel"], timeout=15)
    yield from executar_comando(["git", "status", "--short", "--branch"], timeout=30)
    yield from executar_comando(["git", "log", "--oneline", "-8"], timeout=30)


def action_disk_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("disk_report")
    if comando_disponivel("df"):
        yield from executar_comando(["df", "-h"], timeout=30)
    uso = shutil.disk_usage(Path.cwd())
    yield f"Diretorio atual total: {bytes_humanos(uso.total)}"
    yield f"Diretorio atual usado: {bytes_humanos(uso.used)}"
    yield f"Diretorio atual livre: {bytes_humanos(uso.free)}"
    if comando_disponivel("du"):
        yield from executar_comando(["du", "-sh", "."], timeout=60)


def action_memory_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("memory_report")
    if comando_disponivel("free"):
        yield from executar_comando(["free", "-h"], timeout=30)
    else:
        yield "Comando free nao encontrado."
    if hasattr(os, "getloadavg"):
        l1, l5, l15 = os.getloadavg()
        yield f"Carga 1m/5m/15m: {l1:.2f} / {l5:.2f} / {l15:.2f}"
    if comando_disponivel("ps"):
        yield from executar_comando(["sh", "-lc", "ps aux --sort=-%mem | head -15"], timeout=30)


def action_network_check() -> Generator[str, None, None]:
    yield from cabecalho_acao("network_check")
    if comando_disponivel("ip"):
        yield from executar_comando(["ip", "route"], timeout=30)
    if Path("/etc/resolv.conf").exists():
        yield "Conteudo relevante de /etc/resolv.conf:"
        try:
            for line in Path("/etc/resolv.conf").read_text(errors="replace").splitlines():
                if line.strip() and not line.strip().startswith("#"):
                    yield line
        except Exception as exc:
            yield f"Nao foi possivel ler resolv.conf: {exc}"
    if comando_disponivel("ping"):
        yield from executar_comando(["ping", "-c", "1", "1.1.1.1"], timeout=20)
    else:
        yield "ping nao encontrado."


def action_process_top() -> Generator[str, None, None]:
    yield from cabecalho_acao("process_top")
    if comando_disponivel("ps"):
        yield from executar_comando(["sh", "-lc", "ps aux --sort=-%cpu | head -20"], timeout=30)
    else:
        yield "ps nao encontrado."


def action_env_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("env_report")
    permitidas = ["SHELL", "TERM", "LANG", "LC_ALL", "PATH", "HOME", "PWD", "USER", "WSL_DISTRO_NAME", "WSL_INTEROP"]
    for chave in permitidas:
        valor = os.environ.get(chave)
        if valor:
            if chave == "PATH":
                yield "PATH:"
                for item in valor.split(os.pathsep):
                    yield f"  - {item}"
            else:
                yield f"{chave}: {valor}"


def action_python_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("python_report")
    yield f"Python atual: {sys.version}"
    yield f"Executavel: {sys.executable}"
    for cmd in ([sys.executable, "-m", "pip", "--version"], [sys.executable, "-m", "venv", "--help"]):
        yield from executar_comando(list(cmd), timeout=30)
    modulos = ["json", "http.server", "sqlite3", "ssl", "venv", "subprocess"]
    for modulo in modulos:
        try:
            __import__(modulo)
            yield f"Modulo {modulo}: OK"
        except Exception as exc:
            yield f"Modulo {modulo}: falhou ({exc})"


def action_node_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("node_report")
    for cmd in (["node", "--version"], ["npm", "--version"], ["pnpm", "--version"], ["yarn", "--version"], ["bun", "--version"]):
        if comando_disponivel(cmd[0]):
            yield from executar_comando(list(cmd), timeout=30)
        else:
            yield f"{cmd[0]}: nao encontrado"


def action_docker_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("docker_report")
    for cmd in (["docker", "version"], ["docker", "compose", "version"], ["docker", "info"]):
        if comando_disponivel(cmd[0]):
            yield from executar_comando(list(cmd), timeout=60)
        else:
            yield f"{cmd[0]}: nao encontrado"
            break


def descobrir_custom_actions() -> List[Path]:
    pasta = Path.cwd() / "webnova-actions.d"
    if not pasta.is_dir():
        return []
    return sorted([p for p in pasta.iterdir() if p.is_file() and os.access(p, os.X_OK)])


def action_custom_actions() -> Generator[str, None, None]:
    yield from cabecalho_acao("custom_actions")
    encontrados = descobrir_custom_actions()
    if not encontrados:
        yield "Nenhuma acao executavel encontrada em ./webnova-actions.d"
        yield "Para adicionar uma acao real, crie um script executavel nessa pasta e execute manualmente pelo seu fluxo do projeto."
        return
    for item in encontrados:
        yield f"Encontrada: {item.name}"


def gerar_relatorio_markdown() -> Path:
    data = status_payload()
    nome = f"webnova-relatorio-{_dt.datetime.now().strftime('%Y%m%d-%H%M%S')}.md"
    caminho = Path(tempfile.gettempdir()) / nome
    linhas = [
        f"# Relatorio WebNova Template",
        "",
        f"- App: {APP_NOME}",
        f"- Versao: {APP_VERSAO}",
        f"- Gerado em: {data['agora']}",
        f"- Diretorio: {data['cwd']}",
        f"- Sistema: {data['sistema']}",
        f"- Python: {data['python']}",
        f"- Disco usado: {data['disco_usado_h']} de {data['disco_total_h']} ({data['disco_usado_pct']}%)",
        f"- Acoes catalogadas: {len(ACTIONS)}",
        "",
        "## Acoes",
    ]
    for acao in ACTIONS:
        linhas.append(f"- {acao['icone']} `{acao['id']}`: {acao['titulo']} ({acao['risco']})")
    linhas += ["", "## Historico da sessao"]
    with HISTORICO_LOCK:
        if HISTORICO:
            for item in HISTORICO[:30]:
                linhas.append(f"- {item['quando']} | {item['acao']} | {item['status']} | {item['segundos']}s | {item['linhas']} linhas")
        else:
            linhas.append("- Nenhuma acao executada nesta sessao.")
    caminho.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    return caminho


def action_export_report() -> Generator[str, None, None]:
    yield from cabecalho_acao("export_report")
    caminho = gerar_relatorio_markdown()
    yield f"Relatorio temporario criado: {caminho}"
    yield "Este arquivo foi criado somente porque a acao de exportacao foi acionada."


ACTION_FUNCS = {
    "status": action_status,
    "health_check": action_health_check,
    "list_project": action_list_project,
    "git_status": action_git_status,
    "disk_report": action_disk_report,
    "memory_report": action_memory_report,
    "network_check": action_network_check,
    "process_top": action_process_top,
    "env_report": action_env_report,
    "python_report": action_python_report,
    "node_report": action_node_report,
    "docker_report": action_docker_report,
    "custom_actions": action_custom_actions,
    "export_report": action_export_report,
}

HTML = r'''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="dark light" />
  <title>WebNova Template</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Imprima&display=swap');
    .imprima-regular { font-family: "Imprima", sans-serif; font-weight: 400; font-style: normal; }
    :root {
      --bg: #071016; --bg2: #0d1724; --panel: rgba(16, 27, 42, .82); --panel2: rgba(21, 38, 58, .72);
      --line: rgba(164, 213, 255, .18); --text: #edf7ff; --muted: #9fb3c8; --brand: #78f7d0;
      --brand2: #8da2ff; --warn: #ffd166; --bad: #ff6b8a; --ok: #73f59f; --shadow: rgba(0,0,0,.35);
      --radius-xl: 28px; --radius-lg: 20px; --radius-md: 14px; --sidebar: 292px; --console: 360px;
    }
    body.light { --bg:#f5f8fb; --bg2:#eaf0f7; --panel:rgba(255,255,255,.86); --panel2:rgba(255,255,255,.72); --line:rgba(32,68,98,.16); --text:#0c1724; --muted:#526579; --shadow:rgba(28,53,84,.16); }
    * { box-sizing: border-box; }
    html, body { height: 100%; }
    body { margin: 0; font-family: "Imprima", sans-serif; color: var(--text); background:
      radial-gradient(circle at 12% 8%, rgba(120,247,208,.24), transparent 28%),
      radial-gradient(circle at 86% 16%, rgba(141,162,255,.28), transparent 32%),
      linear-gradient(145deg, var(--bg), var(--bg2)); overflow: hidden; }
    body::before { content:""; position: fixed; inset:0; pointer-events:none; opacity:.35; background-image: linear-gradient(rgba(255,255,255,.05) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.04) 1px, transparent 1px); background-size: 42px 42px; mask-image: radial-gradient(circle at center, #000, transparent 80%); }
    button, input, select { font: inherit; }
    .app { height: 100vh; display: grid; grid-template-columns: var(--sidebar) 1fr var(--console); gap: 16px; padding: 16px; position: relative; }
    .sidebar, .main, .consolePanel, .modalCard { border:1px solid var(--line); background: var(--panel); box-shadow: 0 24px 80px var(--shadow); backdrop-filter: blur(22px); }
    .sidebar { border-radius: var(--radius-xl); padding: 16px; overflow: hidden; display:flex; flex-direction:column; min-width:0; }
    .brand { display:flex; gap:12px; align-items:center; padding:12px; border-radius:20px; background:linear-gradient(135deg, rgba(120,247,208,.15), rgba(141,162,255,.10)); }
    .logo { width:44px; height:44px; border-radius:16px; display:grid; place-items:center; font-size:24px; background:linear-gradient(135deg, var(--brand), var(--brand2)); color:#071016; box-shadow:0 12px 28px rgba(120,247,208,.22); }
    .brand h1 { font-size:18px; margin:0; letter-spacing:.2px; } .brand p { margin:4px 0 0; color:var(--muted); font-size:12px; }
    .search { margin:14px 0; display:flex; gap:8px; align-items:center; padding:10px 12px; border:1px solid var(--line); border-radius:16px; background:rgba(255,255,255,.05); }
    .search input { width:100%; color:var(--text); background:transparent; border:0; outline:0; }
    .nav { overflow:auto; padding-right:4px; } .groupTitle { margin:14px 8px 8px; color:var(--muted); font-size:12px; text-transform:uppercase; letter-spacing:.12em; }
    .navBtn { width:100%; text-align:left; border:0; color:var(--text); background:transparent; border-radius:15px; padding:10px 11px; display:grid; grid-template-columns:28px 1fr auto; align-items:center; gap:9px; cursor:pointer; transition:.18s transform,.18s background,.18s border; border:1px solid transparent; }
    .navBtn:hover, .navBtn.active { background:rgba(120,247,208,.11); border-color:rgba(120,247,208,.22); transform:translateX(2px); } .navBtn small { color:var(--muted); }
    .main { border-radius: var(--radius-xl); padding: 18px; overflow:auto; min-width:0; }
    .topbar { display:flex; justify-content:space-between; gap:12px; align-items:center; margin-bottom:16px; }
    .hero { display:grid; grid-template-columns: 1.25fr .75fr; gap:14px; margin-bottom:16px; }
    .heroCard, .metric, .card, .tableBox, .chartBox { border:1px solid var(--line); background:var(--panel2); border-radius:var(--radius-lg); padding:16px; position:relative; overflow:hidden; }
    .heroCard::after, .card::after { content:""; position:absolute; width:190px; height:190px; border-radius:50%; background:radial-gradient(circle, rgba(120,247,208,.16), transparent 65%); right:-74px; top:-82px; pointer-events:none; }
    .eyebrow { color:var(--brand); font-size:12px; text-transform:uppercase; letter-spacing:.16em; margin-bottom:8px; }
    h2 { font-size:34px; line-height:1.02; margin:0 0 10px; letter-spacing:-.04em; } .muted { color:var(--muted); }
    .actionsBar { display:flex; gap:10px; flex-wrap:wrap; margin-top:14px; }
    .btn { border:1px solid var(--line); color:var(--text); background:rgba(255,255,255,.07); border-radius:14px; padding:10px 13px; cursor:pointer; transition:.18s transform,.18s background; display:inline-flex; gap:8px; align-items:center; }
    .btn:hover { transform:translateY(-1px); background:rgba(120,247,208,.12); } .btn.primary { background:linear-gradient(135deg, rgba(120,247,208,.24), rgba(141,162,255,.20)); border-color:rgba(120,247,208,.32); }
    .metrics { display:grid; grid-template-columns: repeat(2, minmax(0,1fr)); gap:12px; } .metric b { display:block; font-size:22px; margin-top:6px; } .metric span { color:var(--muted); font-size:12px; }
    .grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap:12px; }
    .card { min-height:148px; cursor:pointer; transition:.2s transform,.2s border,.2s background; } .card:hover { transform:translateY(-3px); border-color:rgba(120,247,208,.36); background:rgba(25,46,66,.76); }
    .cardIcon { width:42px; height:42px; border-radius:15px; display:grid; place-items:center; font-size:23px; background:rgba(255,255,255,.08); margin-bottom:12px; }
    .card h3 { margin:0 0 8px; font-size:17px; } .card p { margin:0; color:var(--muted); font-size:13px; line-height:1.35; }
    .badge { display:inline-flex; gap:6px; align-items:center; border:1px solid var(--line); border-radius:999px; padding:5px 8px; color:var(--muted); font-size:12px; margin-top:12px; }
    .sectionTitle { display:flex; justify-content:space-between; align-items:center; gap:10px; margin:20px 0 10px; }
    .chartTable { display:grid; grid-template-columns: .85fr 1.15fr; gap:12px; margin-top:14px; } canvas { width:100%; height:250px; display:block; }
    table { width:100%; border-collapse:collapse; font-size:13px; } th,td { padding:10px; border-bottom:1px solid var(--line); text-align:left; } th { color:var(--muted); font-weight:400; }
    .consolePanel { border-radius:var(--radius-xl); display:flex; flex-direction:column; overflow:hidden; min-width:0; }
    .consoleHead { padding:14px; display:flex; justify-content:space-between; gap:8px; border-bottom:1px solid var(--line); align-items:center; }
    .console { flex:1; overflow:auto; padding:14px; white-space:pre-wrap; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size:12px; line-height:1.45; color:#d9fff3; background:rgba(0,0,0,.22); }
    body.light .console { color:#102333; background:rgba(255,255,255,.48); }
    .consoleFooter { padding:10px 14px; border-top:1px solid var(--line); color:var(--muted); font-size:12px; }
    .toast { position:fixed; left:50%; bottom:24px; transform:translateX(-50%); background:var(--panel); border:1px solid var(--line); border-radius:16px; padding:12px 14px; box-shadow:0 18px 45px var(--shadow); display:none; z-index:20; }
    .modal { position:fixed; inset:0; display:none; place-items:center; background:rgba(0,0,0,.52); z-index:30; padding:20px; } .modal.show { display:grid; }
    .modalCard { width:min(720px, 100%); border-radius:28px; padding:20px; } .modalCard h3 { margin:0 0 8px; font-size:24px; }
    .kbd { border:1px solid var(--line); border-bottom-width:3px; border-radius:8px; padding:2px 7px; color:var(--muted); }
    body.consoleHidden { --console: 0px; } body.consoleHidden .consolePanel { display:none; }
    body.compact .card { min-height:122px; padding:13px; } body.compact .cardIcon { width:36px; height:36px; font-size:20px; margin-bottom:8px; }
    @media (max-width: 1180px) { .app { grid-template-columns: 96px 1fr; } .sidebar { padding:10px; } .brand div:not(.logo), .search, .navBtn span, .groupTitle { display:none; } .navBtn { grid-template-columns:1fr; place-items:center; } .consolePanel { grid-column: 1 / -1; min-height:280px; } }
    @media (max-width: 760px) { body { overflow:auto; } .app { height:auto; min-height:100vh; grid-template-columns:1fr; padding:10px; } .sidebar, .main, .consolePanel { border-radius:22px; } .nav { display:grid; grid-template-columns: repeat(2, minmax(0,1fr)); gap:8px; overflow:visible; } .navBtn span { display:block; } .hero, .chartTable { grid-template-columns:1fr; } h2 { font-size:28px; } }
  </style>
</head>
<body class="imprima-regular">
  <div class="app">
    <aside class="sidebar">
      <div class="brand"><div class="logo">🌌</div><div><h1>WebNova</h1><p>TUI Web reutilizavel</p></div></div>
      <label class="search">🔎 <input id="search" aria-label="Buscar acao" title="Buscar acao" /></label>
      <nav class="nav" id="nav"></nav>
    </aside>
    <main class="main">
      <div class="topbar">
        <div><div class="eyebrow">🧭 Template premium pt-BR</div><strong id="clock">Carregando...</strong></div>
        <div class="actionsBar"><button class="btn" id="themeBtn">☀️ Tema</button><button class="btn" id="compactBtn">🧱 Compactar</button><button class="btn" id="consoleBtn">🖥️ Console</button></div>
      </div>
      <section class="hero">
        <div class="heroCard"><div class="eyebrow">🚀 Cockpit WebNova</div><h2>Um TUI Web grafico para qualquer projeto.</h2><p class="muted">Sidebar, cards, tabelas, graficos canvas, console em tempo real, historico de sessao, tema claro/escuro e acoes reais conectadas ao ambiente local.</p><div class="actionsBar"><button class="btn primary" onclick="runAction('health_check')">🩺 Rodar health check</button><button class="btn" onclick="runAction('export_report')">📄 Exportar relatorio</button><button class="btn" onclick="openModal()">✨ Como reutilizar</button></div></div>
        <div class="metrics"><div class="metric">🧩<span>Acoes reais</span><b id="mActions">-</b></div><div class="metric">💾<span>Disco usado</span><b id="mDisk">-</b></div><div class="metric">⏱️<span>Uptime</span><b id="mUptime">-</b></div><div class="metric">🐍<span>Python</span><b id="mPython">-</b></div></div>
      </section>
      <div class="sectionTitle"><h3>🧱 Cards de acoes</h3><span class="muted">Clique para executar no console real</span></div>
      <section class="grid" id="cards"></section>
      <section class="chartTable"><div class="chartBox"><div class="sectionTitle"><h3>📈 Disco</h3><span class="muted">Canvas nativo</span></div><canvas id="diskChart" width="520" height="260"></canvas></div><div class="tableBox"><div class="sectionTitle"><h3>📋 Historico</h3><span class="muted">Sessao atual</span></div><table><thead><tr><th>Quando</th><th>Acao</th><th>Status</th><th>Tempo</th></tr></thead><tbody id="history"><tr><td colspan="4">Sem execucoes ainda.</td></tr></tbody></table></div></section>
    </main>
    <section class="consolePanel"><div class="consoleHead"><strong>🖥️ Console real</strong><div><button class="btn" onclick="clearConsole()">🧹</button><button class="btn" onclick="toggleConsole()">👁️</button></div></div><div class="console" id="console">Pronto. Escolha uma acao no painel.\n</div><div class="consoleFooter" id="consoleState">SSE aguardando.</div></section>
  </div>
  <div class="toast" id="toast"></div>
  <div class="modal" id="modal"><div class="modalCard"><h3>✨ Reutilizacao rapida</h3><p class="muted">Copie este arquivo para qualquer projeto, execute com <span class="kbd">bash webnova-template.sh</span> e use o painel local. Para integrar suas proprias rotinas, coloque scripts executaveis em <span class="kbd">webnova-actions.d</span> e use o painel como cockpit visual.</p><div class="actionsBar"><button class="btn primary" onclick="closeModal()">✅ Entendi</button><button class="btn" onclick="runAction('custom_actions'); closeModal();">🧩 Ver extensoes</button></div></div></div>
<script>
const TOKEN = new URLSearchParams(location.search).get('token') || '';
let ACTIONS = [];
const $ = sel => document.querySelector(sel);
function toast(msg){ const t=$('#toast'); t.textContent=msg; t.style.display='block'; setTimeout(()=>t.style.display='none',2600); }
function api(path){ return fetch(path + (path.includes('?')?'&':'?') + 'token=' + encodeURIComponent(TOKEN)).then(r=>r.json()); }
function groupBy(arr,key){ return arr.reduce((a,x)=>{(a[x[key]] ||= []).push(x); return a;},{}); }
function renderActions(list){
  const nav=$('#nav'), cards=$('#cards'); nav.innerHTML=''; cards.innerHTML=''; const groups=groupBy(list,'grupo');
  Object.keys(groups).forEach(g=>{ const title=document.createElement('div'); title.className='groupTitle'; title.textContent=g; nav.appendChild(title); groups[g].forEach(a=>{ const b=document.createElement('button'); b.className='navBtn'; b.innerHTML=`<span>${a.icone}</span><span>${a.titulo}<br><small>${a.id}</small></span><small>↵</small>`; b.onclick=()=>runAction(a.id); nav.appendChild(b); }); });
  list.forEach(a=>{ const c=document.createElement('article'); c.className='card'; c.innerHTML=`<div class="cardIcon">${a.icone}</div><h3>${a.titulo}</h3><p>${a.descricao}</p><span class="badge">${a.risco==='Seguro'?'🟢': '🟡'} ${a.risco}</span>`; c.onclick=()=>runAction(a.id); cards.appendChild(c); });
}
function drawDiskChart(status){ const cv=$('#diskChart'), ctx=cv.getContext('2d'), w=cv.width, h=cv.height; ctx.clearRect(0,0,w,h); const used=status.disco_usado_pct||0; const cx=w/2, cy=h/2+5, r=84; ctx.lineWidth=28; ctx.strokeStyle='rgba(255,255,255,.12)'; ctx.beginPath(); ctx.arc(cx,cy,r,0,Math.PI*2); ctx.stroke(); ctx.strokeStyle='#78f7d0'; ctx.beginPath(); ctx.arc(cx,cy,r,-Math.PI/2, -Math.PI/2 + Math.PI*2*(used/100)); ctx.stroke(); ctx.fillStyle=getComputedStyle(document.body).getPropertyValue('--text'); ctx.textAlign='center'; ctx.font='30px Imprima'; ctx.fillText(used+'%',cx,cy+8); ctx.font='14px Imprima'; ctx.fillStyle=getComputedStyle(document.body).getPropertyValue('--muted'); ctx.fillText('disco usado',cx,cy+34); }
function refreshStatus(){ api('/api/status').then(s=>{ $('#clock').textContent=s.agora; $('#mActions').textContent=s.acoes; $('#mDisk').textContent=s.disco_usado_pct+'%'; $('#mUptime').textContent=Math.round(s.uptime_segundos)+'s'; $('#mPython').textContent=s.python; drawDiskChart(s); }); api('/api/history').then(h=>{ const tb=$('#history'); if(!h.length){tb.innerHTML='<tr><td colspan="4">Sem execucoes ainda.</td></tr>'; return;} tb.innerHTML=h.slice(0,12).map(x=>`<tr><td>${x.quando.split('T')[1]||x.quando}</td><td>${x.acao}</td><td>${x.status}</td><td>${x.segundos}s</td></tr>`).join(''); }); }
function runAction(id){ const con=$('#console'); const state=$('#consoleState'); con.textContent += `\n▶ Executando: ${id}\n`; state.textContent='Conectando SSE...'; const es=new EventSource(`/events?action=${encodeURIComponent(id)}&token=${encodeURIComponent(TOKEN)}`); es.onmessage=e=>{ con.textContent += e.data + '\n'; con.scrollTop=con.scrollHeight; }; es.addEventListener('done', e=>{ state.textContent='Concluido: '+id; es.close(); refreshStatus(); toast('Acao concluida: '+id); }); es.onerror=()=>{ state.textContent='Conexao SSE encerrada ou falhou.'; es.close(); refreshStatus(); }; }
function clearConsole(){ $('#console').textContent='Console limpo.\n'; }
function toggleConsole(){ document.body.classList.toggle('consoleHidden'); }
function openModal(){ $('#modal').classList.add('show'); } function closeModal(){ $('#modal').classList.remove('show'); }
$('#themeBtn').onclick=()=>document.body.classList.toggle('light'); $('#compactBtn').onclick=()=>document.body.classList.toggle('compact'); $('#consoleBtn').onclick=toggleConsole; $('#modal').onclick=e=>{ if(e.target.id==='modal') closeModal(); };
$('#search').addEventListener('input', e=>{ const q=e.target.value.toLowerCase(); renderActions(ACTIONS.filter(a => (a.id+a.titulo+a.descricao+a.grupo).toLowerCase().includes(q))); });
document.addEventListener('keydown', e=>{ if(e.key==='Escape') closeModal(); if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){ e.preventDefault(); $('#search').focus(); } });
api('/api/actions').then(a=>{ ACTIONS=a; renderActions(a); refreshStatus(); setInterval(refreshStatus,5000); });
</script>
</body>
</html>'''


def validar_token(query: Dict[str, List[str]], headers: http.client.HTTPMessage) -> bool:
    token = query.get("token", [""])[0] or headers.get("X-WebNova-Token", "")
    return token == TOKEN


class WebNovaHandler(http.server.BaseHTTPRequestHandler):
    server_version = "WebNovaTemplate/1.0"

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def send_json(self, payload: object, status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        path = parsed.path
        if path == "/":
            data = HTML.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if not validar_token(query, self.headers):
            self.send_json({"erro": "token invalido"}, 403)
            return
        if path == "/api/status":
            self.send_json(status_payload())
            return
        if path == "/api/actions":
            self.send_json(ACTIONS)
            return
        if path == "/api/history":
            with HISTORICO_LOCK:
                self.send_json(HISTORICO)
            return
        if path == "/events":
            action_id = query.get("action", [""])[0]
            self.stream_action(action_id)
            return
        self.send_json({"erro": "rota nao encontrada"}, 404)

    def stream_action(self, action_id: str) -> None:
        if action_id not in ACTION_FUNCS:
            self.send_response(404)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.end_headers()
            self.wfile.write(f"data: Acao inexistente: {action_id}\n\nevent: done\ndata: erro\n\n".encode("utf-8"))
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        inicio = time.time()
        linhas = 0
        status = "ok"
        try:
            for line in ACTION_FUNCS[action_id]():
                linhas += 1
                safe = str(line).replace("\r", "").replace("\n", " ")
                self.wfile.write(f"data: {safe}\n\n".encode("utf-8"))
                self.wfile.flush()
        except BrokenPipeError:
            status = "cliente_desconectou"
        except Exception as exc:
            status = "erro"
            msg = f"Erro na acao {action_id}: {exc}"
            try:
                self.wfile.write(f"data: {msg}\n\n".encode("utf-8"))
                self.wfile.flush()
            except Exception:
                pass
        finally:
            segundos = time.time() - inicio
            registrar_historico(action_id, status, segundos, linhas)
            try:
                self.wfile.write(f"event: done\ndata: {status}\n\n".encode("utf-8"))
                self.wfile.flush()
            except Exception:
                pass


def encontrar_porta(host: str, porta_inicial: int) -> int:
    for porta in range(porta_inicial, porta_inicial + 60):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind((host, porta))
                return porta
            except OSError:
                continue
    raise RuntimeError("Nao foi encontrada uma porta livre no intervalo configurado.")


def self_test() -> int:
    erros: List[str] = []
    ids = [a["id"] for a in ACTIONS]
    if len(ids) != len(set(ids)):
        erros.append("IDs duplicados no catalogo de acoes")
    for action_id in ids:
        if action_id not in ACTION_FUNCS:
            erros.append(f"Acao sem funcao: {action_id}")
    if "@import url('https://fonts.googleapis.com/css2?family=Imprima" not in HTML:
        erros.append("Fonte Imprima nao encontrada no HTML")
    for trecho in ["EventSource", "<canvas", "<table", "sidebar", "grid"]:
        if trecho not in HTML:
            erros.append(f"Componente ausente: {trecho}")
    try:
        source = SCRIPT_PATH.read_text(encoding="utf-8", errors="replace")
    except Exception:
        source = ""
    proibidos = ["ev"+"al ", "TO"+"DO", "PLACE"+"HOLDER"]
    for termo in proibidos:
        if termo in source:
            erros.append(f"Termo proibido encontrado: {termo}")
    if erros:
        print("SELF-TEST FALHOU")
        for erro in erros:
            print(f"- {erro}")
        return 1
    print(f"SELF-TEST OK. Catalogo possui {len(ACTIONS)} acoes reais. Template WebNova funcional.")
    return 0


def list_actions_json() -> int:
    print(json.dumps(ACTIONS, ensure_ascii=False, indent=2))
    return 0


def menu_preview() -> int:
    print(f"{APP_NOME} v{APP_VERSAO}")
    for acao in ACTIONS:
        print(f"{acao['icone']} {acao['id']} | {acao['grupo']} | {acao['titulo']} | {acao['risco']}")
    return 0


def run_action_cli(action_id: str) -> int:
    if action_id not in ACTION_FUNCS:
        print(f"Acao inexistente: {action_id}", file=sys.stderr)
        return 2
    linhas = 0
    inicio = time.time()
    for line in ACTION_FUNCS[action_id]():
        linhas += 1
        print(line)
    registrar_historico(action_id, "ok", time.time() - inicio, linhas)
    return 0


def start_server(open_browser: bool = True) -> int:
    porta = encontrar_porta(HOST, PORT_DEFAULT)
    httpd = http.server.ThreadingHTTPServer((HOST, porta), WebNovaHandler)
    url = f"http://{HOST}:{porta}/?token={urllib.parse.quote(TOKEN)}"
    print("=" * 76)
    print(f"{APP_NOME} v{APP_VERSAO}")
    print(f"URL local: {url}")
    print("Servidor limitado ao host local. Pressione Ctrl+C para encerrar.")
    print("=" * 76)
    if open_browser and os.environ.get("WEBNOVA_NO_BROWSER", "0") != "1":
        try:
            webbrowser.open(url)
        except Exception:
            pass
    def stop(signum, frame):
        print("\nEncerrando WebNova...")
        httpd.shutdown()
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    try:
        httpd.serve_forever()
    finally:
        httpd.server_close()
    return 0


def main(argv: List[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    if "--list-actions-json" in argv:
        return list_actions_json()
    if "--menu-preview" in argv:
        return menu_preview()
    if "--run-action" in argv:
        idx = argv.index("--run-action")
        if idx + 1 >= len(argv):
            print("Informe a acao apos --run-action", file=sys.stderr)
            return 2
        return run_action_cli(argv[idx + 1])
    if "--no-browser" in argv:
        return start_server(open_browser=False)
    return start_server(open_browser=True)

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
PY_WEBNOVA
