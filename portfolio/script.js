(function () {
  'use strict';

  var html = document.documentElement;
  var toggle = document.getElementById('themeToggle');
  var burger = document.getElementById('burger');
  var navLinks = document.getElementById('navLinks');
  var nav = document.getElementById('nav');
  var API = window.location.origin;

  /* ---------- EMBEDDED DATA (fallback when no backend) ---------- */
  var FALLBACK_REVIEWS = [
    {author:"Slyness",text:"Как всегда - 5+! Великолепный специалист, профессионал своего дела. Продолжаем работать с Михаилом и развивать проекты!",order_title:"Доработка тг бота AI повар",date:"2026-04-10"},
    {author:"Slyness",text:"Превосходный специалист! Продолжаю с Михаилом работать над проектами и рассчитываю, что наше сотрудничество будет продолжительным и максимально эффективным. Михаил, жму руку!",order_title:"Доработка ТГ бота",date:"2026-04-10"},
    {author:"Slyness",text:"Выражаю бесконечный респект Михаилу! Пожалуй, лучший специалист из тех, с кем у меня получалось сотрудничать, уже не один проект с ним проработали. На этот раз стояла задача, оптимизировать и проработать ТГ-бот, с онлайн-оплатой, управлением контентом и прочими премудростями. Михаил, сделал всё на высшем уровне, на отлично с плюсом. Всегда на связи, с полным погружением в задачу и в проект в целом, код выдаёт чистейший и красивейший. Работать с Михаилом, без преувеличения, удовольствие!",order_title:"Доработка ТГ бота",date:"2026-02-10"},
    {author:"brothertin1",text:"гений гений гений гений гений гений гений гений гений гений",order_title:"Добавление поддержки арабского языка и rtl на сайт",date:"2026-02-05"},
    {author:"Patronium",text:"всё чётко сделал предложил несколько вариантов очень понравилось обратная связь очень адекватный парень точка Там где другие можете попросили бы какую-то дополнительную плату отказался. сказал что это всё входит в заказ сказал что если будут какие-то там баги или какие-то недочёты там за в ближайшее время выявлены он на безвозмездной основе всё отладит. Всем рекомендую исполнителя",order_title:"Веб сервис AI",date:"2026-01-20"}
  ];

  var FALLBACK_PORTFOLIO = [
    {title:"Работа 1",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/68/3529bd3f665802316962291cf1994a7040559ea8-1733925268.jpg"},
    {title:"Работа 2",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/23/c153a914e06dceee0abf2c76ab10b83f4d5f6377-1735904523.jpg"},
    {title:"Работа 3",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/83/7e613aa867b9a369ead9d1a6b19676014da5d615-1772878383.jpg"},
    {title:"Работа 4",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/57/1d873414aad9d779f1dec638ef8d42b4daabc38c-1750665657.jpg"},
    {title:"Работа 5",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/42/e3e74ac2a5b9022fe027811e00e1e36e8e4e5b1a-1750665542.jpg"},
    {title:"Работа 6",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/85/1f2db5ccf2f5db61b7b9fc9a6dfe0e4b0fdd4d9e-1750665743.jpg"},
    {title:"Работа 7",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/32/3b74edd8e2de5aa13bbd2e2b7a1a2fb32e37eff2-1750665774.jpg"},
    {title:"Работа 8",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/86/f6b339e3f4c7990e1c2e4e3e930e964e37b38a5d-1750665803.jpg"},
    {title:"Работа 9",image_url:"https://cdn-edge.kwork.ru/files/portfolio/t0/94/6b73e4291e370bb1e3b9b7a8e94f54c780d51d68-1772878282.jpg"}
  ];

  var FALLBACK_PROJECTS = [
    {title:"Noetica",subtitle:"Трекер личного развития",description:"Приложение \u00abвторой мозг\u00bb с пентагоном осей роста, XP-системой, AI-коучем и мемуарной лентой.",tags:["Flutter","Dart","FastAPI","SQLite"],icon:"rocket",link:"https://github.com/gamegroyvi/noetica"},
    {title:"Telegram Mini Apps",subtitle:"Веб-приложения в Telegram",description:"Разработка функциональных Mini Apps: интерфейсы, платежи, интеграции с ботами.",tags:["React","TypeScript","Node.js","TG API"],icon:"message",link:""},
    {title:"Лендинги и веб-сайты",subtitle:"Pixel-perfect вёрстка",description:"Адаптивные лендинги, мультиязычные сайты, email-шаблоны. Кроссбраузерность и pixel-perfect.",tags:["Next.js","React","Tailwind","SCSS"],icon:"monitor",link:""},
    {title:"REST API и бэкенд",subtitle:"Серверная разработка",description:"Проектирование API, базы данных, авторизация, документация, деплой на Linux/Nginx.",tags:["FastAPI","Flask","PostgreSQL","Express"],icon:"server",link:""}
  ];

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

  /* ---------- RENDER HELPERS ---------- */
  function renderProjects(data) {
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
  }

  /* ---------- CAROUSEL ---------- */
  var carouselIndex = 0;
  var carouselTotal = 0;

  function renderPortfolio(data) {
    var track = document.getElementById('portfolioTrack');
    var dots = document.getElementById('carouselDots');
    if (!track || !data.length) return;
    carouselTotal = data.length;
    carouselIndex = 0;

    track.innerHTML = data.map(function (p) {
      return '<div class="carousel__slide">' +
        '<img src="' + esc(p.image_url) + '" alt="' + esc(p.title) + '" loading="lazy" />' +
        (p.title ? '<span class="carousel__slide-caption">' + esc(p.title) + '</span>' : '') +
        '</div>';
    }).join('');

    dots.innerHTML = data.map(function (_, i) {
      return '<button class="carousel__dot' + (i === 0 ? ' active' : '') + '" data-index="' + i + '"></button>';
    }).join('');

    updateCarousel();
  }

  function updateCarousel() {
    var track = document.getElementById('portfolioTrack');
    var dots = document.querySelectorAll('.carousel__dot');
    if (!track) return;
    track.style.transform = 'translateX(-' + (carouselIndex * 100) + '%)';
    dots.forEach(function (d, i) {
      d.classList.toggle('active', i === carouselIndex);
    });
  }

  function initCarouselControls() {
    var prev = document.getElementById('carouselPrev');
    var next = document.getElementById('carouselNext');
    var dotsWrap = document.getElementById('carouselDots');

    if (prev) prev.addEventListener('click', function () {
      carouselIndex = (carouselIndex - 1 + carouselTotal) % carouselTotal;
      updateCarousel();
    });
    if (next) next.addEventListener('click', function () {
      carouselIndex = (carouselIndex + 1) % carouselTotal;
      updateCarousel();
    });
    if (dotsWrap) dotsWrap.addEventListener('click', function (e) {
      var dot = e.target.closest('.carousel__dot');
      if (!dot) return;
      carouselIndex = parseInt(dot.dataset.index, 10);
      updateCarousel();
    });

    // Auto-advance every 5s
    setInterval(function () {
      if (carouselTotal > 0) {
        carouselIndex = (carouselIndex + 1) % carouselTotal;
        updateCarousel();
      }
    }, 5000);
  }

  initCarouselControls();

  function renderReviews(data) {
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
  }

  /* ---------- LOAD DATA (API with fallback) ---------- */
  function loadProjects() {
    fetch(API + '/api/projects')
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) { renderProjects(data); })
      .catch(function () { renderProjects(FALLBACK_PROJECTS); });
  }

  function loadPortfolio() {
    fetch(API + '/api/portfolio')
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) { renderPortfolio(data); })
      .catch(function () { renderPortfolio(FALLBACK_PORTFOLIO); });
  }

  function loadReviews() {
    fetch(API + '/api/reviews')
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) { renderReviews(data); })
      .catch(function () { renderReviews(FALLBACK_REVIEWS); });
  }

  /* ---------- INIT ---------- */
  loadProjects();
  loadPortfolio();
  loadReviews();

})();
