#version 120

varying vec2 tc;

void main(){
  gl_Position = ftransform();
  tc = gl_MultiTexCoord0.xy;
}
