/**
 * Growth OS behaviours as LiveView hooks.
 * GosPassword keeps the revealed state across morphdom patches and shows the
 * 72-byte bcrypt limit as an inline error. GosModal traps focus. GosToast
 * announces a status line.
 */

const GosPassword = {
  mounted() {
    this.revealed = false;
    this.button = this.el.querySelector("[data-password-toggle-button]");
    if (this.button) {
      this.button.addEventListener("mousedown", (event) => event.preventDefault());
      this.clickHandler = (event) => {
        event.preventDefault();
        this.revealed = !this.revealed;
        this.applyState();
      };
      this.button.addEventListener("click", this.clickHandler);
    }
    this.applyState();
    this.setupValidation();
    this.setupCaps();
  },

  updated() {
    this.applyState();
  },

  destroyed() {
    if (this.button && this.clickHandler) {
      this.button.removeEventListener("click", this.clickHandler);
    }
  },

  input() {
    return this.el.querySelector('input[type="password"], input[type="text"]');
  },

  applyState() {
    const input = this.input();
    if (!input || !this.button) return;
    const type = this.revealed ? "text" : "password";
    if (input.getAttribute("type") !== type) input.setAttribute("type", type);
    this.button.setAttribute("aria-pressed", String(this.revealed));
    this.button.setAttribute("aria-label", this.revealed ? "Hide password" : "Show password");
    const openEye = this.button.querySelector("[data-eye-open]");
    const closedEye = this.button.querySelector("[data-eye-closed]");
    if (openEye && closedEye) {
      openEye.classList.toggle("hidden", this.revealed);
      closedEye.classList.toggle("hidden", !this.revealed);
    }
  },

  setupCaps() {
    const input = this.input();
    if (!input) return;
    let caps = this.el.querySelector(".gos-caps");
    if (!caps) {
      caps = document.createElement("p");
      caps.className = "gos-caps gos-msg";
      caps.hidden = true;
      caps.textContent = "Caps Lock is on";
      input.insertAdjacentElement("afterend", caps);
    }
    const check = (event) => {
      caps.hidden = !event.getModifierState?.("CapsLock");
    };
    input.addEventListener("keydown", check);
    input.addEventListener("keyup", check);
    input.addEventListener("blur", () => {
      caps.hidden = true;
    });
  },

  setupValidation() {
    const input = this.input();
    const list = this.el.querySelector("#password-requirements");
    if (!input || !list) return;
    const byteError = list.querySelector("#password-byte-error");
    const rules = Array.from(list.querySelectorAll("[data-password-rule]"))
      .map((element) => {
        if (element.dataset.passwordRule === "max_bytes") {
          const maxBytes = Number(element.dataset.passwordMaxBytes || 72);
          return {
            element,
            maxBytes,
            test: (value) => new TextEncoder().encode(value).length <= maxBytes,
          };
        }
        try {
          const pattern = new RegExp(element.dataset.passwordPattern);
          return { element, test: (value) => pattern.test(value) };
        } catch (_error) {
          return null;
        }
      })
      .filter(Boolean);

    input.addEventListener("input", () => {
      let over = false;
      rules.forEach(({ element, test, maxBytes }) => {
        const ok = test(input.value);
        if (maxBytes && !ok && input.value.length > 0) over = true;
        element.querySelector("[data-rule-met]")?.classList.toggle("hidden", !ok);
        element.querySelector("[data-rule-unmet]")?.classList.toggle("hidden", ok);
        element.classList.toggle("text-green-500", ok);
      });
      if (byteError) {
        byteError.hidden = !over;
        byteError.textContent = over ? byteError.dataset.byteError : "";
      }
      input.setAttribute("aria-invalid", String(over));
    });
  },
};

const GosModal = {
  mounted() {
    this.onKey = (event) => {
      if (event.key !== "Tab") return;
      const focusable = this.el.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    this.el.addEventListener("keydown", this.onKey);
  },
  destroyed() {
    this.el.removeEventListener("keydown", this.onKey);
  },
};

const GosLock = {
  mounted() {
    let left = Number(this.el.dataset.seconds || 900);
    const clock = this.el.querySelector("[data-lock-clock]");
    const paint = () => {
      const m = String(Math.floor(left / 60)).padStart(2, "0");
      const s = String(left % 60).padStart(2, "0");
      if (clock) clock.textContent = `${m}:${s}`;
    };
    paint();
    this.timer = setInterval(() => {
      left = Math.max(0, left - 1);
      paint();
      if (left === 0) clearInterval(this.timer);
    }, 1000);
  },
  destroyed() {
    clearInterval(this.timer);
  },
};

const GosToast = {
  mounted() {
    this.el.setAttribute("role", "status");
    this.el.setAttribute("aria-live", "polite");
  },
};

export { GosPassword, GosModal, GosToast, GosLock };
