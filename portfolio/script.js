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

  var starSvg = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>';

  function esc(s) { if (!s) return ''; var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

  /* ====================================================================
     UNIVERSAL CAROUSEL ENGINE — touch, mouse drag, arrows, dots, auto
     ==================================================================== */
  function Carousel(cfg) {
    this.track = document.getElementById(cfg.trackId);
    this.dotsWrap = document.getElementById(cfg.dotsId);
    this.prevBtn = document.getElementById(cfg.prevId);
    this.nextBtn = document.getElementById(cfg.nextId);
    this.index = 0;
    this.total = 0;
    this.autoMs = cfg.autoMs || 0;
    this.autoTimer = null;
    this._startX = 0;
    this._currentX = 0;
    this._dragging = false;
    this._threshold = 50;

    var self = this;

    if (this.prevBtn) this.prevBtn.addEventListener('click', function () { self.prev(); });
    if (this.nextBtn) this.nextBtn.addEventListener('click', function () { self.next(); });
    if (this.dotsWrap) this.dotsWrap.addEventListener('click', function (e) {
      var dot = e.target.closest('.carousel__dot');
      if (!dot) return;
      self.goTo(parseInt(dot.dataset.index, 10));
    });

    if (this.track) {
      this.track.addEventListener('touchstart', function (e) { self._onStart(e.touches[0].clientX); }, { passive: true });
      this.track.addEventListener('touchmove', function (e) { self._onMove(e.touches[0].clientX); }, { passive: true });
      this.track.addEventListener('touchend', function () { self._onEnd(); });

      this.track.addEventListener('mousedown', function (e) {
        e.preventDefault();
        self._onStart(e.clientX);
        self.track.classList.add('dragging');
      });
      document.addEventListener('mousemove', function (e) {
        if (self._dragging) self._onMove(e.clientX);
      });
      document.addEventListener('mouseup', function () {
        if (self._dragging) {
          self.track.classList.remove('dragging');
          self._onEnd();
        }
      });
    }
  }

  Carousel.prototype._onStart = function (x) {
    this._dragging = true;
    this._startX = x;
    this._currentX = x;
    this._resetAuto();
  };

  Carousel.prototype._onMove = function (x) {
    if (!this._dragging) return;
    this._currentX = x;
    var diff = this._currentX - this._startX;
    var offset = -(this.index * 100) + (diff / this.track.parentElement.offsetWidth * 100);
    this.track.style.transform = 'translateX(' + offset + '%)';
  };

  Carousel.prototype._onEnd = function () {
    if (!this._dragging) return;
    this._dragging = false;
    var diff = this._currentX - this._startX;
    if (Math.abs(diff) > this._threshold) {
      if (diff < 0) this.next(); else this.prev();
    } else {
      this.update();
    }
    this._startAuto();
  };

  Carousel.prototype.goTo = function (i) {
    this.index = Math.max(0, Math.min(i, this.total - 1));
    this.update();
    this._resetAuto();
    this._startAuto();
  };

  Carousel.prototype.next = function () {
    this.index = (this.index + 1) % this.total;
    this.update();
  };

  Carousel.prototype.prev = function () {
    this.index = (this.index - 1 + this.total) % this.total;
    this.update();
  };

  Carousel.prototype.update = function () {
    if (!this.track) return;
    this.track.style.transform = 'translateX(-' + (this.index * 100) + '%)';
    var dots = this.dotsWrap ? this.dotsWrap.querySelectorAll('.carousel__dot') : [];
    for (var i = 0; i < dots.length; i++) {
      dots[i].classList.toggle('active', i === this.index);
    }
  };

  Carousel.prototype.setTotal = function (n) {
    this.total = n;
    this.index = 0;
    if (this.dotsWrap) {
      var html = '';
      for (var i = 0; i < n; i++) {
        html += '<button class="carousel__dot' + (i === 0 ? ' active' : '') + '" data-index="' + i + '"></button>';
      }
      this.dotsWrap.innerHTML = html;
    }
    this.update();
    this._startAuto();
  };

  Carousel.prototype._startAuto = function () {
    if (!this.autoMs || this.total <= 1) return;
    var self = this;
    this.autoTimer = setInterval(function () { self.next(); }, self.autoMs);
  };

  Carousel.prototype._resetAuto = function () {
    if (this.autoTimer) { clearInterval(this.autoTimer); this.autoTimer = null; }
  };

  /* ---------- CREATE CAROUSELS ---------- */
  var portfolioCarousel = new Carousel({
    trackId: 'portfolioTrack',
    dotsId: 'carouselDots',
    prevId: 'carouselPrev',
    nextId: 'carouselNext',
    autoMs: 5000
  });

  var reviewsCarousel = new Carousel({
    trackId: 'reviewsTrack',
    dotsId: 'reviewsDots',
    prevId: 'reviewsPrev',
    nextId: 'reviewsNext',
    autoMs: 7000
  });

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

  function renderPortfolio(data) {
    var track = document.getElementById('portfolioTrack');
    if (!track || !data.length) return;

    track.innerHTML = data.map(function (p) {
      return '<div class="carousel__slide">' +
        '<img src="' + esc(p.image_url) + '" alt="' + esc(p.title) + '" loading="lazy" />' +
        (p.title ? '<span class="carousel__slide-caption">' + esc(p.title) + '</span>' : '') +
        '</div>';
    }).join('');

    portfolioCarousel.setTotal(data.length);
  }

  function renderReviews(data) {
    var track = document.getElementById('reviewsTrack');
    if (!track || !data.length) return;

    var stars5 = '';
    for (var s = 0; s < 5; s++) stars5 += starSvg;

    track.innerHTML = data.map(function (r) {
      return '<div class="carousel__slide">' +
        '<div class="review-card">' +
        '<div class="review-card__stars">' + stars5 + '</div>' +
        '<p class="review-card__text">&laquo;' + esc(r.text) + '&raquo;</p>' +
        '<footer class="review-card__footer">' +
        '<strong>' + esc(r.author) + '</strong>' +
        (r.order_title ? '<span>' + esc(r.order_title) + '</span>' : '') +
        '</footer>' +
        '</div>' +
        '</div>';
    }).join('');

    reviewsCarousel.setTotal(data.length);
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
