/* ═══════════════════════════════
   Noetica Landing JS
   ═══════════════════════════════ */

// ── Mobile menu toggle ──
const burger = document.getElementById('burger');
const navLinks = document.getElementById('navLinks');

burger.addEventListener('click', () => {
  navLinks.classList.toggle('open');
});

navLinks.querySelectorAll('a').forEach(a =>
  a.addEventListener('click', () => navLinks.classList.remove('open'))
);

// ── Scroll-triggered fade-in animations ──
const animEls = document.querySelectorAll('[data-anim]');

const io = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      io.unobserve(entry.target);
    }
  });
}, { threshold: 0.15 });

animEls.forEach(el => io.observe(el));

// ── Hero canvas: spinning pentagon wireframe ──
(function drawPentagon() {
  const canvas = document.getElementById('heroPentagon');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  const size = 700;
  canvas.width = size * 2;
  canvas.height = size * 2;
  ctx.scale(2, 2);

  const cx = size / 2;
  const cy = size / 2;
  const R = 260;
  let angle = -Math.PI / 2;

  function frame() {
    ctx.clearRect(0, 0, size, size);
    angle += 0.0015;

    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1;

    // Outer pentagon
    ctx.beginPath();
    for (let i = 0; i < 5; i++) {
      const a = angle + (i * 2 * Math.PI) / 5;
      const x = cx + R * Math.cos(a);
      const y = cy + R * Math.sin(a);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.stroke();

    // Inner pentagons
    for (let ring = 1; ring <= 3; ring++) {
      const r = R * (ring / 4);
      ctx.beginPath();
      for (let i = 0; i < 5; i++) {
        const a = angle + (i * 2 * Math.PI) / 5;
        const x = cx + r * Math.cos(a);
        const y = cy + r * Math.sin(a);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.stroke();
    }

    // Spokes
    for (let i = 0; i < 5; i++) {
      const a = angle + (i * 2 * Math.PI) / 5;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + R * Math.cos(a), cy + R * Math.sin(a));
      ctx.stroke();
    }

    // Center dot
    ctx.beginPath();
    ctx.arc(cx, cy, 3, 0, 2 * Math.PI);
    ctx.fillStyle = '#fff';
    ctx.fill();

    requestAnimationFrame(frame);
  }

  frame();
})();
