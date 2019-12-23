#version 120
#include "lib/essentials.glsl"
#include "lib/shadowtransform.glsl"
#include "lib/trans.glsl"
#include "lib/sky.glsl"




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


#include "lib/ambcol.glsl"
#include "lib/lmcol.glsl"
#include "lib/clouds.set"

vec3 lc=vec3(0.);

#define SSR
#define SHADOW_SPACE_REFLECTION

#define FAKE_REFRACTION
//#define REFRACT_ALL_TRANSPARENTS

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
#include "lib/shadow.glsl"*


bool isout=false;
float outsideness = 0.;

vec3 lightDir,lightcol;

#define USE_METALS

float getCloudShadow(vec3 p)
{
  if(p.y>cloud_mid)
    return 1.;
  vec3 slp = normalize(view2cam(shadowLightPosition));
  p-=slp*p.y/slp.y;
  vec2 pc = ((p.xz+.5*resolution)/resolution);
  return pc==fract(pc)?saturate(texture2D(colortex1,pc*.5+vec2(.5,0)).r):1.;
}

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
  vec3 gi = texture2D(colortex4,tc).rgb*.25;
  vec3 sky = .5*(getSky2(camdir(rd))+dither*0.01);

  vec3 cl = texture2D(colortex1,tc*.5).rgb;
  vec3 amb = ambientCol*ambi*.5;
  vec3 cc = mix(amb,lightcol,cl.g);
  sky = mix(cc*.5, sky, cl.r);

  int ITER =int(ceil(float(SSR_STEPS)*(1.-rough)));

  vec3 ret= true?mix(max(sky,gi*.25),gi,1.-outsideness):gi;
  ret = mix(ret, getsuncol(camdir(rd)),highlight*sh*(cl.r));
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
            ret*=texture2D(colortex4,p.xy).rgb*.5;
          #endif

        }

        #else
        if(depth<1.){
          ret = texture2D(colortex0,p.xy).rgb*2.;
          float m  = texture2D(colortex3,p.xy).g;
          #ifdef USE_METALS
          if(m>.9)
            ret*=texture2D(colortex4,p.xy).rgb*.5;
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
            vec3 l = lc*max(0.,n.z)*getCloudShadow(p)+ambi*ambientCol;
            ret = l*texture2D(shadowcolor0,sc.xy).rgb;
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
  float highlight = abs(brdflight(n,-rd,normalize(shadowLightPosition),rough));
  float rq = rough*rough;
  //rq *=rq;
  for(int i=0;i<SSR_FILTER;i++){

  vec3 n = cosineDirection(n,rq,gl_FragCoord.xy,i);

  c+= ssr(p,rd,n,i,sh,rough,fresnel,highlight);
  }
  return c/float(SSR_FILTER);
}



#define WATER_VOL_STEPS 8 //[2 4 8 16 32]
#define VOLUMETRIC_WATER

#ifdef VOLUMETRIC_WATER
vec3 volumeWater(vec3 p1, vec3 p2,float sh, vec3 c){
  p1=screen2cam(p1),
  p2=screen2cam(p2);
  vec3 rd = p2-p1;
  vec3 st = rd/float(WATER_VOL_STEPS+1);
  float shade =sh;
  float stlen = length(st);
  p2=p2-st*(dit+1.);
  for(int i=1;i<WATER_VOL_STEPS;i++){
      shade+=shadow2(p2)*exp2(-distance(p1,p2)*WATER_THICCNESS*.01)*getCloudShadow(p2);
      c=mix((.3*shade+.1)*vec3(.05,.07,.3)*lightcol,c,exp2(-stlen*WATER_THICCNESS));
      p2-=st;
  }
  return c;
}
#endif

#define VOL_STEPS 8 //[2 4 8 16 32]
#define VOLUMETRIC_LIGHT

