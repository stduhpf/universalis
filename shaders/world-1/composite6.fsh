#version 120
#include "/lib/essentials.glsl"
#include "/lib/trans.glsl"
#include "/lib/temp.glsl"

const bool colortex6Clear = false;


varying vec2 tc;
uniform sampler2D colortex6;
uniform sampler2D colortex2;
uniform sampler2D colortex1;
uniform sampler2D colortex0;
uniform sampler2D depthtex1;
uniform int frameCounter;

#define TAA_STRENGTH .1 //[.05 .1 .15 .2 .25 .3 .4 .5 .75 .9 1.]

#define AVGEXPS 20.
#define expocurve 200.
#define EXPOSURE_SPEED .01 //[.001 .0025 .005 .0075 .01 .015 .02 .05 1. 2.]
#define AUTO_EXPOSURE
/*DRAWBUFFERS:06*/
void main(){
  float avgexp=1.;
  #ifdef AUTO_EXPOSURE
  vec2 fc = tc*resolution;
  if(max(fc.x,fc.y)<5.){
    vec3 lumaWeights = vec3(.3,.59,.11);
    avgexp=0.;
    vec2 offset = vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));

    for(float x=0.;x<1.;x+=1./AVGEXPS){
      for(float y=0.;y<1.;y+=1./AVGEXPS){
        vec2 p = vec2(x,y)+(.5+offset)/AVGEXPS;
        float s =dot(texture2D(colortex0,p).rgb*2.,lumaWeights);
        avgexp += pow(s,1./expocurve);
        }
      }
    avgexp/=AVGEXPS*AVGEXPS;
    avgexp=pow(avgexp,expocurve)*50.;
  }
  #endif

  vec3 c = texture2D(colortex0,tc).rgb;
  float pd = texture2D(depthtex1,tc).r;
  vec3 p = (vec3(tc,pd));
  float reflectance = texture2D(colortex1,tc).g;


  vec3 clipPos = screen2clip(p);
  vec3 wpos = clip2view(clipPos);
  wpos = view2cam(wpos);//position relative to the view of the player
  vec3 pclipPos= pworld2clip(cam2world(wpos));
  float newdepth = pclipPos.z;
  pclipPos=pclipPos*.5+.5;

  vec3 lastc = floor(pclipPos.xy)==vec2(0.)?neighborhoodClip(tc,texture2D(colortex6, pclipPos.xy).rgb,colortex0):c;
  c=mix(lastc,c,TAA_STRENGTH);
  float expo = texture2D(colortex6,2./resolution).a;
  gl_FragData[1]=vec4(c,mix(avgexp,expo,exp2(-EXPOSURE_SPEED)));
  gl_FragData[0] = vec4(c/expo,1.);


}
