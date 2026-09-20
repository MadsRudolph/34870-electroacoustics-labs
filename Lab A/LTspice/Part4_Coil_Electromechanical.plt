[AC Analysis]
{
   Npanes: 3
   {
      traces: 2 {524290,0,"V(u_c)"} {524291,0,"V(u_1)"}
      X: (' ',0,1,0,10000)
      Y[0]: (' ',0,1e-07,20,10)
      Y[1]: (' ',0,-180,45,180)
      Log: 1 2 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   }
   {
      traces: 1 {524292,0,"1.5*I(Vs1)/V(u_c)"}
      X: (' ',0,1,0,10000)
      Y[0]: (' ',0,0.01,20,100000)
      Y[1]: (' ',0,-180,45,180)
      Log: 1 2 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   }
   {
      traces: 1 {524293,0,"V(vin)/I(Vs1)"}
      X: (' ',0,1,0,10000)
      Y[0]: (' ',0,0.1,20,100)
      Y[1]: (' ',0,-180,45,180)
      Log: 1 2 0
      GridStyle: 1
      PltMag: 1
      PltPhi: 1 0
   }
}
