#version 120
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


#define GI_SAMPLES 4  //[1 2 4 8 12 16 32 64 128]


#define AMBIENT_OCCLUSION
#define GLOBAL_ILLUMINATION

#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));
float dither = 0;

#ifdef AMBIENT_OCCLUSION

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

vec3 rsm(float pixdpth,vec3 normal){
  normal = (camdir(normal));
  vec3 view = screen2view(vec3(tc,pixdpth));
  vec3 p = view2cam(view);
  vec3 sp = scam2clip(p);
  const float inte = 128.*128/(shadowDistance*shadowDistance);
  const float size = .05;

  vec3 a = vec3(0);
  vec2 angle = vec2(0,size/sqrt(float(GI_SAMPLES+1)));
  float seq = float(frameCounter)/17.;
  angle*=rot((dither+sign(dither)*10*seq)*6.28318530718);
  float r = 1.+fract(.5+dither-sign(dither)*24*seq);
  #ifdef OREN_NAYAR_DIFFUSE
    float rough = (1.-texture2D(colortex3,tc).r);
    rough*=rough;
  #endif
  for(int i = 0;i<GI_SAMPLES;i++){
    r+=1./r;
    angle *= Grot;
    vec2 sc = (r-1.)*angle+sp.xy;
    vec2 sc2 = stransform2(sc)*.5+.5;
    vec3 ssp = sclip2cam(vec3(sc,stransformd(texture2D(shadowtex1,sc2).r*2.-1.)));
    vec3 dep = (p-ssp);
    float ld = dot(dep,dep)*inte;
    dep=normalize(dep);
    vec3 sn = (scamdir(normalize(texture2D(shadowcolor1,sc2).rgb*2.-1.)));
    #ifdef OREN_NAYAR_DIFFUSE
    a+=texture2D(shadowcolor0,sc2).rgb*max(0,diffuse(-normalize(view),-dep,normal,rough))*max(0,dot(sn,dep))/(ld);
    #else
    a+=texture2D(shadowcolor0,sc2).rgb*max(0,dot(normal,-dep))*max(0,dot(sn,dep))/(ld);
    #endif
  }
  #include "lib/lightcol.glsl"
	return lightCol*a*100000.*size*size/float(GI_SAMPLES);
}
#endif

/*DRAWBUFFERS:014*/
void main(){
  vec4 col = texture2D(gcolor,tc);

  dither = dither16(gl_FragCoord.xy);
  vec3 normal = texture2D(gnormal,tc).rgb*2.-1.;
  float pixdpth = texture2D(depthtex1,tc).r;
  float r =texture2D(gdepth,tc).r;
  if(pixdpth>=1. ){
    r=1.;
    vec3 rd = normalize(screen2cam(vec3(tc,1.)));
    /*col.rgb = texture2D(colortex4,tc/3.).rgb;
    float maxrb = max( col.r, col.b );
    float k = clamp( (col.g-maxrb)*5.0, 0.0, 1.0 );
    float dg = col.g;
    col.g = min( col.g, maxrb*0.8 );
    col.rgb += dg - col.g;
    col.rgb = mix(col.rgb, getSky(rd,0.), k);*/
    col.rgb = getSky(rd,0.);
  }
  float ao=r,sh=1.;
  float csh = texture2D(colortex4,tc*.5).r*.85+.15;
  //csh = 1.;
  if(pixdpth<1.){
    #ifdef AMBIENT_OCCLUSION
      ao *= ssao(pixdpth,normal);
    #endif
    #ifdef GLOBAL_ILLUMINATION
      vec3 gi = rsm(pixdpth,normal)*csh;
      gl_FragData[2] = vec4(gi,1.);
    #else
      gl_FragData[2] = vec4(0.,0.,0.,1.);
    #endif
    sh =  shadow(pixdpth)*texture2D(gdepth,tc).g* csh;
  }else{
    gl_FragData[2] = vec4(0,0,0,1.);
  }

  col.rgb*=.5*r;
  gl_FragData[0] = col;
  gl_FragData[1] = vec4(ao,sh,r,1);
}
