"""Load System D filters: file parsing, command list, silent mode and failures. No hardware: subprocess is mocked."""
import sys, tempfile, unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from test_minidsp import MiniDSPTestCase, EXE, done, cp  # noqa: E402

WOOF = (0.000111435745339, 0.000222871490678, 0.000111435745339, 1.969920198141118, -0.970365941122475)
MIDTW = (0.985071534815898, -1.970143069631796, 0.985071534815898, 1.969920198141118, -0.970365941122475)


def write(tmp, name, text):
    p = Path(tmp) / name
    p.write_text(text, encoding='utf-8')
    return p


def bq_text(*bqs):
    return ''.join(f' biquad{i + 1}, \n b0 = {b[0]}, \n b1 = {b[1]}, \n b2 = {b[2]}, \n a1 = {b[3]}, \n a2 = {b[4]}, \n'
                   for i, b in enumerate(bqs))


class TestParse(MiniDSPTestCase):
    def test_real_files(self):
        m = cp.MiniDSPControl
        self.assertEqual(m.parse_filter_file(m.DSP_DIR / m.FILTER_FILES[0]), [WOOF, WOOF])
        self.assertEqual(m.parse_filter_file(m.DSP_DIR / m.FILTER_FILES[1]), [MIDTW, MIDTW])

    def test_rejects_wrong_count_incomplete_and_unstable(self):
        with tempfile.TemporaryDirectory() as tmp:
            for text, msg in ((bq_text(WOOF), 'exactly 2'), (bq_text(WOOF, WOOF, WOOF), 'exactly 2'),
                              (bq_text(WOOF, WOOF).replace(' a2 = -0.970365941122475, \n', '', 1), 'incomplete'),
                              (bq_text(WOOF, WOOF[:3] + (2.5, -1.2)), 'unstable'),
                              (bq_text(WOOF, WOOF) + 'gain = 3', 'unexpected')):
                with self.subTest(msg=msg), self.assertRaisesRegex(ValueError, msg):
                    cp.MiniDSPControl.parse_filter_file(write(tmp, 'f.txt', text))


class TestCommands(MiniDSPTestCase):
    def test_order_and_content(self):
        cmds = [c for c, _ in cp.MiniDSPControl().filter_commands(EXE)]
        self.assertEqual(len(cmds), 28)
        for c in cmds:
            self.assertEqual(c[:3], [EXE, '--usb', '2752:0011'])
        args = [c[3:] for c in cmds]
        self.assertEqual(args[0], ['output', '0', 'crossover', 'all', 'all', 'clear'])     # clear before set
        self.assertEqual(args[1], ['output', '0', 'crossover', '0', '0', 'set', '--'] + [repr(x) for x in WOOF])
        self.assertIn(['output', '1', 'crossover', '0', '1', 'set', '--'] + [repr(x) for x in MIDTW], args)
        for o in '01':
            for a in (['peq', 'all', 'bypass', 'on'], ['fir', 'bypass', 'on'], ['compressor', '--bypass', 'on'],
                      ['crossover', '1', 'all', 'bypass', 'on'], ['crossover', '0', 'all', 'bypass', 'off'],
                      ['invert', 'off'], ['delay', '0'], ['mute', 'off']):
                self.assertIn(['output', o] + a, args)
        for i in '01':
            for o in '01':
                self.assertIn(['input', i, 'routing', o, 'enable', 'on'], args)
        self.assertEqual(args[-2:], [['output', '0', 'gain', '--', '-5.8'], ['output', '1', 'gain', '--', '0']])
        self.assertFalse(any('config' in a or 'gain' == a[0] for a in args))   # no preset switch, no master gain


class TestLoad(MiniDSPTestCase):
    def test_success_sets_design_and_status(self):
        self.run_mock.side_effect = None
        self.run_mock.return_value = done()
        m = cp.MiniDSPControl()
        r = m.load_filters()
        self.assertEqual(r, dict(steps=28, simulated=False))
        self.assertEqual(self.run_mock.call_count, 28)
        self.assertEqual(m.last_gains, dict(output1=-5.8, output2=0.0))
        self.assertIn('System D filters loaded', m.status(True)['filters'])

    def test_silent_mode_sends_nothing(self):
        m = cp.MiniDSPControl(null_audio=True)
        r = m.load_filters()
        self.assertTrue(r['simulated'])
        self.run_mock.assert_not_called()
        self.assertTrue(m.simulated)

    def test_failure_midway_stops_and_marks_unknown(self):
        self.run_mock.side_effect = [done(), done(), done(1, err='Error: No devices found')]
        m = cp.MiniDSPControl()
        m.last_gains = dict(output1=-5.8, output2=0.0)
        with self.assertRaisesRegex(cp.MiniDSPError, r'not on USB.*step 3 of 28.*partly loaded'):
            m.load_filters()
        self.assertEqual(self.run_mock.call_count, 3)
        self.assertIsNone(m.last_gains)
        self.assertEqual(m.status(True)['filters'], '')

    def test_bad_file_sends_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(tmp, cp.MiniDSPControl.FILTER_FILES[0], bq_text(WOOF))
            write(tmp, cp.MiniDSPControl.FILTER_FILES[1], bq_text(MIDTW, MIDTW))
            with mock.patch.object(cp.MiniDSPControl, 'DSP_DIR', Path(tmp)):
                with self.assertRaisesRegex(ValueError, 'exactly 2'):
                    cp.MiniDSPControl().load_filters()
        self.run_mock.assert_not_called()

    def test_cli_missing(self):
        self.which_mock.return_value = None
        with self.assertRaisesRegex(cp.MiniDSPError, 'not found'):
            cp.MiniDSPControl().load_filters()
        self.run_mock.assert_not_called()


if __name__ == '__main__':
    unittest.main()
