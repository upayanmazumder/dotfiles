#!/usr/bin/env python3
"""Exercise isolation, credential rejection, and concurrent remote edits."""
import importlib.util
import json
import base64
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('autosync', Path(__file__).with_name('dotfiles-autosync.py'))
auto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto)


def run(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, stderr=subprocess.DEVNULL).decode().strip()


class AutosyncTest(unittest.TestCase):
    def test_rejects_links_and_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            regular = root / 'plain'
            regular.write_text('safe text\n')
            link = root / 'link'
            link.symlink_to(regular)
            with self.assertRaises(OSError):
                auto.read_regular(link)
            regular.write_text('api_key=' + 'example-secret-value' + '\n')
            with self.assertRaises(ValueError):
                auto.read_regular(regular)
            for target in ('../escape', 'etc/../escape', 'etc/.git/config', '/etc/hosts'):
                with self.assertRaises(ValueError):
                    auto.destination(target)

    def test_failed_scan_preserves_previous_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'source'
            source.write_text('safe content\n')
            state = root / 'state'
            state.mkdir()
            snapshot = state / 'snapshot.json'
            snapshot.write_text('previous safe snapshot\n')
            with self.assertRaises(subprocess.CalledProcessError):
                auto.collect({'paths': {str(source): 'etc/example'}}, state, '/bin/false')
            self.assertEqual(snapshot.read_text(), 'previous safe snapshot\n')

    def test_push_isolated_and_remote_conflict_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            remote = root / 'remote.git'
            work = root / 'work'
            run('git', 'init', '--bare', '--quiet', str(remote))
            run('git', 'clone', '--quiet', str(remote), str(work))
            run('git', 'config', 'user.name', 'Test', cwd=work)
            run('git', 'config', 'user.email', 'test@example.invalid', cwd=work)
            run('git', 'switch', '-c', 'main', cwd=work)
            (work / 'etc').mkdir()
            (work / 'etc/example').write_text('before\n')
            run('git', 'add', 'etc/example', cwd=work)
            run('git', 'commit', '--quiet', '-m', 'baseline', cwd=work)
            run('git', 'push', '--quiet', 'origin', 'main', cwd=work)
            baseline = run('git', 'rev-parse', 'HEAD', cwd=work)
            (work / 'personal').write_text('unrelated pending edit\n')
            snapshot = root / 'snapshot.json'
            snapshot.write_text(json.dumps({'etc/example': {'mode': '100644', 'data': base64.b64encode(b'after\n').decode()}}))
            config = {'remote': str(remote), 'email': 'test@example.invalid', 'baseline': baseline,
                      'paths': {'/etc/example': 'etc/example'}}
            auto.publish(config, snapshot, root / 'store')
            published = run('git', '--git-dir', str(remote), 'rev-parse', 'main')
            self.assertNotEqual(published, baseline)
            self.assertEqual(run('git', 'rev-parse', 'HEAD', cwd=work), baseline)
            self.assertEqual((work / 'personal').read_text(), 'unrelated pending edit\n')
            auto.publish(config, snapshot, root / 'store')
            self.assertEqual(run('git', '--git-dir', str(remote), 'rev-parse', 'main'), published)
            run('git', 'fetch', 'origin', 'main', cwd=work)
            run('git', 'merge', '--ff-only', 'FETCH_HEAD', cwd=work)
            (work / 'etc/example').write_text('concurrent remote value\n')
            run('git', 'add', 'etc/example', cwd=work)
            run('git', 'commit', '--quiet', '-m', 'concurrent edit', cwd=work)
            run('git', 'push', '--quiet', 'origin', 'main', cwd=work)
            with self.assertRaises(RuntimeError):
                auto.publish(config, snapshot, root / 'store')
            self.assertEqual(run('git', '--git-dir', str(remote), 'show', 'main:etc/example'), 'concurrent remote value')


if __name__ == '__main__':
    unittest.main()
