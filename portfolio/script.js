(function () {
  'use strict';

  var html = document.documentElement;
  var toggle = document.getElementById('themeToggle');
  var burger = document.getElementById('burger');
  var navLinks = document.getElementById('navLinks');
  var nav = document.getElementById('nav');

  /* ---------- THEME ---------- */
  function getSystemTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function applyTheme(theme) {
    html.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }

  var saved = localStorage.getItem('theme');
  applyTheme(saved || getSystemTheme());

  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    if (!localStorage.getItem('theme')) applyTheme(e.matches ? 'dark' : 'light');
  });

  toggle.addEventListener('click', function () {
    applyTheme(html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark');
  });

  /* ---------- BURGER ---------- */
  burger.addEventListener('click', function () {
    burger.classList.toggle('open');
    navLinks.classList.toggle('open');
  });

  navLinks.querySelectorAll('a').forEach(function (a) {
    a.addEventListener('click', function () {
      burger.classList.remove('open');
      navLinks.classList.remove('open');
    });
  });

  /* ---------- NAV SHADOW ---------- */
  window.addEventListener('scroll', function () {
    nav.style.boxShadow = window.scrollY > 50 ? '0 1px 0 var(--border)' : 'none';
  });

  /* ---------- SCROLL ANIMATIONS ---------- */
  var animEls = document.querySelectorAll('[data-anim]');
  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        observer.unobserve(e.target);
      }
    });
  }, { threshold: 0.15 });

  animEls.forEach(function (el) { observer.observe(el); });

})();
