(function () {
  'use strict';

  var html = document.documentElement;
  var toggle = document.getElementById('themeToggle');
  var burger = document.getElementById('burger');
  var navLinks = document.getElementById('navLinks');
  var nav = document.getElementById('nav');
  var API = window.location.origin;

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
  function initAnimations() {
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
  }

  initAnimations();

  /* ---------- ICON MAP ---------- */
  var icons = {
    rocket: '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><path d="M12 19l7-7 3 3-7 7-3-3z"/><path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"/><path d="M2 2l7.586 7.586"/><circle cx="11" cy="11" r="2"/></svg>',
    message: '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>',
    monitor: '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>',
    server: '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
    code: '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>'
  };

  function esc(s) { if (!s) return ''; var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

  /* ---------- LOAD PROJECTS ---------- */
  function loadProjects() {
    fetch(API + '/api/projects')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var grid = document.getElementById('projectsGrid');
        if (!grid || !data.length) return;
        grid.innerHTML = data.map(function (p) {
          var tagsHtml = (p.tags || []).map(function (t) { return '<span>' + esc(t) + '</span>'; }).join('');
          var linkHtml = p.link ? '<a href="' + esc(p.link) + '" target="_blank" rel="noopener">GitHub &rarr;</a>' : '';
          var iconSvg = icons[p.icon] || icons.code;
          return '<article class="project-card" data-anim>' +
            '<div class="project-card__img"><div class="project-card__placeholder">' + iconSvg + '</div></div>' +
            '<div class="project-card__body">' +
            '<h3>' + esc(p.title) + '</h3>' +
            '<div class="project-card__tags">' + tagsHtml + '</div>' +
            '<p class="project-card__type">' + esc(p.subtitle) + '</p>' +
            '<p>' + esc(p.description) + '</p>' +
            linkHtml +
            '</div></article>';
        }).join('');
        initAnimations();
      })
      .catch(function () {});
  }

  /* ---------- LOAD PORTFOLIO ---------- */
  function loadPortfolio() {
    fetch(API + '/api/portfolio')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var grid = document.getElementById('portfolioGrid');
        if (!grid || !data.length) return;
        grid.innerHTML = data.map(function (p) {
          return '<div class="portfolio-item" data-anim>' +
            '<img src="' + esc(p.image_url) + '" alt="' + esc(p.title) + '" loading="lazy" />' +
            (p.title ? '<p class="portfolio-item__title">' + esc(p.title) + '</p>' : '') +
            '</div>';
        }).join('');
        initAnimations();
      })
      .catch(function () {});
  }

  /* ---------- LOAD REVIEWS ---------- */
  function loadReviews() {
    fetch(API + '/api/reviews')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var list = document.getElementById('reviewsList');
        if (!list || !data.length) return;
        list.innerHTML = data.map(function (r) {
          return '<blockquote class="review-card" data-anim>' +
            '<p class="review-card__text">&laquo;' + esc(r.text) + '&raquo;</p>' +
            '<footer class="review-card__footer">' +
            '<strong>' + esc(r.author) + '</strong>' +
            (r.order_title ? '<span>' + esc(r.order_title) + '</span>' : '') +
            '</footer>' +
            '</blockquote>';
        }).join('');
        initAnimations();
      })
      .catch(function () {});
  }

  /* ---------- INIT ---------- */
  loadProjects();
  loadPortfolio();
  loadReviews();

})();
