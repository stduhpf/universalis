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
uniform int worldTime;
uniform float rainStrength;


#define iTime frameTimeCounter

#define USE_METALS

uniform vec3 skyColor;



float vnoise(vec2 a){
  return texture2D(noisetex,a).r;
}


vec3 hash33(vec3 p3){
    p3 = mod(p3+50.3,100.6)-50.3;
	   p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract((p3.xxy + p3.yxx)*p3.zyx)-.5;
}

vec3 dephash(vec3 p){
    return p+hash33(p);
}

float worley(vec3 p){
    p+=worldTime*vec3(.1,.02,.3)*.005;
    vec3 P =floor(p);
    vec3 p0 = dephash(P)
        ,p1= dephash(P+vec3(0,0,1))
        ,p2= dephash(P+vec3(0,1,0))
        ,p3= dephash(P+vec3(0,1,1))
        ,p4= dephash(P+vec3(1,0,0))
        ,p5= dephash(P+vec3(1,0,1))
        ,p6= dephash(P+vec3(1,1,0))
        ,p7= dephash(P+vec3(1,1,1));
    float d0 = distance(p,p0),
          d1 = distance(p,p1),
          d2 = distance(p,p2),
          d3 = distance(p,p3),
          d4 = distance(p,p4),
          d5 = distance(p,p5),
          d6 = distance(p,p6),
          d7 = distance(p,p7);
    float md = min(min(min(d0,d1),min(d2,d3)),min(min(d4,d5),min(d6,d7)));
 return 1.-(md)*2.3;
}
float fbm(vec3 p){
    vec4 p4 = vec4(p,iTime*.05);
	float n = .7*worley((p*=8.1));
	n=(1.+n)*worley(n*.1+(p/=8.1));
	n+=.05*worley(p*=-vec3(15.1,19.5,14.3));
   // n=1.-((hash33(p).r*.1+.9)*(1.-n));
	return n*2.;
}
float fbm2(vec3 p){
    vec4 p4 = vec4(p,iTime*.05);
	float n = .7*worley((p*=8.1));
	n=(1.+n)*worley(n*.1+(p/=8.1));
	//n+=.05*worley(p*=19.5);
   // n=1.-((hash33(p).r*.1+.9)*(1.-n));
	return n*2.;
}

#include "lib/clouds.set"

float cloods( vec3 p){
    float c= fbm(.02*p*vec3(.1,.15,.2))*smoothstep(cloud_min_plane,cloud_low,p.y)*smoothstep(cloud_top_plane,cloud_high,p.y)
    *smoothstep(-0.4,0.3,vnoise(0.0005*p.xz));
    return smoothstep(.1,.3,c+.7*rainStrength);
}
float cloods2( vec3 p){
float c= fbm2(.02*p*vec3(.1,.15,.2))*smoothstep(cloud_min_plane,cloud_low,p.y)*smoothstep(cloud_top_plane,cloud_high,p.y)
    *smoothstep(-0.4,0.3,vnoise(0.0005*p.xz));
    return smoothstep(.1,.3,c+.7*rainStrength);
}
#define it 8.
#define shit 2.

float shad(vec3 ro,vec3 rd,float d){
	const float dist = 80.;
    vec3 p = ro+dist*rd*d/shit;
    float a =0.;
    for(int i = 0;i++<int(shit)+1&&a<shit*.8;p+=rd*dist/shit)
        a+=max(cloods2(p),0.);

	return (a/shit);
}
#include "lib/ambcol.glsl"

vec4 trace(vec3 ro,vec3 rd,vec2 I,vec3 ld,vec3 col,float dpt){
    #include "lib/lightcol.glsl"
    vec3 ambcol = ambientCol*ambi*.15;
      float h = (cloud_min_plane-ro.y)/(rd.y);
      float h2 = (cloud_top_plane-ro.y)/(rd.y);
    if((h<0.&&h2<0.)||(h>dpt&&h2>dpt))
    	return vec4(col,0.);
    float t= h;
    h=max(h,h2),
    h=min(h,dpt),
    h2 = minp(t,h2);
    if(h2==0.)h=min(h,240.);
    float d = fract(bayer16(I*resolution)+120.1*frameTimeCounter);
    vec3 p = ro+(h-d*(h2-=h)/it)*rd;
    float a =0.;

    for(int i = 0;i++<int(it)+1&&a<it*.8;p+=rd*h2/it){
        float v =max(cloods(p),0.);
        a+=v;
        col = mix(col,mix(ambcol,lightCol,exp2(-shad(p,ld,1.-d)*10.)),clamp(v,0.,1.));
    }
    col*=(1.-.9*rainStrength);
    float scatter = exp2(-distance(p,ro)*.000015);
    col = mix( getSky3(rd),col,scatter);
	return vec4(col,mix(1.,exp2(-a/it*15.),scatter*scatter));
}
#define sit 6.
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
  vec3 p = ro+(h-d*(h2-=h)/it)*rd;
  float a =0.;
    for(int i = 0;i++<int(sit)+1&&a<sit*.8;p+=rd*h2/it){
        float v =max(cloods2(p),0.);
        a+=v;
      }
  return exp2(-a/it*15.);
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
          vec4 cl = trace(cameraPosition,rd,tc,ld,c,pixdpth<1.?depthBlock(pixdpth):1e12);
          c = mix(cl.rgb*.5,c,sqrt(cl.a));
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
            fresnel = ((1.0 - f0) * pow(1.0 - clamp(dot(-rd, n), 0.0, 1.0), 5.0) + f0)*(pbr.r);

          if(fresnel>.001)
          {
            vec4 cl =base;
            vec3 n = cosineDirection(n,roughness*roughness,gl_FragCoord.xy);
            cl= roughness<.3?mix(trace(p,reflect(rd,n),tc,ld,c,1e12),cl,smoothstep(.2,.3,roughness)):cl;
                c = mix(cl.rgb,c,sqrt(cl.a));
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
