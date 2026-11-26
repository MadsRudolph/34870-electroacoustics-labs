"""Tests for the MiniDSP 2x4 HD gain control in control_panel.py.

Every call to the minidsp CLI is mocked: these tests never touch real hardware.
Run from the control-panel folder:  python3 -m unittest discover -s tests -v
"""
import json, subprocess, sys, threading, unittest, urllib.error, urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import control_panel as cp  # noqa: E402

EXE = '/usr/bin/minidsp'


def done(rc=0, out='', err=''):
    return subprocess.CompletedProcess(args=[], returncode=rc, stdout=out, stderr=err)


class MiniDSPTestCase(unittest.TestCase):
    def setUp(self):
        # Any un-mocked subprocess call would be a bug in a test: make it fail loudly.
        p = mock.patch.object(cp.subprocess, 'run', side_effect=AssertionError('unexpected subprocess.run'))
        self.run_mock = p.start()
        self.addCleanup(p.stop)
        w = mock.patch.object(cp.shutil, 'which', return_value=EXE)
        self.which_mock = w.start()
        self.addCleanup(w.stop)
        lg = mock.patch.object(cp, 'log')
        lg.start()
        self.addCleanup(lg.stop)


class TestValidation(MiniDSPTestCase):
    def test_accepts_the_three_levels(self):
        for g in (-11.6, -5.8, 0, '-5.8', 0.0):
            o1, o2 = cp.MiniDSPControl.validate(g, 0)
            self.assertIn(o1, cp.MiniDSPControl.OUTPUT1_GAINS)
            self.assertEqual(o2, 0.0)

    def test_refuses_anything_else(self):
        for o1, o2 in ((-5.0, 0), (-5.8, -1), (3, 0), (-11.6, 0.5), (float('nan'), 0), (float('inf'), 0),
                       ('abc', 0), (None, 0), (-5.8, None)):
            with self.subTest(o1=o1, o2=o2), self.assertRaises(ValueError):
                cp.MiniDSPControl.validate(o1, o2)

    def test_refused_gain_sends_nothing(self):
        with self.assertRaises(ValueError):
            cp.MiniDSPControl().set_gains(-20, 0)
        self.run_mock.assert_not_called()


class TestCommands(MiniDSPTestCase):
    def test_command_puts_double_dash_before_the_value(self):
        cmd = cp.MiniDSPControl().gain_command(EXE, 0, -5.8)
        self.assertEqual(cmd, [EXE, '--usb', '2752:0011', 'output', '0', 'gain', '--', '-5.8'])
        self.assertEqual(cp.MiniDSPControl().gain_command(EXE, 1, 0.0)[-2:], ['--', '0'])

    def test_set_gains_runs_output1_then_output2(self):
        self.run_mock.side_effect = None
        self.run_mock.return_value = done()
        m = cp.MiniDSPControl()
        self.assertEqual(m.set_gains(-11.6, 0), dict(output1=-11.6, output2=0.0))
        cmds = [c.args[0] for c in self.run_mock.call_args_list]
        self.assertEqual(cmds, [[EXE, '--usb', '2752:0011', 'output', '0', 'gain', '--', '-11.6'],
                                [EXE, '--usb', '2752:0011', 'output', '1', 'gain', '--', '0']])
        for c in self.run_mock.call_args_list:
            self.assertIn('timeout', c.kwargs)
            self.assertNotIn('shell', c.kwargs)
        self.assertEqual(m.last_error, '')
        self.assertFalse(m.simulated)

    def test_each_level(self):
        self.run_mock.side_effect = None
        self.run_mock.return_value = done()
        m = cp.MiniDSPControl()
        for g, txt in ((-11.6, '-11.6'), (-5.8, '-5.8'), (0, '0')):
            self.run_mock.reset_mock()
            m.set_gains(g, 0)
            self.assertEqual(self.run_mock.call_args_list[0].args[0][-1], txt)


class TestSilentMode(MiniDSPTestCase):
    def test_test_mode_never_calls_the_cli(self):
        m = cp.MiniDSPControl(null_audio=True)
        self.assertEqual(m.set_gains(-5.8, 0), dict(output1=-5.8, output2=0.0))
        self.assertTrue(m.simulated)
        self.assertIn('Silent', m.check())
        self.run_mock.assert_not_called()

    def test_test_mode_still_validates(self):
        with self.assertRaises(ValueError):
            cp.MiniDSPControl(null_audio=True).set_gains(-3, 0)


