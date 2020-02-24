float wta = abs(abs(float(worldTime)-17990)-5220);
float ambi = .5*(.9*(smoothstep(0.,1000.,wta))+.1);
