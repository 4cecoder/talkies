// Raw WebGL2 renderer for the hero waveform. One full-screen triangle and a
// small fragment shader; no buffers, textures or dependencies.
//
// The motion follows a simulated speech envelope (syllable-like bursts). It
// never asks for microphone access.

const VERTEX_SHADER = `#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`;

const FRAGMENT_SHADER = `#version 300 es
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
}`;

export const MAX_DEVICE_PIXEL_RATIO = 1.5;
const STATIC_FRAME_TIME = 7.4;

export interface HeroWaveOptions {
  onReady: () => void;
  onFail: () => void;
}

function compile(gl: WebGL2RenderingContext, type: number, source: string) {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

function isLightTheme() {
  return getComputedStyle(document.documentElement).getPropertyValue('--scheme').trim() === 'light';
}

/** Starts the renderer and returns a cleanup function. */
export function startHeroWave(canvas: HTMLCanvasElement, { onReady, onFail }: HeroWaveOptions): () => void {
  let gl: WebGL2RenderingContext | null = null;
  try {
    gl = canvas.getContext('webgl2', {
      alpha: true,
      premultipliedAlpha: true,
      antialias: false,
      depth: false,
      stencil: false,
      powerPreference: 'low-power',
      preserveDrawingBuffer: false,
    });
  } catch {
    gl = null;
  }
  if (!gl) {
    onFail();
    return () => {};
  }

  const vs = compile(gl, gl.VERTEX_SHADER, VERTEX_SHADER);
  const fs = compile(gl, gl.FRAGMENT_SHADER, FRAGMENT_SHADER);
  const program = gl.createProgram();
  if (!vs || !fs || !program) {
    onFail();
    return () => {};
  }
  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);
  gl.deleteShader(vs);
  gl.deleteShader(fs);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    gl.deleteProgram(program);
    onFail();
    return () => {};
  }

  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  gl.useProgram(program);
  gl.clearColor(0, 0, 0, 0);

  const uRes = gl.getUniformLocation(program, 'uRes');
  const uTime = gl.getUniformLocation(program, 'uTime');
  const uPointer = gl.getUniformLocation(program, 'uPointer');
  const uPointerAmt = gl.getUniformLocation(program, 'uPointerAmt');
  const uLight = gl.getUniformLocation(program, 'uLight');

  const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  const schemeQuery = window.matchMedia('(prefers-color-scheme: light)');
  const finePointer = window.matchMedia('(pointer: fine)').matches;

  let reducedMotion = motionQuery.matches;
  let inView = true;
  let pageVisible = document.visibilityState === 'visible';
  let lost = false;
  let raf = 0;
  let last = 0;
  let time = STATIC_FRAME_TIME;
  let readyFired = false;
  const pointer = { x: 0.5, y: 0.5, amt: 0, targetX: 0.5, targetAmt: 0 };

  const draw = () => {
    if (!gl || lost) return;
    gl.uniform1f(uTime, time);
    gl.uniform2f(uPointer, pointer.x, pointer.y);
    gl.uniform1f(uPointerAmt, pointer.amt);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    if (!readyFired) {
      readyFired = true;
      onReady();
    }
  };

  const resize = () => {
    if (!gl) return;
    const dpr = Math.min(window.devicePixelRatio || 1, MAX_DEVICE_PIXEL_RATIO);
    const width = Math.max(1, Math.round(canvas.clientWidth * dpr));
    const height = Math.max(1, Math.round(canvas.clientHeight * dpr));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
    gl.viewport(0, 0, width, height);
    gl.uniform2f(uRes, width, height);
    if (!raf) draw();
  };

  const applyTheme = () => {
    if (!gl) return;
    gl.uniform1f(uLight, isLightTheme() ? 1 : 0);
    if (!raf) draw();
  };

  const tick = (now: number) => {
    raf = 0;
    const dt = last ? Math.min((now - last) / 1000, 0.05) : 0;
    last = now;
    time += dt;
    pointer.x += (pointer.targetX - pointer.x) * Math.min(1, dt * 4);
    pointer.amt += (pointer.targetAmt - pointer.amt) * Math.min(1, dt * 3);
    draw();
    schedule();
  };

  function schedule() {
    const shouldRun = !reducedMotion && inView && pageVisible && !lost;
    if (shouldRun && !raf) {
      raf = requestAnimationFrame(tick);
    } else if (!shouldRun && raf) {
      cancelAnimationFrame(raf);
      raf = 0;
    }
    if (!shouldRun) last = 0;
  }

  const onMotionChange = () => {
    reducedMotion = motionQuery.matches;
    if (reducedMotion) {
      time = STATIC_FRAME_TIME;
      pointer.amt = pointer.targetAmt = 0;
      draw();
    }
    schedule();
  };

  const onVisibility = () => {
    pageVisible = document.visibilityState === 'visible';
    schedule();
  };

  const onPointerMove = (event: PointerEvent) => {
    if (reducedMotion) return;
    const rect = canvas.getBoundingClientRect();
    const inside = event.clientY > rect.top - 160 && event.clientY < rect.bottom + 80;
    pointer.targetX = (event.clientX - rect.left) / Math.max(rect.width, 1);
    pointer.targetAmt = inside ? 1 : 0;
  };

  const onPointerLeave = () => {
    pointer.targetAmt = 0;
  };

  const onContextLost = (event: Event) => {
    event.preventDefault();
    lost = true;
    schedule();
    onFail();
  };

  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(canvas);

  const intersectionObserver = new IntersectionObserver(
    (entries) => {
      inView = entries.some((entry) => entry.isIntersecting);
      schedule();
    },
    { rootMargin: '64px' },
  );
  intersectionObserver.observe(canvas);

  const themeObserver = new MutationObserver(applyTheme);
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

  motionQuery.addEventListener('change', onMotionChange);
  schemeQuery.addEventListener('change', applyTheme);
  document.addEventListener('visibilitychange', onVisibility);
  canvas.addEventListener('webglcontextlost', onContextLost);
  if (finePointer) {
    window.addEventListener('pointermove', onPointerMove, { passive: true });
    document.documentElement.addEventListener('pointerleave', onPointerLeave);
  }

  gl.uniform1f(uLight, isLightTheme() ? 1 : 0);
  resize();
  schedule();

  return () => {
    if (raf) cancelAnimationFrame(raf);
    raf = 0;
    resizeObserver.disconnect();
    intersectionObserver.disconnect();
    themeObserver.disconnect();
    motionQuery.removeEventListener('change', onMotionChange);
    schemeQuery.removeEventListener('change', applyTheme);
    document.removeEventListener('visibilitychange', onVisibility);
    canvas.removeEventListener('webglcontextlost', onContextLost);
    window.removeEventListener('pointermove', onPointerMove);
    document.documentElement.removeEventListener('pointerleave', onPointerLeave);
    if (gl && !lost) {
      gl.deleteVertexArray(vao);
      gl.deleteProgram(program);
    }
    gl = null;
  };
}
