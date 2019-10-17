#version 120
#include "lib/essentials.glsl"
#include "lib/shadowtransform.glsl"
#include "lib/trans.glsl"
#include "lib/sky.glsl"

#include "lib/clouds.set"

float dither;

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
vec3 lc=vec3(0.);

#define SSR
#define SHADOW_SPACE_REFLECTION


#define SSR_STEPS 8 //[4 8 12 16 24 32 64]$
#define SSR_REJECTION
#define SSR_FILTER 4 //[1 2 4 8 16]

#define SSR_MIN_PREC .05 //[.02 .03 .04 .05 .06 .07 .08 .1 .2]

#define SHSR_STEPS 8 //[4 8 12 16 24 32 64]
#define SHSR_PREC .4 //[.05 .1 .15 .2 .25 .3 .35 .4 .45 .5 .55]
#define SHSR_PREC_BIAS .2 //[.01 .02 .03 .04 .05 .06 .07 .08 .09 .1 .11 .12 .13 .14 .15 .16 .17 .18 .19 .2 .22 .24 .26 .28 .3 .35 .4 .5 1.]

//#define shadowtex1 shadowtex0
#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));
#include "lib/shadow.glsl"

bool isout=false;
float outsideness = 0.;

vec3 lightDir,lightcol;

#define USE_METALS

float brdflight(vec3 n, vec3 v, vec3 l,float r){

  r+=.0025;
  float d = max(dot(n,normalize(v+l)),0.);
  d*=d;
  float a = .5*r/(d*r*r+1.-d);
  return a*a/PI;
}

vec3 ssr2(vec3 p,vec3 rd,vec3 n,int count,float sh, float rough){
  rd = reflect(rd,n);
  vec3 ret= getSky(camdir(rd),rough)*.5+dither*0.01;
  return ret;
}

