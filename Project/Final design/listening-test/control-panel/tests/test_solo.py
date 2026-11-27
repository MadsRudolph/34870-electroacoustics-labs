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

    def set_manual(self, g1, g2):                   # the real range check, then record like set_gains
        g1, g2 = cp.MiniDSPControl.validate_manual(g1, g2)
        return self.set_gains(g1, g2)

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


class TestTune(SoloTestCase):
    """The tune page: the listener sets Out 1 / Out 2 by hand from the phone and plays T1..T4."""

    def gain(self, seq, out1, out2):
        self.solo.handled = seq
        self.solo._do({'seq': seq, 'action': 'gain', 'item': '', 'out1': out1, 'out2': out2})

    def test_manual_range(self):
        ok = cp.MiniDSPControl.validate_manual
        self.assertEqual(ok(-18, -6), (-18.0, -6.0))
        self.assertEqual(ok(0, 0), (0.0, 0.0))
        self.assertEqual(ok('-7.5', -0.5), (-7.5, -0.5))
        self.assertEqual(ok(-5.8, 0), (-5.8, 0.0))             # the design is reachable
        for bad in ((0.5, 0), (-18.5, 0), (0.3, 0), (-5.85, 0), (0, 0.5), (0, -6.5), (float('nan'), 0), ('x', 0), (None, 0)):
            with self.assertRaises(ValueError, msg=bad):
                ok(*bad)

    def test_refused_gain_sends_nothing(self):
        self.gain(1, 0.5, 0)
        self.assertEqual(self.panel.minidsp.calls, [])
        self.assertEqual(self.solo.state['state'], 'error')
        self.assertIsNone(self.solo.state['gain'])

    def test_gain_is_set_and_reported(self):
        self.gain(1, -7.5, -1)
        self.assertEqual(self.panel.minidsp.calls, [(-7.5, -1.0)])
        self.assertEqual(self.solo.state['state'], 'gain_set')
        self.assertEqual(self.solo.state['gain'], dict(out1=-7.5, out2=-1.0, source='manual'))
        self.assertEqual(self.panel.stops, 0)

    def test_live_gain_while_playing_keeps_playing(self):
        self.run_cmd(1, 'play', 'T2')
        self.solo.state['started'] -= 2
        self.solo._watch()
        stops = self.panel.stops
        self.gain(2, -9, 0)
        self.assertEqual(self.panel.stops, stops)               # the music is not stopped
        st = self.solo.state
        self.assertEqual((st['state'], st['item'], st['seq']), ('playing', 'T2', 2))
        self.assertEqual(st['label'], 'Solo · T2')
        self.assertEqual(st['gain']['out1'], -9.0)
        self.solo._watch()                                     # and the watcher still follows that playback
        self.assertEqual(self.solo.state['state'], 'playing')

    def test_gain_hidden_after_a_b_item(self):
        self.gain(1, -3, 0)
        self.run_cmd(2, 'play', 'B1')
        self.assertIsNone(self.solo.state['gain'])
        self.solo.state['started'] -= 2
        self.panel.chain, self.panel.mode, self.panel.finished_at = None, None, time.monotonic()
        self.solo._watch()
        self.assertEqual(self.solo.state['state'], 'done')
        self.assertIsNone(self.solo.state['gain'])

    def test_part_a_reports_the_design(self):
        self.run_cmd(1, 'play', 'A1')
        self.assertEqual(self.solo.state['gain'], dict(out1=-5.8, out2=0.0, source='design'))

    def test_tune_play_after_a_b_item_resets_to_design(self):
        self.run_cmd(1, 'play', 'B3')                          # B3 = L in ROUND's order
        self.run_cmd(2, 'play', 'T4')
        self.assertEqual(self.panel.minidsp.calls, [(-11.6, 0.0), (-5.8, 0.0)])
        self.assertEqual(self.panel.played[-1][:3], ([3], 'Solo · T4', None))
        self.assertEqual(self.panel.played[-1][3], -5.8)       # the gain in force when it started
        self.assertEqual(self.solo.state['gain']['source'], 'design')

    def test_tune_play_keeps_a_manual_gain(self):
        self.gain(1, -4, -2)
        self.run_cmd(2, 'play', 'T1')
        self.assertEqual(self.panel.minidsp.calls, [(-4.0, -2.0)])  # no extra set before the play
        self.assertEqual(self.solo.state['gain']['out1'], -4.0)

    def test_rapid_gain_taps_only_apply_the_last(self):
        self.solo.handled = 3                                  # three taps arrived before any was carried out
        for seq, g in ((1, -1), (2, -2), (3, -3)):
            self.solo._do({'seq': seq, 'action': 'gain', 'out1': g, 'out2': 0})
        self.assertEqual(self.panel.minidsp.calls, [(-3.0, 0.0)])

    def test_status_after_tune_never_contains_the_order(self):
        self.run_cmd(1, 'play', 'B1')
        self.gain(2, -6, 0)
        st = json.dumps(self.solo.status())
        self.assertNotIn('order', st)
        self.assertNotIn('HDLD', st)


if __name__ == '__main__':
    unittest.main()
