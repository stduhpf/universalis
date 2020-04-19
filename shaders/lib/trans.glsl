uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;


uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousModelViewInverse;

uniform vec3 previousCameraPosition;

uniform float far;
uniform float near;






//screen = 0 to 1 and depthtx
//clip = -1 to 1 and depthtx
//view = coord in m orig camera rep camera
//cam = coord in m orig camera rep def
//world = true coordinates


//forward currentframe

 //this one works with previous frame
vec3 screen2clip(vec3 screenpos){
  return screenpos*2.-1.;
}

vec3 clip2view(vec3 clippos){
  vec4 p = gbufferProjectionInverse*vec4(clippos,1.);
  return p.xyz/p.w;
}

vec3 view2cam(vec3 viewpos){
  vec4 p = gbufferModelViewInverse*vec4(viewpos,1);
  return p.xyz/p.w;
}

vec3 cam2world(vec3 campos){
  return campos+cameraPosition;
}

vec3 camdir(vec3 viewdir){
  vec4 d = gbufferModelViewInverse*vec4(viewdir,0);
  return d.xyz;
}

#define clip2cam(clippos)       view2cam(clip2view(clippos))
#define screen2view(screenpos)  clip2view(screen2clip(screenpos))
#define view2world(viewpos)     cam2world(view2cam(viewpos))

#define screen2cam(screenpos)   clip2cam(screen2clip(screenpos))
#define clip2world(clippos)     view2world(clip2view(clippos))

#define screen2world(screenpos) view2world(screen2view(screenpos))


//backwards current frame

vec3 viewdir(vec3 camdir){
  vec4 d = gbufferModelView*vec4(camdir,0);
  return d.xyz;
}

vec3 world2cam(vec3 worldpos){
  return worldpos-cameraPosition;
}

vec3 cam2view(vec3 campos){
  vec4 p = gbufferModelView*vec4(campos,1.);
  return p.xyz/p.w;
}

vec3 view2clip(vec3 viewpos){
  vec4 p = gbufferProjection*vec4(viewpos,1.);
  return p.xyz/p.w;
}

vec3 clip2screen(vec3 clippos){       //this one works with previous frames
  return clippos*.5+.5;
}

#define cam2clip(campos)        view2clip(cam2view(campos))
#define view2screen(viewpos)    clip2screen(view2clip(viewpos))
#define world2view(worldpos)    cam2view(world2cam(worldpos))

#define cam2screen(campos)      clip2screen(cam2clip(campos))
#define world2clip(worldpos)    view2clip(world2view(worldpos))

#define world2screen(worldpos)  view2screen(world2view(worldpos))


//forward previous frame

vec3 pclip2view(vec3 clippos){
  vec4 p = gbufferPreviousProjectionInverse*vec4(clippos,1.);
  return p.xyz/p.w;
}

vec3 pview2cam(vec3 viewpos){
  vec4 p = gbufferPreviousModelViewInverse*vec4(viewpos,1);
  return p.xyz/p.w;
}

vec3 pcam2world(vec3 campos){
  return campos+previousCameraPosition;
}

#define pclip2cam(clippos)       pview2cam(pclip2view(clippos))
#define pscreen2view(screenpos)  pclip2view(screen2clip(screenpos))
#define pview2world(viewpos)     pcam2world(pview2cam(viewpos))

#define pscreen2cam(screenpos)   pclip2cam(screen2clip(screenpos))
#define pclip2world(clippos)     pview2world(pclip2view(clippos))

#define pscreen2world(screenpos) pview2world(pscreen2view(screenpos))


//backwards previous frame

vec3 pworld2cam(vec3 worldpos){
  return worldpos-previousCameraPosition;
}
vec3 pcam2view(vec3 campos){
  vec4 p = gbufferPreviousModelView*vec4(campos,1.);
  return p.xyz/p.w;
}
vec3 pview2clip(vec3 viewpos){
  vec4 p = gbufferPreviousProjection*vec4(viewpos,1.);
  return p.xyz/p.w;
}

#define pcam2clip(campos)        pview2clip(pcam2view(campos))
#define pview2screen(viewpos)    clip2screen(pview2clip(viewpos))
#define pworld2view(worldpos)    pcam2view(pworld2cam(worldpos))

#define pcam2screen(campos)      clip2screen(pcam2clip(screenpos))
#define pworld2clip(worldpos)    pview2clip(pworld2view(worldpos))

#define pworld2screen(worldpos)  pview2screen(pworld2view(screenpos))



// other utils
float depthLin(float depth) {           //get linear depth
    return (2.0 * near) / (far + near - depth * (far - near));
}
float depthBlock(float depth) {           //get linear depth
    return (far-near)*(near) / (far + near - depth * (far - near));
}
float blockToFrag(float depth){
  return (far+near)/(far-near)-near/depth;
}
