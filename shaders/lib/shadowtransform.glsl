#define pow8(a) (a*=(a*=(a*=a)))

float length8(vec2 a){
    a=abs(a);
    return sqrt(sqrt(sqrt(pow8(a.x)+pow8(a.y))));
}


uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;
//forwards shadow map

vec3 sclip2view(vec3 clippos){
  vec4 p =shadowProjectionInverse*vec4(clippos,1.);
  return p.xyz/p.w;
}

vec3 sview2cam(vec3 viewpos){
  vec4 p =shadowModelViewInverse*vec4(viewpos,1);
  return p.xyz/p.w;
}

#define sclip2cam(clippos)       sview2cam(sclip2view(clippos))

//backwards shadow map

vec3 scam2view(vec3 campos){
  vec4 p = shadowModelView*vec4(campos,1.);
  return p.xyz/p.w;
}
vec3 sview2clip(vec3 viewpos){
  vec4 p = shadowProjection*vec4(viewpos,1.);
  return p.xyz/p.w;
}

vec3 scamdir(vec3 viewdir){
  vec4 d = shadowModelViewInverse*vec4(viewdir,0);
  return d.xyz;
}

#define scam2clip(campos)        sview2clip(scam2view(campos))


#define SHADOW_BIAS .4 //[.1 .2 .4 .6 .8 1. 1.2 1.4 1.6]

vec3 stransformcam(vec3 campos){
  campos.xy/=SHADOW_BIAS+length8(campos.xy);
  campos.z*=.4;
  return campos;
}
vec2 stransform2(vec2 campos){
  campos.xy/=SHADOW_BIAS+length8(campos.xy);
  return campos;
}
float stransformd(float camdepth){
  camdepth*=2.5;
  return camdepth;
}


float sdepthLin(float depth){
  return depth;
}
