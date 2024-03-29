#version 420
#extension GL_ARB_shader_texture_lod : enable
#extension GL_ARB_gpu_shader4 : enable

layout(location = 0) out vec4 fragData0;
layout(location = 1) out vec4 fragData1;
layout(location = 2) out vec4 fragData2;
layout(location = 3) out vec4 fragData3;
layout(location = 4) out vec4 fragData4;

#define NORMAL_MAPPING
#define POM
#define SELF_SHADOW

#define FORCE_SSS // enables subsurface scattering on leaves and grass,
                  // overwriting the ressource pack sss
//#define DIRECTIONAL_LIGHTMAPS //super broken, not recommended

#include "/common/pbrformats"

//#define AO_FIX
#define PARALLAX_ALTER_DEPTHMAP
#ifdef PARALLAX_ALTER_DEPTHMAP
layout(depth_greater) out float gl_FragDepth;
#endif

uniform sampler2D texture;
uniform sampler2D normals;
#if PBR_FORMAT
uniform sampler2D specular;
#endif
uniform sampler2D noisetex;
#include "/lib/colorspace.glsl"
#include "/lib/essentials.glsl"
#include "/lib/trans.glsl"

uniform float alphaTestRef;

in vec3 normal;
in vec4 texcoord;
in vec4 tintColor;
in vec4 lmcoord;
in mat3 tbn;
in vec3 vpos;
in vec2 midTexCoord;
in flat int vegetal;
uniform vec3 shadowLightPosition;
uniform float frameTimeCounter;
uniform int frameCounter;
in vec3 wpos;

const int noiseTextureResolution = 256;

uniform float wetness;
uniform float rainStrength;

in vec2 texres;
#define tt texres // vec2(max(texres.x,texres.y))

float dither = bayer16(gl_FragCoord.xy);

vec2 dcdx = dFdx(texcoord.rg);
vec2 dcdy = dFdy(texcoord.rg);

vec4 gettex(sampler2D t, vec2 v) {
  v = (v - midTexCoord) / texres + .5;
  v = (fract(v) - .5) * texres + midTexCoord;
  return texture2DGradARB(t, v, dcdx, dcdy);
}

#define POM_DEPTH .25 // [.025 .05 .1 .2 .25 .3 .4 .5 .6 .7 .75 .8 .9 1.]
#define POM_STEPS 64  //[4 8 16 32 64 128 256]
vec2 parallaxpos(vec2 uv, vec3 rd) {
  float dpth = POM_DEPTH;
  float ste = dpth / (POM_STEPS + 1);
  float height = dpth * gettex(normals, uv).w;
  vec3 pc = vec3(uv, 0.);
  vec3 rstep = -ste * vec3(tt, 1.) * rd / rd.z;
  pc += rstep * fract(dither + haltonSeq(13, frameCounter));
  for (int i = 0; i < POM_STEPS && pc.z >= height - dpth; i++) {
    if (gettex(texture, pc.xy).w == 0.)
      break;
    pc += rstep;
    height = dpth * gettex(normals, pc.xy).w; //*(sin(frameTimeCounter)*.5+.5);
  }
  // pc.xy -= rstep.xy*(height-pc.z)*ste;
  return pc.xy;
}

float parallaxshadow(vec2 pp, vec3 ld) {
  float dpth = POM_DEPTH;
  float ste = dpth / (POM_STEPS);
  float height = dpth * gettex(normals, pp).w;
  vec3 pc = vec3(pp, height);
  vec3 rstep = ld * min(ste * vec3(tt, 1.) / abs(ld.z), .005);
  pc += rstep * fract(dither + haltonSeq(19, frameCounter));
  for (int i = 0; i < POM_STEPS; i++) {
    pc += rstep;
    height = dpth * gettex(normals, pc.xy).w;
    if (pc.z <= height)
      return 0.;
  }
  // pc.xy -= rstep.xy*(height-pc.z)*ste;
  return 1.;
}

#define OREN_NAYAR_DIFFUSE

