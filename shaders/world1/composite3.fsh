#version 120
#include "/lib/essentials.glsl"
#include "/lib/trans.glsl"




float dither,dit;

varying vec2 tc;
uniform sampler2D colortex7;
uniform sampler2D colortex4;
uniform sampler2D colortex3;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform float frameTimeCounter;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;


uniform sampler2D noisetex;

uniform int frameCounter;
uniform int isEyeInWater;

uniform float wetness;
uniform float rainStrength;

uniform vec3 skyColor;


uniform int worldTime;


#include "/lib/ambcol.glsl"
#include "/lib/lmcol.glsl"


#define SSR


#define SSR_STEPS 8 //[4 8 12 16 24 32 64]$
#define SSR_REJECTION
#define SSR_FILTER 4 //[1 2 4 8 16]

#define SSR_MIN_PREC .05 //[.02 .03 .04 .05 .06 .07 .08 .1 .2]


//#define shadowtex1 shadowtex0
#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));


bool isout=false;
float outsideness = 0.;


#define USE_METALS



vec3 ssr2(vec3 p,vec3 rd,vec3 n,int count,float sh, float rough){
  rd = reflect(rd,n);
  vec3 ret=  vec3(.013,.005,.004);
  return ret;
}


vec3 ssr(vec3 p,vec3 rd,vec3 n,int count,float sh, float rough, float fresnel,float highlight){
  vec3 P=p,RD=rd;
  rd = reflect(rd,n);
  vec3 gi = texture2D(colortex4,tc).rgb*.25;

  int ITER =int(ceil(float(SSR_STEPS)*(1.-rough)));

  vec3 ret=gi;// min3(vec3(.013,.005,.004),gi);
 bool nohit = true;
 if(fresnel-.5*rough>.01){
   #ifdef SSR
    vec3 d = normalize(view2screen(screen2view(p)+rd)-p);
    float iter = float(ITER+1);
    vec3 toBord = (step(0,d)-p)/(d*iter); //distances to borders divided by the number of steps
    float limstep =max(min(1./iter,SSR_MIN_PREC),min(min(toBord.x,toBord.y),toBord.z));
    float stepl =(.1+.9*fract(dither+count/float(SSR_FILTER)))*limstep;
  p+=stepl*d;
    for(int i =0;i<ITER;i++){
      nohit=true;
      if((floor(p.xy)!=vec2(0)))
        break;
      float depth = texture2D(depthtex1,p.xy).r;
      vec3 n = texture2D(colortex2,p.xy).rgb*2.-1.;
      if(depth<p.z&& dot(n,rd)<0.){
        #ifdef SSR_REJECTION
        if(p.z-depth-.001<abs(stepl*d.z)&&depth<1.){
          nohit = false;
          ret = texture2D(colortex0,p.xy).rgb*2.;
          float m  = texture2D(colortex3,p.xy).g;
          #ifdef USE_METALS
          if(m>.9)
            ret*=texture2D(colortex4,p.xy).rgb*.25;
          #endif

        }

        #else
        if(depth<1.){
          ret = texture2D(colortex0,p.xy).rgb;
          float m  = texture2D(colortex3,p.xy).g;
          #ifdef USE_METALS
          if(m>.9)
            ret*=texture2D(colortex4,p.xy).rgb;
          #endif
          nohit=false;
        }
        #endif
        break;
      }
      stepl =clamp((depth-p.z)/abs(d.z),.01*limstep,limstep);
      p+=stepl*d;
    }

    #endif
}
  return ret;
}

vec3 hash33(vec3 p3){
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract((p3.xxy + p3.yxx)*p3.zyx);

}
float hash13(vec3 p3){
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract(dot(p3,vec3(1)));

}
mat3 gettbn(vec3 nor){
    vec3 tc = vec3( 1.0+nor.z-nor.xy*nor.xy, -nor.x*nor.y)/(1.0+nor.z);
    vec3 uu = vec3( tc.x, tc.z, -nor.x );
    vec3 vv = vec3( tc.z, tc.y, -nor.y );
    return mat3(uu,vv,nor);
}

