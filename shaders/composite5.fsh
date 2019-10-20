#version 120
#include "lib/essentials.glsl"
#include "lib/shadowtransform.glsl"
#include "lib/trans.glsl"

uniform vec3 shadowLightPosition;



float dither,dit;

varying vec2 tc;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform float frameTimeCounter;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;


uniform sampler2D noisetex;

uniform int frameCounter;
uniform int isEyeInWater;

uniform float wetness;
uniform float rainStrength;



uniform int worldTime;


#include "lib/lmcol.glsl"
#include "lib/clouds.set"

vec3 lc=vec3(0.);

#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));
#include "lib/shadow.glsl"


vec3 lightDir,lightcol;

#define USE_METALS

float getCloudShadow(vec3 p)
{
  if(p.y>cloud_mid)
    return 1.;
  vec3 slp = normalize(view2cam(shadowLightPosition));
  p-=slp*p.y/slp.y;
  vec2 pc = ((p.xz+.5*resolution)/resolution);
  return pc==fract(pc)?saturate(texture2D(colortex1,pc*.5+vec2(.5,0)).r):1.;
}


float hash13(vec3 p3){
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract(dot(p3,vec3(1)));

}


#define WATER_VOL_STEPS 4 //[2 4 8 16 32]
#define VOLUMETRIC_WATER

#ifdef VOLUMETRIC_WATER
vec3 volumeWater(vec3 p1, vec3 p2,float sh, vec3 c){
  p1=screen2cam(p1),
  p2=screen2cam(p2);
  vec3 rd = p2-p1;
  vec3 st = rd/float(WATER_VOL_STEPS+1);
  float shade =sh;
  float stlen = length(st);
  p2=p2-st*(dit+1.);
  for(int i=1;i<WATER_VOL_STEPS;i++){
      shade+=shadow2(p2)*exp2(-distance(p1,p2)*WATER_THICCNESS*.01)*getCloudShadow(p2);
      c=mix((.3*shade+.1)*vec3(.05,.07,.3)*lightcol,c,exp2(-stlen*WATER_THICCNESS));
      p2-=st;
  }
  return c;
}
#endif

#define VOL_STEPS 4 //[2 4 8 16 32]
#define VOLUMETRIC_LIGHT

#ifdef VOLUMETRIC_LIGHT
vec3 volumeLight(vec3 c,vec3 rd){

  //vec3 rd = screen2cam(p1);
  vec3 st = rd/float(VOL_STEPS);
  vec3 p = rd;
  vec3 shade =vec3(0.);

  p-=st*fract(dit);

  vec3 fogColor = vec3(.058,.063,.08)*(1.+length(lightcol));
float rayl = .7+.3*saturate(mix(dot(normalize(rd),lightDir),1.,.3));
rayl*=rayl;
float wetd = wetness*wetness;
wetd = wetd*wetd;
vec3 li = lightcol*lightcol;
vec3 rb = vec3(li.r,0,0)*smoothstep(.05,.0,abs(dot(normalize(rd),lightDir)+.1));
rb = mix(rb,vec3(0,li.g,0),smoothstep(.05,.0,abs(dot(normalize(rd),lightDir)+.125)));
rb = mix(rb,vec3(0,0,li.b),smoothstep(.04,.0,abs(dot(normalize(rd),lightDir)+.15)));
vec3 lc =lightcol;
vec3 rba = vec3(0);
float stlen = length(st);

  for(int i=0;i<VOL_STEPS;i++){
    vec4 n = texture2D(noisetex,(p.xz+cameraPosition.xz- frameTimeCounter)*.0001);
    float density=(.05*n.r*n.r+.05*wetd)*exp2(-abs(p.y+cameraPosition.y-62.)*(.1+.3*sqrt(n.g)*(1.-.9*wetness)));
    float den = density*stlen;
    float l = shadow2(p)*getCloudShadow(p);
      shade=mix(fogColor,lc,rayl*l);
      float ext= exp2(-den);
      c=mix(shade,c,ext);
      rba +=rb*(.1+.2*wetness)*l*rayl*rayl*(1.-ext);
      p-=st;
  }
  return c+rba;
}
#endif

/*DRAWBUFFERS:0*/
void main(){
  #include "lib/lightcol.glsl"
  lightDir=lightdir,lightcol=lightCol;
  vec3 c = texture2D(colortex0,tc).rgb;

  vec3 hc = vec3(gl_FragCoord.xy,mod(frameCounter*3.,PI)*50.);
  dit = hash13(hc-hc.zxy);


  dither = fract(dither16(gl_FragCoord.xy)+frameTimeCounter*240.);


  float pd = texture2D(depthtex0,tc).r;


  vec3 n = texture2D(colortex2,tc).rgb*2.-1.;

  float iswater = length(n)<.8?1.:0.;
  n = normalize(n);

  lc = lightcol;

  vec3 p = (vec3(tc,pd));
  vec3 viewp = screen2view(p);
  vec3 rd = normalize(viewp);

  float depth = depthBlock(pd);


  if(isEyeInWater>0){
    #ifdef VOLUMETRIC_WATER
    c = volumeWater(p,vec3(0),0.,c);
    #else
    c= mix(vec3(.005,.007,.03)*lightCol,c,exp2(-depth*WATER_THICCNESS));
    #endif

  }else{

    vec3 rd = camdir(viewp);
    float rayl = .2+.8*saturate(mix(dot(normalize(rd),lightDir),1.,.3));
    vec3 fogColor = vec3(.05,.06,.1);
    #ifdef VOLUMETRIC_LIGHT
    c=volumeLight(c,rd*(1.-.9*step(1.,pd)));
    //fogColor = vol.rgb;
    #else
    float vol=1.;
    c=mix(c,fogColor,vol);
    #endif


    //if(fresnel>.01)
    //c*=0.;
  }
  gl_FragData[0] = vec4(c,1.);//texture2D(colortex1,tc*.5+vec2(.5,0.));

}