#ifdef VOLUMETRIC_LIGHT
vec3 volumeLight(vec3 c,vec3 rd,vec3 p){

  //vec3 rd = screen2cam(p1);
  rd-=p;
  vec3 st = rd/float(VOL_STEPS);
  p += rd;
  vec3 shade =vec3(0.);

  p-=st*fract(dit);

  vec3 fogColor = vec3(.058,.063,.08)*(1.+length(lightcol));
  float rayl = saturate(mix(dot(normalize(rd),lightDir),1.,.3));
  rayl=2.*pow(rayl,8.);
  rayl+=.6;

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
    float density=.0005+(.05*n.r*n.r+.05*wetd)*exp2(-abs(p.y+cameraPosition.y-62.)*(.1+.3*sqrt(n.g)*(1.-.9*wetness)));
    float den = density*stlen;
    float l = shadow2(p)*getCloudShadow(p);
      shade=mix(fogColor,lc,rayl*l);
      float ext= exp2(-den);
      c=mix(shade,c,ext);
      rba +=rb*(.1+.2*wetness)*l*rayl*rayl*(1.-ext);
      p-=st;
  }
  return c+rba;
}

vec3 volumeLightSky(vec3 c,vec3 rd,vec3 p0){

  float rdDotUp = abs(normalize(rd).y);
  float powe = 1./(1.-rdDotUp*.8);


  vec3 st = (rd-p0)/float(VOL_STEPS);
  vec3 shade =vec3(0.);
  float rdlen = length(rd);
  //p0+=st*fract(dither);
  float stlen = length(st);


  vec3 fogColor = vec3(.058,.063,.08)*(1.+length(lightcol));
  float rayl = saturate(mix(dot(normalize(rd),lightDir),1.,.3));
  rayl=2.*pow(rayl,8.);
  rayl+=.6;

  float wetd = wetness*wetness;
  wetd = wetd*wetd;
  vec3 li = lightcol*lightcol;
  vec3 rb = vec3(li.r,0,0)*smoothstep(.05,.0,abs(dot(normalize(rd),lightDir)+.1));
  rb = mix(rb,vec3(0,li.g,0),smoothstep(.05,.0,abs(dot(normalize(rd),lightDir)+.125)));
  rb = mix(rb,vec3(0,0,li.b),smoothstep(.04,.0,abs(dot(normalize(rd),lightDir)+.15)));
  vec3 lc =lightcol;
  vec3 rba = vec3(0);

  float m = 1.;
  vec3 trans = vec3(0);
  float dist = stlen*fract(dither);
  vec3 stn = normalize(st);
  float lpd = 0.;
  for(int i=0;i<VOL_STEPS;i++){
    float pdist = pow(dist/rdlen,powe)*rdlen;

    vec3 p = p0+stn*pdist;
    float postlen = abs(lpd-pdist);
    vec4 n = texture2D(noisetex,(p.xz+cameraPosition.xz- frameTimeCounter)*.0001);
    float density=.0005+(.05*n.r*n.r+.05*wetd)*exp2(-abs(p.y+cameraPosition.y-62.)*(.1+.3*sqrt(n.g)*(1.-.9*wetness)));
    float den = density*postlen;
    float l = shadow2(p)*getCloudShadow(p);
      shade=mix(fogColor,lc,rayl*l);

      float ext= exp2(-den);
      trans+=m*shade*(1.-ext);
      m*=ext;
      if(m<.01){
        break;
      }
      //c=mix(shade,c,ext);
      rba +=rb*(.2+.3*wetness)*l*rayl*rayl*(1.-ext);
      lpd = pdist;
      dist+=stlen;
  }
  return (c*m+trans+rba);
}

#endif

