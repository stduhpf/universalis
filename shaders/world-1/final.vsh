#version 400 compatibility

varying vec2 tc;
varying float avgexp;
uniform sampler2D colortex0;
uniform int frameCounter;
#include "../lib/essentials.glsl"


#define AVGEXPS 50.
const bool colortex0MipmapEnabled = true;
#define expocurve 200.

//#define AUTO_EXPOSURE

void main(){
  gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
  tc = gl_MultiTexCoord0.xy;
  #ifdef AUTO_EXPOSURE
  vec3 lumaWeights = vec3(.3,.59,.11);
  avgexp=0.;
  vec2 offset = vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));

  for(float x=0.;x<1.;x+=1./AVGEXPS){
    for(float y=0.;y<1.;y+=1./AVGEXPS){
      vec2 p = vec2(x,y)+(.5+offset)/AVGEXPS;
      float s =dot(textureLod(colortex0,p,5.).rgb*2.,lumaWeights);
      avgexp += pow(s,1./expocurve);
      }
    }
  avgexp/=AVGEXPS*AVGEXPS;
  avgexp=pow(avgexp,expocurve)*25.;
  #else
  avgexp=1.;
  #endif

}
