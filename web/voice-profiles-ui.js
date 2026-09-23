/* Browser-local profile editor. Only Save writes a new voice profile. */
(function (root) {
  'use strict';
  const EMOJI = [
    ['🐥', 'Chick'], ['🐱', 'Cat'], ['🐶', 'Dog'], ['🐻', 'Bear'],
    ['🐼', 'Panda'], ['🐰', 'Rabbit'], ['🦊', 'Fox'], ['🐸', 'Frog'],
    ['🐯', 'Tiger'], ['🦁', 'Lion'], ['🐨', 'Koala'], ['🐵', 'Monkey'],
    ['🦄', 'Unicorn'], ['🐧', 'Penguin'], ['🐢', 'Turtle'], ['🐙', 'Octopus'],
    ['🦋', 'Butterfly'], ['🌻', 'Flower'], ['⭐', 'Star'], ['🚀', 'Rocket']
  ];
  const PHRASES = [
    'Hello Pip, I am ready to play.',
    'The little bird likes the sunny sky.',
    'I can say these words loud and clear.',
    'My happy puppy runs around the garden.',
    'We read a story and count the stars.',
    'Today is a good day to learn something new.'
  ];
  const MAX_USERS = 10;
  const MAX_NAME = 24;

  class VoiceProfilesUI {
    constructor({ multiplayer, store, onChanged = () => {}, onClose = () => {}, beforeOpen = null, env = root } = {}) {
      if (!store) throw new Error('A voice profile store is required.');
      this.env = env;
      this.document = env.document;
      this.multiplayer = multiplayer;
      this.store = store;
      this.onChanged = onChanged;
      this.onClose = onClose;
      this.beforeOpen = beforeOpen;
      this.error = '';
      this.profiles = [];
      this.opened = false;
      this.recording = false;
      this.starting = false;
      this.finishing = false;
      this.releaseFailed = false;
      this.sessionSerial = 0;
      this.activeSession = 0;
      this.completedSession = 0;
      this.captureMode = null;
      this.avatarCache = new Map();
      this.modelState = multiplayer?.state || { status: 'unsupported' };
      this._loadProfiles();
      this._mount();
      this.unobserve = multiplayer?.observe(state => {
        this.modelState = state;
        if (this.opened) this._renderModel();
      });
      this.onVisibility = () => {
        if (this.document.hidden && this.opened) this._interruptRecording('Recording stopped while this page was in the background. Please try again.');
      };
      this.onPageHide = () => {
        if (this.opened) this._interruptRecording('Recording stopped when you left this page. Please try again.');
      };
      this.onPageShow = () => {
        if (this.opened && !this.document.hidden && this.multiplayer?.isReady()) {
          Promise.resolve(this.multiplayer.verifyReady?.()).catch(error => this._showError(error.message));
        }
      };
      this.document.addEventListener('visibilitychange', this.onVisibility);
      this.env.addEventListener('pagehide', this.onPageHide);
      this.env.addEventListener('pageshow', this.onPageShow);
      // Hiding a focused Record/Retry button can move browser focus to body.
      // Keep Escape and the focus trap active in that gap, and shield the game.
      this.onOutsideKey = event => {
        if (!this.opened || this.overlay.contains(event.target)) return;
        if (event.type === 'keydown') this._keyDown(event);
        else event.stopPropagation();
        event.preventDefault();
        if (this.opened && !this.overlay.contains(this.document.activeElement)) this.dialog.focus({ preventScroll: true });
      };
      for (const name of ['keydown', 'keyup', 'keypress']) this.document.addEventListener(name, this.onOutsideKey, true);
      this.onOutsidePointer = event => {
        if (!this.opened) this.lastOpener = event.target.closest?.('button, input, a, canvas, [tabindex]') || null;
      };
      this.document.addEventListener('pointerdown', this.onOutsidePointer, true);
    }

    _node(tag, className = '', text = '') {
      const node = this.document.createElement(tag);
      if (className) node.className = className;
      if (text) node.textContent = text;
      return node;
    }

    _button(text, action, className = '') {
      const button = this._node('button', `vp-button ${className}`.trim(), text);
      button.type = 'button';
      button.addEventListener('click', () => {
        try { Promise.resolve(action()).catch(error => this._showError(error.message)); }
        catch (error) { this._showError(error.message); }
      });
      return button;
    }

    _mount() {
      this.overlay = this._node('div', 'vp-overlay');
      this.overlay.id = 'voice-profiles';
      this.overlay.hidden = true;
      this.dialog = this._node('section', 'vp-dialog');
      this.dialog.setAttribute('role', 'dialog');
      this.dialog.setAttribute('aria-modal', 'true');
      this.dialog.setAttribute('aria-labelledby', 'vp-title');
      this.dialog.setAttribute('aria-describedby', 'vp-privacy');
      this.dialog.tabIndex = -1;
      const header = this._node('header', 'vp-header');
      this.title = this._node('h2', '', 'Users 0/10');
      this.title.id = 'vp-title';
      this.closeButton = this._button('Close', () => this.close(), 'vp-close');
      this.closeButton.setAttribute('aria-label', 'Close users');
      header.append(this.title, this.closeButton);
      this.model = this._node('div', 'vp-model');
      this.model.setAttribute('role', 'status');
      this.model.setAttribute('aria-live', 'polite');
      this.alert = this._node('p', 'vp-alert');
      this.alert.setAttribute('role', 'alert');
      this.alert.hidden = true;
      this.releaseButton = this._button('Retry stopping microphone', () => this._retryRelease(), 'vp-release');
      this.releaseButton.hidden = true;
      this.content = this._node('div', 'vp-content');
      const privacy = this._node('p', 'vp-privacy', 'Voice profiles stay in this browser. Recordings are discarded.');
      privacy.id = 'vp-privacy';
      const nextRound = this._node('p', 'vp-help vp-next-round', 'Changes apply to the next round.');
      this.dialog.append(header, this.model, this.alert, this.releaseButton, this.content, privacy, nextRound);
      this.overlay.append(this.dialog);
      this.document.body.append(this.overlay);
      this.overlay.addEventListener('click', event => {
        if (event.target === this.overlay) this.close();
      });
      this.overlay.addEventListener('keydown', event => this._keyDown(event));
      for (const name of ['keyup', 'keypress', 'pointerdown', 'pointerup', 'pointermove', 'mousedown', 'mouseup', 'touchstart', 'touchmove', 'touchend', 'click', 'wheel']) {
        this.overlay.addEventListener(name, event => event.stopPropagation());
      }
    }

    _keyDown(event) {
      event.stopPropagation();
      if (event.isComposing) return;
      if (event.key === 'Escape') { event.preventDefault(); this.close(); return; }
      if (event.key !== 'Tab') return;
      const items = [...this.dialog.querySelectorAll('button, input, [tabindex="0"]')]
        .filter(node => !node.disabled && !node.hidden && !node.closest('[hidden]') && node.getClientRects().length);
      if (!items.length) { event.preventDefault(); this.dialog.focus(); return; }
      const first = items[0], last = items.at(-1), active = this.document.activeElement;
      if (event.shiftKey && (active === first || !items.includes(active))) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && (active === last || !items.includes(active))) { event.preventDefault(); first.focus(); }
    }

    _loadProfiles() {
      try {
        this.profiles = this.store.list();
        this.storeError = '';
        return true;
      } catch (error) {
        this.storeError = error.message || 'Voice profiles could not be loaded.';
        this.error = this.storeError;
        return false;
      }
    }

    get state() { return { open: this.opened, profiles: this.metadataSnapshot(), error: this.error }; }
    isOpen() { return this.opened; }

    metadataSnapshot(profiles = this.profiles) {
      return profiles.map(({ id, name, emoji }) => ({ id, name, emoji, avatar_png: this._avatar(emoji) }));
    }

    _needsRecording(profile) {
      const version = this.store.constructor.SPEAKER_MODEL_VERSION || this.env.SPEAKER_MODEL_VERSION;
      return !!version && profile.modelVersion !== version;
    }

    _avatar(emoji) {
      if (this.avatarCache.has(emoji)) return this.avatarCache.get(emoji);
      let png = '';
      try {
        const canvas = this.document.createElement('canvas');
        canvas.width = canvas.height = 128;
        const context = canvas.getContext('2d');
        if (context) {
          context.font = '88px "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif';
          context.textAlign = 'center';
          context.textBaseline = 'middle';
          context.fillText(emoji || '🐥', 64, 70);
          png = canvas.toDataURL('image/png');
        }
      } catch { /* A blocked canvas still leaves an accessible emoji and name. */ }
      this.avatarCache.set(emoji, png);
      return png;
    }

    async open({ returnFocus } = {}) {
      if (this.opened) return true;
      if (this.opening) return this.opening;
      this.opening = (async () => {
        if (this.beforeOpen && await this.beforeOpen() === false) return false;
        const active = this.document.activeElement;
        // Safari touch does not focus the tapped launcher button by default.
        this.previousFocus = returnFocus || (active && active !== this.document.body ? active
          : this.lastOpener || this.document.getElementById('canvas') || active);
        this.background = [...this.document.body.children].filter(node => node !== this.overlay)
          .map(node => ({ node, inert: node.inert }));
        for (const { node } of this.background) node.inert = true;
        this.opened = true;
        this.overlay.hidden = false;
        this.error = '';
        this._loadProfiles();
        this._renderList();
        this._renderModel();
        this.closeButton.focus({ preventScroll: true });
        if (this.modelState.status === 'idle') this._prepare();
        return true;
      })();
      try { return await this.opening; } finally { this.opening = null; }
    }

    async close() {
      if (!this.opened) return true;
      if (!this._release()) return false;
      this.opened = false;
      this.draft = null;
      this._discardResult();
      this.identification = null;
      this.overlay.hidden = true;
      for (const { node, inert } of this.background || []) if (node.isConnected) node.inert = inert;
      this.background = [];
      const previous = this.previousFocus;
      if (previous?.isConnected) previous.focus({ preventScroll: true });
      this.onClose();
      return true;
    }

    _showError(message) {
      this.error = message || 'Something went wrong. Please try again.';
      this.alert.textContent = this.error;
      this.alert.hidden = false;
    }

    _discardResult(result) {
      if (arguments.length === 0) result = this.result;
      const erase = vector => { if (Array.isArray(vector)) vector.fill(0); };
      erase(result?.embedding);
      if (Array.isArray(result?.templates)) result.templates.forEach(erase);
      if (Array.isArray(result?.segments)) result.segments.forEach(segment => erase(segment?.embedding));
      if (result === this.result) this.result = null;
    }

    _clearError() {
      if (this.releaseFailed || this.modelState.microphoneBlocked) {
        this._showError(this.modelState.microphoneMessage || 'The microphone could not be stopped. Keep this window open and retry stopping it.');
        return;
      }
      this.error = '';
      this.alert.textContent = '';
      this.alert.hidden = true;
    }

    _prepare() {
      if (!this.multiplayer) return;
      try { Promise.resolve(this.multiplayer.prepare()).catch(error => this._showError(error.message)); }
      catch (error) { this._showError(error.message); }
    }

    _renderModel() {
      const state = this.modelState;
      if (state.microphoneBlocked) {
        this.releaseFailed = true;
        this._showError(state.microphoneMessage || 'The microphone could not be stopped. Keep this window open and retry stopping it.');
        this.releaseButton.hidden = false;
      }
      this.model.replaceChildren();
      this.model.dataset.state = state.status || 'idle';
      let message;
      if (state.status === 'ready' && this.multiplayer?.isReady()) message = 'Voice model is ready';
      else if (state.status === 'downloading') {
        const percent = Number.isFinite(state.total) && state.total > 0 && Number.isFinite(state.loaded)
          ? Math.min(100, Math.max(0, Math.floor(state.loaded / state.total * 100))) : null;
        message = `Preparing voice recording${percent === null ? '…' : ` · ${percent}%`}`;
        const progress = this._node('progress', 'vp-download');
        progress.max = 100;
        if (percent !== null) progress.value = percent;
        progress.setAttribute('aria-label', 'Voice model download');
        this.model.append(progress);
      } else if (state.status === 'initializing') message = 'Starting voice recording…';
      else if (state.status === 'unsupported') message = 'Voice recording is not supported on this device. You can still edit saved users.';
      else if (state.status === 'error') message = state.message || 'Voice preparation failed.';
      else message = 'Preparing voice recording…';
      this.model.prepend(this._node('span', '', message));
      if (state.status === 'error') this.model.append(this._button('Retry', () => this._prepare(), 'vp-small'));
      this._updateEditor();
    }

    _renderList() {
      this.draft = null;
      this._discardResult();
      this.identification = null;
      this.identifyButton = null;
      this.identifyHelp = null;
      this.title.textContent = `Users ${this.profiles.length}/${MAX_USERS}`;
      this.content.replaceChildren();
      this.editor = null;
      if (this.storeError) {
        this._showError(this.storeError);
        this.content.append(this._button('Retry loading users', () => {
          this._clearError();
          this._loadProfiles();
          this._renderList();
        }));
        return;
      }
      if (!this.profiles.length) {
        const empty = this._node('div', 'vp-empty');
        empty.append(this._node('div', 'vp-empty-emoji', '🐥'),
          this._node('h3', '', 'Who is playing?'),
          this._node('p', '', 'Add a name, pick an emoji, and read a few phrases.'));
        this.content.append(empty);
      }
      const list = this._node('ul', 'vp-users');
      for (const profile of this.profiles) {
        const item = this._node('li', 'vp-user');
        const avatar = this._node('span', 'vp-avatar', profile.emoji);
        avatar.setAttribute('aria-hidden', 'true');
        const name = this._node('span', 'vp-user-name', profile.name);
        if (this._needsRecording(profile)) name.append(this._node('small', 'vp-old-voice', 'Re-record needed'));
        else if ((profile.templates?.length || 1) < 2)
          name.append(this._node('small', 'vp-old-voice', 'Add samples for a stronger voice match'));
        const edit = this._button('Edit', () => this._edit(profile), 'vp-small');
        edit.setAttribute('aria-label', `Edit ${profile.name}`);
        item.append(avatar, name, edit);
        list.append(item);
      }
      this.content.append(list);
      const add = this._button('Add user', () => this._edit(), 'vp-primary vp-add');
      add.disabled = this.profiles.length >= MAX_USERS;
      this.content.append(add);
      if (add.disabled) this.content.append(this._node('p', 'vp-help', 'Your user library is full. Delete a user to add someone new.'));
      this.identifyButton = this._button('Identify user', () => this._identify(), 'vp-identify-button');
      this.identifyHelp = this._node('p', 'vp-help vp-identify-help');
      this.identifyHelp.id = 'vp-identify-help';
      this.identifyButton.setAttribute('aria-describedby', this.identifyHelp.id);
      this.content.append(this.identifyButton, this.identifyHelp);
      this._updateIdentifyButton();
    }

    _updateIdentifyButton() {
      if (!this.identifyButton) return;
      const compatible = this.profiles.some(profile => !this._needsRecording(profile));
      this.identifyButton.disabled = !compatible || !this.multiplayer?.isReady() || this.releaseFailed || !!this.modelState.microphoneBlocked;
      this.identifyHelp.textContent = !this.profiles.length ? 'Add a user and record their voice first.'
        : !compatible ? 'Re-record a saved voice before identifying a user.'
          : 'Speak two sentences to find your saved avatar.';
    }

    _identify() {
      if (!this.opened || this.starting || this.recording || this.finishing || this.releaseFailed
        || this.modelState.microphoneBlocked || !this.multiplayer?.isReady()) return;
      if (!this._loadProfiles() || !this.profiles.some(profile => !this._needsRecording(profile))) {
        this._renderList();
        return;
      }
      this._clearError();
      this._discardResult();
      this.draft = this.editor = null;
      this.identifyButton = this.identifyHelp = null;
      this.title.textContent = 'Identify user';
      this.content.replaceChildren();
      const card = this._node('section', 'vp-identification');
      const live = this._node('div', 'vp-identify-result');
      live.setAttribute('role', 'status');
      live.setAttribute('aria-live', 'polite');
      live.setAttribute('aria-atomic', 'true');
      const avatar = this._node('div', 'vp-identify-avatar', '🎙️');
      avatar.setAttribute('aria-hidden', 'true');
      const feedback = this._node('p', 'vp-record-status');
      const name = this._node('h3', 'vp-identify-name');
      const help = this._node('p', 'vp-help');
      live.append(avatar, feedback, name, help);
      const phrase = this._node('ol', 'vp-identify-phrase');
      phrase.setAttribute('aria-label', 'Read both sentences');
      for (const sentence of PHRASES.slice(0, 2)) phrase.append(this._node('li', '', sentence));
      const progress = this._node('progress', 'vp-identify-progress');
      progress.max = 1;
      progress.value = 0;
      progress.setAttribute('aria-label', 'Voice sample progress');
      const timing = this._node('p', 'vp-timing');
      const back = this._button('Cancel', () => {
        if (!this._release()) return;
        this._clearError();
        this._renderList();
        this.identifyButton?.focus({ preventScroll: true });
      });
      const retry = this._button('Try again', () => this._identify(), 'vp-primary');
      const actions = this._node('div', 'vp-actions');
      actions.append(back, retry);
      card.append(live, phrase, progress, timing, actions);
      this.content.append(card);
      this.identification = { card, avatar, feedback, name, help, phrase, progress, timing, back, retry,
        status: 'listening', match: null, voiceProgress: null };
      const token = this.activeSession = ++this.sessionSerial;
      this.captureMode = 'identification';
      this.starting = true;
      this._updateIdentification();
      back.focus({ preventScroll: true });
      try {
        // Start within the trusted button gesture, including retries on mobile.
        const started = this.multiplayer.startIdentification({
          sessionId: `voice-identify-${Date.now()}-${token}`,
          profiles: this.profiles.filter(profile => !this._needsRecording(profile)),
          onStarted: () => {
            if (this.activeSession !== token || !this.opened || this.recording) return;
            this.starting = false;
            this.recording = true;
            this._updateIdentification();
          },
          onProgress: progress => {
            if (this.activeSession !== token || !this.opened) return;
            this.identification.voiceProgress = progress;
            this._updateIdentification();
          },
          onComplete: result => this._identified(token, result),
          onError: error => this._identificationError(token, error)
        });
        Promise.resolve(started).then(ok => {
          if (ok === false && this.activeSession === token)
            this._identificationError(token, new Error('Listening could not start. Please try again.'));
        }).catch(error => this._identificationError(token, error));
      } catch (error) { this._identificationError(token, error); }
    }

    _updateIdentification() {
      const ui = this.identification;
      if (!ui) return;
      const busy = this.starting || this.recording || this.finishing;
      const complete = ui.status === 'complete';
      ui.card.dataset.state = busy && !this.releaseFailed ? 'listening' : complete && ui.match ? 'matched' : 'idle';
      ui.avatar.textContent = complete ? ui.match?.emoji || '❔' : '🎙️';
      ui.feedback.textContent = this.releaseFailed ? 'Microphone needs attention'
        : this.starting ? 'Waiting for microphone permission…'
          : busy ? ui.voiceProgress?.message || 'Listening…'
            : complete ? ui.match ? 'User identified' : 'No match found' : 'Try identifying again';
      ui.feedback.dataset.state = this.releaseFailed ? 'error' : complete && ui.match ? 'complete' : busy ? 'recording' : 'idle';
      ui.name.textContent = complete && ui.match ? ui.match.name : '';
      ui.name.hidden = !ui.name.textContent;
      const noMatchHelp = {
        unknown_voice: 'This voice does not clearly match a saved user. Try again, or add your voice to Users.',
        ambiguous_voice: 'This voice is close to more than one saved user. Try again, or add voice samples to strengthen your saved voice.',
        segment_disagreement: 'The sentences did not match the same saved user. Please try again with one person speaking.',
        insufficient_consensus: 'We need two clear samples of the same voice. Read both sentences and pause between them.'
      };
      ui.help.textContent = busy ? 'Read both sentences in your normal voice. Pause between them. Aim for 4–6 seconds of speech. Listening stops automatically.'
        : complete ? ui.match ? 'This voice matches a saved user.' : noMatchHelp[ui.reason] || 'Speak clearly, or add your voice to Users first.'
          : ui.message || 'Speak clearly in a quiet place with one person at a time.';
      ui.phrase.hidden = !busy;
      ui.progress.hidden = !busy;
      ui.timing.hidden = !busy;
      const progress = ui.voiceProgress;
      ui.progress.value = Number.isFinite(progress?.progress) ? Math.min(1, Math.max(0, progress.progress)) : 0;
      const requiredSegments = Math.max(1, progress?.requiredSegments || 2);
      const requiredSeconds = Math.max(1, progress?.requiredVoicedMs || 4000) / 1000;
      ui.timing.textContent = `${Math.min(progress?.segments || 0, requiredSegments)}/${requiredSegments} voice samples · ` +
        `${((progress?.voicedMs || 0) / 1000).toFixed(1)} / ${requiredSeconds} s effective speech`;
      [...ui.phrase.children].forEach((node, index) => {
        node.dataset.complete = String(index < (progress?.segments || 0));
        if (busy && index === Math.min(progress?.segments || 0, 1)) node.setAttribute('aria-current', 'step');
        else node.removeAttribute('aria-current');
      });
      ui.back.textContent = busy ? 'Cancel' : 'Back to users';
      ui.retry.hidden = busy;
      ui.retry.disabled = !this.multiplayer?.isReady() || this.releaseFailed || !!this.modelState.microphoneBlocked;
    }

    _identified(token, result) {
      if (!token || this.activeSession !== token || this.completedSession === token || !this.opened || !this.identification) return;
      if (!this._release()) return;
      this.completedSession = token;
      this.identification.status = 'complete';
      this.identification.match = this.profiles.find(profile => profile.id === result?.profile?.id) || null;
      this.identification.reason = result?.quality?.reason || '';
      this._updateIdentification();
    }

    _identificationError(token, error) {
      if (!token || this.activeSession !== token || !this.opened || !this.identification) return;
      if (!this._release()) return;
      this.identification.status = 'error';
      this._showError(error?.message || 'Please speak clearly and try again.');
      this._updateIdentification();
    }

    _edit(profile = null) {
      this._clearError();
      this.identification = null;
      this.identifyButton = this.identifyHelp = null;
      this.draft = { id: profile?.id || '', name: profile?.name || '', emoji: profile?.emoji || EMOJI[0][0] };
      this._discardResult();
      this.wantsVoice = !profile;
      this.voiceAction = 'replace';
      this.oldVoice = profile ? this._needsRecording(profile) : false;
      this.legacyVoice = !!profile && !this.oldVoice && (profile.templates?.length || 1) < 2;
      this.voiceProgress = null;
      this.recordElapsedMs = 0;
      this.recordStatus = '';
      this.title.textContent = profile ? 'Edit user' : 'Add user';
      this.content.replaceChildren();
      const form = this._node('form', 'vp-editor');
      form.addEventListener('submit', event => { event.preventDefault(); this._save(); });
      const label = this._node('label', 'vp-label', 'Name');
      label.htmlFor = 'vp-name';
      const input = this._node('input', 'vp-name');
      input.id = 'vp-name';
      input.name = 'name';
      input.type = 'text';
      input.autocomplete = 'off';
      input.autocapitalize = 'words';
      input.spellcheck = false;
      input.required = true;
      input.value = this.draft.name;
      input.setAttribute('aria-describedby', 'vp-name-help');
      input.addEventListener('input', () => { this.draft.name = input.value; this._updateEditor(); });
      const nameHelp = this._node('p', 'vp-help');
      nameHelp.id = 'vp-name-help';
      const palette = this._node('fieldset', 'vp-emoji-picker');
      palette.append(this._node('legend', 'vp-label', 'Choose an emoji'));
      const emojiGrid = this._node('div', 'vp-emoji-grid');
      for (const [emoji, name] of EMOJI) {
        const button = this._button(emoji, () => {
          this.draft.emoji = emoji;
          for (const choice of emojiGrid.children) choice.setAttribute('aria-pressed', String(choice.textContent === emoji));
        }, 'vp-emoji');
        button.setAttribute('aria-label', name);
        button.setAttribute('aria-pressed', String(emoji === this.draft.emoji));
        emojiGrid.append(button);
      }
      palette.append(emojiGrid);
      const voice = this._node('section', 'vp-voice');
      const voiceTitle = this._node('h3', '', 'Voice practice');
      voice.append(voiceTitle);
      const instructions = this._node('p', 'vp-help');
      const phrases = this._node('ol', 'vp-phrases');
      for (const phrase of PHRASES) phrases.append(this._node('li', '', phrase));
      const feedback = this._node('p', 'vp-record-status');
      feedback.setAttribute('role', 'status');
      feedback.setAttribute('aria-live', 'polite');
      const timing = this._node('p', 'vp-timing');
      timing.setAttribute('aria-live', 'off');
      const record = this._button('Record voice', () => this._record(), 'vp-primary');
      const stop = this._button('Stop', () => this._finish());
      const retry = this._button('Retry recording', () => this._record());
      const chooseRecording = action => {
        this.voiceAction = action;
        this.wantsVoice = true;
        this._discardResult();
        this.recordStatus = '';
        this.voiceProgress = null;
        this.recordElapsedMs = 0;
        this._updateEditor();
        record.focus();
      };
      const rerecord = this._button('Re-record voice', () => chooseRecording('replace'));
      const append = this._button('Add voice samples', () => chooseRecording('append'));
      const voiceActions = this._node('div', 'vp-actions');
      voiceActions.append(record, stop, retry, append, rerecord);
      voice.append(instructions, phrases, feedback, timing, voiceActions);
      const save = this._button('Save', () => this._save(), 'vp-primary');
      const cancel = this._button('Cancel', () => {
        if (!this._release()) return;
        this._clearError();
        this._renderList();
        this.closeButton.focus();
      });
      const actions = this._node('div', 'vp-actions vp-editor-actions');
      actions.append(cancel, save);
      const unsaved = this._node('p', 'vp-help', 'Nothing is saved until you choose Save.');
      form.append(label, input, nameHelp, palette, voice, unsaved, actions);
      if (profile) {
        const deletion = this._node('div', 'vp-delete');
        const remove = this._button('Delete user', () => {
          confirmation.hidden = false;
          keep.focus();
        }, 'vp-danger');
        const confirmation = this._node('div', 'vp-delete-confirm');
        confirmation.hidden = true;
        confirmation.setAttribute('role', 'group');
        confirmation.setAttribute('aria-label', 'Confirm deletion');
        confirmation.append(this._node('p', '', `Delete ${profile.name} and their saved voice? This cannot be undone.`));
        const keep = this._button('Keep user', () => { confirmation.hidden = true; remove.focus(); });
        const confirm = this._button('Delete permanently', () => this._delete(profile.id), 'vp-danger');
        const buttons = this._node('div', 'vp-actions');
        buttons.append(keep, confirm);
        confirmation.append(buttons);
        deletion.append(remove, confirmation);
        form.append(deletion);
      }
      this.content.append(form);
      this.editor = { input, nameHelp, voiceTitle, instructions, phrases, feedback, timing, record, stop, retry, append, rerecord, save, palette };
      this._updateEditor();
      input.focus({ preventScroll: true });
    }

    _updateEditor() {
      this._updateIdentifyButton();
      this._updateIdentification();
      if (!this.editor || !this.draft) return;
      const ui = this.editor, busy = this.starting || this.recording || this.finishing;
      const length = [...this.draft.name.trim()].length;
      ui.nameHelp.textContent = `${length}/${MAX_NAME} characters`;
      ui.input.setAttribute('aria-invalid', String(length > MAX_NAME));
      ui.input.setCustomValidity(length > MAX_NAME ? `Use ${MAX_NAME} characters or fewer.` : '');
      const ready = this.multiplayer?.isReady() === true;
      ui.record.hidden = !this.wantsVoice || !!this.result || busy || !!this.recordStatus;
      ui.record.disabled = !ready || this.releaseFailed;
      ui.stop.hidden = !busy;
      ui.stop.disabled = this.starting || this.finishing || this.releaseFailed;
      ui.stop.textContent = this.finishing ? 'Checking voice…' : 'Stop';
      ui.retry.hidden = !this.wantsVoice || busy || (!this.result && !this.recordStatus);
      ui.retry.disabled = !ready || this.releaseFailed;
      ui.rerecord.hidden = this.wantsVoice;
      ui.rerecord.disabled = busy || this.releaseFailed;
      ui.append.hidden = this.wantsVoice || this.oldVoice;
      ui.append.disabled = busy || !ready || this.releaseFailed;
      ui.save.disabled = !length || length > MAX_NAME || busy || this.releaseFailed || (this.wantsVoice && !this.result);
      ui.instructions.hidden = !this.wantsVoice;
      ui.phrases.hidden = !this.wantsVoice;
      ui.voiceTitle.textContent = this.wantsVoice && this.voiceAction === 'append' ? 'Add voice samples' : 'Voice practice';
      ui.instructions.textContent = 'Read these six short phrases in your normal voice, pausing between phrases. ' +
        'Aim for 12–20 seconds of speech. ' + (this.voiceAction === 'append'
          ? 'Your saved voice stays unchanged until you choose Save.' : 'Keep going until the samples and speech time are ready.');
      ui.feedback.textContent = this.recordStatus || (this.starting ? 'Waiting for microphone permission…'
        : this.recording ? this.voiceProgress?.message || 'Recording — read the phrases, then choose Stop.'
          : this.wantsVoice ? 'Speak clearly in a quiet place. Only one person should speak.'
            : this.oldVoice ? 'This voice uses an older model. Re-record it before playing.'
              : this.legacyVoice ? 'Your saved voice still works. Add voice samples for a stronger match.' : 'A voice is saved for this user.');
      ui.feedback.dataset.state = this.releaseFailed ? 'error' : this.result ? 'complete' : busy ? 'recording' : 'idle';
      const progress = this.voiceProgress;
      this._updateTiming();
      [...ui.phrases.children].forEach((node, index) => {
        node.dataset.complete = String(index < (progress?.segments || 0));
        if (busy && index === Math.min(progress?.segments || 0, PHRASES.length - 1)) node.setAttribute('aria-current', 'step');
        else node.removeAttribute('aria-current');
      });
    }

    _updateTiming() {
      if (!this.editor) return;
      const progress = this.voiceProgress;
      const elapsed = this.recording || this.finishing ? this.env.performance.now() - this.recordStartedAt : this.recordElapsedMs || 0;
      const parts = [];
      if (elapsed > 0) parts.push(`${Math.floor(elapsed / 1000)} s elapsed`);
      const requiredSegments = Math.max(1, progress?.requiredSegments || 3);
      const requiredSeconds = Math.max(1, progress?.requiredVoicedMs || 12000) / 1000;
      if (progress) parts.push(`${Math.min(progress.segments || 0, requiredSegments)}/${requiredSegments} voice samples`,
        `${((progress.voicedMs || 0) / 1000).toFixed(1)} / ${requiredSeconds} s effective speech`,
        this.result ? 'Quality checked' : progress.canFinish ? 'Ready to stop' : 'Keep going');
      this.editor.timing.textContent = parts.join(' · ');
    }

    _record() {
      if (!this.draft || this.starting || this.recording || this.finishing || this.releaseFailed || !this.multiplayer?.isReady()) return;
      this._clearError();
      this._discardResult();
      this.voiceProgress = null;
      this.recordElapsedMs = 0;
      this.recordStatus = '';
      const token = this.activeSession = ++this.sessionSerial;
      this.captureMode = 'enrollment';
      this.starting = true;
      this._updateEditor();
      try {
        // Keep this call in the trusted button gesture for mobile microphone access.
        const started = this.multiplayer.startEnrollment({
          sessionId: `voice-profile-${Date.now()}-${token}`,
          onStarted: () => {
            if (this.activeSession !== token || !this.opened || this.recording || this.finishing) return;
            this.starting = false;
            this.recording = true;
            this.recordStartedAt = this.env.performance.now();
            this.recordTimer = this.env.setInterval(() => this._updateTiming(), 250);
            this._updateEditor();
          },
          onProgress: progress => {
            if (this.activeSession !== token || !this.opened) return;
            this.voiceProgress = progress;
            this._updateEditor();
          },
          onComplete: result => this._completed(token, result),
          onError: error => this._recordError(token, error)
        });
        Promise.resolve(started).then(ok => {
          if (ok === false && this.activeSession === token) this._recordError(token, new Error('Recording could not start. Please try again.'));
        }).catch(error => this._recordError(token, error));
      } catch (error) { this._recordError(token, error); }
    }

    async _finish() {
      if (!this.recording || this.finishing || this.releaseFailed) return;
      const token = this.activeSession;
      this.finishing = true;
      this.recordStatus = 'Checking voice quality…';
      this._updateEditor();
      try { this._completed(token, await this.multiplayer.finishEnrollment()); }
      catch (error) { this._recordError(token, error); }
    }

    _completed(token, result) {
      // finishEnrollment resolves with the same object already delivered by
      // onComplete. Keep that accepted draft until Save or explicit disposal.
      if (result && result === this.result) return;
      if (!token || this.activeSession !== token || this.completedSession === token || !this.opened) {
        this._discardResult(result);
        return;
      }
      if (!result?.embedding || !result.modelVersion) {
        this._discardResult(result);
        this._recordError(token, new Error('This recording could not be used. Please read the phrases again.'));
        return;
      }
      if (!this._release()) { this._discardResult(result); return; }
      this.completedSession = token;
      this._discardResult();
      this.result = result;
      this.voiceProgress = { ...(this.voiceProgress || {}), ...result.quality, canFinish: true };
      this.recordStatus = 'Voice quality checked. Ready to save.';
      this._updateEditor();
    }

    _recordError(token, error) {
      if (!token || this.activeSession !== token || !this.opened) return;
      this._discardResult();
      if (!this._release()) return;
      this.recordStatus = 'Recording needs another try.';
      this._showError(error?.message || 'Please read the phrases clearly and try again.');
      this._updateEditor();
    }

    _release() {
      const hadRecording = !!this.activeSession || this.starting || this.recording || this.finishing || this.releaseFailed || this.modelState.microphoneBlocked;
      if (!hadRecording) return true;
      let stopped = false;
      try {
        stopped = (this.captureMode === 'identification'
          ? this.multiplayer?.cancelIdentification() : this.multiplayer?.cancelEnrollment()) === true;
      }
      catch { /* Keep the dialog visible until the capture confirms release. */ }
      if (!stopped) {
        this.releaseFailed = true;
        this._showError('The microphone could not be stopped. Keep this window open and retry stopping it.');
        this.releaseButton.hidden = false;
        this._updateEditor();
        return false;
      }
      this.activeSession = 0;
      this.captureMode = null;
      if (this.recordTimer) {
        this.recordElapsedMs = this.env.performance.now() - this.recordStartedAt;
        this.env.clearInterval(this.recordTimer);
        this.recordTimer = null;
      }
      this.starting = this.recording = this.finishing = this.releaseFailed = false;
      this.releaseButton.hidden = true;
      this._updateEditor();
      return true;
    }

    _retryRelease() {
      if (!this._release()) return;
      this._clearError();
      this._discardResult();
      this.recordStatus = 'Microphone stopped. You can try recording again or close this window.';
      if (this.identification) {
        this.identification.status = 'error';
        this.identification.message = 'Microphone stopped. Try again when you are ready.';
      }
      this._updateEditor();
    }

    _interruptRecording(message) {
      if (!this.activeSession && !this.releaseFailed) return;
      if (!this._release()) return;
      this._discardResult();
      this.recordStatus = message;
      if (this.identification) {
        this.identification.status = 'error';
        this.identification.message = message;
      }
      this._updateEditor();
    }

    _save() {
      if (!this.editor || this.editor.save.disabled || !this.draft || !this._release()) return;
      try {
        const { id, name, emoji } = this.draft;
        if (this.wantsVoice) {
          const sample = { name: name.trim(), emoji, embedding: this.result.embedding,
            ...(this.result.templates ? { templates: this.result.templates } : {}), modelVersion: this.result.modelVersion };
          if (id && this.voiceAction === 'append') this.store.addVoice(id, sample);
          else this.store.save({ ...(id ? { id } : {}), ...sample });
        } else this.store.update(id, { name: name.trim(), emoji });
        this._loadProfiles();
        this._clearError();
        this._renderList();
        this.onChanged(this.metadataSnapshot());
        this.closeButton.focus();
      } catch (error) { this._showError(error.message); }
    }

    _delete(id) {
      if (!this._release()) return;
      try {
        this.store.remove(id);
        this._loadProfiles();
        this._clearError();
        this._renderList();
        this.onChanged(this.metadataSnapshot());
        this.closeButton.focus();
      } catch (error) { this._showError(error.message); }
    }
  }

  VoiceProfilesUI.EMOJI = EMOJI.map(([emoji, name]) => ({ emoji, name }));
  VoiceProfilesUI.PHRASES = [...PHRASES];
  root.VoiceProfilesUI = VoiceProfilesUI;
  if (typeof module !== 'undefined' && module.exports) module.exports = { VoiceProfilesUI };
})(typeof globalThis !== 'undefined' ? globalThis : window);
