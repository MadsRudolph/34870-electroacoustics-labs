"""Tests for the solo round (SoloLink in control_panel.py): the listener's phone drives the panel.

No network and no hardware: the server and the panel are faked.
Run from the control-panel folder:  python3 -m unittest discover -s tests -v
"""
import json, sys, threading, time, unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import control_panel as cp  # noqa: E402


class FakeDsp:
    def __init__(self):
        self.calls = []

    def set_gains(self, g1, g2):
        self.calls.append((g1, g2))
        return dict(output1=g1, output2=g2)

    def exe(self):
        return '/usr/bin/minidsp'


class FakePanel:
    def __init__(self):
        self.s = {'minidsp_auto': True, 'cues': True}
        self.null_audio = False
        self.minidsp = FakeDsp()
        self.lock = threading.RLock()
        self.chain = self.mode = self.finished_at = None
        self.message = ''
        self.played = []
        self.stops = 0

    def stop(self):
        self.stops += 1
        self.chain = self.mode = None

    def play_tracks(self, idx, label=None, cue=None, after_cue=None):
        self.played.append((list(idx), label, cue, self.minidsp.calls[-1][0]))
        self.chain, self.mode = {'name': label, 'labels': [], 'index': 0}, 'test'

    def status(self):
        return {'now': {'track': 1, 'elapsed': 1.0, 'length': 55.0}}


ROUND = {'id': 'abc-123', 'n': 4, 'code': '1234', 'partA': True, 'order': ['H', 'D', 'L', 'D'], 'ended': False}


class SoloTestCase(unittest.TestCase):
    def setUp(self):
        lg = mock.patch.object(cp, 'log')
        lg.start()
        self.addCleanup(lg.stop)
        self.panel = FakePanel()
        self.solo = cp.SoloLink(self.panel, base='http://test.invalid')
        self.solo.LEAD = 0.0
        self.solo.round = dict(ROUND)

    def run_cmd(self, seq, action, item):
        self.solo.handled = seq
        self.solo._do({'seq': seq, 'action': action, 'item': item})


class TestPlan(SoloTestCase):
    def test_part_a_plays_the_design(self):
        for k in range(1, 5):
            self.assertEqual(self.solo.plan(f'A{k}'), ([k - 1], f'a{k}', -5.8))

    def test_part_b_follows_the_order(self):
        want = {'B1': 0.0, 'B2': -5.8, 'B3': -11.6, 'B4': -5.8}
        for item, g in want.items():
            tracks, cue, g1 = self.solo.plan(item)
            self.assertEqual((tracks, cue, g1), ([1, 2], 'b' + item[1], g))

    def test_refuses_unknown_items_and_part_a_when_off(self):
        for bad in ('C1', 'B5', 'A0', '', None, 'B1; rm'):
            with self.assertRaises(ValueError):
                self.solo.plan(bad)
        self.solo.round['partA'] = False
        with self.assertRaises(ValueError):
            self.solo.plan('A1')


class TestCommands(SoloTestCase):
    def test_every_play_sets_both_gains_before_playing(self):
        for seq, item in enumerate(['B1', 'B2', 'B3', 'B4'], start=1):
            self.run_cmd(seq, 'play', item)
        self.assertEqual(self.panel.minidsp.calls, [(0.0, 0.0), (-5.8, 0.0), (-11.6, 0.0), (-5.8, 0.0)])
        self.assertEqual([p[3] for p in self.panel.played], [0.0, -5.8, -11.6, -5.8])   # gain in force when it played
        self.assertEqual(self.panel.played[0][:3], ([1, 2], 'Solo · B1', 'b1'))

    def test_superseded_tap_does_nothing(self):
        self.solo.handled = 5                       # a newer tap (seq 5) already arrived
        self.solo._do({'seq': 4, 'action': 'play', 'item': 'B1'})
        self.assertEqual(self.panel.minidsp.calls, [])
        self.assertEqual(self.panel.played, [])

    def test_gain_failure_does_not_play(self):
        def boom(g1, g2):
            raise cp.MiniDSPError('MiniDSP Output 1 gain 0 dB failed: No devices found')
        self.panel.minidsp.set_gains = boom
        self.run_cmd(1, 'play', 'B1')
        self.assertEqual(self.panel.played, [])
        self.assertEqual(self.solo.state['state'], 'error')
        self.assertIn('MiniDSP', self.solo.state['msg'])

    def test_stop(self):
        self.run_cmd(1, 'play', 'A2')
        self.run_cmd(2, 'stop', 'A2')
        self.assertEqual(self.solo.state['state'], 'stopped')
        self.assertEqual(self.solo.state['item'], 'A2')

    def test_fixed_lead_time(self):
        self.solo.LEAD = 0.3
        t0 = time.monotonic()
        self.run_cmd(1, 'play', 'B2')
        self.assertGreaterEqual(time.monotonic() - t0, 0.29)


class TestWatch(SoloTestCase):
    def test_playing_then_done(self):
        self.run_cmd(1, 'play', 'B1')
        self.solo.state['started'] -= 2
        self.solo._watch()
        self.assertEqual(self.solo.state['state'], 'playing')
        self.assertEqual(self.solo.state['track'], 2)
        self.panel.chain, self.panel.mode, self.panel.finished_at = None, None, time.monotonic()
        self.solo._watch()
        self.assertEqual(self.solo.state['state'], 'done')

    def test_something_else_took_over(self):
        self.run_cmd(1, 'play', 'B1')
        self.solo.state['started'] -= 2
        self.panel.chain, self.panel.mode = {'name': 'Track 4'}, 'test'
        self.solo._watch()
        self.assertEqual(self.solo.state['state'], 'stopped')


class TestBlind(SoloTestCase):
    def test_status_never_contains_the_order(self):
        for seq, item in enumerate(['B1', 'B2', 'B3', 'B4'], start=1):
            self.run_cmd(seq, 'play', item)
        st = json.dumps(self.solo.status())
        self.assertNotIn('order', st)
        self.assertNotIn('-11.6', st)
        self.assertNotIn('HDLD', st)
        for k in ('L', 'H'):
            self.assertNotIn(f'"{k}"', st)

    def test_start_refused_without_minidsp_automation(self):
        self.panel.s['minidsp_auto'] = False
        with self.assertRaises(RuntimeError):
            self.solo.start()


if __name__ == '__main__':
    unittest.main()
