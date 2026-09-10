# Pip's Memory Garden

The next playability improvement is a fifth mode, Memory. Existing Match shows all eight cards; Sky and Listen are two-choice recognition. A stable concealed board lets the player decide what to inspect and use remembered positions. All five words in the current lesson participate.

## Player experience

- Ten fixed cards contain five written words and their five pictures. Card backs identify Word or Picture and a stable position number, without revealing the noun. Choose a word card and a picture card; choosing another card of the same kind changes the selection without spending an attempt.
- A completed pair counts one attempt. A correct pair remains planted, showing its word and picture; five flowers track the garden's growth. A mismatch does not move the cards. Teaching feedback shows the two real word-picture associations until Continue, then hides only the mismatched pair. Memory mistakes represent exploration and do not enter the missed-vocabulary list.
- Study reveals this same board without scoring. Return to play hides unmatched cards without shuffling or clearing completed pairs. Study has no timer and is available between attempts. It cancels an unfinished first selection.
- No countdown, lives, loss after three attempts, reward multiplier, or new currency. All five pairs complete the round. The existing chest awards one ordinary medal fragment through its save-before-reveal path.
- Repeat keeps the five words and world but reshuffles positions. Switching other modes retains the current lesson as today. Themes, resizing, reduced motion and opening/closing My rewards preserve the current Memory board and attempt.

## Boundaries

Keep Godot 4.7, the existing web shell, original word art and audio, and existing persistence. No new dependency or external asset is needed. The unavailable Store browser connection does not block this gameplay work.

The model owns card order, visibility, selected indexes, matched words, attempts and transitions. The Control owns drawing, input, explicit teaching feedback and sound requests. The main scene owns mode selection, pause, accessibility announcements and the ordinary result/reward transaction.

Cards fit a 5-by-2 wide board or 2-by-5 tall board. All controls remain inside the assigned area at desktop, phone, tablet, square and narrow layouts. Hidden words must not leak through card tooltips or accessible labels. Normal Buttons provide touch, mouse, keyboard and existing Xbox focus navigation. Study and feedback must block synthetic card inputs as well as visible clicks.

## Verification

Native tests prove seeded layouts, exactly five safe pairs, stable positions, reselection, duplicate input rejection, explicit feedback, Study invariants, no early loss, five-pair completion exactly once, lifecycle/pause, small layouts, audio fallback and one existing reward claim. Browser playtests exercise actual input and rendered screenshots across desktop Chromium, iPhone and iPad WebKit, including memory discoveries, Study, correction, victory, modal return and replay. Existing learning, adventure and reward regressions remain passing. Deploy the tested export after commit/merge/push and verify the production pack hash and visible Memory interaction.
