// UI interaction hooks for LiveView
// Handles user interactions like external links and page reloads

// Page reload hook
export const PageReload = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      window.location.reload();
    });
  }
};


// Play a preset's preview <video> while the pointer hovers its container.
// Replaces inline onmouseenter/onmouseleave handlers (blocked by a nonce-based CSP).
export const VideoHoverPreview = {
  mounted() {
    const video = this.el.querySelector('.video-preview');
    if (!video) return;
    this.onEnter = () => {
      video.currentTime = 0;
      video.play().catch(() => {});
    };
    this.onLeave = () => video.pause();
    this.el.addEventListener('mouseenter', this.onEnter);
    this.el.addEventListener('mouseleave', this.onLeave);
  },
  destroyed() {
    this.el.removeEventListener('mouseenter', this.onEnter);
    this.el.removeEventListener('mouseleave', this.onLeave);
  }
};


// Accessibility for the core <.modal>. The overlay is a display:none/flex
// toggled <div> (driven either by a server assign or a client-side JS.hide/
// JS.show command), so we watch the `style` attribute rather than relying on
// mount/unmount. When the modal becomes visible we remember the element that
// had focus, move focus into the dialog, and trap Tab within it; when it hides
// again we restore focus to wherever it came from. This gives every modal in
// the app keyboard containment and focus restoration in one place.
const FOCUSABLE_SELECTOR = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
  'iframe',
  'audio[controls]',
  'video[controls]',
  '[contenteditable]:not([contenteditable="false"])'
].join(',');

export const ModalFocusTrap = {
  mounted() {
    this.active = false;
    this.previouslyFocused = null;
    this.onKeydown = (e) => this.handleKeydown(e);
    this.observer = new MutationObserver(() => this.syncVisibility());
    this.observer.observe(this.el, { attributes: true, attributeFilter: ['style'] });
    this.syncVisibility();
  },

  updated() {
    this.syncVisibility();
  },

  destroyed() {
    this.observer?.disconnect();
    this.release();
  },

  isVisible() {
    // The component toggles the overlay purely via inline `display`, and the
    // observer only watches this element's `style`, so that is the canonical
    // visibility signal.
    return this.el.style.display !== 'none';
  },

  syncVisibility() {
    if (this.isVisible()) {
      this.activate();
    } else {
      this.release();
    }
  },

  focusable() {
    // getClientRects().length also catches position:fixed elements, which
    // offsetParent === null incorrectly treats as hidden.
    //
    // Note: an <iframe> can be included in this list and act as the first/
    // last stop for Tab, but a keydown fired inside a cross-document iframe
    // cannot be intercepted by this listener — full containment of the
    // iframe's own document content is not achievable from the parent frame.
    return Array.from(this.el.querySelectorAll(FOCUSABLE_SELECTOR))
      .filter((el) => el.getClientRects().length > 0);
  },

  activate() {
    if (this.active) return;
    this.active = true;
    this.previouslyFocused =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;

    const items = this.focusable();
    // A modal whose point is a single field marks it with the AutoFocus hook so
    // it opens ready to type in. We defer to that element rather than taking the
    // first focusable one, which is the header's close button on every modal in
    // the app, and would otherwise win the race: AutoFocus fires during the
    // patch, this runs a frame later.
    const preferred = items.find((el) => el.getAttribute('phx-hook') === 'AutoFocus');
    const target = preferred || items[0] || this.el.querySelector('[role="dialog"]') || this.el;
    // Defer so the browser has painted the now-visible modal before we focus.
    requestAnimationFrame(() => target?.focus());

    document.addEventListener('keydown', this.onKeydown, true);
  },

  release() {
    if (!this.active) return;
    this.active = false;
    document.removeEventListener('keydown', this.onKeydown, true);

    const restore = this.previouslyFocused;
    this.previouslyFocused = null;
    if (restore && typeof restore.focus === 'function') restore.focus();
  },

  handleKeydown(e) {
    if (e.key !== 'Tab' || !this.active) return;

    const items = this.focusable();
    if (items.length === 0) {
      e.preventDefault();
      return;
    }

    const first = items[0];
    const last = items[items.length - 1];

    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  }
};

// Closes the mobile dashboard sidebar on Escape. A `phx-window-keydown`
// binding cannot do this alone: it fires whether or not the drawer is open,
// and the dismiss command returns focus to the menu toggle, which would pull
// focus out of whatever the organiser was doing. So the hook acts only while
// the drawer carries its open class, and runs the server-rendered command in
// `data-dismiss`, the one the close button and the backdrop run as well.
export const SidebarEscape = {
  mounted() {
    this.onKeydown = (e) => {
      if (e.defaultPrevented) return;
      if (e.key === 'Escape') {
        if (!this.el.classList.contains('dashboard-sidebar-open')) return;
        this.liveSocket.execJS(this.el, this.el.dataset.dismiss);
        return;
      }
      if (e.key === 'Tab' && this.drawerOpen()) this.trap(e);
    };
    window.addEventListener('keydown', this.onKeydown);
    this.onResize = () => this.syncDrawer();
    window.addEventListener('resize', this.onResize);
    this.observer = new MutationObserver(() => this.syncDrawer());
    this.observer.observe(this.el, {attributes: true, attributeFilter: ['class']});
    this.syncDrawer();
  },

  destroyed() {
    window.removeEventListener('keydown', this.onKeydown);
    window.removeEventListener('resize', this.onResize);
    this.observer?.disconnect();
  },

  mobile() {
    return typeof window.matchMedia === 'function' && window.matchMedia('(max-width: 1023px)').matches;
  },

  drawerOpen() {
    return this.el.classList.contains('dashboard-sidebar-open');
  },

  // A closed phone drawer is inert and hidden from assistive tech. From the
  // lg breakpoint the sidebar is the page, so it stays in the tab order.
  syncDrawer() {
    const closed = this.mobile() && !this.drawerOpen();
    this.el.toggleAttribute('inert', closed);
    this.el.setAttribute('aria-hidden', closed ? 'true' : 'false');
    if (this.drawerOpen() && this.mobile()) {
      const first = this.focusable()[0];
      if (first) first.focus();
    }
  },

  focusable() {
    return [...this.el.querySelectorAll('a, button, input, select, textarea, [tabindex]')]
      .filter((node) => !node.hasAttribute('disabled') && node.tabIndex !== -1);
  },

  trap(e) {
    const nodes = this.focusable();
    if (!nodes.length) return;
    const first = nodes[0];
    const last = nodes[nodes.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  }
};
