#version 120
#include "lib/essentials.glsl"
#include "lib/trans.glsl"
#include "lib/sky.glsl"
#include "lib/lmcol.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex1;


varying vec2 tc;

uniform sampler2D noisetex;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform int worldTime;
uniform float rainStrength;
uniform float wetness;



#define USE_METALS

uniform vec3 skyColor;



#include "lib/clouds.glsl"


#define CLOUD_RAYTRACING_QUALITY 4.0 //[1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0]
#define CLOUD_LIGHTING_QUALITY 2.0 //[1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0]

float shad(vec3 ro,vec3 rd,float d){
	const float dist = 80.;
    vec3 p = ro+dist*rd*d/CLOUD_LIGHTING_QUALITY;
    float a =1.;
    float sts = dist/CLOUD_LIGHTING_QUALITY;
    for(int i = 0;i++<int(CLOUD_LIGHTING_QUALITY)+1;p+=rd*sts){
        a*=exp2(-abs(sts)*max(cloods2(p),0.)*cloud_den);
    }

	return (a);
}
#include "lib/ambcol.glsl"


vec3 trace(vec3 ro,vec3 rd,vec2 I,vec3 ld,float dpt){

    float h = (cloud_min_plane-ro.y)/(rd.y);
    float h2 = (cloud_top_plane-ro.y)/(rd.y);
  if((h<0.&&h2<0.)||(h>dpt&&h2>dpt))
    return vec3(1.);
  float t= h;
  h=max(h,h2),
  h=min(h,dpt),
  h2 = minp(t,h2);
  if(h2==0.)h=min(h,240.);
  float d = fract(bayer16(I*resolution)+120.1*frameTimeCounter);

  float extinct = 1.;
  float lightness = 0.;
  vec3 p = ro+(h-d*(h2-=h)/CLOUD_RAYTRACING_QUALITY)*rd;
    float sts = h2/CLOUD_RAYTRACING_QUALITY;
    for(int i = 0;i++<int(CLOUD_RAYTRACING_QUALITY)+1;p+=rd*sts){
        float v =max(cloods(p),0.);
        float vp = exp2(-abs(sts)*cloud_den*v);
        extinct*=(vp);
        lightness = mix(shad(p,ld,d),lightness,vp);
    }
	return vec3(1.-(1.-extinct)*exp2(-h*.00015),lightness,extinct);
}

#define CLOUD_VL_QUALITY 4.0 //[1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0]
float cloudsh(vec3 ro,vec3 rd,vec2 I){
  float h = (cloud_min_plane-ro.y)/(rd.y);
  float h2 = (cloud_top_plane-ro.y)/(rd.y);
  if((h<0.&&h2<0.))
    return 1.;
  float t= h;
  h=max(h,h2),
  h2 = minp(t,h2);
  if(h2==0.)h=min(h,240.);
  float d = bayer16(I*resolution);
  vec3 p = ro+(h-d*(h2-=h)/CLOUD_VL_QUALITY)*rd;
  float a =0.;

  float sts = h2/CLOUD_VL_QUALITY;

    for(int i = 0;i++<int(CLOUD_VL_QUALITY)+1&&a<CLOUD_VL_QUALITY*.8;p+=rd*sts){
        float v =max(cloods2(p),0.);
        a+=v;
      }
  return exp2(-a*abs(sts)*cloud_den);
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

vec3 tracerough(vec3 ro,vec3 rd,vec2 I,vec3 ld,float dpt,float q){

    float h = (cloud_min_plane-ro.y)/(rd.y);
    float h2 = (cloud_top_plane-ro.y)/(rd.y);
  if((h<0.&&h2<0.)||(h>dpt&&h2>dpt))
    return vec3(1.);
  float t= h;
  h=max(h,h2),
  h=min(h,dpt),
  h2 = minp(t,h2);
  if(h2==0.)h=min(h,240.);
  float d = fract(bayer16(I*resolution));

  float extinct = 1.;
  float lightness = 0.;
  vec3 p = ro+(h-d*(h2-=h)/q)*rd;
    float sts = h2/q;
    for(int i = 0;i++<int(q)+1;p+=rd*sts){
        float v =max(cloods(p),0.);
        float vp = exp2(-abs(sts)*cloud_den*v);
        extinct*=(vp);
        lightness = mix(shad(p,ld,d),lightness,vp);
    }
	return vec3(1.-(1.-extinct)*exp2(-h*.00015),lightness,extinct);
}
#define CLOUD_REF_FILTER 4 //[1 2 4 8 16]
vec3 traceRough(vec3 ro,vec3 rd,vec2 I,vec3 ld,float dpt,float rough,vec3 n){
	  vec3 c = vec3(0);
	  float rq = rough*rough;
	  //rq *=rq;
		float q = ceil(CLOUD_RAYTRACING_QUALITY*(1.0-rough));
	  for(int i=0;i<int(1.+CLOUD_REF_FILTER*rough);i++){

	  vec3 n = cosineDirection(n,rq,gl_FragCoord.xy,i);

	  c+= tracerough(ro,reflect(rd,n),I,ld,dpt,q);
	  }
	  return c/ceil(CLOUD_REF_FILTER*rough);

}


/*DRAWBUFFERS:1*/
void main(){

  vec4 base = vec4(ambi*ambientCol,1.-.99*rainStrength);
  vec2 ntc =tc*2.;
  vec3 ld = camdir(normalize(shadowLightPosition));
    if(floor(ntc)==vec2(0)||floor(ntc)==vec2(1)){
      vec3 c = vec3(0,1,0);
      vec2 ntcf = fract(ntc);
      float pixdpth = boxmax(ntcf,depthtex1);
      vec3 p = screen2cam(vec3(ntcf,pixdpth));
      vec3 rd = normalize(p);
      p=cam2world(p);

      if(floor(ntc)==vec2(1)){
      //rd = normalize(screen2cam(vec3(ntc,1.)));

          vec3 cl = trace(cameraPosition,rd,tc,ld,pixdpth<1.?depthBlock(pixdpth):1e12);
          c =cl;
            //gl_FragData[0]=vec4(saturate3(cl.rgb*.5),cl.a);
      }else{
        if(pixdpth<1.){
          c = vec3(0,1,0);
          vec3 pbr = texture2D(colortex3,ntc).rgb;
          float f0 = pbr.g*pbr.g;
          vec3 n = texture2D(colortex2,ntc).rgb*2.-1.;
          n = camdir(normalize(n));
          float roughness = pow(1 - pbr.r, 2);
          float fresnel=0.;
          #ifdef USE_METALS
          if(pbr.g>.9)
            fresnel=1.;
            else
          #endif
            fresnel = ((1.0 - f0) * pow(1.0 - clamp(dot(-rd, n), 0.0, 1.0), 5.0) + f0)*(pbr.r*pbr.r);

          if(fresnel>.001)
          {
            //vec4 cl =base;
            //vec3 n = cosineDirection(n,roughness*roughness,gl_FragCoord.xy);
						vec3 cl=traceRough(p,rd,tc,ld,1e12,roughness,n);
            c += cl;

          }
        }
        //gl_FragData[0]=vec4(saturate3(c),1.);
      }
      gl_FragData[0]=vec4(saturate3(c),1.);

    }else{
      if(floor(ntc)==vec2(1,0)){
        vec3 p = cameraPosition+vec3((ntc-vec2(1.5,.5))*resolution,0.).xzy;
        gl_FragData[0]=vec4(cloudsh(p,ld,tc),0.,0.,1.);

      }else{
        gl_FragData[0]=vec4(0.,0.,0.,1.);
      }
    }

}
