#include "clouds.set"

const int noiseTextureResolution = 1024;

float vnoise(vec2 a){
  vec2 b = floor(a);
  a=fract(a);
  const float res = float(noiseTextureResolution);
  vec2 g1 = texture2D(noisetex,(b/res)).rg*2.-1.;
  vec2 g2 = texture2D(noisetex,((b+vec2(0,1))/res)).rg*2.-1.;
  vec2 g3 = texture2D(noisetex,((b+vec2(1,0))/res)).rg*2.-1.;
  vec2 g4 = texture2D(noisetex,((b+1.)/res)).rg*2.-1.;
  float d1 = dot(a,g1);
  float d2 = dot(a-vec2(0,1),g2);
  float d3 = dot(a-vec2(1,0),g3);
  float d4 = dot(a-1.,g4);

  a=smoothstep(0.,1.,a);
  float n = mix(mix(d1,d2,a.y),mix(d3,d4,a.y),a.x);
  return n+.5;
}


vec3 hash33c(vec3 p3){
    p3 = mod(p3+50.3,100.6)-50.3;
	   p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return fract((p3.xxy + p3.yxx)*p3.zyx)-.5;
}

vec3 dephash(vec3 p){
    return p+hash33c(p);
}

float worley(vec3 p){
    p+=worldtime*vec3(.1,.02,.3)*.005;
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
	float n = worley((p*=4.1*CLOUD_SCALE));
	n=(1.+n*med)*worley(n*turb+(p/=4.1));
  #if(CLOUD_DETAILS>1)
	n+=smol*worley(p*=-vec3(15.1,19.5,14.3));
  #if(CLOUD_DETAILS>2)
  n+=mini*worley(p*=-vec3(4.1,2.5,4.3));
  #endif
  #endif
   // n=1.-((hash33c(p).r*.1+.9)*(1.-n));
	return n*2.;
}
float fbm2(vec3 p){
	float n = worley((p*=4.1*CLOUD_SCALE));
	n=(1.+n*med)*worley(n*turb+(p/=4.1));
  #if(CLOUD_LIGHTING_DETAILS>1)
  n+=smol*worley(p*=-vec3(15.1,19.5,14.3));
  #if(CLOUD_LIGHTING_DETAILS>2)
  n+=mini*worley(p*=-vec3(4.1,2.5,4.3));
  #endif
  #endif
     // n=1.-((hash33c(p).r*.1+.9)*(1.-n));
	return n*2.;
}

float clf(vec3 p, float c){
  float lowbound = smoothstep(cloud_min_plane,cloud_low,p.y),highbound = smoothstep(cloud_top_plane,cloud_high,p.y);
  highbound=sqrt(highbound);
    c*= lowbound*highbound
    *max(smoothstep(0.6,0.3,vnoise(0.00001*(p.xz-vec2(worldtime)*5.))),max(rainStrength,wetness));
    return smoothstep(.1,.3,c+.7*rainStrength);
}


float cloods( vec3 p){
    float c=fbm(.02*p*vec3(.1,.15,.2));
    return clf( p, c);
}
float cloods2( vec3 p){
  float c= fbm2(.02*p*vec3(.1,.15,.2));
  return clf( p, c);
}
