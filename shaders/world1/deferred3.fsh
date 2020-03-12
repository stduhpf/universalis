#version 130
#include "../lib/trans.glsl"
#include "../lib/essentials.glsl"


uniform sampler2D gcolor;

uniform sampler2D gdepth;
uniform sampler2D gnormal;

uniform sampler2D colortex7;
uniform sampler2D colortex4;
uniform sampler2D colortex3;

uniform sampler2D depthtex1;
uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform float frameTimeCounter;
uniform int frameCounter;

uniform int worldTime;


varying vec2 tc;


#define AO_SAMPLES 2    //[1 2 4 8 12 16]  //samples per pixelper frame
#define AO_RADIUS .45   //[.1 .15 .2 .25 .3 .35 .4 .45 .5 .55 .6 .65 .7 .75 .8 .85 .9 .95 1. 1.25 1.5 1.75 2. 3. ]radius in m*pixel/screenwidthh

const float autorad = float(AO_RADIUS)*.715/sqrt(float(AO_SAMPLES+1)); //.715 is empirical


#define AMBIENT_OCCLUSION

#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));
float dither = 0;

#ifdef AMBIENT_OCCLUSION
//#define COLORED_SHADOW

float ssao(float pixdpth, vec3 n){
  vec3 p =screen2view(vec3(tc,pixdpth));

  float a = 0.;
  float seq = float(frameCounter)/17.;

  vec2 angle = vec2(0,autorad/(p.z));
  angle*=rot(dither*6.28318530718+24*seq);
  float r = 1.+fract(dither+10*seq);
  for(int i = 0;i<AO_SAMPLES;i++){
    r+=1./r;
    angle *= Grot;
    vec2 sc = (r-1.)*angle+tc;
    if(sc == clamp(sc,0.,1.)){
      vec3 sp = screen2view(vec3(sc,texture2D(depthtex1,sc).r))-p;
      float o = max(0.,dot(n,sp)-.1)/(dot(sp,sp)+.0001);
      a+=o;
    }
  }
  return max(0.,-2.*(a/AO_SAMPLES)+1.);
}
#endif








/*DRAWBUFFERS:014*/
void main(){
  vec4 col = texture2D(gcolor,tc);
  vec3 pbr = texture2D(colortex3,tc).rgb;


  dither = dither16(gl_FragCoord.xy);
  vec3 normal = texture2D(gnormal,tc).rgb*2.-1.;
  float pixdpth = texture2D(depthtex1,tc).r;
  float r =texture2D(gdepth,tc).r;
  vec3 rd = normalize(screen2view(vec3(tc,1.)));

  if(pixdpth>=1. ){
    r=1.;

    col.rgb = vec3(.013,.005,.004);
  }
  float ao=r;
  //csh = 1.;
  if(pixdpth<1.){
    #ifdef AMBIENT_OCCLUSION
      ao *= ssao(pixdpth,normal) ;
    #endif
    gl_FragData[2] = vec4(0.,0.,0.,1.);

  }else{
    gl_FragData[2] = vec4(0,0,0,1.);
  }

  col.rgb*=.5;
  gl_FragData[0] = col;
  gl_FragData[1] = vec4(ao,0.,r,1);
}
