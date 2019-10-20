#version 120
#include "lib/essentials.glsl"
#include "lib/trans.glsl"
#include "lib/temp.glsl"

const bool colortex6Clear = false;


varying vec2 tc;
uniform sampler2D colortex6;
uniform sampler2D colortex2;
uniform sampler2D colortex1;
uniform sampler2D colortex0;
uniform sampler2D depthtex1;



/*DRAWBUFFERS:06*/
void main(){
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
  c=mix(lastc,c,.1);
  gl_FragData[1]=vec4(c,1.);

  gl_FragData[0] = vec4(c,1.);
}
