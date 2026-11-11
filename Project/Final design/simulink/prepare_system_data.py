#!/usr/bin/env python3
"""Export course design, measured-data FIRs and independent reference to MATLAB.
FIR interpolation uses magnitude and unwrapped phase; all units share one added
causal delay. Above the measured band the response is smoothly tapered to zero.
These band-limited FIRs approximate the measured tables, not physical drivers.
"""
from pathlib import Path
import sys, json
import numpy as np
H=Path(__file__).resolve().parent
sys.path.insert(0,str(H.parent/'design'))
import xover as X
D=X.Data(box_ratio=False); des=json.loads((H.parent/'design/design.json').read_text())
fs=96000.; N=32768; delay=N//2
fg=np.fft.rfftfreq(N,1/fs)
fields={'f':D.f,'fs':fs,'delay_samples':delay}
for tag,typ in [('lp','LPF'),('hp','HPF')]:
 b0,b1,b2,a1,a2=X.bq(des['digital']['fc'],1/np.sqrt(2),typ)
 fields['b_'+tag]=[b0,b1,b2]; fields['a_'+tag]=[1,a1,a2]
fields['g_woof']=10**(des['digital']['g_woof_dB']/20)
fields['Lmid']=des['mid']['vals']['L1']; fields['Cmid']=des['mid']['vals']['C1']
fields['Ctw']=des['tw']['vals']['C1']; fields['Ltw']=des['tw']['vals']['L1']
fields['Rs']=des['tw']['pad']['Rs']; fields['Rp']=des['tw']['pad']['Rp']
ref,_=X.evaluate(D,des)
for u in ('woof','mid','tw'):
 z=D.tf['on'][u]
 # Match the common distance correction of the LTspice TF files.
 z=z*np.exp(-2j*np.pi*D.f*1.15/345)
 mag=np.interp(fg,D.f,np.abs(z)); phase=np.interp(fg,D.f,np.unwrap(np.angle(z)))
 taper=np.clip((24000-fg)/(24000-D.f[-1]),0,1)
 low=np.minimum(fg/D.f[0],1)
 spec=mag*np.exp(1j*phase)*taper*low
 spec[0]=0; spec[-1]=0
 h=np.roll(np.fft.irfft(spec,n=N),delay)
 fields['fir_'+u]=h
 fields['tf_'+u]=z
 fields['ref_'+u]=ref[u]*np.exp(-2j*np.pi*D.f*1.15/345)
 fields['pol_'+u]=des['pol'][u]
 if u!='woof': fields['zi_'+u]=D.zi[u]
fields['ref_sum']=sum(fields['ref_'+u] for u in ('woof','mid','tw'))
out={}
for k,v in fields.items():
 a=np.asarray(v)
 if np.iscomplexobj(a): out[k+'_re']=a.real.tolist(); out[k+'_im']=a.imag.tolist()
 else: out[k]=a.tolist()
(H/'system_data.json').write_text(json.dumps(out))
print('Wrote system_data.json: 96 kHz FIRs, common additional delay %.3f ms'%(1000*delay/fs))
