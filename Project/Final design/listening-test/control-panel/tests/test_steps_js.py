"""Checks the guided-step table in panel.html: which MiniDSP gains each step asks for, and which steps
still need the operator's ✓ Set done when automatic gains are on. Runs the page's own step code in
Node (skipped if Node is not installed). No browser, no server, no hardware.
Run from the control-panel folder:  python3 -m unittest discover -s tests -v
"""
import json, re, shutil, subprocess, unittest
from pathlib import Path

HTML = Path(__file__).resolve().parent.parent / 'panel.html'

HARNESS = r'''
let S = null;
%s
const needsSet = x => !!(x && x.play && x.set && x.set.change);
const out = {};
for (const auto of [false, true]) for (const partD of [false, true]) for (let n = 1; n <= 7; n++) {
  S = { minidsp_auto: auto, part_d: partD };
  out[`${auto}|${partD}|${n}`] = steps(n).map(x => ({ g: x.g, t: x.t, play: !!x.play, dsp: x.dsp, chip: x.chip,
    setk: x.set.k || null, manual: needsManualSet(x), needs: needsSet(x) }));
}
console.log(JSON.stringify(out));
'''


@unittest.skipUnless(shutil.which('node'), 'node is not installed')
class TestStepGains(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        src = HTML.read_text(encoding='utf-8')
        block = re.search(r'(const B_ORDER.*?)\nfunction renderSteps', src, re.S).group(1)
        helpers = '\n'.join(re.search(p, src, re.M).group(0) for p in (
            r'^const dspHandles = .*$', r'^const needsManualSet = .*$'))
        r = subprocess.run(['node', '-e', HARNESS % (block + '\n' + helpers)], capture_output=True, text=True, timeout=30)
        if r.returncode:
            raise AssertionError(r.stderr)
        cls.data = json.loads(r.stdout)
        cls.b_order = {int(k): v for k, v in re.findall(r"(\d): '([DLH]{4})'", re.search(r'const B_ORDER = \{.*?\}', src).group(0))}

    def test_part_b_gain_follows_the_order_sheet(self):
        level = {'L': -11.6, 'D': -5.8, 'H': 0}
        for n in range(1, 8):
            st = self.data[f'false|false|{n}']
            b = [x for x in st if x['g'] == 'B' and x['play']]
            order = self.b_order[(n - 1) % 6 + 1]
            self.assertEqual([x['chip'] for x in b], list(order))
            self.assertEqual([x['dsp']['output1'] for x in b], [level[c] for c in order])

    def test_output2_always_zero_and_every_step_has_gains(self):
        for key, st in self.data.items():
            for x in st:
                with self.subTest(key=key, step=x['t']):
                    self.assertIsNotNone(x['dsp'])
                    self.assertEqual(x['dsp']['output2'], 0)
                    if x['g'] != 'B' or not x['play']:
                        self.assertEqual(x['dsp']['output1'], -5.8)   # everything outside Part B samples is the design

    def test_design_restored_after_part_b_and_at_the_end(self):
        for key, st in self.data.items():
            after_b = next(x for x in st if x['t'] == 'After Part B')
            self.assertEqual(after_b['dsp'], {'output1': -5.8, 'output2': 0})
            self.assertEqual(st[-1]['dsp'], {'output1': -5.8, 'output2': 0})
            self.assertEqual(st[0]['dsp'], {'output1': -5.8, 'output2': 0})

    def test_set_done_only_skipped_for_out1(self):
        for key, st in self.data.items():
            auto = key.startswith('true')
            for x in st:
                with self.subTest(key=key, step=x['t']):
                    if not x['needs']:
                        self.assertFalse(x['manual'])
                    elif x['setk'] == 'Out 1':
                        self.assertEqual(x['manual'], not auto)        # Part B: the panel does it when on
                    else:
                        self.assertTrue(x['manual'])                  # Rp swap, vent: always by hand


if __name__ == '__main__':
    unittest.main()
