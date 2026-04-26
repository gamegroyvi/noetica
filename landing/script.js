/* ═══════════════════════════════════════════════════
   Noetica Landing — interactive pentagon + scroll FX
   ═══════════════════════════════════════════════════ */

(function () {
  'use strict';

  // ─── MOBILE MENU ───
  const burger = document.getElementById('burger');
  const menu   = document.getElementById('mobileMenu');
  if (burger && menu) {
    burger.addEventListener('click', () => menu.classList.toggle('open'));
    menu.querySelectorAll('a').forEach(a =>
      a.addEventListener('click', () => menu.classList.remove('open'))
    );
  }

  // ─── SCROLL REVEAL ───
  const reveals = document.querySelectorAll('[data-anim]');
  const io = new IntersectionObserver(
    (entries) => entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        io.unobserve(e.target);
      }
    }),
    { threshold: 0.15 }
  );
  reveals.forEach(el => io.observe(el));

  // ─── PENTAGON RENDERER ───

  const FG    = '#ffffff';
  const LINE  = '#1f1f1f';
  const MUTED = '#8a8a8a';

  function drawPentagon(ctx, w, h, scores, opts) {
    const {
      progress  = 1,
      rings     = 4,
      dotRadius = 3.5,
      labels    = null,
      labelFont = '14px Inter, sans-serif',
      fillAlpha = 0.15,
      lineWidth = 1.5,
      animate   = false,
      time      = 0,
    } = opts || {};

    const n = scores.length;
    if (n < 3) return;

    const cx = w / 2;
    const cy = h / 2;
    const maxR = Math.min(w, h) / 2 - (labels ? 44 : 20);

    function vertex(cx, cy, r, i, n) {
      const angle = -Math.PI / 2 + (2 * Math.PI * i) / n;
      return [cx + r * Math.cos(angle), cy + r * Math.sin(angle)];
    }

    ctx.clearRect(0, 0, w, h);

    // reference rings
    ctx.strokeStyle = LINE;
    ctx.lineWidth = 1;
    for (let k = 1; k <= rings; k++) {
      const r = maxR * k / rings;
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const [x, y] = vertex(cx, cy, r, i, n);
        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.stroke();
    }

    // spokes
    for (let i = 0; i < n; i++) {
      const [x, y] = vertex(cx, cy, maxR, i, n);
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(x, y);
      ctx.stroke();
    }

    // animated scores
    const animScores = scores.map((s, i) => {
      if (!animate) return s;
      const phase = time * 0.5 + i * 1.2;
      return s + Math.sin(phase) * 8;
    });

    // filled polygon
    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const s = Math.max(0, Math.min(100, animScores[i])) / 100;
      const r = maxR * s * progress;
      const [x, y] = vertex(cx, cy, r, i, n);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.fillStyle = `rgba(255,255,255,${fillAlpha})`;
    ctx.fill();
    ctx.strokeStyle = FG;
    ctx.lineWidth = lineWidth;
    ctx.lineJoin = 'round';
    ctx.stroke();

    // dots
    for (let i = 0; i < n; i++) {
      const s = Math.max(0, Math.min(100, animScores[i])) / 100;
      const r = maxR * s * progress;
      const [x, y] = vertex(cx, cy, r, i, n);
      ctx.beginPath();
      ctx.arc(x, y, dotRadius, 0, Math.PI * 2);
      ctx.fillStyle = FG;
      ctx.fill();
    }

    // labels
    if (labels) {
      ctx.fillStyle = FG;
      ctx.font = labelFont;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      for (let i = 0; i < n; i++) {
        const [x, y] = vertex(cx, cy, maxR + 24, i, n);
        ctx.fillText(labels[i], x, y);
      }
    }
  }

  // ─── HERO CANVAS ───
  const heroCanvas = document.getElementById('pentagonCanvas');
  if (heroCanvas) {
    const ctx = heroCanvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;

    function resizeHero() {
      const rect = heroCanvas.getBoundingClientRect();
      heroCanvas.width  = rect.width * dpr;
      heroCanvas.height = rect.height * dpr;
      ctx.scale(dpr, dpr);
    }
    resizeHero();
    window.addEventListener('resize', () => {
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      resizeHero();
    });

    const heroScores = [72, 55, 88, 40, 65];
    let t = 0;

    function animateHero() {
      t += 0.016;
      const rect = heroCanvas.getBoundingClientRect();
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      drawPentagon(ctx, rect.width, rect.height, heroScores, {
        animate: true,
        time: t,
        fillAlpha: 0.12,
        rings: 5,
      });
      requestAnimationFrame(animateHero);
    }
    animateHero();
  }

  // ─── SHOWCASE CANVAS ───
  const showCanvas = document.getElementById('showcaseCanvas');
  if (showCanvas) {
    const ctx2 = showCanvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const labels = ['\u{1F4DA}', '\u{1F4BB}', '\u{1F3CB}', '\u{1F3B5}', '\u{2764}'];

    function resizeShow() {
      const rect = showCanvas.getBoundingClientRect();
      showCanvas.width  = rect.width * dpr;
      showCanvas.height = rect.height * dpr;
      ctx2.scale(dpr, dpr);
    }
    resizeShow();
    window.addEventListener('resize', () => {
      ctx2.setTransform(1, 0, 0, 1, 0, 0);
      resizeShow();
    });

    const showScores = [82, 60, 45, 70, 90];
    let t2 = 0;

    function animateShow() {
      t2 += 0.016;
      const rect = showCanvas.getBoundingClientRect();
      ctx2.setTransform(dpr, 0, 0, dpr, 0, 0);
      drawPentagon(ctx2, rect.width, rect.height, showScores, {
        animate: true,
        time: t2,
        labels: labels,
        labelFont: '18px Inter, sans-serif',
        fillAlpha: 0.18,
        dotRadius: 4,
        lineWidth: 2,
      });
      requestAnimationFrame(animateShow);
    }
    animateShow();
  }

  // ─── NAV SCROLL EFFECT ───
  const nav = document.getElementById('nav');
  let lastY = 0;
  window.addEventListener('scroll', () => {
    const y = window.scrollY;
    if (nav) {
      nav.style.borderBottomColor = y > 20 ? 'var(--line)' : 'transparent';
    }
    lastY = y;
  }, { passive: true });

  // ─── SMOOTH ANCHOR OFFSET ───
  document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener('click', (e) => {
      const id = a.getAttribute('href');
      if (id === '#') return;
      const el = document.querySelector(id);
      if (el) {
        e.preventDefault();
        const top = el.getBoundingClientRect().top + window.scrollY - 80;
        window.scrollTo({ top, behavior: 'smooth' });
      }
    });
  });

})();