class TestErrors(MiniDSPTestCase):
    def test_cli_missing(self):
        self.which_mock.return_value = None
        m = cp.MiniDSPControl()
        with self.assertRaisesRegex(cp.MiniDSPError, 'not found'):
            m.set_gains(-5.8, 0)
        with self.assertRaisesRegex(cp.MiniDSPError, 'not found'):
            m.check()
        self.run_mock.assert_not_called()
        self.assertFalse(m.status(True)['available'])

    def test_output1_fails_stops_and_marks_unknown(self):
        self.run_mock.side_effect = [done(1, err='Error: no device found')]
        m = cp.MiniDSPControl()
        m.last_gains = dict(output1=-5.8, output2=0.0)
        with self.assertRaisesRegex(cp.MiniDSPError, 'Output 1 .*no device found'):
            m.set_gains(0, 0)
        self.assertEqual(self.run_mock.call_count, 1)          # Output 2 is not tried
        self.assertIsNone(m.last_gains)                         # gain is now unknown
        self.assertIn('no device found', m.status(True)['last_error'])

    def test_output2_fails_warns_output1_changed(self):
        self.run_mock.side_effect = [done(), done(2, out='', err='usb error')]
        m = cp.MiniDSPControl()
        with self.assertRaisesRegex(cp.MiniDSPError, 'Output 2.*usb error.*Output 1 may already have changed'):
            m.set_gains(-11.6, 0)
        self.assertIsNone(m.last_gains)

    def test_empty_error_text_reports_exit_code(self):
        self.run_mock.side_effect = [done(101)]
        with self.assertRaisesRegex(cp.MiniDSPError, 'exit code 101'):
            cp.MiniDSPControl().set_gains(-5.8, 0)

    def test_timeout(self):
        self.run_mock.side_effect = subprocess.TimeoutExpired(cmd='minidsp', timeout=10)
        with self.assertRaisesRegex(cp.MiniDSPError, 'no answer'):
            cp.MiniDSPControl().set_gains(-5.8, 0)

    def test_oserror(self):
        self.run_mock.side_effect = PermissionError('Permission denied')
        with self.assertRaisesRegex(cp.MiniDSPError, 'could not run'):
            cp.MiniDSPControl().set_gains(-5.8, 0)


class TestCheck(MiniDSPTestCase):
    def test_check_is_a_status_read(self):
        status = {'master': {'preset': 0, 'source': 'Analog', 'volume': -8.0, 'mute': False},
                  'input_levels': [-60, -60], 'output_levels': [-60, -60, -60, -60]}
        self.run_mock.side_effect = [done(out=json.dumps(status) + '\n')]
        msg = cp.MiniDSPControl().check()
        self.assertIn('preset 0', msg)
        cmd = self.run_mock.call_args.args[0]
        self.assertEqual(cmd, [EXE, '--usb', '2752:0011', '-o', 'json'])
        self.assertNotIn('gain', cmd)

    def test_check_failure(self):
        self.run_mock.side_effect = [done(1, err='No devices found')]
        m = cp.MiniDSPControl()
        with self.assertRaisesRegex(cp.MiniDSPError, 'No devices found'):
            m.check()
        self.assertIn('No devices found', m.status(True)['check'])


class TestPanelAndHttp(MiniDSPTestCase):
    def fake_panel(self, enabled, null_audio=False):
        p = SimpleNamespace(s=dict(minidsp_auto=enabled), minidsp=cp.MiniDSPControl(null_audio=null_audio),
                            store=SimpleNamespace(save=mock.Mock()), _measure_all=lambda: None)
        p.set_minidsp_gains = lambda body: cp.Panel.set_minidsp_gains(p, body)
        return p

    def test_default_is_off(self):
        self.assertIs(cp.DEFAULT_SETTINGS['minidsp_auto'], False)

    def test_disabled_refuses_and_sends_nothing(self):
        p = self.fake_panel(False)
        with self.assertRaisesRegex(cp.MiniDSPError, 'off'):
            p.set_minidsp_gains(dict(output1=-5.8, output2=0))
        self.run_mock.assert_not_called()

    def test_setting_is_saved(self):
        p = self.fake_panel(False)
        with mock.patch.object(cp.threading, 'Thread'):
            cp.update_settings(p, dict(minidsp_auto=True))
        self.assertIs(p.s['minidsp_auto'], True)
        p.store.save.assert_called_once()

    def post(self, panel, path, body):
        srv = ThreadingHTTPServer(('127.0.0.1', 0), cp.make_handler(panel))
        t = threading.Thread(target=srv.serve_forever, daemon=True)
        t.start()
        try:
            req = urllib.request.Request(f'http://127.0.0.1:{srv.server_address[1]}{path}',
                                         data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
            try:
                with urllib.request.urlopen(req, timeout=5) as r:
                    return r.status, json.loads(r.read())
            except urllib.error.HTTPError as e:
                with e:
                    return e.code, json.loads(e.read())
        finally:
            srv.shutdown()
            srv.server_close()

    def test_http_success(self):
        self.run_mock.side_effect = None
        self.run_mock.return_value = done()
        code, body = self.post(self.fake_panel(True), '/api/dsp/gains', dict(output1=-11.6, output2=0))
        self.assertEqual(code, 200)
        self.assertEqual(body['gains'], dict(output1=-11.6, output2=0.0))

    def test_http_failure_is_an_error_the_page_can_show(self):
        self.run_mock.side_effect = [done(1, err='Error: device not found')]
        code, body = self.post(self.fake_panel(True), '/api/dsp/gains', dict(output1=0, output2=0))
        self.assertEqual(code, 500)
        self.assertIn('device not found', body['error'])

    def test_http_refuses_odd_gain(self):
        code, body = self.post(self.fake_panel(True), '/api/dsp/gains', dict(output1=-40, output2=0))
        self.assertEqual(code, 500)
        self.assertIn('Refused', body['error'])
        self.run_mock.assert_not_called()

    def test_http_test_mode_simulates(self):
        code, body = self.post(self.fake_panel(True, null_audio=True), '/api/dsp/gains', dict(output1=-5.8, output2=0))
        self.assertEqual(code, 200)
        code, body = self.post(self.fake_panel(True, null_audio=True), '/api/dsp/check', {})
        self.assertEqual(code, 200)
        self.run_mock.assert_not_called()


if __name__ == '__main__':
    unittest.main()
