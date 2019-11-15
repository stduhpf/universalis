#version 120
#include "../lib/essentials.glsl"
#include "../lib/shadowtransform.glsl"
#include "../lib/trans.glsl"

uniform vec3 shadowLightPosition;



float dither;

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


#include "/lib/lmcol.glsl"


#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));




vec3 hash33c(vec3 p3){
    p3 = mod(p3+50.3,100.6)-50.3;
	   p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract((p3.xxy + p3.yxx)*p3.zyx)-.5;
}

vec3 dephash(vec3 p){
    return p+hash33c(p);
}

float worley(vec3 p){
    vec3 P =floor(p);
    vec3 p0 = dephash(P)
        ,p1= dephash(P+vec3(0,0,1))
        ,p2= dephash(P+vec3(0,1,0))
        ,p3= dephash(P+vec3(0,1,1))
        ,p4= dephash(P+vec3(1,0,0))
        ,p5= dephash(P+vec3(1,0,1))
        ,p6= dephash(P+vec3(1,1,0))
        ,p7= dephash(P+vec3(1,1,1));
    float d0 = distance(p,p0),
          d1 = distance(p,p1),
          d2 = distance(p,p2),
          d3 = distance(p,p3),
          d4 = distance(p,p4),
          d5 = distance(p,p5),
          d6 = distance(p,p6),
          d7 = distance(p,p7);
    float md = min(min(min(d0,d1),min(d2,d3)),min(min(d4,d5),min(d6,d7)));
 return 1.-(md)*2.3;
}

float hash13(vec3 p3){
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract(dot(p3,vec3(1)));

}


#define VOL_STEPS 8 //[2 4 8 16 32]
#define VOLUMETRIC_LIGHT

#ifdef VOLUMETRIC_LIGHT
vec3 volumeLight(vec3 c,vec3 rd){

  //vec3 rd = screen2cam(p1);
  vec3 p = gbufferModelViewInverse[3].xyz;
  vec3 st = (rd-p)/float(VOL_STEPS);
  vec3 shade =vec3(0.);

  p+=st*fract(dither);
  float stlen = length(st);


  vec3 fogColor = vec3(.013,.005,.004);


  vec3 lc = vec3(.3,.1,.1);

  float m = 1.;
  vec3 trans = vec3(0);

  for(int i=0;i<VOL_STEPS;i++){
    float density=.25*saturate(1.-abs(worley((p+cameraPosition)*.01)*worley((p+cameraPosition-frameTimeCounter)*.1)));
    density*=density;
    float den = density*stlen;
    float l = .01*den;
      shade=mix(fogColor,lc,l);

      float ext= exp2(-den);
      trans+=m*shade*(1.-ext);
      m*=ext;
      if(m<.001){
        break;
      }
      //c=mix(shade,c,ext);
      p+=st;
  }
  return c*m+trans;
}
#endif

/*DRAWBUFFERS:0*/
void main(){
  vec3 c = texture2D(colortex0,tc).rgb;
  float pd = texture2D(depthtex0,tc).r;


  vec3 hc = vec3(gl_FragCoord.xy,mod(frameCounter*3.,PI)*50.);
  dither =  hash13(hc-hc.zxy);

  //dither = pd<1.?dither:.35+.3*dither;


  vec3 n = texture2D(colortex2,tc).rgb*2.-1.;

  float iswater = length(n)<.8?1.:0.;
  n = normalize(n);


  vec3 p = (vec3(tc,pd));
  vec3 viewp = screen2view(p);

  float depth = depthBlock(pd);




    vec3 rd = camdir(viewp);
    #ifdef VOLUMETRIC_LIGHT
    c=volumeLight(c,rd);
    //fogColor = vol.rgb;
    #else
    vec3 fogColor = vec3(.1,.9,.05);
    float vol=1.;
    c=mix(c,fogColor,vol);
    #endif

  gl_FragData[0] = vec4(c,1.);//texture2D(colortex1,tc*.5+vec2(.5,0.));

}
