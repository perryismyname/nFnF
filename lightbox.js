/* NAS-T site script.

   1. Lightbox: click a photo to view it. Click again to toggle between
      fit-to-screen and true (100%) size. At true size the browser does no
      scaling, so fine textures show with zero moire.
   2. Mobile nav toggle.
   3. Footer copyright year.

   Works in Edge, Chrome, Firefox, Safari, and on mobile. */

/* ---------- mobile nav + footer year ---------- */
document.addEventListener('DOMContentLoaded', function () {
  var toggle = document.querySelector('.nav-toggle');
  var nav    = document.getElementById('nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('open');
      // keep screen readers in step with the visual state
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
  var year = document.getElementById('year');
  if (year) year.textContent = new Date().getFullYear();
});

/* ---------- lightbox ---------- */
(function () {
  var box, stage, imgEl, caption, hint, closeBtn;

  function build() {
    box = document.createElement('div');
    box.className = 'lb';
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-modal', 'true');
    box.innerHTML =
      '<button class="lb-close" aria-label="Close">&times;</button>' +
      '<div class="lb-hint">Click image for full size &middot; Esc to close</div>' +
      '<div class="lb-stage"><img class="lb-img" alt=""></div>' +
      '<div class="lb-cap"></div>';
    document.body.appendChild(box);
    stage    = box.querySelector('.lb-stage');
    imgEl    = box.querySelector('.lb-img');
    caption  = box.querySelector('.lb-cap');
    hint     = box.querySelector('.lb-hint');
    closeBtn = box.querySelector('.lb-close');

    closeBtn.addEventListener('click', close);

    // Click the image toggles fit <-> true size
    imgEl.addEventListener('click', function (e) {
      e.stopPropagation();
      toggleZoom(e);
    });

    // Click empty area (backdrop / stage) dismisses
    stage.addEventListener('click', function (e) {
      if (e.target === stage) close();
    });

    document.addEventListener('keydown', function (e) {
      if (!box.classList.contains('open')) return;
      if (e.key === 'Escape') close();
    });
  }

  function toggleZoom(e) {
    var zooming = !box.classList.contains('zoomed');
    box.classList.toggle('zoomed', zooming);
    hint.textContent = zooming
      ? 'Click image to fit \u00b7 Esc to close'
      : 'Click image for full size \u00b7 Esc to close';

    // When zooming in, center the scroll on where the user clicked
    if (zooming) {
      // wait a frame for layout to update to true size
      requestAnimationFrame(function () {
        var rect = imgEl.getBoundingClientRect();
        var relX = (e.clientX) / window.innerWidth;
        var relY = (e.clientY) / window.innerHeight;
        stage.scrollLeft = (imgEl.offsetWidth  - stage.clientWidth)  * relX;
        stage.scrollTop  = (imgEl.offsetHeight - stage.clientHeight) * relY;
      });
    }
  }

  function open(src, alt) {
    if (!box) build();
    box.classList.remove('zoomed');
    imgEl.src = src;
    imgEl.alt = alt || '';
    caption.textContent = alt || '';
    hint.textContent = 'Click image for full size \u00b7 Esc to close';
    box.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function close() {
    if (!box) return;
    box.classList.remove('open');
    box.classList.remove('zoomed');
    document.body.style.overflow = '';
    imgEl.src = '';
  }

  document.addEventListener('DOMContentLoaded', function () {
    var shots = document.querySelectorAll(
      '.photo-duo img, .gallery img, .feature-img img'
    );
    Array.prototype.forEach.call(shots, function (img) {
      img.classList.add('zoomable');
      img.setAttribute('tabindex', '0');
      img.setAttribute('role', 'button');

      // photos/x.jpg  ->  photos-full/x.jpg
      var full = img.getAttribute('src').replace('photos/', 'photos-full/');

      function go() { open(full, img.getAttribute('alt')); }
      img.addEventListener('click', go);
      img.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); }
      });
    });
  });
})();
