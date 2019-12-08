#version 120

const bool colortex5Clear = false;

#include "lib/trans.glsl"
#include "lib/essentials.glsl"
#include "lib/temp.glsl"

uniform sampler2D colortex0;
uniform sampler2D gnormal;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D colortex7;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

uniform int worldTime;
uniform vec3 skyColor;
uniform float rainStrength;


#define TEMPORAL_LIGHT_ACCUMULATION
#define GLOBAL_ILLUMINATION
#define GI_HQ_FILTER
#define GI_DITHER_SCALE 2  //[1 2 3 4 5 6 7 8]
#ifdef GI_HQ_FILTER
#define filtersize 2
#else
#define filtersize 1
#endif

uniform int frameCounter;

varying vec2 tc;




#ifdef GLOBAL_ILLUMINATION
vec3 filt(vec2 tc, sampler2D s){
  return texture2D(s,tc ).rgb;
  vec3 a = vec3(0);
  float b =0.;
  float dp =depthLin(texture2D(depthtex1,tc).r);
  for(int i =-1;i<1;i++){
    for(int j =-1;j<1;j++){
      float si = 3.-float(i+j+i*j);
      vec2 sc = tc+2.5*vec2(i,j)/resolution;
      if(abs(depthLin(texture2D(depthtex1,sc).r)-dp)<.001){
        a+=si*texture2D(s,sc ).rgb;
        b+=si;
      }
    }
  }
  return a/b;
}
#endif

#include "lib/lmcol.glsl"


float hash(float seed) {
    return fract(sin(seed)*43758.5453123);
}
/*DRAWBUFFERS:154*/
void main() {
  #include "lib/thunder.glsl"

  vec2 lmcoord=texture2D(colortex7,tc).rg;


  lmcoord*=lmcoord;

  vec3 naosh =  texture2D(colortex1, tc).rgb;
  float ao =naosh.x;
  vec3 boltc = bolt*ao*lmcoord.y*vec3(.1,.01,.4);
  #include "lib/ambcol.glsl"
  ao*=.05+lmcoord.y*ambi;
  #ifdef GLOBAL_ILLUMINATION


    const float kernel[6] = float[](9./64., 3./32., 3./128., 1./64., 1./16., 1./256.);
    vec3 sum =  vec3(0);
    float cum_w = 0.0;
    float c_phi = 1.0;
    float r_phi = 1.0;
    float n_phi = 0.5;
    float p_phi = 0.25;

    vec3 cval = texture2D(colortex4, tc).xyz;
    vec3 nval = texture2D(gnormal, tc).xyz;

    float ang = 2.0*3.1415926535*hash(2510.12860182*tc.x + 7290.9126812*tc.y+5.1839513*frameCounter);
    mat2 m = mat2(cos(ang),sin(ang),-sin(ang),cos(ang));
    float denoiseStrength = GI_DITHER_SCALE*(2. + 3.*hash(6410.128752*tc.x + 3120.321374*tc.y+1.92357812*frameCounter));
vec3 newgi = ambientCol*ao+boltc;
  for(int i=-filtersize; i<filtersize+1; i++){
    for(int j=-filtersize; j<filtersize+1; j++){
        vec2 uv = (tc+m*(vec2(i,j)* denoiseStrength)/resolution.xy);

        vec3 ctmp = texture2D(colortex4, uv).xyz;
        vec3 t = cval - ctmp;
        float dist2 = dot(t,t);
        float c_w = min(exp(-(dist2)/c_phi), 1.0);

        vec3 ntmp = texture2D(gnormal, uv).xyz;
        t = nval - ntmp;
        dist2 = max(dot(t,t), 0.0);
        float n_w = min(exp(-(dist2)/n_phi), 1.0);

        int kerk = int(abs(i)==0||abs(i)!=abs(j)?abs(i)+abs(j):3.+abs(i));

        float weight0 = c_w*n_w;
        sum += ctmp*weight0*kernel[kerk];
        cum_w += weight0*kernel[kerk];
      }
    }
  newgi += sum/cum_w;
  #else
        vec3 newgi = ambientCol*ao;
  #endif
#ifdef TEMPORAL_LIGHT_ACCUMULATION
    float pixdpth = texture2D(depthtex1,tc).r;
    float lpixdpth = depthLin(boxmin(tc,depthtex1));

    vec3 clipPos = screen2clip(vec3(tc,pixdpth));
    vec3 wpos = clip2view(clipPos);
    wpos = view2cam(wpos);//position relative to the view of the player

    vec3 pwpos = pworld2cam(cam2world(wpos));
    vec3 pclipPos= pcam2clip(pwpos);
    pclipPos=clip2screen(pclipPos);//*.5+.5;
    float newdepth = pclipPos.z;



    float nd =depthLin(newdepth);
    float maxd = boxmin(tc,depthtex1);

    vec3 lastgi = texture2D(colortex5, pclipPos.xy).rgb;

    vec3 t = newgi-lastgi;
    float distgi = dot(t,t);
    float p = .05+.95*exp(-distgi/p_phi);

    if(pclipPos.xy != clamp(pclipPos.xy,0,1)||texture2D(depthtex1,pclipPos.xy).r!=texture2D(depthtex2,pclipPos.xy).r){
        lastgi=newgi;
    }

        newgi = mix(lastgi,newgi,p);


      gl_FragData[0] = vec4(0.,naosh.yz,1);
      newgi = saturate3(newgi);
      gl_FragData[1] = vec4(newgi,1.);
      newgi+=TorchColor*(ao*.5+.5)*lmcoord.x;
      gl_FragData[2] = vec4(newgi,1.);
#else
      gl_FragData[0] = vec4(0.,naosh.yz,1);
      gl_FragData[2] =texture2D(colortex4, tc)+vec4(TorchColor*(naosh.x*.75+.25)*lmcoord.x,0)+vec4(ao*ambientCol,0.);
#endif

  }