#ifdef OREN_NAYAR_DIFFUSE

float diffuse(vec3 v, vec3 l, vec3 n, float r) {
  r *= r;

  float cti = dot(n, l);
  float ctr = dot(n, v);

  float t = max(cti, ctr);
  float g = max(.0, dot(v - n * ctr, l - n * cti));
  float c = g / t - g * t;

  float a = .285 / (r + .57) + .5;
  float b = c * .45 * r / (r + .09);

  return max(0., cti) * (b + a);
}
#else
float diffuse(vec3 v, vec3 l, vec3 n, float r) {

  float cti = dot(n, l);

  return max(0., cti);
}
#endif
float brdflight(vec3 n, vec3 v, vec3 l, float r) {
  r += .015;
  float d = max(dot(n, normalize(v + l)), 0.);
  d *= d;
  float a = .5 * r / (d * r * r + 1. - d);
  return a * a / 3.14;
}

float puddlen(vec3 p) {
  return saturate(
      smoothstep(.6, .7, texture2D(noisetex, p.xz * .0006).r) *
      (texture2D(noisetex, p.xz * .003).r * .7 +
       .5 * (texture2D(noisetex, vec2(p.x + p.z, p.x - p.z) * .0008).r - .5) +
       .03 * texture2D(noisetex, vec2(p.x - p.z, p.x + p.z) * .1).r));
}

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 443.8975);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
  p3 += dot(p3, p3.yzx + 19.19) +
        ceil(hash(p) * mod(frameTimeCounter, 500.) * 3.);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 cmp(vec2 a, vec2 b, vec2 u) {
  float la = length(a - u), lb = length(b - u);
  return (la < lb ? vec3(la, a) : vec3(lb, b));
}

vec4 voro(inout vec2 uv) {
  uv *= 2.9;
  vec2 u = floor(uv);
  vec2 off1 = hash22(u);
  vec2 off2 = vec2(0, 1) + hash22(u + vec2(0, 1));
  vec2 off3 = vec2(1) + hash22(u + vec2(1));
  vec2 off4 = vec2(1, 0) + hash22(u + vec2(1, 0));
  u = fract(uv);
  vec3 ret = cmp(cmp(off1, off2, u).yz, cmp(off3, off4, u).yz, u);
  return vec4(ret, hash(ret.yz - (ret.yz == off1   ? vec2(0)
                                  : ret.yz == off2 ? vec2(0, 1)
                                  : ret.yz == off3 ? vec2(1)
                                                   : vec2(1, 0))));
}

