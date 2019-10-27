float isday = sin(TAU*float(worldTime)/24000.);
float bolt = step((1.-rainStrength)*2.+.45+.15*sign(isday),dot(skyColor,skyColor));
