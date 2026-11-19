#!/usr/bin/env python3
"""Collect reviewed live configuration and publish from an isolated Git store."""
import base64
import fcntl
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile

CONFIG = Path('/etc/dotfiles-autosync.json')
STATE = Path('/var/lib/dotfiles-autosync')
SCANNER = '/usr/local/lib/dotfiles-autosync/gitleaks'
LIMIT = 1024 * 1024
PRIVATE = re.compile(r'(secret|token|password|credential|private|\.pem$|\.key$)', re.I)
SECRET = re.compile(r'-----BEGIN .*PRIVATE KEY-----|(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]{20,}|\bAKIA[A-Z0-9]{16}\b|(?im:^\s*(?:password|passwd|api_key|access_token|client_secret)\s*[=:]\s*[\"\']?[^\s\"\']+)')


def destination(value: str) -> str:
    path = PurePosixPath(value)
    if (path.is_absolute() or '..' in path.parts or '.' in path.parts
            or not path.parts or path.parts[0] not in ('etc', 'usr', 'boot', 'home')
            or any(part == '.git' for part in path.parts) or PRIVATE.search(value)):
        raise ValueError('Unsafe destination path')
    return str(path)


def read_regular(path: Path) -> tuple[bytes, str]:
    """Open each component without following links, including the final file."""
    if not path.is_absolute() or '..' in path.parts:
        raise ValueError('Source must be an absolute path without traversal')
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        child = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(child, 'rb') as source:
            info = os.fstat(source.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size > LIMIT:
                raise ValueError('Source is not a bounded regular file')
            data = source.read(LIMIT + 1)
            if len(data) > LIMIT or b'\0' in data:
                raise ValueError('Source is too large or contains binary data')
            text = data.decode('utf-8')
            if SECRET.search(text):
                raise ValueError('Possible credential content')
            return data, '100755' if info.st_mode & 0o111 else '100644'
    finally:
        os.close(fd)


def scan(directory: Path, scanner: str = SCANNER) -> None:
    env = {k: v for k, v in os.environ.items() if not k.startswith('GITLEAKS')}
    subprocess.run([scanner, 'dir', '--no-banner', '--redact', '--ignore-gitleaks-allow',
                    '--gitleaks-ignore-path', '/dev/null', '--max-decode-depth', '2',
                    str(directory)], check=True, env=env, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=60)


def collect(config: dict, state: Path = STATE, scanner: str = SCANNER) -> None:
    state.mkdir(mode=0o755, parents=True, exist_ok=True)
    files = {}
    with tempfile.TemporaryDirectory(prefix='.scan-', dir=state) as tmp:
        root = Path(tmp)
        for source, target in config['paths'].items():
            target = destination(target)
            if PRIVATE.search(source):
                raise ValueError('Private source path')
            try:
                data, mode = read_regular(Path(source))
            except FileNotFoundError:
                print(f'Missing source preserved in Git: {target}', flush=True)
                continue
            # FAT mount masks do not describe executable configuration files.
            if target.startswith('boot/'):
                mode = '100644'
            out = root / target
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(data)
            files[target] = {'data': base64.b64encode(data).decode('ascii'), 'mode': mode}
        scan(root, scanner)
    payload = json.dumps(files, sort_keys=True).encode()
    current = state / 'snapshot.json'
    if current.exists() and current.read_bytes() == payload:
        return
    fd, name = tempfile.mkstemp(prefix='.snapshot-', dir=state)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
            os.fchmod(output.fileno(), 0o644)
        os.replace(name, current)
    finally:
        Path(name).unlink(missing_ok=True)
    print(f'Collected {len(files)} reviewed files', flush=True)


def git(repo: Path, *args: str, data: bytes | None = None, env: dict | None = None) -> bytes:
    result = subprocess.run(['git', '--git-dir', str(repo), '-c', 'core.hooksPath=/dev/null',
                             *args], input=data, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env=env, timeout=90)
    if result.returncode:
        # Git stderr can contain credential-bearing remote URLs. Do not print it.
        raise RuntimeError(f'Git {args[0]} failed with status {result.returncode}')
    return result.stdout.strip()


def entry(repo: Path, revision: str, path: str) -> bytes:
    return git(repo, 'ls-tree', revision, '--', path).split(b'\t')[0]


def publish(config: dict, snapshot: Path = STATE / 'snapshot.json',
            store: Path | None = None) -> None:
    store = store or Path.home() / '.local/state/dotfiles-autosync'
    store.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (store / 'lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        repo = store / 'repo.git'
        env = dict(os.environ, GIT_TERMINAL_PROMPT='0',
                   GIT_AUTHOR_NAME='Dotfiles autosync', GIT_AUTHOR_EMAIL=config['email'],
                   GIT_COMMITTER_NAME='Dotfiles autosync', GIT_COMMITTER_EMAIL=config['email'])
        if not repo.exists():
            subprocess.run(['git', 'init', '--bare', '--quiet', str(repo)], check=True)
        git(repo, 'fetch', '--quiet', config['remote'], 'refs/heads/main', env=env)
        head = git(repo, 'rev-parse', 'FETCH_HEAD').decode()
        try:
            baseline = git(repo, 'rev-parse', '--verify', 'refs/autosync/published').decode()
        except RuntimeError:
            baseline = config['baseline']
        git(repo, 'cat-file', '-e', baseline + '^{commit}')
        bundle = json.loads(snapshot.read_text())
        allowed = set(config['paths'].values())
        with tempfile.TemporaryDirectory(dir=store) as temporary:
            index = Path(temporary) / 'index'
            env['GIT_INDEX_FILE'] = str(index)
            git(repo, 'read-tree', head, env=env)
            for path, item in bundle.items():
                destination(path)
                if path not in allowed or item['mode'] not in ('100644', '100755'):
                    raise ValueError('Snapshot path or mode is not allowed')
                data = base64.b64decode(item['data'], validate=True)
                if len(data) > LIMIT or SECRET.search(data.decode('utf-8')):
                    raise ValueError('Unsafe snapshot content')
                blob = git(repo, 'hash-object', '-w', '--stdin', data=data).decode()
                desired = f"{item['mode']} blob {blob}".encode()
                remote = entry(repo, head, path)
                if desired == remote:
                    continue
                if remote != entry(repo, baseline, path):
                    raise RuntimeError(f'Remote changed {path}. Review before publication.')
                git(repo, 'update-index', '--add', '--cacheinfo', item['mode'], blob, path, env=env)
            tree = git(repo, 'write-tree', env=env).decode()
        if tree != git(repo, 'rev-parse', head + '^{tree}').decode():
            head = git(repo, 'commit-tree', tree, '-p', head,
                       data=b'chore: synchronized reviewed system configuration\n', env=env).decode()
            git(repo, 'update-ref', 'refs/heads/main', head)
            git(repo, 'push', '--quiet', config['remote'], head + ':refs/heads/main', env=env)
            print(f'Published {head}', flush=True)
        git(repo, 'update-ref', 'refs/autosync/published', head)


def main() -> None:
    config = json.loads(CONFIG.read_text())
    if sys.argv[1:] == ['collect']:
        collect(config)
    elif sys.argv[1:] == ['publish']:
        publish(config)
    else:
        raise SystemExit('Usage: dotfiles-autosync.py collect|publish')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        # Source contents and credential values must never reach the journal.
        print(f'Autosync stopped: {type(error).__name__}: {error}', file=sys.stderr)
        raise SystemExit(1)