/*DRAWBUFFERS:03271*/
void main() {
#ifdef POM
  vec2 uv = parallaxpos(texcoord.st, vpos * tbn);
#else
  vec2 uv = texcoord.st;
#endif
  vec2 distpar = vec2(uv - texcoord.st) / tt;
  vec2 lm = lmcoord.xy / 256.;
  mat2 dlm = mat2(dFdx(lm.x), -dFdy(lm.x), dFdx(lm.y), -dFdy(lm.y));
  vec3 blocklightdir = normalize(vec3(dlm[0], 2. * length(dlm[0]) * (lm.x)));
  vec3 skylightdir = normalize(vec3(dlm[1], 3. * length(dlm[1])));
#if PBR_FORMAT
  vec4 PBRdata = gettex(specular, uv);
#else
  vec4 PBRdata = vec4(0);
#endif
#if PBR_FORMAT == labPBRv1_3
  PBRdata.g = sqrt(PBRdata.g);
#endif
  float porosity = PBRdata.b < .251 ? PBRdata.b * 4. : 0.;
  PBRdata.b = saturate((PBRdata.b - .25) / .75);
#ifdef FORCE_SSS
  if (vegetal > 0) {
    PBRdata.b = .7;
  }
#endif
  float wet = wetness * smoothstep(.8, .93, lm.y);
  float puddle = 0.;
  if (wet > 0. && camdir(normal).y > .99) {
    puddle = puddlen(wpos + view2cam(tbn * vec3(distpar, 0.))) * wet * 2.;
    puddle = smoothstep(.1, .8, puddle);
  }
  fragData0 = gettex(texture, uv) * tintColor;
  if (fragData0.a < alphaTestRef)
    discard;

  fragData0.rgb = srgbToLinear(
      fragData0.rgb); //*step(abs(texres.x-texres.y),.0001);//*0.+blocklightdir;

  fragData0.rgb *= (1. - porosity * wet * .82 + .05 * puddle * puddle);
  float roug = mix(PBRdata.r, 1., puddle * puddle * puddle * puddle);
  roug = mix(roug, 1., wet * (wet * .5 + .5 * porosity));
  PBRdata.g = mix(PBRdata.g, .134,
                  pow(wet, 1. / abs(PBRdata.r - roug)) * (.5 + .5 * porosity) *
                      float(PBRdata.g < .9));
  PBRdata.r = roug;

  // PBRdata.r= 1.-sqrt(fract(wpos.x*.5));
  fragData4 = vec4(1);
  vec3 n = normal, nrml = normal;
  if (puddle > 0. && rainStrength > 0.) {
    vec3 p = wpos.xyz;
    vec4 a = voro(p.xz);
    vec2 d = normalize(a.yz - fract(p.xz));
    float phi = a.a * 10.;
    d = .1 * d * cos(50. * a.x - frameTimeCounter * 24. + phi) * exp(-5. * a.x);
    nrml = tbn * normalize(vec3(d.x, d.y, 1.));
  }
  float ao = 1.;
#ifdef NORMAL_MAPPING
#include "/lib/normals.glsl"
#ifdef DIRECTIONAL_LIGHTMAPS
  float rgh = pow(1. - PBRdata.r, 2.);
  lm.x = min(blocklightdir.z > .0
                 ? diffuse(vpos, blocklightdir, n * tbn, rgh) *
                       (parallaxshadow(uv, blocklightdir) * .75 + .25)
                 : 1.,
             lm.x);
  // lm.y*=skylightdir.z>.01?max(0.1,dot(n*tbn,skylightdir))*parallaxshadow(uv,skylightdir):1.;
  ao = min(skylightdir.z > .01
               ? diffuse(vpos, skylightdir, n * tbn, rgh) *
                     (parallaxshadow(uv, skylightdir) * .75 + .75)
               : 1.,
           ao);
#endif
  fragData4.r = (ao);
  // fragData0.rgb = vec3(ao*ao);

  if (sqrt(puddle) >= nmp.a * nmp.a) {
    n = nrml;
    if (PBRdata.g < .9)
      PBRdata.xyz = vec3(.9, .134, 0.);
    // nmp.a = pow(puddle,.25);
    // fragData0.rgb=vec3(sin((wpos+view2cam((tbn)*vec3(distpar,(1.-nmp.a)*POM_DEPTH)))*300.).xz,.1);
  }
  // fragData0.rgb=sin((wpos+view2cam((tbn)*vec3(distpar,(1.-nmp.a)*POM_DEPTH)))*200.).xyz;
#endif
  fragData2 = vec4(.5 + .5 * n, 1.);
#ifdef SELF_SHADOW
  fragData4.g = parallaxshadow(uv, normalize(shadowLightPosition) * tbn);
#endif
  fragData3 = vec4(lm, PBRdata.a < 1. ? PBRdata.a * 255. / 254. : 0., 1.);

  // fragData0.rg = texres;fragData0.b=0.;
  // fragData0.rgb=vec3(getpa(texture,uv),0.);
  // fragData0.rgb*=step(224, lmcoord.x);
  fragData1 = vec4(PBRdata.rgb, 1);
#ifdef PARALLAX_ALTER_DEPTHMAP
  gl_FragDepth =
      blockToFrag(depthBlock(gl_FragCoord.z) +
                  sqrt(dot(distpar, distpar) +
                       POM_DEPTH * POM_DEPTH * (1. - nmp.a) * (1. - nmp.a)));
#endif
}
