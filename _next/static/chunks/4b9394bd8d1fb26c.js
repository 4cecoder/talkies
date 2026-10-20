(globalThis.TURBOPACK||(globalThis.TURBOPACK=[])).push(["object"==typeof document?document.currentScript:void 0,32331,e=>{"use strict";let t=`#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`,i=`#version 300 es
precision highp float;

uniform vec2 uRes;
uniform float uTime;
uniform vec2 uPointer;
uniform float uPointerAmt;
uniform float uLight;

out vec4 outColor;

float hash(float n) { return fract(sin(n) * 43758.5453123); }

float noise(float x) {
  float i = floor(x);
  float f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(hash(i), hash(i + 1.0), f);
}

void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  float aspect = uRes.x / uRes.y;
  vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
  float t = uTime;

  // Speech-like loudness: slow phrases plus faster syllables.
  float phrase = 0.4 + 0.6 * smoothstep(0.15, 0.7, noise(t * 0.55));
  float syllable = noise(t * 4.1 + 10.0) * 0.55 + noise(t * 7.3 + 3.0) * 0.45;
  float env = 0.3 + 0.85 * phrase * (0.5 + 0.7 * syllable);

  // Quiet at the edges, loud in the middle, like a waveform scrubber.
  float taper = smoothstep(0.02, 0.42, uv.x) * smoothstep(0.98, 0.58, uv.x);
  float near = exp(-pow((uv.x - uPointer.x) * 5.0, 2.0)) * uPointerAmt;

  vec3 acc = vec3(0.0);
  float alpha = 0.0;
  float px = 1.0 / uRes.y;

  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float ph = fi * 1.37;
    float amp = (0.11 + 0.035 * fi) * (env * taper + near * 0.35) * (1.0 + near * 0.6);
    float y = amp * (
      sin(p.x * (5.0 + fi * 1.6) + t * (1.1 + fi * 0.23) + ph) * 0.55 +
      sin(p.x * (11.0 + fi * 2.1) - t * (1.8 + fi * 0.31) + ph * 2.0) * 0.25 +
      (noise(p.x * 2.6 + t * 0.9 + fi * 7.0) - 0.5) * 0.9
    );
    y += (fi - 2.0) * 0.01 * (0.4 + taper);

    float d = abs(p.y - y);
    float core = smoothstep(px * (1.6 + fi * 0.25), 0.0, d);
    float glow = 0.0032 / (d + 0.0045);
    float inten = (core * 0.95 + glow * 0.32) * mix(0.3, 1.0, taper);

    float hue = clamp(uv.x + 0.12 * sin(t * 0.35 + fi), 0.0, 1.0);
    vec3 c = mix(vec3(0.66, 0.33, 0.97), vec3(0.93, 0.28, 0.60), hue);
    c = mix(c, vec3(0.23, 0.51, 0.96), smoothstep(0.55, 1.0, hue) * 0.45 * (fi / 4.0));
    c = mix(c, vec3(1.0), core * 0.35 * (1.0 - uLight));
    c = mix(c, c * 0.78, uLight);

    acc += c * inten;
    alpha += inten;
  }

  // Fade out toward the top and bottom of the band.
  float vfade = smoothstep(0.5, 0.18, abs(p.y));
  alpha = clamp(alpha * vfade * mix(1.0, 0.85, uLight), 0.0, 1.0);
  vec3 rgb = min(acc * vfade, vec3(alpha));
  outColor = vec4(rgb, alpha);
}`;function a(e,t,i){let a=e.createShader(t);return a?(e.shaderSource(a,i),e.compileShader(a),e.getShaderParameter(a,e.COMPILE_STATUS))?a:(e.deleteShader(a),null):null}function o(){return"light"===getComputedStyle(document.documentElement).getPropertyValue("--scheme").trim()}function r(e,{onReady:r,onFail:n}){let l=null;try{l=e.getContext("webgl2",{alpha:!0,premultipliedAlpha:!0,antialias:!1,depth:!1,stencil:!1,powerPreference:"low-power",preserveDrawingBuffer:!1})}catch{l=null}if(!l)return n(),()=>{};let c=a(l,l.VERTEX_SHADER,t),m=a(l,l.FRAGMENT_SHADER,i),s=l.createProgram();if(!c||!m||!s)return n(),()=>{};if(l.attachShader(s,c),l.attachShader(s,m),l.linkProgram(s),l.deleteShader(c),l.deleteShader(m),!l.getProgramParameter(s,l.LINK_STATUS))return l.deleteProgram(s),n(),()=>{};let u=l.createVertexArray();l.bindVertexArray(u),l.useProgram(s),l.clearColor(0,0,0,0);let f=l.getUniformLocation(s,"uRes"),h=l.getUniformLocation(s,"uTime"),d=l.getUniformLocation(s,"uPointer"),v=l.getUniformLocation(s,"uPointerAmt"),p=l.getUniformLocation(s,"uLight"),g=window.matchMedia("(prefers-reduced-motion: reduce)"),x=window.matchMedia("(prefers-color-scheme: light)"),b=window.matchMedia("(pointer: fine)").matches,w=g.matches,E=!0,L="visible"===document.visibilityState,y=!1,A=0,P=0,S=7.4,R=!1,M={x:.5,y:.5,amt:0,targetX:.5,targetAmt:0},T=()=>{l&&!y&&(l.uniform1f(h,S),l.uniform2f(d,M.x,M.y),l.uniform1f(v,M.amt),l.clear(l.COLOR_BUFFER_BIT),l.drawArrays(l.TRIANGLES,0,3),R||(R=!0,r()))},_=()=>{if(!l)return;let t=Math.min(window.devicePixelRatio||1,1.5),i=Math.max(1,Math.round(e.clientWidth*t)),a=Math.max(1,Math.round(e.clientHeight*t));(e.width!==i||e.height!==a)&&(e.width=i,e.height=a),l.viewport(0,0,i,a),l.uniform2f(f,i,a),A||T()},C=()=>{l&&(l.uniform1f(p,+!!o()),A||T())},I=e=>{A=0;let t=P?Math.min((e-P)/1e3,.05):0;P=e,S+=t,M.x+=(M.targetX-M.x)*Math.min(1,4*t),M.amt+=(M.targetAmt-M.amt)*Math.min(1,3*t),T(),U()};function U(){let e=!w&&E&&L&&!y;e&&!A?A=requestAnimationFrame(I):!e&&A&&(cancelAnimationFrame(A),A=0),e||(P=0)}let F=()=>{(w=g.matches)&&(S=7.4,M.amt=M.targetAmt=0,T()),U()},O=()=>{L="visible"===document.visibilityState,U()},V=t=>{if(w)return;let i=e.getBoundingClientRect(),a=t.clientY>i.top-160&&t.clientY<i.bottom+80;M.targetX=(t.clientX-i.left)/Math.max(i.width,1),M.targetAmt=+!!a},D=()=>{M.targetAmt=0},X=e=>{e.preventDefault(),y=!0,U(),n()},B=new ResizeObserver(_);B.observe(e);let H=new IntersectionObserver(e=>{E=e.some(e=>e.isIntersecting),U()},{rootMargin:"64px"});H.observe(e);let k=new MutationObserver(C);return k.observe(document.documentElement,{attributes:!0,attributeFilter:["data-theme"]}),g.addEventListener("change",F),x.addEventListener("change",C),document.addEventListener("visibilitychange",O),e.addEventListener("webglcontextlost",X),b&&(window.addEventListener("pointermove",V,{passive:!0}),document.documentElement.addEventListener("pointerleave",D)),l.uniform1f(p,+!!o()),_(),U(),()=>{A&&cancelAnimationFrame(A),A=0,B.disconnect(),H.disconnect(),k.disconnect(),g.removeEventListener("change",F),x.removeEventListener("change",C),document.removeEventListener("visibilitychange",O),e.removeEventListener("webglcontextlost",X),window.removeEventListener("pointermove",V),document.documentElement.removeEventListener("pointerleave",D),l&&!y&&(l.deleteVertexArray(u),l.deleteProgram(s)),l=null}}e.s(["MAX_DEVICE_PIXEL_RATIO",0,1.5,"startHeroWave",()=>r])}]);