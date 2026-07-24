/* NAS-T lightbox: click any photo to view it full screen at full resolution.
   Works in Edge, Chrome, Firefox, Safari, and on mobile. */
(function () {
  var box, imgEl, caption, closeBtn;

  function build() {
    box = document.createElement('div');
    box.className = 'lb';
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-modal', 'true');
    box.innerHTML =
      '<button class="lb-close" aria-label="Close">&times;</button>' +
      '<img class="lb-img" alt="">' +
      '<div class="lb-cap"></div>';
    document.body.appendChild(box);
    imgEl    = box.querySelector('.lb-img');
    caption  = box.querySelector('.lb-cap');
    closeBtn = box.querySelector('.lb-close');

    closeBtn.addEventListener('click', close);
    box.addEventListener('click', function (e) {
      if (e.target === box) close();      // click backdrop to dismiss
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') close();
    });
  }

  function open(src, alt) {
    if (!box) build();
    imgEl.src = src;
    imgEl.alt = alt || '';
    caption.textContent = alt || '';
    box.classList.add('open');
    document.body.style.overflow = 'hidden';   // stop background scroll
  }

  function close() {
    if (!box) return;
    box.classList.remove('open');
    document.body.style.overflow = '';
    imgEl.src = '';                            // free memory
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
