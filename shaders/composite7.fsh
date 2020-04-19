#version 120



varying vec2 tc;
uniform sampler2D colortex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;
uniform float centerDepthSmooth;

//#define DOF
#define BETTER_DOF
//#define TEMPORAL_DOF //increases the demporal resolution of DOF, but looks jittery

#ifdef TEMPORAL_DOF
uniform float frameTimeCounter;
#endif


#define DOF_APERTURE 0.1  // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]//radius in m*pixel/screenwidthh
#define DOF_IT 4  //[1 2 4 8 16 32 64 128]
#define DOF_FOCAL 0.0257 //[0.0001 0.0002 0.0005 0.001 0.0017 0.0026 0.0037 0.005 0.0065 0.0082 0.0101 0.0122 0.0145 0.017 0.0197 0.0226 0.0257 0.029 0.0325 0.0362 0.0401 0.0442 0.0485 0.05299 0.05769 0.06259 0.06769 0.07299 0.07849 0.08419 0.09009 0.09619 0.10249 0.10899 0.11569 0.12259 0.12969 0.13699 0.14449 0.15218 0.16008 0.16818 0.17648 0.18498 0.19368 0.20258 0.21168 0.22098 0.23048 0.24018 0.25007 0.26017 0.27047 0.28097 0.29167 0.30257 0.31367 0.32497 0.33647 0.34817 0.36006 0.37216 0.38446 0.39696 0.40966 0.42256 0.43566 0.44896 0.46245 0.47615 0.49005 0.50415 0.51845 0.53295 0.54765 0.56254 0.57764 0.59294 0.60844 0.62414 0.64004 0.65613 0.67243 0.68893 0.70563 0.72253 0.73963 0.75692 0.77442 0.79212 0.81002 0.82812 0.84642 0.86491 0.88361 0.90251 0.92161 0.94091 0.9604 0.9801 1.0]
#define DOF_CLOSEST 0.125 //[0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]

//#define ANISOTROPIC_DOF
#define ANISOTROPIC_DOF_DEFORMATION 0.75  // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]

#ifdef DOF
#include "lib/essentials.glsl"
#include "lib/trans.glsl"
#define GA 2.39996322973
const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));

const float autorad = .715/sqrt(float(DOF_IT+1)); //.715 is empirical
const float centerDepthHalflife =2.0f;

float getCoC(float depth, float focalDepth){
  return float(DOF_APERTURE)*DOF_FOCAL*abs(depth-focalDepth)/(depth*(focalDepth - DOF_FOCAL));
}

vec3 getDOF(vec2 tc, float depth,float Coc,float focalDepth){

  vec3 c=vec3(0);
  float d = bayer16(gl_FragCoord.xy);
  #ifdef TEMPORAL_DOF
    d=fract(d+frameTimeCounter*240.1);
  #endif
  float delta = depth-focalDepth;
  float rad = Coc*autorad;
  vec2 angle = vec2(0,rad);
  angle*=rot(6.28*d);
  float r = 1.;
  float j=0.;
  vec2 corr = resolution.x/resolution;
  for(int i = 0;i<DOF_IT;i++){
    r+=1./r;
    angle*=Grot;
    vec2 sc = (r-1.)*angle;
    #ifdef ANISOTROPIC_DOF
    vec2 toCenter = (tc-.5)*corr;
      sc-=toCenter*dot(normalize(toCenter),sc*corr)*ANISOTROPIC_DOF_DEFORMATION;
    #endif
    sc = sc*corr+tc;
    float sdepth = depthBlock(texture2D(depthtex1,sc).r);
    #ifdef BETTER_DOF
      Coc=getCoC(sdepth,focalDepth);
    #endif
    if((r-1.)*rad<=Coc){
      j++;
      c+=texture2D(colortex0,sc).rgb;
    }
  }
  if(j<=0.)
    return texture2D(colortex0,tc).rgb;
  return c/j;
}
#endif



/*DRAWBUFFERS:07*/
void main(){
  #ifdef DOF
  float focalDepth=max(depthBlock(centerDepthSmooth),DOF_FOCAL*(1.+DOF_CLOSEST));
  vec2 uv = tc;
  float d = texture2D(depthtex1,uv).r;
  float depth = depthBlock(d);
  float Coc = getCoC( depth,  focalDepth);
  vec3 c = getDOF(uv,depth,Coc,focalDepth) ;

  bool filter = Coc>=sqrt(DOF_IT)/min(viewWidth,viewHeight);
  bool filter1 = Coc>=sqrt(DOF_IT)*3./min(viewWidth,viewHeight);
  gl_FragData[1]=vec4(filter,filter1,0,1.);
  #else
  vec3 c = texture2D(colortex0,tc).rgb;
  gl_FragData[1]=vec4(0,0,0,1.);
  #endif

  gl_FragData[0]=vec4(c,1.);
  //gl_FragData[1]=vec4(kawazePass(colortex0,tc,1.,resolution),1.);

}
