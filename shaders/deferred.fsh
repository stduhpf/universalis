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


#define iTime frameTimeCounter


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
    float md = min(min(min(min(min(min(min(d0,d1),d2),d3),d4),d5),d6),d7);
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
    return smoothstep(.1,.3,c+.6*rainStrength);
}
float cloods2( vec3 p){
float c= fbm2(.02*p*vec3(.1,.15,.2))*smoothstep(cloud_min_plane,cloud_low,p.y)*smoothstep(cloud_top_plane,cloud_high,p.y)
    *smoothstep(-0.4,0.3,vnoise(0.0005*p.xz));
    return smoothstep(.1,.3,c+.6*rainStrength);
}
#define it 2.

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
  vec3 p = ro+(h-d*(h2-=h)/it)*rd;
  float a =0.;
    for(int i = 0;i++<int(it)+1&&a<it*.8;p+=rd*h2/it){
        float v =max(cloods2(p),0.);
        a+=v;
      }
  return exp2(-a/it*15.);
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
