const revealItems = Array.from(document.querySelectorAll(".reveal"));
const meters = Array.from(document.querySelectorAll(".meter-fill"));
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

if (reduceMotion) {
  revealItems.forEach((item) => item.classList.add("show"));
  meters.forEach((meter) => meter.classList.add("ready"));
} else {
  const revealObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("show");
          revealObserver.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.18 }
  );

  revealItems.forEach((item, index) => {
    item.style.animationDelay = `${Math.min(index * 110, 520)}ms`;
    revealObserver.observe(item);
  });

  const meterObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("ready");
          meterObserver.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.45 }
  );

  meters.forEach((meter) => meterObserver.observe(meter));

  const statusBadge = document.querySelector(".status-badge");
  if (statusBadge) {
    setInterval(() => {
      statusBadge.classList.toggle("dim");
    }, 920);
  }
}

const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = `${new Date().getFullYear()}`;
}
