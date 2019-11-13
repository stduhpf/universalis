#version 120
#include "lib/essentials.glsl"
#include "lib/trans.glsl"
#include "lib/sky.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex1;


varying vec2 tc;

uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform int worldTime;
uniform float rainStrength;
uniform float wetness;


#define iTime frameTimeCounter


#include "lib/clouds.glsl"

#define CLOUD_SHADOW_QUALITY 2.0 //[1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0]

float cloudsh(vec3 ro,vec3 rd,vec2 I){
  float h = dot(vec3(0,cloud_min_plane,0)-ro,vec3(0,1,0))/dot(rd,vec3(0,1,0));
  float h2 = dot(vec3(0,cloud_top_plane,0)-ro,vec3(0,1,0))/dot(rd,vec3(0,1,0));
  if((h<0.&&h2<0.))
    return 1.;
  float t= h;
  h=max(h,h2),
  h2 = minp(t,h2);
  if(h2==0.)h=min(h,100.);
  float d = bayer16(I*resolution);
  vec3 p = ro+(h-d*(h2-=h)/CLOUD_SHADOW_QUALITY)*rd;
  float a =0.;
  float sts = h2/CLOUD_SHADOW_QUALITY;
    for(int i = 0;i++<int(CLOUD_SHADOW_QUALITY)+1&&a<CLOUD_SHADOW_QUALITY*.8;p+=rd*sts){
        float v =max(cloods2(p),0.);
        a+=v;
      }
  return exp2(-a*abs(sts)*cloud_den);
}


/*DRAWBUFFERS:4*/
void main(){
  vec2 ntc =tc*2.;
  vec3 ld = camdir(normalize(shadowLightPosition));
  if(floor(ntc)==vec2(0)){
    vec3 p = screen2world(vec3(ntc,texture2D(depthtex1,ntc).r));
    gl_FragData[0]=vec4(cloudsh(p,ld,tc),0.,0.,1.);

  }
  /*else{
    if(floor(ntc)==vec2(0)){
      vec3 rd = normalize(screen2cam(vec3(ntc,1.)));
      vec3 c = vec3(0,1,0);
      vec4 cl = trace(cameraPosition,rd,tc,ld,c);
          c = mix(cl.rgb,c,cl.a);

      gl_FragData[0]=vec4(c,1.);

    }else{
      gl_FragData[0]=vec4(0.,0.,0.,1.);
    }
  }
*/
}
