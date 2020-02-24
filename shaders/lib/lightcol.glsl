vec3 lightdir = camdir(normalize(shadowLightPosition));
vec3 lightCol=vec3(0);
if(worldTime<=12770 || worldTime>=23210){
   lightCol=mix(vec3(.4,.1,0.),vec3(1.,1.,.85),max(0.,sqrt(lightdir.y)));
}
else{
  lightCol=mix(vec3(.08,.08,.08),.5*vec3(.078,.08,.1),max(0.,sqrt(lightdir.y)));
}
float wt = abs(abs(float(worldTime)-17990)-5220);
lightCol*=smoothstep(0,770,wt);