/*DRAWBUFFERS:04*/
void main(){
  #include "lib/lightcol.glsl"
  lightDir=lightdir,lightcol=lightCol;

  #include "lib/thunder.glsl"
  vec3 n = texture2D(colortex2,tc).rgb*2.-1.;

  float pd = texture2D(depthtex0,tc).r;
  float depth = depthBlock(pd);


  float iswater = length(n)<.8?1.:0.;
  #ifdef REFRACT_ALL_TRANSPARENTS
  float isTransp = depthBlock(texture2D(depthtex1,tc).r)-depth>.01?1.:0.;
  #else
  float isTransp = iswater;
  #endif
  #ifdef FAKE_REFRACTION
  vec3 vn = camdir(n);
  vec2 tct = tc+(isTransp>.5?vn.xy*vn.z*1.3/max(depth,1.):vec2(0))*smoothstep(0.,3.,abs(depthBlock(texture2D(depthtex1,tc).r)-depth));
  tct = tc+(isTransp>.5?vn.xy*vn.z*1.3/max(depth,1.):vec2(0))*smoothstep(0.,3.,abs(depthBlock(texture2D(depthtex1,tct).r)-depth));
  if(texture2D(depthtex1,tct).r==texture2D(depthtex0,tct).r)
    tct = tc;
#else
  #define tct tc
#endif
  vec3 c = texture2D(colortex0,tct).rgb;
  vec3 refc = vec3(0);
  outsideness = smoothstep(.6,1.,texture2D(colortex7,tct).g);
  isout = outsideness>=.5;
  //c*=outsideness;

  vec3 hc = vec3(gl_FragCoord.xy,mod(frameCounter*3.,PI)*50.);
  dit = hash13(hc-hc.zxy);


  dither = fract(dither16(gl_FragCoord.xy)+haltonSeq(7,frameCounter));

  vec3 p = (vec3(tc,pd));
  vec3 viewp = screen2view(p);
  vec3 pbr = texture2D(colortex3,tc).rgb;
  //pbr.g=.134;
  //pbr.r = .9;
  float f0 = pbr.g*pbr.g;


  n = normalize(n);
  float sh = 0.;
  if(iswater>.5)
    sh=shadow3(p);
    else
    sh=texture2D(colortex7,tc).b;

  lc = lightcol;

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
    fresnel = ((1.0 - f0) * pow(1.0 - clamp(dot(-rd, n), 0.0, 1.0), 5.0)*(pbr.r*pbr.r) + f0);
  //fresnel=1.;


  if(pd<1.&&fresnel>0.001){
    float pd2 = texture2D(depthtex1,tct).r;
    if(iswater>.5){
      float deltad =abs(depthBlock(pd2)-depth);

      if(isEyeInWater<=0){
    #ifdef VOLUMETRIC_WATER
          c = volumeWater(p,vec3(tc,pd2),sh,c);
    #else
          c= mix(vec3(.005,.007,.03)*lightCol,c,exp2(-deltad*WATER_THICCNESS));
    #endif

          c=mix(.1*vec3(.05,.07,.3)*lightcol,c,mix(1.,sh,.3));
        }else{
          c= pd2<1.?volumeLight(c,screen2cam(vec3(tc,pd2)),p):volumeLightSky(c,screen2cam(vec3(tc,pd2)),p);

        }
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
    refc=ref*texture2D(colortex0,tc).rgb*2.,c*=0.;
    else
    #endif
    c*=(1.-fresnel),refc=ref*fresnel;

  }


  if((pd<1.?depth:1e6)>=max((cloud_low-cameraPosition.y)/camdir(rd).y,0.)){
    vec3 cl = texture2D(colortex1,tc*.5+.501).rgb;
    vec3 amb = ambientCol*ambi*.5;
    vec3 cc = mix(amb,lightcol,cl.g);
    cc = mix(cc,vec3(.1,.05,.6),(1.-cl.r)*bolt);
    c = mix(cc*.5, c,cl.r);
  }

  gl_FragData[0] = vec4(c,1.);//texture2D(colortex1,tc*.5+vec2(.5,0.));
  gl_FragData[1] = vec4(refc,1.);//texture2D(colortex1,tc*.5+vec2(.5,0.));

}