vec3 ssr(vec3 p,vec3 rd,vec3 n,int count,float sh, float rough, float fresnel,float highlight){
  vec3 P=p,RD=rd;
  rd = reflect(rd,n);
  vec3 gi = texture2D(colortex4,tc).rgb*.5;
  vec3 sky = .5*(getSky2(camdir(rd))+dither*0.01);

  vec3 cl = texture2D(colortex1,tc*.5).rgb;
  float maxrb = max( cl.r, cl.b );
  float k = saturate( (cl.g-maxrb)*2.0);
  float dg = cl.g;
  cl.g = min( cl.g, maxrb*0.8 );
  cl += dg - cl.g;
  cl = mix(cl,vec3(.1,.05,.6),(k)*step(1.5-rainStrength,length(skyColor)));
  k*=k;
  sky = mix(cl, sky, k*k);

  int ITER =int(ceil(float(SSR_STEPS)*(1.-rough)));

  vec3 ret= true?mix(max(sky,gi*.25),gi,1.-outsideness):gi;
  ret = mix(ret, getsuncol(camdir(rd)),highlight*sh*k);
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
          ret = texture2D(colortex0,p.xy).rgb;
          float m  = texture2D(colortex3,p.xy).g;
          #ifdef USE_METALS
          if(m>.9)
            ret*=texture2D(colortex4,p.xy).rgb;
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
    #ifdef SHADOW_SPACE_REFLECTION
    if(nohit && isout){
      vec3 d=normalize(view2cam(rd));
      p=screen2cam(P);
      p+=(dither+.2)*d;
      float stepl=SHSR_PREC;
      for(int i =0;i<SHSR_STEPS;i++){
        vec3 sc = stransformcam(scam2clip(p))*.5+.5;
        if(floor(sc.xy)!=vec2(0))
          break;
        float depth = texture2D(shadowtex1,sc.xy).r;
        if(depth<sc.z){
          //ret = vec3(depth-sc.z);
          if(sc.z-depth<abs(stepl*stepl*.001)&&depth<1.){
            vec3 n = texture2D(shadowcolor1,sc.xy).rgb*2.-1.;
            vec3 l = lc*max(0.,n.z);
            ret = l*texture2D(shadowcolor0,sc.xy).rgb*.5;
          break;
        }
      }
        stepl += SHSR_PREC_BIAS*i;
        p+=d*stepl;
      }
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

vec3 cosineDirection( in vec3 nor,float r, vec2 fc)
{
	 float seed=frameTimeCounter*120.1;
    mat3 tbn = gettbn(nor);

    float u = r*hash13(vec3(fc, 78.233) + seed);
    float v = TAU*hash13( vec3(fc,10.873 )+ seed);
    return  normalize(tbn*vec3(sqrt(u)*vec2(cos(v),sin(v)) , sqrt(1.0-u)));
}



vec3 ssrs(vec3 p, vec3 rd, float rough,float sh, float fresnel){
  vec3 c = vec3(0);
  vec3 n = normalize(texture2D(colortex2,tc).rgb*2.-1.);
  float highlight = abs(brdflight(n,-rd,normalize(shadowLightPosition),rough));
  float rq = rough*rough;
  //rq *=rq;
  for(int i=0;i<SSR_FILTER;i++){

  vec3 n = cosineDirection(n,rq,gl_FragCoord.xy);

  c+= ssr(p,rd,n,i,sh,rough,fresnel,highlight);
  }
  return c/float(SSR_FILTER);
}

float getCloudShadow(vec3 p)
{
  if(p.y>cloud_mid)
    return 1.;
  vec3 slp = normalize(view2cam(shadowLightPosition));
  p-=slp*p.y/slp.y;
  vec2 pc = ((p.xz+.5*resolution)/resolution);
  return pc==fract(pc)?saturate(texture2D(colortex1,pc*.5+vec2(.5,0)).r):1.;
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
  p2=p2-st*(dither+1.);
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
  float dither = hash13(vec3(gl_FragCoord.xy,mod(frameCounter,TAU)*50.));
  p-=st*fract(dither);

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
      rba +=rb*(.1+.1*wetness)*rayl*rayl*(1.-ext);
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
  outsideness = smoothstep(.6,1.,texture2D(colortex7,tc).g);
  isout = outsideness>=.5;
  //c*=outsideness;
  dither = fract(dither16(gl_FragCoord.xy)+frameTimeCounter*240.);
  float pd = texture2D(depthtex0,tc).r;

  vec3 p = (vec3(tc,pd));
  vec3 viewp = screen2view(p);
  vec3 pbr = texture2D(colortex3,tc).rgb;
  //pbr.g=.134;
  //pbr.r = .9;
  float f0 = pbr.g*pbr.g;

  vec3 n = texture2D(colortex2,tc).rgb*2.-1.;

  float iswater = length(n)<.8?1.:0.;
  n = normalize(n);
  float sh = 0.;
  if(iswater>.5)
    sh=shadow3(p);
    else
    sh=texture2D(colortex7,tc).b;

  lc = lightcol;

  vec3 rd = normalize(viewp);
  float roughness = pow(1 - pbr.r, 2);
  float fresnel=0.;
  //pbr.g++;
  #ifdef USE_METALS
  if(pbr.g>.9)
    fresnel=1.;
    else
  #endif
    fresnel = ((1.0 - f0) * pow(1.0 - clamp(dot(-rd, n), 0.0, 1.0), 5.0)*(pbr.r*pbr.r) + f0);
  //fresnel=1.;

  float depth = depthBlock(pd);

  if(pd<1.&&fresnel>0.001){
    if(iswater>.5){
          float deltad =isEyeInWater<=0? abs(depthBlock(texture2D(depthtex1,tc).r)-depth):0.;
    #ifdef VOLUMETRIC_WATER
          c = volumeWater(p,vec3(tc,texture2D(depthtex1,tc).r),sh,c);
    #else
    c= mix(vec3(.005,.007,.03)*lightCol,c,exp2(-deltad*WATER_THICCNESS));
    #endif

          c=mix(.1*vec3(.05,.07,.3)*lightcol,c,mix(1.,sh,.3));
    }

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
    c=ref*texture2D(colortex0,tc).rgb*2.;
    else
    #endif
    c=mix(c,ref,fresnel);


  }

  if((pd<1.?depth:1e6)>=max((cloud_low-cameraPosition.y)/camdir(rd).y,0.)){
    vec3 cl = texture2D(colortex1,tc/2.+.5).rgb;
    float maxrb = max( cl.r, cl.b );
    float k = saturate( (cl.g-maxrb)*2.);
    float dg = cl.g;
    cl.g = min( cl.g, maxrb*0.8 );
    cl += dg - cl.g;
    cl = saturate3(cl);
    cl = mix(cl,vec3(.1,.05,.6),(k)*step(1.5-rainStrength,length(skyColor)));
    k*=k;
    c = mix(cl, c,k*k);
  }


  if(isEyeInWater>0){
    #ifdef VOLUMETRIC_WATER
    c = volumeWater(vec3(0),p,0.,c);
    #else
    c= mix(vec3(.005,.007,.03)*lightCol,c,exp2(-depth*WATER_THICCNESS));
    #endif

  }else{

    vec3 rd = camdir(screen2view(p));
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