vec3 cosineDirection( in vec3 nor,float r, vec2 fc, int it)
{
	 float seed= dither8(fc);//+frameTimeCounter*120.1;
    mat3 tbn = gettbn(nor);

    float seqf = haltonSeq(13,it);

    float u = r*fract(haltonSeq(5,frameCounter)+seed+seqf);//hash13(vec3(fc, 78.233) + seed);
    float v = TAU*fract(haltonSeq(7,frameCounter+12+int(seed*16.))-seqf);//hash13( vec3(fc,10.873 )+ seed);
    return  normalize(tbn*vec3(sqrt(u)*vec2(cos(v),sin(v)) , sqrt(1.0-u)));
}



vec3 ssrs(vec3 p, vec3 rd, float rough,float sh, float fresnel){
  vec3 c = vec3(0);
  vec3 n = normalize(texture2D(colortex2,tc).rgb*2.-1.);
  float rq = rough*rough;
  //rq *=rq;
  for(int i=0;i<SSR_FILTER;i++){

  vec3 n = cosineDirection(n,rq,gl_FragCoord.xy,i);

  c+= ssr(p,rd,n,i,sh,rough,fresnel,.0);
  }
  return c/float(SSR_FILTER);
}



/*DRAWBUFFERS:04*/
void main(){

  vec3 c = texture2D(colortex0,tc).rgb;
  vec3 refc = vec3(0);
  outsideness = smoothstep(.6,1.,texture2D(colortex7,tc).g);
  isout = outsideness>=.5;
  //c*=outsideness;

  vec3 hc = vec3(gl_FragCoord.xy,mod(frameCounter*3.,PI)*50.);
  dit = hash13(hc-hc.zxy);


  dither = fract(dither16(gl_FragCoord.xy)+frameTimeCounter*240.);
  float pd = texture2D(depthtex0,tc).r;

  vec3 p = (vec3(tc,pd));
  vec3 viewp = screen2view(p);
  vec3 pbr = texture2D(colortex3,tc).rgb;
  //pbr.g=.134;
  //pbr.r = .9;
  float f0 = pbr.g*pbr.g;

  vec3 n = texture2D(colortex2,tc).rgb*2.-1.;

  n = normalize(n);
  float sh = 0.;



  vec3 rd = normalize(viewp);
  float roughness = (1 - pbr.r);
  roughness*=roughness;
  float fresnel=0.;
  //pbr.g++;
  #ifdef USE_METALS
  if(pbr.g>.9)
    fresnel=1.;
    else
  #endif
    fresnel = ((1.0 - f0) * pow(1.0 - clamp(dot(-rd, n), 0.0, 1.0), 5.0)*(pbr.r) + f0);
  //fresnel=1.;

  float depth = depthBlock(pd);

  if(pd<1.&&fresnel>0.001){

    vec3 ref = ssrs(p,rd,roughness,sh,fresnel);
    /*
    float n0 = 1.33;
    n0=1./n0;
    vec3 rt = refract(rd, n, n0);
    float cti = dot(rd,n),ctt = dot(rt,n);
    float fresnel = (cti-n0*ctt)/(cti+n0*ctt);
    fresnel*=fresnel;
    float fresnel2 = (n0*ctt-cti)/(cti+n0*ctt);
    fresnel =saturate(.5*(fresnel+fresnel2*fresnel2));
    //*/
    #ifdef USE_METALS
    if(pbr.g>.9)
    refc=ref*texture2D(colortex0,tc).rgb*2.,c*=0.;
    else
    #endif
    c*=(1.-fresnel),refc=ref*fresnel;

  }


  gl_FragData[0] = vec4(c,1.);//texture2D(colortex1,tc*.5+vec2(.5,0.));
  gl_FragData[1] = vec4(refc,1.);//texture2D(colortex1,tc*.5+vec2(.5,0.));

}
