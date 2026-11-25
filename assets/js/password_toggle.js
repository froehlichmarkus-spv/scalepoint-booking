/**
 * Password visibility toggle.
 *
 * Implemented as a LiveView hook so the "revealed" state survives
 * morphdom patches. Without this, any LiveView re-render of the form
 * (e.g. phx-change validation) resets the input's `type` attribute
 * back to "password" and the toggle appears broken.
 */

const PasswordToggle = {
  mounted() {
    this.revealed = false;
    this.button = this.el.querySelector('[data-password-toggle-button]');
    if (this.button) {
      this.clickHandler = (event) => {
        event.preventDefault();
        this.revealed = !this.revealed;
        this.applyState();
      };
      this.button.addEventListener('mousedown', (event) => event.preventDefault());
      this.button.addEventListener('click', this.clickHandler);
    }
    this.applyState();
    this.setupValidation();
  },

  updated() {
    // After a LiveView patch, re-resolve the input (it may be a new node)
    // and re-apply the revealed state so the toggle survives re-renders.
    this.applyState();
  },

  destroyed() {
    if (this.button && this.clickHandler) {
      this.button.removeEventListener('click', this.clickHandler);
    }
  },

  input() {
    return this.el.querySelector('input[type="password"], input[type="text"]');
  },

  applyState() {
    const input = this.input();
    if (!input || !this.button) return;

    const type = this.revealed ? 'text' : 'password';
    if (input.getAttribute('type') !== type) {
      input.setAttribute('type', type);
    }

    this.button.setAttribute('aria-pressed', this.revealed ? 'true' : 'false');
    this.button.setAttribute('aria-label', this.revealed ? 'Hide password' : 'Show password');
    if (input.id) this.button.setAttribute('aria-controls', input.id);

    const openEye = this.button.querySelector('[data-eye-open]');
    const closedEye = this.button.querySelector('[data-eye-closed]');
    if (openEye && closedEye) {
      openEye.classList.toggle('hidden', this.revealed);
      closedEye.classList.toggle('hidden', !this.revealed);
    }
  },

  setupValidation() {
    const input = this.input();
    // Scoped to this hook's own container, so the confirm-password field does
    // not tick the checklist that belongs to the password field above it.
    const list = this.el.querySelector('#password-requirements');
    if (!input || !list) return;

    // The rules and their patterns come from the server (PasswordValidator),
    // so this checklist cannot claim a different set to the one enforced.
    const rules = Array.from(list.querySelectorAll('[data-password-rule]'))
      .map((element) => {
        try {
          return {
            element,
            key: element.dataset.passwordRule,
            pattern: new RegExp(element.dataset.passwordPattern)
          };
        } catch (error) {
          console.error('Unusable password rule pattern', element.dataset.passwordPattern, error);
          return null;
        }
      })
      .filter(Boolean);

    const caps = this.el.querySelector('[data-caps-hint]');
    const meter = this.el.querySelector('[data-strength]');
    const meterLabel = this.el.querySelector('[data-strength-label]');

    const emailLocal = () => {
      const form = input.form;
      const email = form && form.querySelector('input[type="email"]');
      const value = email ? email.value.trim().toLowerCase() : '';
      return value.split('@')[0] || '';
    };

    const paint = () => {
      const value = input.value;
      const local = emailLocal();
      let met = 0;
      rules.forEach(({ element, key, pattern }) => {
        let ok;
        if (key === 'email') {
          ok =
            value.length > 0 &&
            (local.length < 3 || !value.toLowerCase().includes(local));
        } else if (key === 'breached') {
          ok = pattern.test(value.toLowerCase());
        } else {
          ok = pattern.test(value);
        }
        if (ok) met += 1;
        updateRequirement(element, ok);
      });
      const score = value.length === 0 ? 0 : met >= rules.length ? (value.length >= 14 ? 4 : 3) : value.length >= 8 ? 2 : 1;
      if (meter) meter.dataset.score = String(score);
      if (meterLabel) {
        meterLabel.textContent = ['Password strength', 'Too weak', 'Weak', 'Good', 'Strong'][score];
      }
    };

    input.addEventListener('input', paint);
    input.addEventListener('keyup', (event) => {
      if (!caps || !event.getModifierState) return;
      caps.hidden = !event.getModifierState('CapsLock');
    });
    input.addEventListener('blur', () => {
      if (caps) caps.hidden = true;
    });
  },
};

function updateRequirement(element, isValid) {
  if (!element) return;
  // Both icons are rendered server-side; this only toggles which one shows.
  element.querySelector('[data-rule-met]')?.classList.toggle('hidden', !isValid);
  element.querySelector('[data-rule-unmet]')?.classList.toggle('hidden', isValid);
  element.classList.toggle('text-gray-500', !isValid);
  element.classList.toggle('text-green-500', isValid);
  const state = element.querySelector('[data-rule-state]');
  if (state) state.textContent = isValid ? 'met' : 'not met';
}

export { PasswordToggle };
