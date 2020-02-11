#version 130
#include "lib/trans.glsl"
#include "lib/essentials.glsl"
#include "lib/shadowtransform.glsl"
#include "lib/sky.glsl"


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


#define GI_SAMPLES 8  //[1 2 4 8 12 16 32 64 128]
#define GI_DITHER_SCALE 1  //[1 2 3 4 5 6 7 8] //increases noise but saves framerate
#define RSM_DIST .1 //[.01 .015 .02 .025 .05 .075 .1 .2 .3 .4 .5 .6 .7 .8 .9 1.]


#define AMBIENT_OCCLUSION
#define GLOBAL_ILLUMINATION

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

#include "lib/shadow.glsl"

#define OREN_NAYAR_DIFFUSE


#ifdef OREN_NAYAR_DIFFUSE

float diffuse(vec3 v, vec3 l, vec3 n, float r) {
    r *= r;

    float cti = dot(n,l);
    float ctr = dot(n,v);

    float t = max(cti,ctr);
    float g = max(.0, dot(v - n * ctr, l - n * cti));
    float c = g/t - g*t;

    float a = .285 / (r+.57) + .5;
    float b = c * .45 * r / (r+.09);

    return max(0., cti) * ( b + a);
}
#endif


#ifdef GLOBAL_ILLUMINATION

vec3 rsm(float pixdpth,vec3 normal,vec3 pbr){
  normal = camdir(normal);
  vec3 view = screen2view(vec3(tc,pixdpth));
  vec3 p = view2cam(view);
  vec3 sp = scam2clip(p);
  const float inte = 128.*128/(shadowDistance*shadowDistance);
  float dither = bayer64(gl_FragCoord.xy/GI_DITHER_SCALE+frameCounter%GI_DITHER_SCALE);

  vec3 a = vec3(0);
  float anglev = dither*TAU+frameCounter*GA;
  vec2 angle = vec2(cos(anglev),sin(anglev));
  float rstep = RSM_DIST/float(GI_SAMPLES);
  float r = rstep*fract(15.*dither+frameCounter*TAU);
  #ifdef OREN_NAYAR_DIFFUSE
    float rough = (1.-pbr.r);
    rough*=rough;
  #endif
  float sweight = 0.;
  for(int i = 0;i<GI_SAMPLES;i++){
    r+=rstep;
    angle *= Grot;
    vec2 sc = r*angle+sp.xy;

    vec2 sc2 = stransform2(sc)*.5+.5;
    vec3 ssp = sclip2cam(vec3(sc,stransformd(texture2D(shadowtex1,sc2).r*2.-1.)));

    float weight = sqrt(r);
    sweight+=weight;

    vec3 dep = (p-ssp);
    float ld = dot(dep,dep)*inte;


    dep=normalize(dep);
    vec3 snv = normalize(texture2D(shadowcolor1,sc2).rgb*2.-1.);
    vec3 sn = scamdir(snv);
    #ifdef OREN_NAYAR_DIFFUSE
    a+=weight*texture2D(shadowcolor0,sc2).rgb*max(0.,snv.z)*max(0,diffuse(-normalize(view),-dep,normal,rough))*max(0,dot(sn,dep))/(ld);
    #else
    a+=weight*texture2D(shadowcolor0,sc2).rgb*max(0.,snv.z)*max(0,dot(normal,-dep))*max(0,dot(sn,dep))/(ld);
    #endif
  }
  #include "lib/lightcol.glsl"
	return shadowDistance*shadowDistance*lightCol*a*8.6*RSM_DIST*RSM_DIST*inte/sweight;
}
#endif
vec3 colorshadow(float pixdpth,vec3 pbr,inout float sh,vec3 rd,vec3 n){
  #include "lib/lightcol.glsl"
  #ifdef OREN_NAYAR_DIFFUSE
    float rough = (1.-pbr.r);
    rough*=rough;
  #endif
  vec3 scp = vec3(tc,pixdpth);
  vec3 p = screen2cam(scp);
  vec3 sp = stransformcam(scam2clip(p))*.5+.5;
  sp.z-=.0001;
  sp.z = sp.z-shadow_offset*(SHADOW_BIAS+length8(sp.xy));
  float s =1.;
  float i = smoothstep(sp.z-pbr.b*.015,sp.z,texture2D(shadowtex1,sp.xy).r);
  vec3 col = texture2D(gcolor,tc.xy).rgb*((i>=1.)?0.:i*i)*lightCol;//sss
  #ifdef COLORED_SHADOW
  if(texture2D(shadowtex0,sp.xy).r<texture2D(shadowtex1,sp.xy).r && sh>0.){
    #ifdef OREN_NAYAR_DIFFUSE
    float i = diffuse(-rd,normalize(shadowLightPosition),n,rough);
    #else
    float i = saturate(dot(rd,normalize(shadowLightPosition)));
    #endif
    col+=sh*texture2D(shadowcolor0,sp.xy).rgb*lightCol*i*2.;
    sh=0.;
  }
  #endif
//  #ifdef PCSS
//  return min(s,getSoftShadows(sp,max(getPenumbra(sp),1.41421356237/float(shadowMapResolution*MC_SHADOW_QUALITY)),pixdpth));
//  #else
  return col*2.;
//  #endif
}
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
    /*col.rgb = texture2D(colortex4,tc/3.).rgb;
    float maxrb = max( col.r, col.b );
    float k = clamp( (col.g-maxrb)*5.0, 0.0, 1.0 );
    float dg = col.g;
    col.g = min( col.g, maxrb*0.8 );
    col.rgb += dg - col.g;
    col.rgb = mix(col.rgb, getSky(rd,0.), k);*/
    col.rgb = getSky(camdir(rd),0.);
  }
  float ao=r,sh=1.;
  float csh = texture2D(colortex4,tc*.5).r;
  //csh = 1.;
  if(pixdpth<1.){
    #ifdef AMBIENT_OCCLUSION
      ao *= ssao(pixdpth,normal) ;
    #endif
    sh =  shadow(pixdpth)*texture2D(gdepth,tc).g*csh;
    #ifdef GLOBAL_ILLUMINATION
      vec3 gi = rsm(pixdpth,normal,pbr);
      gi+=colorshadow(pixdpth,pbr,sh,rd,normal);
      gi*=csh;
      gl_FragData[2] = vec4(gi,1.);
    #else
      gl_FragData[2] = vec4(0.,0.,0.,1.);
    #endif
  }else{
    gl_FragData[2] = vec4(0,0,0,1.);
  }

  col.rgb*=.5;
  gl_FragData[0] = col;
  gl_FragData[1] = vec4(ao,sh,r,1);
}
