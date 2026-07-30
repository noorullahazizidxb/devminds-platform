(() => {
  "use strict";

  const PHRASES = {
    "jobs-title": [
      "Find your dream job",
      "Hire the best talent",
      "Build your network",
    ],
    "jobs-sub": [
      "Serious careers across Afghanistan — search, apply, and track in one place.",
      "Post roles, discover candidates, and hire with a fair, dual-sided marketplace.",
      "Companies, services, and opportunities built around your ambition.",
    ],
    "market-title": [
      "Buy, Sell & Rent",
      "Listings for your next move",
      "Access over ownership",
    ],
    "market-sub": [
      "Trusted classifieds — browse fresh offers and connect with sellers faster.",
      "List what you have. Find what you need. Trade with confidence.",
      "A circular marketplace for goods people actually use.",
    ],
  };

  const HINT = {
    jobs: "Enter Kaaryabi",
    market: "Enter Marketplace",
  };

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const coarsePointer = window.matchMedia("(hover: none), (pointer: coarse)").matches;

  const stage = document.getElementById("stage");
  const hint = document.getElementById("cursor-hint");
  const wedges = Array.from(document.querySelectorAll(".wedge"));

  /* ── Forced-choice hover / focus ── */
  function setActive(side) {
    if (!stage) return;
    stage.dataset.active = side || "none";
  }

  wedges.forEach((wedge) => {
    const side = wedge.dataset.side;

    wedge.addEventListener("pointerenter", () => {
      setActive(side);
      showHint(side);
    });
    wedge.addEventListener("pointerleave", () => {
      if (document.activeElement !== wedge) setActive("none");
      hideHint();
    });
    wedge.addEventListener("focus", () => {
      setActive(side);
      showHint(side);
    });
    wedge.addEventListener("blur", () => {
      setActive("none");
      hideHint();
    });
  });

  /* ── Cursor hint ── */
  function showHint(side) {
    if (!hint || coarsePointer || reducedMotion) return;
    hint.hidden = false;
    hint.textContent = HINT[side] || "";
    hint.dataset.side = side;
    hint.classList.add("is-visible");
    hint.setAttribute("aria-hidden", "false");
  }

  function hideHint() {
    if (!hint) return;
    hint.classList.remove("is-visible");
    hint.setAttribute("aria-hidden", "true");
  }

  if (hint && !coarsePointer && !reducedMotion) {
    window.addEventListener(
      "pointermove",
      (event) => {
        hint.style.left = `${event.clientX + 18}px`;
        hint.style.top = `${event.clientY - 12}px`;
      },
      { passive: true },
    );
  }

  /* ── Typewriter ── */
  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async function typeInto(el, text, speed) {
    const target = el.querySelector(".type-text");
    if (!target) return;
    target.textContent = "";
    for (let i = 0; i < text.length; i += 1) {
      target.textContent += text[i];
      await sleep(speed);
    }
  }

  async function deleteFrom(el, speed) {
    const target = el.querySelector(".type-text");
    if (!target) return;
    while (target.textContent.length > 0) {
      target.textContent = target.textContent.slice(0, -1);
      await sleep(speed);
    }
  }

  async function runTypewriter(el, key) {
    const phrases = PHRASES[key];
    if (!phrases || !phrases.length) return;

    const textEl = el.querySelector(".type-text");
    if (!textEl) return;

    if (reducedMotion) {
      textEl.textContent = phrases[0];
      const caret = el.querySelector(".caret");
      if (caret) caret.style.display = "none";
      return;
    }

    let index = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const phrase = phrases[index % phrases.length];
      await typeInto(el, phrase, key.includes("title") ? 42 : 22);
      await sleep(key.includes("title") ? 2200 : 2600);
      await deleteFrom(el, key.includes("title") ? 24 : 14);
      await sleep(320);
      index += 1;
    }
  }

  document.querySelectorAll("[data-typewriter]").forEach((el) => {
    const key = el.getAttribute("data-typewriter");
    if (key) runTypewriter(el, key);
  });
})();
