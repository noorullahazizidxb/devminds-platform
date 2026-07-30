(() => {
  "use strict";

  const TYPEWRITER_CONTENT = {
    "careers-title": [
      "Find work that moves you forward.",
      "Turn ambition into opportunity.",
      "Hire people who move ideas forward.",
    ],
    "careers-subtitle": [
      "Discover relevant roles, present your strengths, and manage each application from one focused workspace.",
      "Build a credible professional presence and connect with teams looking for what you do best.",
      "Publish roles, discover capable talent, and move from opening to offer with less friction.",
    ],
    "marketplace-title": [
      "Find it. List it. Move it.",
      "Own less. Access more.",
      "Turn unused value into opportunity.",
    ],
    "marketplace-subtitle": [
      "Buy, sell, and rent useful products through a faster, more human local marketplace.",
      "Browse fresh listings, compare options, and move from discovery to conversation in moments.",
      "Reach real buyers, unlock value from what you own, and access what you need without the usual friction.",
    ],
  };

  const PORTAL_HINTS = {
    careers: "Open Kaaryabi",
    marketplace: "Open Marketplace",
  };

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const stage = document.querySelector(".experience");
  const portals = Array.from(document.querySelectorAll("[data-portal]"));
  const cursorHint = document.getElementById("cursor-hint");
  const cursorText = cursorHint?.querySelector(".cursor-hint__text");

  let pointerFrame = 0;
  let latestPointer = { x: window.innerWidth / 2, y: window.innerHeight / 2 };

  function setActive(portalName = "neutral") {
    if (!stage) return;
    stage.dataset.active = portalName;
  }

  function showCursorHint(portalName) {
    if (!cursorHint || !cursorText || !finePointer || reducedMotion) return;
    cursorHint.hidden = false;
    cursorHint.dataset.portal = portalName;
    cursorText.textContent = PORTAL_HINTS[portalName] || "Open portal";
    cursorHint.classList.add("is-visible");
    cursorHint.setAttribute("aria-hidden", "false");
  }

  function hideCursorHint() {
    if (!cursorHint) return;
    cursorHint.classList.remove("is-visible");
    cursorHint.setAttribute("aria-hidden", "true");
  }

  portals.forEach((portal) => {
    const portalName = portal.dataset.portal;

    portal.addEventListener("pointerenter", () => {
      setActive(portalName);
      showCursorHint(portalName);
    });

    portal.addEventListener("pointerleave", () => {
      if (document.activeElement !== portal) setActive("neutral");
      hideCursorHint();
    });

    portal.addEventListener("focus", () => {
      setActive(portalName);
      showCursorHint(portalName);
    });

    portal.addEventListener("blur", () => {
      setActive("neutral");
      hideCursorHint();
    });
  });

  function renderPointer() {
    pointerFrame = 0;
    const { x, y } = latestPointer;
    document.documentElement.style.setProperty("--pointer-x", `${x}px`);
    document.documentElement.style.setProperty("--pointer-y", `${y}px`);

    if (cursorHint && !cursorHint.hidden) {
      cursorHint.style.left = `${x}px`;
      cursorHint.style.top = `${y}px`;
    }
  }

  if (finePointer && !reducedMotion) {
    window.addEventListener(
      "pointermove",
      (event) => {
        latestPointer = { x: event.clientX, y: event.clientY };
        if (!pointerFrame) pointerFrame = window.requestAnimationFrame(renderPointer);
      },
      { passive: true },
    );

    window.addEventListener("pointerleave", hideCursorHint);
  }

  const wait = (milliseconds) => new Promise((resolve) => window.setTimeout(resolve, milliseconds));

  async function typeText(target, text, speed) {
    target.textContent = "";
    for (const character of Array.from(text)) {
      target.textContent += character;
      await wait(speed + Math.random() * 18);
    }
  }

  async function eraseText(target, speed) {
    const characters = Array.from(target.textContent);
    while (characters.length) {
      characters.pop();
      target.textContent = characters.join("");
      await wait(speed + Math.random() * 7);
    }
  }

  async function runTypewriter(element, key, startDelay) {
    const textTarget = element.querySelector(".typewriter__text");
    const phrases = TYPEWRITER_CONTENT[key];
    const isTitle = key.endsWith("title");

    if (!textTarget || !phrases?.length) return;

    if (reducedMotion) {
      textTarget.textContent = phrases[0];
      return;
    }

    await wait(startDelay);
    let phraseIndex = 0;

    while (true) {
      const phrase = phrases[phraseIndex % phrases.length];
      await typeText(textTarget, phrase, isTitle ? 39 : 18);
      await wait(isTitle ? 2100 : 2550);
      await eraseText(textTarget, isTitle ? 22 : 11);
      await wait(isTitle ? 420 : 620);
      phraseIndex += 1;
    }
  }

  const startDelays = {
    "careers-title": 240,
    "careers-subtitle": 820,
    "marketplace-title": 520,
    "marketplace-subtitle": 1120,
  };

  document.querySelectorAll("[data-typewriter]").forEach((element) => {
    const key = element.dataset.typewriter;
    runTypewriter(element, key, startDelays[key] || 0);
  });
})();
