// Usturlap sitesi: tema seçici, kayan ekran görüntüsü şeritleri, görünürken
// oynayan videolar. Betik olmadan da sayfa eksiksiz okunur.
(() => {
  const root = document.documentElement;
  const KEY = "usturlap-tema";
  const sysDark = window.matchMedia("(prefers-color-scheme: dark)");
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Tema: seçim tarayıcıda saklanır (saklanamazsa yalnız bu sayfada geçerli).
  const current = () => root.dataset.theme || (sysDark.matches ? "dark" : "light");
  const buttons = document.querySelectorAll(".theme-btn");
  const label = () => {
    const text = current() === "dark" ? "Açık temaya geç" : "Koyu temaya geç";
    buttons.forEach((b) => {
      b.setAttribute("aria-label", text);
      b.title = text;
    });
  };
  buttons.forEach((b) =>
    b.addEventListener("click", () => {
      const next = current() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      try {
        localStorage.setItem(KEY, next);
      } catch (e) {
        /* gizli pencere vb. */
      }
      label();
    })
  );
  label();

  // Şeritler: içerik bir kez daha eklenir (ekran okuyucudan gizli), kesintisiz kayar.
  if (!reduce) {
    document.querySelectorAll(".strip").forEach((strip) => {
      const track = strip.querySelector(".strip-track");
      if (!track) return;
      // Sığıyorsa kaydırma yok; sığmıyorsa iki kopya, saniyede ~35 px.
      if (track.scrollWidth <= strip.clientWidth) {
        strip.classList.add("is-static");
        return;
      }
      const width = track.scrollWidth;
      [...track.children].forEach((el) => {
        const copy = el.cloneNode(true);
        copy.setAttribute("aria-hidden", "true");
        copy.querySelectorAll("img").forEach((img) => (img.alt = ""));
        track.appendChild(copy);
      });
      strip.style.setProperty("--sure", `${Math.round(width / 35)}s`);
      strip.classList.add("is-live");
    });
  }

  // Videolar: ekrandayken oynar, çıkınca durur; hareket azaltmada denetimli.
  const videos = document.querySelectorAll("video[data-auto]");
  if (reduce) {
    videos.forEach((v) => {
      v.removeAttribute("autoplay");
      v.pause();
      v.controls = true;
    });
  } else if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          const v = e.target;
          if (e.isIntersecting) {
            v.play().catch(() => {});
          } else {
            v.pause();
          }
        }),
      { threshold: 0.3 }
    );
    videos.forEach((v) => io.observe(v));
  }
})();
