const revealItems = Array.from(document.querySelectorAll(".reveal"));
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (reduceMotion) {
  revealItems.forEach((item) => item.classList.add("show"));
}

const revealObserver = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add("show");
        revealObserver.unobserve(entry.target);
      }
    }
  },
  {
    threshold: 0.2,
  }
);

if (!reduceMotion) {
  revealItems.forEach((item, index) => {
    item.style.animationDelay = `${Math.min(index * 120, 520)}ms`;
    revealObserver.observe(item);
  });
}

const livePill = document.querySelector(".live-pill");
if (livePill && !reduceMotion) {
  setInterval(() => {
    livePill.classList.toggle("dim");
  }, 900);
}
