#version 400

#include "/lib/colorspace.glsl"
#include "/lib/essentials.glsl"
#include "/lib/bloom.glsl"
#include "/lib/temp.glsl"


// temporal buffers: 5 6, don't touch

uniform sampler2D gcolor;
uniform sampler2D colortex2;
uniform sampler2D colortex1;
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform float frameTimeCounter;
varying vec2 tc;



const float		sunPathRotation	= -30.0f;
const bool shadowHardwareFiltering1 = false;
const float 	ambientOcclusionLevel	 = 0.0f;
const float wetnessHalflife = 1500.0f;
const float drynessHalflife = 1000.0f;

/*
const int colortex0Format = RGBA16;
const int colortex5Format = RGBA16;
const int colortex4Format = RGBA16;
const int colortex6Format = RGBA16;
const int colortex2Format = RGBA16;
*/

#define EXPOSURE_MULTIPLIER 2.5 //[1. 2. 2.5 3. 3.5 4 4.5  5. 6. 7.5 10.]
#define SATURATION 1.1 //[0. .1 .2 .3 .4 .5 .6 .7 .8 .9 1. 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9]
#define CONTRAST 1. //[.1 .2 .3 .4 .5 .6 .7 .8 .9 1. 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.]
#define None 0
#define Hable 1
#define ACES 2

//#define LUT  //lowering contrast is advised
#define LUT_TABLE 0 //[0 1 2 3 4 5 6 7 8 9] //the tables are taken from rutherin's raspberry shader (https://rutherin.netlify.com/) you can change them in (/img/Luts.png)

#define BLOOM

#define tonemap Hable //[Hable ACES None]

#if (tonemap == Hable)
const float A = 0.8; //shoulder strength
const float B = 0.30;   //linear strength
const float C = 0.10;   //linear angle
const float D = 0.20;   //toe strength
const float E = 0.02;   //toe numerator
const float F = 0.30;   //toe denominator
const float W = 5.8;   //white
const float norm = 1./(((W*(A*W+C*B)+D*E)/(W*(A*W+B)+D*F))-E/F);

vec3 Tonemap(vec3 x)
{
    x = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
    return x*norm;
}
#else
#if (tonemap == ACES)
const float A = 2.51;   //shoulder strength
const float B = 0.03;   //linear strength
const float C = 2.43;   //linear angle
const float D = 0.59;   //toe strength
const float E = 0.14;   //toe numerator
vec3 Tonemap( vec3 x )
{
    return saturate3((x*(A*x+B))/(x*(C*x+D)+E));
}
#endif
#endif

#define midpoint -1.

const vec3 darktone = vec3(0.);
const vec3 midtone = vec3(.5,.48,.45);
const vec3 brightone = vec3(.85,.9,1);

vec3 grading(vec3 x){
  x*=EXPOSURE_MULTIPLIER;
  vec3 lumaWeights = vec3(.3,.59,.11);
  float grey = dot(lumaWeights,x);
  x = grey + (x-grey)*SATURATION;
  vec3 l = log2(x+1e-4);
  l = midpoint + (l - midpoint)*CONTRAST;
  x=exp2(l)-1e-4;

  l = darktone-dot(darktone,vec3(1./3.));
  vec3 g = .5+ midtone-dot(midtone,vec3(1./3.));
  vec3 a = 1.+brightone-dot(brightone,vec3(1./3.));

  g=log2((.5-l)/(a-l))/log2(g);
  //if(tc.x<.5){
  x = pow(x,1./g);
  x=a*x+l*(1.-x);
//  }

  return x;
}

#define sharpening .5 //[0. .25 .5 .75 1. 1.25 1.5 1.75 2. 2.25 2.5 2.75 3. 3.25 3.5 3.75 4. 4.25 4.5 4.75 5.]
#define BLOOM_strength 1. //[0. .25 .5 .75 1. 1.25 1.5 1.75 2. 2.25 2.5 2.75 3. 3.25 3.5 3.75 4. 4.25 4.5 4.75 5.]

vec3 sharptex(sampler2D s, vec2 tc){
  vec2 r = 1./resolution;
  float sh = sharpening*.25;
  return texture2D(s,tc).rgb*(1.+sharpening)-
  texture2D(s,tc+r*vec2(1,0)).rgb*sh-
  texture2D(s,tc+r*vec2(0,1)).rgb*sh-
  texture2D(s,tc+r*vec2(0,-1)).rgb*sh-
  texture2D(s,tc+r*vec2(-1,0)).rgb*sh;
}

vec3 applyLUT(vec3 c,int id){
  c=c*63.+dither128(tc);
  c = floor(c);
  c = clamp(c,vec3(0),vec3(63.));
  vec2 b = floor(vec2(mod(c.b,8.),floor(c.b/8.)));
  return texture2D(colortex5, vec2(0.,float(id)/10.)+(b*64.+c.rg+.5)/vec2(512.,512.*10.)).rgb;
}

#define Last_Pass
void main(){
  #ifdef BLOOM
  vec3 bloom = kawazePass(colortex1,tc/bloomscale,6.,resolution);
  gl_FragColor.rgb = 2.*(sharptex(colortex0,tc).rgb+BLOOM_strength*bloom);
  #else
  gl_FragColor.rgb = 2.*(sharptex(colortex0,tc).rgb);
  #endif
  gl_FragColor.rgb = grading(gl_FragColor.rgb);

  #if (tonemap!=None)
  gl_FragColor.rgb = Tonemap(gl_FragColor.rgb);
  #endif
  #ifdef LUT
  gl_FragColor.rgb = applyLUT(gl_FragColor.rgb,LUT_TABLE);
  #endif
  gl_FragColor.rgb = linearToSRGB(gl_FragColor.rgb);
}
