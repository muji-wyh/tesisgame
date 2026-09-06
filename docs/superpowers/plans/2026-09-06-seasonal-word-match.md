# Seasonal Word Buddies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个面向约 3 岁英文初学者、全英文、无滚动、适配 iPhone / iPad 的图片与单词匹配游戏，包含独立 JSON 词库、可切换的四季主题和模型原创视听奖励。

**Architecture:** 只有一个 HTML 页面入口 `index.html`，CSS 与游戏 JavaScript 内联；词库保存在 `words.json`，单词图片集中在 `assets\images\words`，BGM、生成的英文语音和原创音效作为本地文件加载。静态 HTTP 服务解决独立 JSON 与媒体的加载问题，不需要业务后端、框架或打包。纯状态机、界面控制与三通道声音控制器各自使用具名内联脚本，素材生成器只在开发阶段运行。

**Tech Stack:** HTML5、CSS Grid、JavaScript、SVG、JSON、WAV、HTML Audio；Node.js 24、Windows PowerShell / System.Speech；测试使用 `node:test`、`node:vm`、Playwright；本地运行使用 `http-server`。

---

## 1. 最终规格与默认规则

本计划合并用户 2026-09-06 的原始需求及全部追加要求。之前设想的“词库和所有素材内嵌、浏览器临时合成中文语音、双击 HTML 运行”不再采用。

| 要求 | 明确实现 |
|---|---|
| 单 HTML | 一个页面入口，不拆成多个游戏页面；独立 JSON 和资源目录是用户追加要求，不是全部资源内嵌的单文件分发。 |
| 全英文 | 标题、按钮、计数、引导、错误、加载失败、无障碍标签、语音均为英文；开发计划可以用中文。 |
| 词库 | `words.json` 是唯一词条来源；初始包含 cat、dog、sun、ball、car、apple、fish、duck。禁止在 HTML 中复制一份备用词库。 |
| 图片 | 模型原创 SVG，实际生成到同一个目录 `assets\images\words`；不使用外链图片或 Emoji 代替图片。 |
| 初始游戏 | 词库和本局图片加载完毕后进入 `waiting`；成功 0、错误 0，没有自动播放或额外开始按钮。加载失败显示英文错误和 Retry，不静默改用固定词库。 |
| 随机出题 | 无放回抽取三个词，生成三张文字卡和三张图片卡；六张卡随机排列在不重叠的网格中。 |
| 两次点击 | 第一次图片或文字均可，进入 `matching`；第二次点击异类卡片才判定匹配。点击同一张取消，点击同类另一张改选，均不计错。 |
| 成功 | 加 1，保留两张卡的位置、标记并禁用，不允许重复得分。 |
| 错误 | 加 1，短暂标记后恢复可选。使用温和鼓励，不用羞辱或惊吓反馈。 |
| 防连点 | 正误反馈期间进入 `feedback`，锁定卡片 700ms；之后才接受下一组操作。 |
| 终局 | 成功累计到 3 次获胜；错误累计到 3 次失败。不是两者合计 3，也不是连续 3。 |
| 主题系统 | 每局开始等概率随机选择 Spring / Summer / Autumn / Winter；下拉选择器支持手动切换，改变页面配色、装饰与 BGM，不清空计数、选中项或已匹配卡片。 |
| 成功界面 | 显示当前主题对应的一个宝箱，不在胜利时再随机抽取不一致的季节。开局随机主题已经提供随机宝箱来源。 |
| 开箱 | `closed → opening → opened`；一次点击触发原创音效、动画、粒子、英文语音，1100ms 后显示奖励；重复点击无效。 |
| 开箱与切换 | 开箱开始锁定本次奖励主题；1100ms 开箱期间短暂禁用主题选择，之后可继续换页面主题，但已打开的宝箱和奖品保持原主题，不产生额外奖励。 |
| 失败界面 | 原创鼓励性小熊图片、原创失败音效、生成的英文鼓励语音和 Play again 按钮。 |
| 重开与清理 | 重置计分、选中项、反馈、宝箱、粒子和回调；停止旧语音、音效和 BGM；保留静音选择。 |
| 可访问性 | 原生按钮、键盘 Enter / Space、英文 aria 标签、清楚的焦点；尊重减少动态效果；不禁用浏览器缩放。 |
| 无滚动 | 最低验收视口 320×320 CSS 像素；重点覆盖 iPhone / iPad Safari 横竖屏、刘海和底部安全区、地址栏伸缩、iPad 分屏与触控；不裁切控件，交互目标至少 48×48。 |

主题切换本身是一次用户交互，可以开启对应背景音乐。首次打开页面保持静音；首次点击卡片或 Listen 后才播放当前主题 BGM。失败时暂停 BGM。旋转设备、改变视口或切换主题不得重建当前回合。

### 素材职责

模型负责创作英文台词、单词 SVG、奖励图案、失败配图、宝箱造型、音效合成规则、开箱动画和粒子效果。语音文件由执行代理调用本机英文 TTS 渲染为 WAV：这是“代理自行生成音频”的实施方式，不声称文本模型本身直接输出音频波形。游戏运行时不调用 `speechSynthesis`，不依赖终端用户安装英文 voice。

本机已发现 `Microsoft Zira Desktop` 和 `Microsoft David Desktop` 两个 `en-US` voice，采用 Zira；同时存在 `ffmpeg` / `ffprobe`。声音自然度与实际响度必须真机试听，不能以文件存在或 API 替身测试代替。

只有 BGM 使用用户提供的素材包。原目录只读，不修改或搬走源文件；不复制 Unity `.meta`、无关文本或整个曲库。

### 四季配置与确定的 BGM 复制来源

资源根目录：`C:\uworks\AssetsSource\Casual Game Music Pack 1.4`。

| 季节 | 源文件，相对资源根目录 | 项目目标 | 原创视觉 / 音效 |
|---|---|---|---|
| Spring | `Flower Theme\Flower-Menu-Loop.wav` | `assets\audio\bgm\spring.wav` | 粉绿花朵箱、花瓣上浮、轻摆开盖、高音短铃。 |
| Summer | `Ukulele Theme\Ukulele-Menu-v1-Loop.wav` | `assets\audio\bgm\summer.wav` | 青蓝太阳箱、气泡上升、弹跳开盖、短促三角波。 |
| Autumn | `Banjo Theme\Banjo-Menu-Loop.wav` | `assets\audio\bgm\autumn.wav` | 橙棕叶子箱、旋转落叶、偏转开盖、中低音木质音色。 |
| Winter | `Space Theme\Space-Menu-Loop.wav` | `assets\audio\bgm\winter.wav` | 冰蓝雪花箱、缓慢落雪、缓缓开盖、高音泛音长尾。 |

这四个路径已存在，格式均为 44.1kHz、双声道、16-bit PCM WAV，合计约 14.2MB；按文件名主题和格式选定，并未声称已经试听。执行时保留原 WAV，避免转码破坏循环边界；如试听后需要换曲，更新明确的源路径与复制记录。目录内没有发现独立许可证文档，不臆造授权结论；对外分发这些 BGM 前需要确认素材包许可。

### 不做的功能

不新增账号、排行榜、倒计时、付费宝箱、奖励收藏、线上 TTS、联网图片搜索或框架。三个音频通道足够：循环 BGM、一次性 SFX、一次性 Voice。

## 2. 仓库现状、文件边界与技术依据

仓库起始只有标题型 `README.md` 和未跟踪的 CommonJS `package.json`；没有游戏实现或有效测试。保留现有清单的名称、仓库、许可证等字段，只增加必要的开发脚本和依赖。用户已明确要求设计完成后直接实现：先完成并审阅本计划，再执行下面的代码、素材生成和复制步骤。

| 文件 | 责任 |
|---|---|
| `index.html` | 唯一 HTML 页面；`game-core`、`game-app`、`game-audio`、`game-audio-wiring` 内联区块。 |
| `words.json` | 唯一词库，含 ID、英文文字、图片 URL 和单词读音 URL。 |
| `voice-prompts.json` | 模型原创英文提示台词；不混入中文。 |
| `tools\generate-images.cjs` | 生成 8 张单词图、4 张奖励图和 1 张失败图。 |
| `tools\generate-sfx.cjs` | 生成通用反馈与四季入场 / 开箱的原创 WAV；不下载音效。 |
| `tools\generate-voices.ps1` | 用本机 Zira voice 生成提示与词库发音 WAV。 |
| `assets\images\words\*.svg` | 单词图片，统一目录。 |
| `assets\images\rewards\*.svg`、`assets\images\scenes\try-again.svg` | 模型原创奖励和失败插画。 |
| `assets\audio\voice\*.wav`、`assets\audio\sfx\*.wav` | 实际生成、可独立播放的本地音频。 |
| `assets\audio\bgm\*.wav` | 从上述四个确定路径复制的音乐。 |
| `tests\load-inline.cjs` | 测试直接读取 HTML 中的真实脚本，禁止另写一份引擎供测试。 |
| `tests\core.test.cjs`、`tests\assets.test.cjs`、`tests\audio.test.cjs` | 纯逻辑、资源与声音生命周期测试。 |
| `tests\browser\game.spec.cjs` | HTTP 加载、真实点击、四季、视口、英文界面与降级流程。 |
| `playwright.config.cjs`、`package.json`、`package-lock.json` | 静态服务和测试命令，不引入运行时框架。 |
| `README.md` | 英文运行、资源生成与维护说明。 |

执行前使用 `using-git-worktrees` 检查隔离方式；若新建工作树，要带入本计划和现有 `package.json`，不要删除原工作区未跟踪文件。代理默认继承当前会话的模型与 reasoning effort。以下命令均从执行工作区根目录运行，文件路径用 Windows 分隔符；JSON / HTML 中的资源字符串是浏览器 URL，使用 URL 的 `/`。

**官方依据：**

1. 独立 JSON 使用同源 HTTP 加载，不关闭浏览器本地文件安全策略。MDN：`https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSRequestNotHttp`。
2. `HTMLMediaElement.play()` 返回 Promise，可能因策略或格式失败；必须显示错误并支持真实点击重试。MDN：`https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/play`。
3. `SetOutputToWaveFile` 支持指定 WAV 格式，`SetOutputToNull` 释放文件输出。Microsoft：`https://learn.microsoft.com/en-us/dotnet/api/system.speech.synthesis.speechsynthesizer.setoutputtowavefile`。
4. `http-server` 的 `-a`、`-p` 和 `-c-1` 分别用于监听地址、端口和关闭缓存。官方仓库：`https://github.com/http-party/http-server`。
5. 单元测试使用内置运行器，浏览器使用可重试状态断言。官方文档：`https://nodejs.org/docs/latest-v24.x/api/test.html`、`https://playwright.dev/docs/test-assertions`。

## Task 1: 独立词库与纯状态机

**Files:** Create `words.json`、`index.html`、`tests\load-inline.cjs`、`tests\core.test.cjs`；修改 `package.json` 的 `scripts.test`。

- [ ] **Step 1: 创建唯一词库。**

`words.json`：

```json
[
  {"id":"cat","text":"cat","image":"assets/images/words/cat.svg","audio":"assets/audio/voice/word-cat.wav"},
  {"id":"dog","text":"dog","image":"assets/images/words/dog.svg","audio":"assets/audio/voice/word-dog.wav"},
  {"id":"sun","text":"sun","image":"assets/images/words/sun.svg","audio":"assets/audio/voice/word-sun.wav"},
  {"id":"ball","text":"ball","image":"assets/images/words/ball.svg","audio":"assets/audio/voice/word-ball.wav"},
  {"id":"car","text":"car","image":"assets/images/words/car.svg","audio":"assets/audio/voice/word-car.wav"},
  {"id":"apple","text":"apple","image":"assets/images/words/apple.svg","audio":"assets/audio/voice/word-apple.wav"},
  {"id":"fish","text":"fish","image":"assets/images/words/fish.svg","audio":"assets/audio/voice/word-fish.wav"},
  {"id":"duck","text":"duck","image":"assets/images/words/duck.svg","audio":"assets/audio/voice/word-duck.wav"}
]
```

- [ ] **Step 2: 创建加载器与失败测试。**

`tests\load-inline.cjs`：

```javascript
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.join(__dirname, '..');
function loadInline(id, globals = {}) {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const match = html.match(new RegExp(`<script id="${id}">([\\s\\S]*?)<\\/script>`));
  assert.ok(match, `Missing inline script: ${id}`);
  const context = vm.createContext({ ...globals });
  new vm.Script(match[1], { filename: `index.html#${id}` }).runInContext(context);
  return context;
}
function loadWords() {
  return JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
}
module.exports = { loadInline, loadWords, root };
```

`tests\core.test.cjs`：

```javascript
const test = require('node:test');
const assert = require('node:assert/strict');
const { loadInline, loadWords } = require('.\\load-inline.cjs');
const core = loadInline('game-core').GameCore;
const words = loadWords();
const round = () => core.createRound(words, () => 0.4);
const ids = (s) => [...new Set(s.cards.map((c) => c.wordId))];
function match(s, id, reverse = false) {
  const kinds = reverse ? ['image', 'word'] : ['word', 'image'];
  return core.chooseCard(core.chooseCard(s, `${id}:${kinds[0]}`), `${id}:${kinds[1]}`);
}
function wrong(s) {
  const [a, b] = ids(s).filter((id) => !s.matched.includes(id));
  return core.chooseCard(core.chooseCard(s, `${a}:word`), `${b}:image`);
}
test('validates vocabulary rather than substituting a built-in list', () => {
  assert.equal(core.validateWords(words).length, 8);
  for (const bad of [[], words.slice(0, 2), [...words, words[0]],
    [{ ...words[0], image: 'https://example.invalid/cat.svg' }, ...words.slice(1)],
    [{ ...words[0], text: '' }, ...words.slice(1)]]) {
    assert.throws(() => core.validateWords(bad), { name: 'TypeError' });
  }
});
test('starts waiting with three unique pairs; shuffle does not mutate its input', () => {
  const s = round();
  assert.equal(s.phase, 'waiting');
  assert.equal(s.cards.length, 6);
  assert.equal(ids(s).length, 3);
  assert.equal(new Set(s.cards.map((c) => c.id)).size, 6);
  assert.equal(s.successes + s.errors, 0);
  for (const id of ids(s)) {
    assert.deepEqual(Array.from(s.cards.filter((c) => c.wordId === id), (c) => c.kind).sort(), ['image', 'word']);
  }
  const input = [1, 2, 3];
  assert.notDeepEqual(Array.from(core.shuffle(input, () => 0)), input);
  assert.deepEqual(input, [1, 2, 3]);
  assert.throws(() => core.createRound(words, () => 1), { name: 'RangeError' });
});
test('either kind can start; same-card cancels; same-kind reselects without error', () => {
  const s = round();
  const [a, b] = ids(s);
  for (const kind of ['image', 'word']) {
    const first = core.chooseCard(s, `${a}:${kind}`);
    assert.equal(first.phase, 'matching');
    const next = core.chooseCard(first, `${b}:${kind}`);
    assert.equal(next.selected, `${b}:${kind}`);
    assert.equal(next.errors, 0);
    assert.equal(core.chooseCard(next, `${b}:${kind}`).phase, 'waiting');
  }
  assert.equal(s.selected, null);
  assert.throws(() => core.chooseCard(s, 'unknown:word'), { name: 'RangeError' });
});
test('correct feedback counts once, locks clicks and permanently disables the pair', () => {
  const s = round();
  const [a, b] = ids(s);
  const feedback = match(s, a, true);
  assert.equal(feedback.successes, 1);
  assert.equal(feedback.feedback.correct, true);
  assert.equal(core.chooseCard(feedback, `${b}:word`), feedback);
  const ready = core.finishFeedback(feedback);
  assert.equal(core.chooseCard(ready, `${a}:image`), ready);
  assert.equal(s.successes, 0);
});
test('wrong feedback increments errors and resets selection', () => {
  const feedback = wrong(round());
  assert.equal(feedback.errors, 1);
  assert.equal(feedback.successes, 0);
  assert.equal(feedback.feedback.correct, false);
  const ready = core.finishFeedback(feedback);
  assert.equal(ready.phase, 'waiting');
  assert.equal(ready.selected, null);
  assert.equal(ready.feedback, null);
});
test('three matches win despite an earlier error; current theme is not rerolled', () => {
  let s = core.finishFeedback(wrong(round()));
  for (const id of ids(s)) s = core.finishFeedback(match(s, id));
  assert.equal(s.phase, 'won');
  assert.equal(s.theme, 'summer');
  assert.equal(s.errors, 1);
  assert.equal(core.finishFeedback(s), s);
  assert.equal(core.chooseCard(s, s.cards[0].id), s);
});
test('errors accumulate independently, not consecutively or as a combined total', () => {
  let s = core.finishFeedback(wrong(round()));
  s = core.finishFeedback(match(s, ids(s)[0]));
  s = core.finishFeedback(wrong(s));
  assert.equal(s.successes + s.errors, 3);
  assert.equal(s.phase, 'waiting');
  s = core.finishFeedback(wrong(s));
  assert.equal(s.phase, 'lost');
  assert.equal(s.errors, 3);
  assert.equal(s.theme, 'summer');
  assert.equal(core.chooseCard(s, s.cards[0].id), s);
  assert.equal(round().matched.length, 0);
});
test('four equal random intervals select the four seasons', () => {
  assert.deepEqual([0, 0.2499, 0.25, 0.5, 0.75, 0.9999].map((r) => core.chooseSeason(() => r).id),
    ['spring', 'spring', 'summer', 'autumn', 'winter', 'winter']);
});
test('theme changes preserve selection, feedback, scores and matched cards', () => {
  let s = core.chooseCard(round(), `${ids(round())[0]}:word`);
  const selected = s.selected;
  s = core.setTheme(s, 'winter');
  assert.equal(s.phase, 'matching');
  assert.equal(s.selected, selected);
  const id = selected.split(':')[0];
  s = core.chooseCard(s, `${id}:image`);
  const changed = core.setTheme(s, 'spring');
  assert.equal(changed.phase, 'feedback');
  assert.equal(changed.successes, 1);
  assert.equal(changed.matched, s.matched);
  assert.equal(changed.cards, s.cards);
  assert.equal(core.finishFeedback(changed).theme, 'spring');
  assert.throws(() => core.setTheme(changed, 'unknown'), { name: 'RangeError' });
});
```

- [ ] **Step 3: 运行红灯。**

Run: `node --test tests\core.test.cjs`

Expected: FAIL，因为尚不存在 `index.html`；语法错误或缺少 Node 不是预期红灯。

- [ ] **Step 4: 创建 HTML 基础与引擎。**

`index.html` 初始完整内容：

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>Word Buddies</title>
</head>
<body>
<main id="app" aria-label="Word Buddies"></main>
<script id="game-core">
(() => {
  const SEASONS = Object.freeze(['spring', 'summer', 'autumn', 'winter'].map((id, i) => Object.freeze({
    id, name: ['Spring', 'Summer', 'Autumn', 'Winter'][i],
    prize: ['flower', 'sun', 'leaf', 'snowflake'][i],
    bgm: `assets/audio/bgm/${id}.wav`, symbol: `assets/images/rewards/${id}.svg`
  })));
  function validateWords(input) {
    if (!Array.isArray(input) || input.length < 3) throw new TypeError('At least three words are required.');
    const ids = new Set(), texts = new Set(), images = new Set();
    return Object.freeze(input.map((word) => {
      if (!word || typeof word !== 'object' ||
        ['id', 'text', 'image', 'audio'].some((key) => typeof word[key] !== 'string') ||
        !/^[a-z][a-z0-9-]{1,19}$/.test(word.id || '') ||
        !/^[a-z]{2,6}$/.test(word.text || '') ||
        !/^assets\/images\/words\/[a-z0-9-]+\.(svg|png|webp)$/.test(word.image || '') ||
        !/^assets\/audio\/voice\/[a-z0-9-]+\.wav$/.test(word.audio || '') ||
        ids.has(word.id) || texts.has(word.text) || images.has(word.image)) {
        throw new TypeError('Each word needs a unique ID, English text, local image and voice URL.');
      }
      ids.add(word.id); texts.add(word.text); images.add(word.image);
      return Object.freeze({ id: word.id, text: word.text, image: word.image, audio: word.audio });
    }));
  }
  function randomIndex(length, rng) {
    const value = rng();
    if (!Number.isFinite(value) || value < 0 || value >= 1) throw new RangeError('Random value must be in [0, 1).');
    return Math.floor(value * length);
  }
  function shuffle(input, rng = Math.random) {
    const result = [...input];
    for (let i = result.length - 1; i > 0; i -= 1) {
      const j = randomIndex(i + 1, rng);
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }
  function chooseSeason(rng = Math.random) { return SEASONS[randomIndex(4, rng)]; }
  function createRound(input, rng = Math.random) {
    const words = shuffle(validateWords(input), rng).slice(0, 3);
    const cards = shuffle(words.flatMap((word) => ['word', 'image'].map((kind) => ({
      id: `${word.id}:${kind}`, wordId: word.id, kind
    }))), rng);
    return { phase: 'waiting', cards, selected: null, matched: [], successes: 0, errors: 0, feedback: null, theme: chooseSeason(rng).id };
  }
  function chooseCard(state, cardId) {
    if (!['waiting', 'matching'].includes(state.phase)) return state;
    const card = state.cards.find((item) => item.id === cardId);
    if (!card) throw new RangeError(`Unknown card: ${cardId}`);
    if (state.matched.includes(card.wordId)) return state;
    if (state.selected === cardId) return { ...state, phase: 'waiting', selected: null };
    const first = state.cards.find((item) => item.id === state.selected);
    if (!first || first.kind === card.kind) return { ...state, phase: 'matching', selected: cardId };
    const correct = first.wordId === card.wordId;
    return {
      ...state, phase: 'feedback', selected: null,
      successes: state.successes + Number(correct), errors: state.errors + Number(!correct),
      matched: correct ? [...state.matched, card.wordId] : state.matched,
      feedback: { correct, cardIds: [first.id, card.id] }
    };
  }
  function finishFeedback(state) {
    if (state.phase !== 'feedback') return state;
    const phase = state.successes === 3 ? 'won' : state.errors === 3 ? 'lost' : 'waiting';
    return { ...state, phase, selected: null, feedback: null };
  }
  function setTheme(state, id) {
    if (!SEASONS.some((theme) => theme.id === id)) throw new RangeError(`Unknown theme: ${id}`);
    return state.theme === id ? state : { ...state, theme: id };
  }
  globalThis.GameCore = Object.freeze({ SEASONS, validateWords, shuffle, chooseSeason, createRound, chooseCard, finishFeedback, setTheme });
})();
</script>
</body>
</html>
```

- [ ] **Step 5: 运行绿灯并提交。**

```powershell
npm pkg set "scripts.test=node --test"
npm test
git add -- words.json index.html package.json tests\load-inline.cjs tests\core.test.cjs
git commit -m "feat: add JSON vocabulary and matching state machine" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: 9 个引擎测试通过，失败数 0；没有安装依赖。初版词条限定 2–6 个小写英文字母，以保证低龄卡片的可读字号。

## Task 2: 模型原创图片并统一输出目录

**Files:** Create `tools\generate-images.cjs`、`tests\assets.test.cjs`；生成 `assets\images\words\cat.svg`、`dog.svg`、`sun.svg`、`ball.svg`、`car.svg`、`apple.svg`、`fish.svg`、`duck.svg`，以及四季奖励 SVG 和失败 SVG。

- [ ] **Step 1: 写图片文件失败测试。**

`tests\assets.test.cjs` 初始内容：

```javascript
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { loadWords, loadInline, root } = require('.\\load-inline.cjs');
const words = loadWords();
const seasons = loadInline('game-core').GameCore.SEASONS;
const local = (url) => path.join(root, ...url.split('/'));
test('all vocabulary pictures are distinct local SVGs in one directory', () => {
  const pictures = words.map((word) => fs.readFileSync(local(word.image), 'utf8'));
  assert.equal(new Set(pictures).size, words.length);
  for (const source of pictures) {
    assert.match(source, /^<svg /);
    assert.doesNotMatch(source, /<script|<image|<text|\shref=|\ssrc=/i);
  }
  assert.equal(new Set(words.map((word) => path.dirname(local(word.image)))).size, 1);
});
test('four rewards and an original failure illustration exist', () => {
  for (const season of seasons) assert.match(fs.readFileSync(local(season.symbol), 'utf8'), /^<svg /);
  assert.match(fs.readFileSync(path.join(root, 'assets', 'images', 'scenes', 'try-again.svg'), 'utf8'), /^<svg /);
});
```

- [ ] **Step 2: 运行红灯。**

Run: `node --test tests\assets.test.cjs`

Expected: FAIL，缺少 SVG 文件。

- [ ] **Step 3: 实现原创 SVG 生成器。**

`tools\generate-images.cjs` 完整内容：

```javascript
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">${body}</svg>\n`;
const words = {
  cat: '<path fill="#efb25d" d="M22 50 20 13 47 32Q60 24 73 32L100 13 98 50Q110 100 60 107 10 100 22 50Z"/><path fill="#ef889a" d="m28 27 15 14-13 9m62-23-15 14 13 9"/><g fill="#38405b"><circle cx="42" cy="61" r="5"/><circle cx="78" cy="61" r="5"/><path d="m53 76 14 0-7 7Z"/></g><path fill="none" stroke="#38405b" stroke-width="3" d="M60 83v9m-30-16-19-3m19 10-18 5m78-12 19-3m-19 10 18 5"/>',
  dog: '<ellipse fill="#985f41" cx="29" cy="51" rx="19" ry="35"/><ellipse fill="#985f41" cx="91" cy="51" rx="19" ry="35"/><rect fill="#e8b879" x="27" y="22" width="66" height="85" rx="30"/><circle fill="#704d3a" cx="43" cy="54" r="13"/><g fill="#2d354e"><circle cx="43" cy="54" r="5"/><circle cx="77" cy="54" r="5"/><ellipse cx="60" cy="76" rx="10" ry="7"/></g><path fill="#e88196" d="M50 89h20q0 24-10 24T50 89"/>',
  sun: '<g stroke="#f4ad32" stroke-width="7" stroke-linecap="round"><path d="M60 8v12m0 80v12M8 60h12m80 0h12M23 23l9 9m56 56 9 9M23 97l9-9m56-56 9-9"/></g><circle fill="#ffdc66" cx="60" cy="60" r="31"/><g fill="#68512d"><circle cx="49" cy="55" r="3"/><circle cx="71" cy="55" r="3"/></g><path d="M46 69q14 14 28 0" fill="none" stroke="#68512d" stroke-width="3"/>',
  ball: '<circle fill="#f8f4e7" stroke="#505980" stroke-width="4" cx="60" cy="60" r="47"/><path fill="#7db3f1" d="m60 34 23 17-9 27H46l-9-27ZM17 43l20 8-7 28-14 3m88-39-21 8 7 28 14 3M43 16l17 18 18-18M37 99l9-21h28l10 21"/><path fill="none" stroke="#505980" stroke-width="3" d="m60 34 23 17-9 27H46l-9-27Z"/>',
  car: '<path fill="#ed7970" d="M14 57h14l13-28h42l16 28h7q8 0 8 10v22H8V68q0-11 6-11Z"/><path fill="#c8eafa" d="m46 36-9 21h22V36Zm19 0v21h24L78 36Z"/><g fill="#3b4667"><circle cx="32" cy="88" r="14"/><circle cx="91" cy="88" r="14"/></g><g fill="#edf1f9"><circle cx="32" cy="88" r="6"/><circle cx="91" cy="88" r="6"/></g>',
  apple: '<path fill="#8bb35d" d="M62 27q2-25 30-18-5 25-30 18Z"/><path d="m60 36 3-25" stroke="#7d5438" stroke-width="7"/><path fill="#ef6969" d="M60 37q-39-25-45 18-5 40 28 55 14 5 17-2 6 7 20 2 33-15 25-55-7-43-45-18Z"/><path d="M34 50q-11 11-7 27" fill="none" stroke="#ffc4bc" stroke-width="7" stroke-linecap="round"/>',
  fish: '<path fill="#efb24f" d="m84 59 29-25v51Z"/><ellipse fill="#f6ce69" cx="51" cy="60" rx="40" ry="28"/><path fill="#ed9761" d="m45 33 20-19 9 23m-29 49 20 19 9-23"/><circle fill="#344666" cx="29" cy="54" r="5"/><path d="M15 67q9 6 15 0" fill="none" stroke="#344666" stroke-width="3"/><path fill="none" stroke="#ed9761" stroke-width="3" d="M51 44q-13 16 0 32m14-30q-12 14 0 28"/>',
  duck: '<path fill="#f5d560" d="M22 69q-8-23 18-31 7-24 30-22 32 2 24 32-4 16-25 15 7 11 31 1 12 36-35 43-50 5-56-34Z"/><path fill="#f4a14b" d="m88 38 28 10-29 10Z"/><circle fill="#3c4761" cx="75" cy="33" r="4"/><path fill="#e9bb4c" d="M33 69q35-9 41 13-25 20-41-13Z"/>'
};
const rewards = {
  spring: '<g fill="#f6a9c2"><circle cx="60" cy="32" r="21"/><circle cx="87" cy="55" r="21"/><circle cx="77" cy="86" r="21"/><circle cx="43" cy="86" r="21"/><circle cx="33" cy="55" r="21"/></g><circle fill="#ffde70" cx="60" cy="59" r="18"/>',
  summer: words.sun,
  autumn: '<path fill="#df8444" d="m60 10 12 28 19-13-3 30 22 3-23 23 7 17-30-7v23h-8V91l-30 7 7-17L10 58l22-3-3-30 19 13Z"/><path d="M60 37v58m0-25L39 56m21 22 23-19" stroke="#a65e36" stroke-width="4" fill="none"/>',
  winter: '<g stroke="#80bddc" stroke-width="7" stroke-linecap="round" fill="none"><path d="M60 10v100M17 35l86 50M17 85l86-50M45 20l15 15 15-15M45 100l15-15 15 15M23 53l20-8-3-22M80 97l-3-22 20-8M23 67l20 8-3 22M80 23l-3 22 20 8"/></g>'
};
const bear = '<g fill="#d4b494"><circle cx="26" cy="25" r="17"/><circle cx="94" cy="25" r="17"/><circle cx="60" cy="62" r="47"/></g><ellipse cx="60" cy="80" rx="25" ry="19" fill="#fff0d9"/><g fill="#675344"><circle cx="43" cy="57" r="4"/><circle cx="77" cy="57" r="4"/><ellipse cx="60" cy="73" rx="6" ry="4"/></g><path d="M48 91q12-8 24 0" stroke="#675344" stroke-width="3" fill="none"/><path d="m101 82 4 8 9 1-7 6 2 9-8-5-8 5 2-9-7-6 9-1Z" fill="#f7cb69"/>';
for (const [folder, items] of Object.entries({ words, rewards, scenes: { 'try-again': bear } })) {
  const directory = path.join(root, 'assets', 'images', folder);
  fs.mkdirSync(directory, { recursive: true });
  for (const [id, body] of Object.entries(items)) fs.writeFileSync(path.join(directory, `${id}.svg`), svg(body));
}
console.log('Generated 13 original SVG images.');
```

- [ ] **Step 4: 生成、运行绿灯并提交。**

```powershell
node tools\generate-images.cjs
node --test tests\core.test.cjs tests\assets.test.cjs
git add -- tools\generate-images.cjs tests\assets.test.cjs assets\images
git commit -m "feat: generate original vocabulary and reward artwork" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: 输出 `Generated 13 original SVG images.`；当前测试全绿。单词卡不在图片上写答案；实际形象是否清晰要在页面中逐张查看。

## Task 3: 生成英文语音、原创 SFX，并复制四首 BGM

**Files:** Create `voice-prompts.json`、`tools\generate-voices.ps1`、`tools\generate-sfx.cjs`；生成 `assets\audio\voice` 与 `assets\audio\sfx`；复制四个 BGM 至 `assets\audio\bgm`；扩充 `tests\assets.test.cjs`。

- [ ] **Step 1: 定义完整英文提示台词。**

`voice-prompts.json`：

```json
{
  "welcome": "Let's find some friends! Tap a picture or a word.",
  "correct": "Great match! Well done!",
  "wrong": "Not quite. Let's try another one!",
  "loss": "Good try! Let's play again!",
  "spring-theme": "Welcome to spring!",
  "summer-theme": "Welcome to summer!",
  "autumn-theme": "Welcome to autumn!",
  "winter-theme": "Welcome to winter!",
  "spring-arrive": "You did it! Tap the spring chest for a surprise!",
  "summer-arrive": "You did it! Tap the summer chest for a surprise!",
  "autumn-arrive": "You did it! Tap the autumn chest for a surprise!",
  "winter-arrive": "You did it! Tap the winter chest for a surprise!",
  "spring-open": "A spring flower for you! Great job!",
  "summer-open": "A summer sun for you! Great job!",
  "autumn-open": "An autumn leaf for you! Great job!",
  "winter-open": "A winter snowflake for you! Great job!"
}
```

- [ ] **Step 2: 向 `tests\assets.test.cjs` 追加真实音频文件测试。**

```javascript
function assertWave(file) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
  assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
  assert.ok(bytes.length > 1000, `Wave file is too short: ${file}`);
  return bytes;
}
test('English voice prompts and every word pronunciation exist as WAV files', () => {
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
  assert.equal(Object.keys(prompts).length, 16);
  for (const [id, text] of Object.entries(prompts)) {
    assert.match(id, /^[a-z-]+$/);
    assert.match(text, /^[\x20-\x7e]+$/);
    assertWave(path.join(root, 'assets', 'audio', 'voice', `${id}.wav`));
  }
  for (const word of words) assertWave(local(word.audio));
});
test('all seasonal BGM and original SFX exist and seasonal opening sounds differ', () => {
  const hashes = [];
  for (const name of ['select', 'correct', 'wrong', 'loss']) {
    assertWave(path.join(root, 'assets', 'audio', 'sfx', `${name}.wav`));
  }
  for (const season of seasons) {
    assertWave(local(season.bgm));
    assertWave(path.join(root, 'assets', 'audio', 'sfx', `${season.id}-arrive.wav`));
    const sound = assertWave(path.join(root, 'assets', 'audio', 'sfx', `${season.id}-open.wav`));
    hashes.push(crypto.createHash('sha256').update(sound).digest('hex'));
    let peak = 0, energy = 0;
    for (let offset = 44; offset < sound.length; offset += 2) {
      const sample = Math.abs(sound.readInt16LE(offset));
      peak = Math.max(peak, sample); energy += sample;
    }
    assert.ok(peak < 30000 && energy > 0, 'Original SFX must not be silent or clipped.');
  }
  assert.equal(new Set(hashes).size, 4);
});
```

- [ ] **Step 3: 运行红灯。**

Run: `node --test tests\assets.test.cjs`

Expected: 图片测试通过，音频文件测试因 WAV 不存在而失败。

- [ ] **Step 4: 实现离线英文语音生成器。**

`tools\generate-voices.ps1`：

```powershell
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'assets\audio\voice'
[System.IO.Directory]::CreateDirectory($output) | Out-Null
$words = Get-Content -LiteralPath (Join-Path $root 'words.json') -Raw | ConvertFrom-Json
$prompts = Get-Content -LiteralPath (Join-Path $root 'voice-prompts.json') -Raw | ConvertFrom-Json
$utterances = [ordered]@{}
foreach ($property in $prompts.PSObject.Properties) {
    $utterances[$property.Name] = [string]$property.Value
}
foreach ($word in $words) {
    $utterances["word-$($word.id)"] = [string]$word.text
}
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $voice = $speaker.GetInstalledVoices() | Where-Object {
        $_.Enabled -and $_.VoiceInfo.Name -eq 'Microsoft Zira Desktop' -and
        $_.VoiceInfo.Culture.Name -eq 'en-US'
    } | Select-Object -First 1
    if (-not $voice) { throw 'Microsoft Zira Desktop (en-US) is required to generate the planned voice assets.' }
    $speaker.SelectVoice($voice.VoiceInfo.Name)
    $speaker.Rate = -1
    $speaker.Volume = 85
    $format = [System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(
        22050,
        [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
        [System.Speech.AudioFormat.AudioChannel]::Mono
    )
    foreach ($entry in $utterances.GetEnumerator()) {
        if ($entry.Key -notmatch '^[a-z0-9-]+$' -or $entry.Value -notmatch '^[\x20-\x7e]+$') {
            throw "Invalid English prompt: $($entry.Key)"
        }
        $target = Join-Path $output "$($entry.Key).wav"
        $temporary = Join-Path $output "$($entry.Key).tmp.wav"
        if (Test-Path -LiteralPath $temporary) { throw "Temporary output already exists: $temporary" }
        $speaker.SetOutputToWaveFile($temporary, $format)
        $speaker.Speak($entry.Value)
        $speaker.SetOutputToNull()
        Move-Item -LiteralPath $temporary -Destination $target -Force
    }
    Write-Output "Generated $($utterances.Count) English voice files."
} finally {
    $speaker.Dispose()
}
```

此处使用 `try/finally` 释放设备，不吞掉合成错误。生成失败时保留具体错误和命名的临时文件供定位，不把半成品替换成成功产物。

- [ ] **Step 5: 实现原创音效生成器。**

`tools\generate-sfx.cjs`：

```javascript
const fs = require('node:fs');
const path = require('node:path');
const rate = 22050;
const melodies = {
  spring: [659.25, 783.99, 987.77, 1318.51],
  summer: [523.25, 659.25, 783.99, 1046.5],
  autumn: [392, 493.88, 587.33, 783.99],
  winter: [783.99, 1046.5, 1174.66, 1567.98]
};
const sounds = {
  select: { notes: [659.25], tone: 'spring', length: 0.12 },
  correct: { notes: [523.25, 659.25, 783.99], tone: 'spring', length: 0.3 },
  wrong: { notes: [392, 329.63], tone: 'autumn', length: 0.3 },
  loss: { notes: [392, 329.63, 261.63], tone: 'autumn', length: 0.5 }
};
for (const [tone, notes] of Object.entries(melodies)) {
  sounds[`${tone}-arrive`] = { notes, tone, length: 0.4 };
  sounds[`${tone}-open`] = {
    notes: [...notes, ...notes.slice().reverse()], tone, length: tone === 'winter' ? 0.8 : 0.45
  };
}
function makeWave({ notes, tone, length }) {
  const spacing = tone === 'summer' ? 0.09 : tone === 'autumn' ? 0.18 : 0.12;
  const samples = new Float64Array(Math.ceil(((notes.length - 1) * spacing + length + 0.03) * rate));
  for (let note = 0; note < notes.length; note += 1) {
    const start = Math.round(note * spacing * rate);
    for (let i = 0; i < Math.floor(length * rate); i += 1) {
      const time = i / rate;
      const phase = 2 * Math.PI * notes[note] * time;
      const envelope = Math.min(time / 0.015, 1) * (1 - time / length) ** 2;
      let wave;
      if (tone === 'summer') wave = 2 * Math.asin(Math.sin(phase)) / Math.PI;
      else if (tone === 'autumn') wave = Math.sin(phase) + 0.15 * Math.sin(phase * 2);
      else if (tone === 'winter') wave = Math.sin(phase) + 0.3 * Math.sin(phase * 2) + 0.1 * Math.sin(phase * 3);
      else wave = Math.sin(phase + 0.2 * Math.sin(time * 35));
      samples[start + i] += wave * envelope * 0.11;
    }
  }
  const result = Buffer.alloc(44 + samples.length * 2);
  result.write('RIFF', 0); result.writeUInt32LE(result.length - 8, 4);
  result.write('WAVEfmt ', 8); result.writeUInt32LE(16, 16);
  result.writeUInt16LE(1, 20); result.writeUInt16LE(1, 22);
  result.writeUInt32LE(rate, 24); result.writeUInt32LE(rate * 2, 28);
  result.writeUInt16LE(2, 32); result.writeUInt16LE(16, 34);
  result.write('data', 36); result.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((sample, i) => {
    if (Math.abs(sample) >= 0.9) throw new RangeError('SFX peak exceeds the allowed headroom.');
    result.writeInt16LE(Math.round(sample * 32767), 44 + i * 2);
  });
  return result;
}
if (require.main === module) {
  const output = path.join(__dirname, '..', 'assets', 'audio', 'sfx');
  fs.mkdirSync(output, { recursive: true });
  for (const [name, definition] of Object.entries(sounds)) fs.writeFileSync(path.join(output, `${name}.wav`), makeWave(definition));
  console.log('Generated 12 original sound effects.');
}
module.exports = { sounds, makeWave };
```

- [ ] **Step 6: 生成语音和音效。**

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File .\tools\generate-voices.ps1
node tools\generate-sfx.cjs
```

Expected: 24 个英文语音文件、12 个原创音效文件。若生成器失败，修复明确原因后再运行，不把浏览器实时 TTS 当作未经说明的替代方案。

- [ ] **Step 7: 逐一复制指定 BGM，并核对源 / 目标哈希。**

```powershell
$source = 'C:\uworks\AssetsSource\Casual Game Music Pack 1.4'
$destination = Join-Path (Get-Location).Path 'assets\audio\bgm'
[System.IO.Directory]::CreateDirectory($destination) | Out-Null
$tracks = [ordered]@{
    spring = 'Flower Theme\Flower-Menu-Loop.wav'
    summer = 'Ukulele Theme\Ukulele-Menu-v1-Loop.wav'
    autumn = 'Banjo Theme\Banjo-Menu-Loop.wav'
    winter = 'Space Theme\Space-Menu-Loop.wav'
}
foreach ($track in $tracks.GetEnumerator()) {
    $from = Join-Path $source $track.Value
    $to = Join-Path $destination "$($track.Key).wav"
    if (Test-Path -LiteralPath $to) {
        if ((Get-FileHash -LiteralPath $from).Hash -ne (Get-FileHash -LiteralPath $to).Hash) {
            throw "Different destination file already exists: $to"
        }
    } else {
        Copy-Item -LiteralPath $from -Destination $to
    }
    if ((Get-FileHash -LiteralPath $from).Hash -ne (Get-FileHash -LiteralPath $to).Hash) {
        throw "BGM copy mismatch: $($track.Key)"
    }
}
```

Expected: 四个目标文件与所选源文件完全一致；不覆盖来源不明的现有不同文件。

- [ ] **Step 8: 运行绿灯并提交本地资源。**

```powershell
node --test tests\core.test.cjs tests\assets.test.cjs
git add -- voice-prompts.json tools\generate-voices.ps1 tools\generate-sfx.cjs tests\assets.test.cjs assets\audio
git commit -m "feat: generate English voice and chest effects with seasonal music" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: 词库、图片、真实 WAV 文件和原创音效非静音 / 不削波检查均通过。这里是本地提交，不执行推送或公开发布音乐素材。

## Task 4: 英文响应式界面、主题切换和开箱交互

**Files:** Create `.gitignore`、`playwright.config.cjs`、`tests\browser\game.spec.cjs`；修改 `index.html`、`package.json`；生成 `package-lock.json`。

- [ ] **Step 1: 增加静态服务与浏览器测试工具。**

到此才安装依赖：独立 JSON 需要 HTTP，真实布局与 iOS 触控需要浏览器测试。没有新增运行时框架。版本由执行时的 `--save-exact` 和锁文件明确记录，不猜测版本号。

```powershell
npm install --save-dev --save-exact @playwright/test http-server
npx playwright install chromium webkit
npm pkg set "scripts.start=http-server . -a 127.0.0.1 -p 4173 -c-1" "scripts.test:browser=playwright test" "scripts.test:all=npm test && npm run test:browser"
```

`.gitignore`：

```text
node_modules
playwright-report
test-results
```

`playwright.config.cjs`：

```javascript
const path = require('node:path');
const { defineConfig, devices } = require('@playwright/test');
if (!devices['iPhone 13'] || !devices['iPad Pro 11']) throw new Error('Required Apple device profiles are unavailable.');
module.exports = defineConfig({
  testDir: path.join(__dirname, 'tests', 'browser'),
  testMatch: '*.spec.cjs',
  timeout: 30000,
  expect: { timeout: 7000 },
  workers: 1,
  retries: 0,
  forbidOnly: true,
  reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:4173', trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  webServer: { command: 'npm start', url: 'http://127.0.0.1:4173', reuseExistingServer: false, timeout: 20000 },
  projects: [
    { name: 'desktop-chromium', use: { browserName: 'chromium', viewport: { width: 1366, height: 768 }, hasTouch: true } },
    { name: 'iphone-webkit', use: { ...devices['iPhone 13'], browserName: 'webkit' } },
    { name: 'ipad-webkit', use: { ...devices['iPad Pro 11'], browserName: 'webkit' } }
  ]
});
```

测试服务只监听回环地址。不为了处理端口占用而关闭其他进程；如果端口冲突，调整本计划对应命令与配置中的同一个端口。

- [ ] **Step 2: 写点击、主题和奖励流程的失败测试。**

`tests\browser\game.spec.cjs` 初始完整内容：

```javascript
const { test, expect } = require('@playwright/test');
const errors = new WeakMap();
test.beforeEach(async ({ page }) => {
  const messages = [];
  errors.set(page, messages);
  page.on('pageerror', (error) => messages.push(error.message));
  await page.addInitScript(() => {
    window.__cues = [];
    window.addEventListener('game:audio', (event) => window.__cues.push(event.detail));
  });
  await page.goto('/');
});
test.afterEach(async ({ page }) => { expect(errors.get(page)).toEqual([]); });
async function ids(page) {
  await expect(page.locator('.card')).toHaveCount(6);
  return page.locator('.card[data-kind="word"]:not(:disabled)').evaluateAll((buttons) => buttons.map((b) => b.dataset.wordId));
}
async function pair(page, id, reverse = false) {
  const kinds = reverse ? ['image', 'word'] : ['word', 'image'];
  await page.locator(`[data-card-id="${id}:${kinds[0]}"]`).tap();
  await page.locator(`[data-card-id="${id}:${kinds[1]}"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', /^(waiting|won|lost)$/);
}
async function wrong(page) {
  const [a, b] = await ids(page);
  await page.locator(`[data-card-id="${a}:word"]`).tap();
  await page.locator(`[data-card-id="${b}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', /^(waiting|lost)$/);
}
async function win(page) {
  for (const id of await ids(page)) await pair(page, id);
  await expect(page.locator('#win-screen')).toBeVisible();
}
async function lose(page) {
  for (let i = 0; i < 3; i += 1) await wrong(page);
  await expect(page.locator('#loss-screen')).toBeVisible();
}
test('waits, changes same-kind selection, and locks feedback against repeated taps', async ({ page }) => {
  const [a, b] = await ids(page);
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await page.locator(`[data-card-id="${a}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'matching');
  await page.locator(`[data-card-id="${b}:image"]`).tap();
  await expect(page.locator('#error-count')).toHaveText('0');
  await page.locator(`[data-card-id="${b}:word"]`).tap();
  await expect(page.locator('.card:disabled')).toHaveCount(6);
  await page.locator(`[data-card-id="${a}:word"]`).evaluate((button) => button.click());
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await expect(page.locator('#success-count')).toHaveText('1');
  await expect(page.locator('.card.is-matched')).toHaveCount(2);
});
test('theme switching preserves selection and scores and controls the winning chest', async ({ page }) => {
  const [a] = await ids(page);
  await page.locator(`[data-card-id="${a}:word"]`).tap();
  await page.locator('#theme').selectOption('winter');
  await expect(page.locator(`[data-card-id="${a}:word"]`)).toHaveAttribute('aria-pressed', 'true');
  await page.locator(`[data-card-id="${a}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await page.locator('#theme').selectOption('spring');
  await expect(page.locator('#success-count')).toHaveText('1');
  await win(page);
  await expect(page.locator('#chest-button')).toHaveAttribute('data-theme', 'spring');
});
test('loss shows its illustration and replay clears counters', async ({ page }) => {
  await lose(page);
  await expect(page.locator('#loss-art')).toBeVisible();
  await expect(page.locator('#chest-button')).toBeHidden();
  expect(await page.evaluate(() => window.__cues.filter((c) => c.type === 'loss').length)).toBe(1);
  await page.locator('#loss-replay').tap();
  await expect(page.locator('#success-count')).toHaveText('0');
  await expect(page.locator('#error-count')).toHaveText('0');
  await expect(page.locator('.card:not(:disabled)')).toHaveCount(6);
});
for (const [draw, theme] of [[0.1, 'spring'], [0.3, 'summer'], [0.6, 'autumn'], [0.9, 'winter']]) {
  test(`random ${theme} theme opens exactly one matching chest`, async ({ page }) => {
    await page.addInitScript((value) => { Math.random = () => value; }, draw);
    await page.reload();
    await ids(page);
    await expect(page.locator('#app')).toHaveAttribute('data-theme', theme);
    await win(page);
    await page.locator('#chest-button').tap();
    await page.locator('#chest-button').evaluate((button) => button.click());
    await expect(page.locator('#app')).toHaveAttribute('data-chest', 'opened');
    await expect(page.locator('#reward')).toBeVisible();
    expect(await page.evaluate(() => window.__cues.filter((c) => c.type === 'open').length)).toBe(1);
    const other = theme === 'winter' ? 'spring' : 'winter';
    await page.locator('#theme').selectOption(other);
    await expect(page.locator('#app')).toHaveAttribute('data-theme', other);
    await expect(page.locator('#chest-button')).toHaveAttribute('data-theme', theme);
    expect(await page.evaluate(() => window.__cues.filter((c) => c.type === 'open').length)).toBe(1);
  });
}
test('replay during opening cancels the old callback', async ({ page }) => {
  await win(page);
  await page.locator('#chest-button').tap();
  await page.locator('#win-replay').tap();
  await pair(page, (await ids(page))[0]);
  await pair(page, (await ids(page))[0]);
  await expect(page.locator('#reward')).toHaveJSProperty('hidden', true);
  await expect(page.locator('#app')).toHaveAttribute('data-chest', 'closed');
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
});
```

- [ ] **Step 3: 运行红灯。**

Run: `npm run test:browser -- --project=desktop-chromium -g "waits, changes"`

Expected: FAIL，因为还没有卡片或界面控制器；依赖安装、端口冲突或浏览器缺失不是业务红灯。

- [ ] **Step 4: 在 `</head>` 前插入响应式样式。**

以下样式使用内容可收缩的网格，避免通过硬编码高度撑出视口。`select` 和按钮均为触控目标；媒体查询只变布局，不改变游戏数据。

```html
<style id="game-style">
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }
  html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; }
  body {
    height: 100vh; height: 100dvh; overscroll-behavior: none;
    color: #35415e; background: #fff7e9;
    font-family: ui-rounded, system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  }
  button, select { font: inherit; color: inherit; touch-action: manipulation; }
  button { cursor: pointer; }
  button:disabled, select:disabled { cursor: default; }
  :is(button, select):focus-visible { outline: 4px solid #435dad; outline-offset: -5px; }
  h1, h2, p { margin: 0; }
  [data-theme="spring"] { --bg: #eff9ed; --accent: #568969; --chest: #88c99f; --edge: #517c65; --trim: #f6b8ce; }
  [data-theme="summer"] { --bg: #eafaff; --accent: #367f9c; --chest: #69c8dc; --edge: #367f9c; --trim: #ffdd75; }
  [data-theme="autumn"] { --bg: #fff1dd; --accent: #9d6140; --chest: #d9995e; --edge: #9d6140; --trim: #f7d078; }
  [data-theme="winter"] { --bg: #eef4ff; --accent: #627fa4; --chest: #a9cee9; --edge: #688faa; --trim: #f5fbff; }
  #app {
    height: 100%; min-width: 0; display: grid;
    grid-template-rows: auto minmax(0, 1fr) auto; gap: clamp(4px, 1.2vh, 14px);
    padding: max(8px, env(safe-area-inset-top)) max(8px, env(safe-area-inset-right))
      max(8px, env(safe-area-inset-bottom)) max(8px, env(safe-area-inset-left));
    background: var(--bg, #fff7e9);
  }
  header { display: grid; grid-template-columns: minmax(0, 1fr) auto auto auto; align-items: center; gap: 4px; }
  h1 { font-size: clamp(16px, 3vmin, 28px); line-height: 1.1; }
  .tool, #theme, .replay {
    min-width: 48px; min-height: 48px; padding: 4px 6px;
    border: 2px solid #d9dbe7; border-radius: 14px; background: #fff; font-weight: 700;
  }
  .tool { font-size: 14px; }
  #theme { width: 94px; font-size: 14px; }
  #screens { display: grid; min-height: 0; min-width: 0; }
  .screen { min-height: 0; min-width: 0; }
  #loading-screen { display: grid; align-content: center; justify-items: center; gap: 12px; text-align: center; }
  #load-message { overflow-wrap: anywhere; }
  #round-screen { display: grid; grid-template-rows: auto minmax(0, 1fr) auto; gap: 6px; }
  .scores { display: flex; justify-content: center; gap: 10px; font-size: 15px; font-weight: 800; }
  .scores span { padding: 3px 10px; background: #fff; border-radius: 12px; }
  #board {
    display: grid; grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: repeat(3, minmax(0, 1fr)); gap: clamp(6px, 2vmin, 18px);
    min-height: 0; width: 100%; max-width: 1050px; justify-self: center;
  }
  .card {
    position: relative; display: grid; place-items: center; min-width: 0; min-height: 0;
    border: 3px solid #e0dfeb; border-radius: 24px; background: #fff;
    padding: clamp(4px, 1vmin, 14px); font-size: clamp(24px, 7vmin, 60px);
    font-weight: 800; line-height: 1; box-shadow: 0 4px 0 #ddd8cb;
  }
  .card img { display: block; width: 100%; height: 100%; max-width: 160px; max-height: 160px; object-fit: contain; }
  .card.is-selected { border-color: var(--accent); background: var(--bg); }
  .card.is-matched { border-color: #72b997; background: #edf8f1; box-shadow: none; }
  .card.is-matched > :first-child { opacity: .4; }
  .card.is-wrong { border-color: #e3998f; background: #fff0e9; animation: wobble .35s; }
  .marker { position: absolute; right: 6px; top: 5px; font-size: 22px; color: #347354; }
  .is-wrong .marker { color: #a45047; }
  #feedback { min-height: 2.2em; font-size: clamp(14px, 2.4vmin, 22px); text-align: center; }
  .result { display: grid; grid-template-rows: auto auto minmax(0, 1fr) auto; gap: 6px; justify-items: center; text-align: center; }
  .result h2 { font-size: clamp(20px, 4vmin, 36px); }
  .result p { font-size: clamp(14px, 2.3vmin, 21px); }
  .stage { display: grid; place-items: center; position: relative; width: 100%; height: 100%; min-height: 0; overflow: hidden; isolation: isolate; }
  #chest-button {
    position: relative; width: min(75vw, 320px); height: 94%; min-height: 48px; max-height: 300px;
    border: 0; border-radius: 20px; background: transparent; padding: 0; z-index: 1;
  }
  .chest-body, .chest-lid {
    position: absolute; left: 10%; width: 80%; border: 5px solid var(--edge);
    background: linear-gradient(90deg, transparent 10%, var(--trim) 10% 18%, transparent 18% 82%, var(--trim) 82% 90%, transparent 90%), var(--chest);
  }
  .chest-body { top: 47%; height: 40%; border-radius: 0 0 17px 17px; }
  .chest-lid { top: 20%; height: 30%; border-radius: 25px 25px 5px 5px; transform-origin: 50% 0; }
  .chest-lock { position: absolute; left: 44%; top: 43%; width: 12%; height: 17%; border-radius: 5px; background: var(--trim); }
  #chest-symbol { position: absolute; left: 41%; top: 62%; width: 18%; height: 20%; object-fit: contain; }
  #app[data-chest="closed"] #chest-button { animation: float 2.4s ease-in-out infinite; }
  #app:is([data-chest="opening"], [data-chest="opened"]) .chest-lid { transform: translateY(-22%) rotate(-12deg); }
  #app[data-chest="opening"] #chest-button[data-theme="spring"] .chest-lid { animation: spring-open 1.1s both; }
  #app[data-chest="opening"] #chest-button[data-theme="summer"] .chest-lid { animation: summer-open 1.1s both; }
  #app[data-chest="opening"] #chest-button[data-theme="autumn"] .chest-lid { animation: autumn-open 1.1s both; }
  #app[data-chest="opening"] #chest-button[data-theme="winter"] .chest-lid { animation: winter-open 1.1s both; }
  #effects { position: absolute; inset: 0; overflow: hidden; pointer-events: none; z-index: 2; }
  .particle { position: absolute; width: 26px; height: 26px; left: var(--x); top: 75%; animation-duration: 2.4s; animation-delay: var(--delay); animation-fill-mode: both; }
  .particle img { width: 100%; height: 100%; display: block; }
  .particle[data-theme="spring"] { animation-name: petals; }
  .particle[data-theme="summer"] { animation-name: bubbles; border: 3px solid #74cfe2; border-radius: 50%; background: #ffffff80; }
  .particle[data-theme="autumn"] { top: 5%; animation-name: leaves; }
  .particle[data-theme="winter"] { top: 0; animation-name: snow; }
  #reward { position: absolute; bottom: 2%; z-index: 3; display: flex; align-items: center; gap: 6px; max-width: 96%; padding: 5px 10px; border-radius: 16px; background: #fff7df; font-weight: 800; font-size: clamp(16px, 2.8vmin, 26px); }
  #reward img { width: 36px; height: 36px; flex: none; object-fit: contain; }
  #loss-art { width: 100%; height: 100%; max-width: 260px; max-height: 260px; object-fit: contain; }
  .replay { min-width: 130px; font-size: 18px; background: #fff3c7; }
  #audio-status { min-height: 1.2em; font-size: 12px; text-align: center; overflow-wrap: anywhere; }
  @media (min-aspect-ratio: 1/1) {
    #board { grid-template-columns: repeat(3, minmax(0, 1fr)); grid-template-rows: repeat(2, minmax(0, 1fr)); }
  }
  @media (max-height: 480px) {
    #app { gap: 4px; }
    #round-screen { gap: 4px; }
    #board { grid-template-columns: repeat(3, minmax(0, 1fr)); grid-template-rows: repeat(2, minmax(0, 1fr)); }
    .card { border-radius: 15px; font-size: 20px; }
    .result h2 { font-size: 20px; }
    .result { gap: 4px; }
    #reward { padding: 3px 7px; }
    #reward img { width: 28px; height: 28px; }
  }
  @keyframes float { 50% { transform: translateY(-4px); } }
  @keyframes wobble { 25% { transform: rotate(-2deg); } 75% { transform: rotate(2deg); } }
  @keyframes spring-open { from { transform: none; } 50% { transform: translateY(-14%) rotate(8deg); } to { transform: translateY(-22%) rotate(-12deg); } }
  @keyframes summer-open { from { transform: none; } 45% { transform: translateY(-38%) rotate(-5deg); } to { transform: translateY(-22%) rotate(-12deg); } }
  @keyframes autumn-open { from { transform: none; } 60% { transform: translateY(-10%) rotate(-22deg); } to { transform: translateY(-22%) rotate(-12deg); } }
  @keyframes winter-open { from { transform: none; opacity: .7; } to { transform: translateY(-22%) rotate(-12deg); opacity: 1; } }
  @keyframes petals { from { opacity: 1; transform: translate(0, 0); } to { opacity: 0; transform: translate(32px, -150px) rotate(130deg); } }
  @keyframes bubbles { from { opacity: .8; transform: scale(.4); } to { opacity: 0; transform: translate(-12px, -170px) scale(1.3); } }
  @keyframes leaves { from { opacity: 1; transform: rotate(0); } to { opacity: 0; transform: translate(45px, 170px) rotate(240deg); } }
  @keyframes snow { from { opacity: 1; transform: translate(0, 0); } to { opacity: 0; transform: translate(-18px, 170px); } }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation: none !important; transition: none !important; }
    #effects { display: none; }
  }
</style>
```

- [ ] **Step 5: 用以下区块替换初始 `main#app`。**

```html
<main id="app" aria-label="Word Buddies" data-phase="loading">
  <header>
    <h1>Word Buddies</h1>
    <select id="theme" aria-label="Theme" disabled></select>
    <button id="mute" class="tool" type="button" aria-pressed="false" disabled>Mute</button>
    <button id="listen" class="tool" type="button" aria-label="Listen again" disabled>Listen</button>
  </header>
  <div id="screens">
    <section id="loading-screen" class="screen">
      <h2>Getting ready</h2>
      <p id="load-message" role="status">Loading words and pictures...</p>
      <button id="retry" class="replay" type="button" hidden>Retry</button>
    </section>
    <section id="round-screen" class="screen" aria-label="Matching game" hidden>
      <div class="scores"><span>Matches <b id="success-count">0</b>/3</span><span>Oops <b id="error-count">0</b>/3</span></div>
      <div id="board" aria-label="Word and picture cards"></div>
      <p id="feedback" role="status" aria-live="polite"></p>
    </section>
    <section id="win-screen" class="screen result" aria-labelledby="win-title" hidden>
      <h2 id="win-title" tabindex="-1">You did it!</h2>
      <p id="win-hint"></p>
      <div class="stage">
        <div id="effects" aria-hidden="true"></div>
        <button id="chest-button" type="button">
          <span class="chest-body" aria-hidden="true"></span>
          <span class="chest-lid" aria-hidden="true"></span>
          <span class="chest-lock" aria-hidden="true"></span>
          <img id="chest-symbol" alt="">
        </button>
        <div id="reward" role="status" tabindex="-1" hidden><img id="reward-image" alt=""><span id="reward-label"></span></div>
      </div>
      <button id="win-replay" class="replay" type="button">Play again</button>
    </section>
    <section id="loss-screen" class="screen result" aria-labelledby="loss-title" hidden>
      <h2 id="loss-title" tabindex="-1">Good try!</h2>
      <p>Let's play again!</p>
      <div class="stage"><img id="loss-art" src="assets/images/scenes/try-again.svg" alt="A friendly bear ready to try again"></div>
      <button id="loss-replay" class="replay" type="button">Play again</button>
    </section>
  </div>
  <p id="audio-status" role="status" aria-live="polite"></p>
</main>
```

- [ ] **Step 6: 在 `game-core` 后插入完整控制器。**

`game:audio` 事件的 `detail` 使用 `{ type, theme?, voice?, muted?, hidden? }`。图片用真实 `<img>` 从 JSON URL 加载，不再从内联词库中生成 DOM 答案。

```html
<script id="game-app">
(() => {
  const core = GameCore, byId = (id) => document.getElementById(id);
  const app = byId('app'), board = byId('board');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const timers = new Set();
  let words = [], state, generation = 0, chest = 'closed', rewardTheme = null, muted = false;
  const cue = (type, detail = {}) => window.dispatchEvent(new CustomEvent('game:audio', { detail: { type, ...detail } }));
  const theme = (id) => {
    const result = core.SEASONS.find((item) => item.id === id);
    if (!result) throw new RangeError(`Unknown theme: ${id}`);
    return result;
  };
  function clearTimers() { generation += 1; for (const timer of timers) clearTimeout(timer); timers.clear(); }
  function later(callback, delay) {
    const current = generation;
    const timer = setTimeout(() => { timers.delete(timer); if (current === generation) callback(); }, delay);
    timers.add(timer);
  }
  function setImage(image, source) { if (image.getAttribute('src') !== source) image.src = source; }
  function render() {
    app.dataset.phase = state.phase; app.dataset.theme = state.theme; app.dataset.chest = chest;
    byId('loading-screen').hidden = true;
    byId('round-screen').hidden = ['won', 'lost'].includes(state.phase);
    byId('win-screen').hidden = state.phase !== 'won';
    byId('loss-screen').hidden = state.phase !== 'lost';
    byId('theme').value = state.theme; byId('theme').disabled = chest === 'opening';
    byId('mute').disabled = false; byId('listen').disabled = false;
    byId('success-count').textContent = state.successes;
    byId('error-count').textContent = state.errors;
    for (const button of board.children) {
      const matched = state.matched.includes(button.dataset.wordId);
      const wrong = Boolean(state.feedback?.cardIds.includes(button.dataset.cardId) && !state.feedback.correct);
      button.disabled = matched || !['waiting', 'matching'].includes(state.phase);
      button.classList.toggle('is-selected', state.selected === button.dataset.cardId);
      button.classList.toggle('is-matched', matched); button.classList.toggle('is-wrong', wrong);
      button.setAttribute('aria-pressed', String(state.selected === button.dataset.cardId));
      button.querySelector('.marker').textContent = matched ? '✓' : wrong ? '×' : '';
    }
    byId('feedback').textContent = state.phase === 'waiting' ? 'Pick a word or a picture.' :
      state.phase === 'matching' ? 'Find its friend!' :
      state.phase === 'feedback' ? (state.feedback.correct ? 'Great match!' : 'Try another friend!') : '';
    byId('chest-button').disabled = state.phase !== 'won' || chest !== 'closed';
    if (state.phase === 'won') {
      const season = theme(rewardTheme || state.theme);
      byId('chest-button').dataset.theme = season.id;
      byId('chest-button').setAttribute('aria-label', `Open the ${season.name} chest`);
      setImage(byId('chest-symbol'), season.symbol);
      byId('win-hint').textContent = chest === 'closed' ? `Tap the ${season.name} chest!` :
        chest === 'opening' ? 'Opening your surprise...' : 'A gift for you!';
    }
  }
  function startRound(focus = false) {
    clearTimers();
    state = core.createRound(words); chest = 'closed'; rewardTheme = null;
    cue('reset', { theme: state.theme });
    byId('effects').replaceChildren(); byId('reward').hidden = true;
    byId('reward-image').removeAttribute('src'); byId('reward-label').textContent = '';
    board.replaceChildren();
    for (const card of state.cards) {
      const word = words.find((item) => item.id === card.wordId);
      const button = document.createElement('button');
      button.type = 'button'; button.className = 'card';
      button.dataset.cardId = card.id; button.dataset.wordId = card.wordId; button.dataset.kind = card.kind;
      button.setAttribute('aria-label', card.kind === 'word' ? word.text : `Picture of ${word.text}`);
      const content = document.createElement(card.kind === 'word' ? 'span' : 'img');
      if (card.kind === 'word') content.textContent = word.text;
      else { content.src = word.image; content.alt = ''; content.draggable = false; }
      const marker = document.createElement('span');
      marker.className = 'marker'; marker.setAttribute('aria-hidden', 'true');
      button.append(content, marker); board.append(button);
    }
    render();
    if (focus) board.querySelector('button').focus();
  }
  function finishTurn() {
    state = core.finishFeedback(state); render();
    if (state.phase === 'won') { cue('win', { theme: state.theme }); byId('win-title').focus(); }
    else if (state.phase === 'lost') { cue('loss'); byId('loss-title').focus(); }
    else board.querySelector('button:not(:disabled)')?.focus();
  }
  function particles(season) {
    byId('effects').replaceChildren();
    if (reduced.matches) return;
    for (let i = 0; i < 24; i += 1) {
      const particle = document.createElement('span');
      particle.className = 'particle'; particle.dataset.theme = season.id;
      particle.style.setProperty('--x', `${5 + Math.random() * 86}%`);
      particle.style.setProperty('--delay', `${Math.random() * 0.6}s`);
      if (season.id !== 'summer') {
        const image = document.createElement('img'); image.src = season.symbol; image.alt = ''; particle.append(image);
      }
      byId('effects').append(particle);
    }
    later(() => byId('effects').replaceChildren(), 3200);
  }
  function preload(source) {
    const image = new Image(); image.src = source;
    return image.decode();
  }
  async function readWords() {
    if (location.protocol === 'file:') throw new Error('Open this game through the local HTTP server.');
    const response = await fetch('words.json', { cache: 'no-store' });
    if (!response.ok) throw new Error(`Vocabulary request failed (${response.status}).`);
    const result = core.validateWords(await response.json());
    await Promise.all([...result.map((word) => word.image), ...core.SEASONS.map((s) => s.symbol),
      'assets/images/scenes/try-again.svg'].map(preload));
    return result;
  }
  function boot() {
    clearTimers(); cue('reset', { theme: null });
    app.dataset.phase = 'loading'; byId('retry').hidden = true;
    byId('loading-screen').hidden = false;
    for (const id of ['round-screen', 'win-screen', 'loss-screen']) byId(id).hidden = true;
    for (const id of ['theme', 'mute', 'listen']) byId(id).disabled = true;
    byId('load-message').textContent = 'Loading words and pictures...';
    readWords().then((loaded) => { words = loaded; startRound(); }, (error) => {
      console.error('Vocabulary or image loading failed.', error);
      app.dataset.phase = 'error';
      byId('load-message').textContent = 'Could not load words or pictures. Check the files and server, then tap Retry.';
      byId('retry').hidden = false;
    });
  }
  for (const season of core.SEASONS) {
    const option = document.createElement('option'); option.value = season.id; option.textContent = season.name;
    byId('theme').append(option);
  }
  board.addEventListener('click', (event) => {
    const button = event.target.closest('button[data-card-id]');
    if (!button || !board.contains(button) || button.disabled) return;
    const next = core.chooseCard(state, button.dataset.cardId);
    if (next === state) return;
    state = next; render();
    if (state.phase === 'matching') {
      const selected = state.cards.find((card) => card.id === state.selected);
      cue('select', { voice: words.find((word) => word.id === selected.wordId).audio });
    } else if (state.phase === 'feedback') {
      cue(state.feedback.correct ? 'correct' : 'wrong'); later(finishTurn, 700);
    }
  });
  byId('theme').addEventListener('change', () => {
    if (!state || chest === 'opening') return;
    state = core.setTheme(state, byId('theme').value); render();
    cue('theme', { theme: state.theme });
  });
  byId('chest-button').addEventListener('click', () => {
    if (state.phase !== 'won' || chest !== 'closed') return;
    rewardTheme = state.theme; chest = 'opening';
    const season = theme(rewardTheme);
    render(); particles(season); cue('open', { theme: season.id });
    later(() => {
      chest = 'opened'; setImage(byId('reward-image'), season.symbol);
      byId('reward-label').textContent = `Your ${season.prize}!`;
      byId('reward').hidden = false; render(); byId('reward').focus();
    }, reduced.matches ? 0 : 1100);
  });
  for (const id of ['win-replay', 'loss-replay']) byId(id).addEventListener('click', () => startRound(true));
  byId('mute').addEventListener('click', () => {
    muted = !muted; byId('mute').textContent = muted ? 'Unmute' : 'Mute';
    byId('mute').setAttribute('aria-pressed', String(muted)); cue('mute', { muted });
  });
  byId('listen').addEventListener('click', () => cue('listen'));
  byId('retry').addEventListener('click', boot);
  boot();
})();
</script>
```

加载失败处理只包围 JSON / 资源读取边界；成功回调中的编程错误不会被伪装成“正常加载失败”。没有使用 `catch` 返回成功形状的默认词库。

- [ ] **Step 7: 运行当前测试并提交。**

```powershell
npm test
npm run test:browser -- --project=desktop-chromium
git add -- .gitignore index.html package.json package-lock.json playwright.config.cjs tests\browser\game.spec.cjs
git commit -m "feat: add responsive English gameplay and switchable seasonal themes" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: 当前单元与交互测试全绿；四季切换、计分和开箱可操作。音频事件尚需 Task 5 连接，不提前声称声音已完成。

## Task 5: 接通 BGM、生成语音与原创音效

**Files:** Create `tests\audio.test.cjs`；在 `index.html` 的 `game-app` 后插入 `game-audio` 与 `game-audio-wiring`。

- [ ] **Step 1: 写三通道声音控制器失败测试。**

`tests\audio.test.cjs`：

```javascript
const test = require('node:test');
const assert = require('node:assert/strict');
const { loadInline } = require('.\\load-inline.cjs');
const themes = loadInline('game-core').GameCore.SEASONS;
const audio = loadInline('game-audio').GameAudio;
function fixture(rejectPlay = false) {
  const instances = [], statuses = [];
  class Media {
    constructor() { this.src = ''; this.paused = true; this.readyState = 4; this.currentTime = 0; this.error = null; this.events = {}; this.plays = 0; instances.push(this); }
    addEventListener(name, callback) { this.events[name] = callback; }
    play() {
      this.plays += 1;
      if (rejectPlay) { this.paused = true; return Promise.reject(Object.assign(new Error('blocked'), { name: 'NotAllowedError' })); }
      this.paused = false; this.events.playing?.(); return Promise.resolve();
    }
    pause() { this.paused = true; this.events.pause?.(); }
    load() { this.error = null; }
  }
  const controller = audio.createController({ Audio: Media, console: { warn() {} } }, (message) => statuses.push(message), themes);
  return { controller, instances, statuses };
}
test('starts silent, then plays the selected word and current theme BGM', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  assert.equal(f.instances.length, 0);
  f.controller.handle({ type: 'select', voice: 'assets/audio/voice/word-cat.wav' });
  assert.ok(f.instances.some((a) => a.src.endsWith('word-cat.wav') && !a.paused));
  assert.ok(f.instances.some((a) => a.src.endsWith('bgm/spring.wav') && a.loop));
});
test('all four themes use their own music, entry sound, opening sound and speech', () => {
  for (const theme of themes) {
    const f = fixture();
    f.controller.handle({ type: 'reset', theme: theme.id });
    f.controller.handle({ type: 'win', theme: theme.id });
    assert.ok(f.instances.some((a) => a.src.endsWith(`sfx/${theme.id}-arrive.wav`)));
    f.controller.handle({ type: 'open', theme: theme.id });
    assert.ok(f.instances.some((a) => a.src.endsWith(`sfx/${theme.id}-open.wav`)));
    assert.ok(f.instances.some((a) => a.src.endsWith(`voice/${theme.id}-open.wav`)));
    assert.equal(f.instances.length, 3);
  }
});
test('theme switching replaces BGM without creating extra players', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'select', voice: 'assets/audio/voice/word-cat.wav' });
  f.controller.handle({ type: 'theme', theme: 'winter' });
  assert.equal(f.instances.length, 3);
  assert.ok(f.instances.some((a) => a.loop && a.src.endsWith('winter.wav') && !a.paused));
  assert.ok(f.instances.some((a) => a.src.endsWith('voice/winter-theme.wav')));
});
test('mute, reset and hiding stop all channels; visibility alone does not autoplay', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'summer' });
  f.controller.handle({ type: 'listen' });
  f.controller.handle({ type: 'mute', muted: true });
  const plays = f.instances.reduce((sum, a) => sum + a.plays, 0);
  f.controller.handle({ type: 'open', theme: 'summer' });
  assert.equal(f.instances.reduce((sum, a) => sum + a.plays, 0), plays);
  assert.ok(f.instances.every((a) => a.paused));
  f.controller.handle({ type: 'mute', muted: false });
  f.controller.handle({ type: 'visibility', hidden: true });
  assert.ok(f.instances.every((a) => a.paused));
  f.controller.handle({ type: 'visibility', hidden: false });
  assert.ok(f.instances.every((a) => a.paused));
  f.controller.handle({ type: 'listen' });
  assert.ok(f.instances.some((a) => !a.paused));
  f.controller.handle({ type: 'reset', theme: 'winter' });
  assert.ok(f.instances.every((a) => a.paused));
});
test('failure stops BGM and plays the prerecorded English encouragement', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'autumn' });
  f.controller.handle({ type: 'listen' });
  f.controller.handle({ type: 'loss' });
  assert.ok(f.instances.find((a) => a.loop).paused);
  assert.ok(f.instances.some((a) => a.src.endsWith('voice/loss.wav') && !a.paused));
});
test('playback errors are visible and stale failures do not pollute a reset', async () => {
  const f = fixture(true);
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'listen' });
  await Promise.resolve(); await Promise.resolve();
  assert.ok(f.statuses.some((text) => text.includes('Listen')));
  const g = fixture(true);
  g.controller.handle({ type: 'reset', theme: 'spring' });
  g.controller.handle({ type: 'listen' });
  g.controller.handle({ type: 'reset', theme: 'winter' });
  await Promise.resolve(); await Promise.resolve();
  assert.equal(g.statuses.at(-1), '');
  assert.throws(() => g.controller.handle({ type: 'unknown' }), { name: 'RangeError' });
});
```

- [ ] **Step 2: 运行红灯。**

Run: `node --test tests\audio.test.cjs`

Expected: FAIL，报告 `Missing inline script: game-audio`。

- [ ] **Step 3: 插入可管理生命周期的媒体控制器。**

最多创建三个 `Audio` 对象；不用不断叠加播放器。每次播放带通道代次，重开 / 换音频后的旧 Promise 不得覆盖新状态。浏览器阻止播放时，显示短英文消息并用 Listen 重试。

```html
<script id="game-audio">
(() => {
  function createController(host, report, themes) {
    const channels = new Map();
    const status = { voice: '', sfx: '', bgm: '' };
    let currentTheme = null, musicEnabled = true, muted = false, hidden = false;
    let lastVoice = 'assets/audio/voice/welcome.wav', lastSfx = null;
    function notice(kind, message, error) {
      status[kind] = message; report(Object.values(status).find(Boolean) || '');
      if (error) host.console.warn(message, error);
    }
    function duck() {
      const bgm = channels.get('bgm')?.element, voice = channels.get('voice')?.element;
      if (bgm) bgm.volume = voice && !voice.paused && !voice.error ? 0.05 : 0.15;
    }
    function channel(kind) {
      if (channels.has(kind)) return channels.get(kind);
      if (typeof host.Audio !== 'function') { notice(kind, 'Audio is not supported on this device.'); return null; }
      const element = new host.Audio();
      element.preload = 'none'; element.loop = kind === 'bgm';
      element.volume = kind === 'voice' ? 0.8 : kind === 'sfx' ? 0.3 : 0.15;
      const entry = { element, source: '', token: 0 };
      element.addEventListener('error', () => {
        if (entry.source && element.error && !muted && !hidden) {
          notice(kind, `${kind === 'bgm' ? 'Music' : kind === 'sfx' ? 'Sound' : 'Voice'} unavailable. Tap Listen.`, element.error);
        }
        duck();
      });
      if (kind === 'voice') for (const event of ['playing', 'pause', 'ended']) element.addEventListener(event, duck);
      channels.set(kind, entry); duck(); return entry;
    }
    function stop(kind) {
      const entry = channels.get(kind);
      if (!entry) return;
      entry.token += 1; entry.element.pause();
      if (entry.element.readyState > 0) entry.element.currentTime = 0;
    }
    function stopAll() { for (const kind of channels.keys()) stop(kind); }
    function play(kind, source) {
      if (!source || muted || hidden) return;
      const entry = channel(kind);
      if (!entry) return;
      const element = entry.element;
      if (kind === 'bgm' && entry.source === source && !element.paused) return;
      stop(kind);
      const token = entry.token;
      if (entry.source !== source) { entry.source = source; element.src = source; }
      else if (element.error) element.load();
      element.play().then(() => {
        if (token === entry.token) { notice(kind, ''); duck(); }
      }).catch((error) => {
        if (token !== entry.token) return;
        notice(kind, error.name === 'NotAllowedError' ? 'Tap Listen to enable audio.' :
          `${kind === 'bgm' ? 'Music' : kind === 'sfx' ? 'Sound' : 'Voice'} unavailable. Tap Listen.`, error);
      });
    }
    function setTheme(id) {
      if (id === null) { currentTheme = null; return; }
      const found = themes.find((theme) => theme.id === id);
      if (!found) throw new RangeError(`Unknown audio theme: ${id}`);
      currentTheme = found;
    }
    function playCurrent() {
      if (musicEnabled && currentTheme) play('bgm', currentTheme.bgm);
      play('sfx', lastSfx); play('voice', lastVoice);
    }
    function prompt(name, sound = name) {
      lastVoice = `assets/audio/voice/${name}.wav`;
      lastSfx = sound ? `assets/audio/sfx/${sound}.wav` : null;
      playCurrent();
    }
    function handle(cue) {
      switch (cue.type) {
        case 'reset':
          stopAll(); setTheme(cue.theme); musicEnabled = true;
          lastVoice = 'assets/audio/voice/welcome.wav'; lastSfx = null;
          for (const kind of Object.keys(status)) status[kind] = '';
          report(''); return;
        case 'visibility':
          hidden = cue.hidden; if (hidden) stopAll(); return;
        case 'mute':
          muted = cue.muted; if (muted) stopAll(); else playCurrent(); return;
        case 'theme':
          setTheme(cue.theme); stop('bgm'); prompt(`${cue.theme}-theme`, `${cue.theme}-arrive`); return;
        case 'select':
          lastVoice = cue.voice; lastSfx = 'assets/audio/sfx/select.wav'; playCurrent(); return;
        case 'correct':
        case 'wrong':
          prompt(cue.type); return;
        case 'win':
          setTheme(cue.theme); musicEnabled = true; prompt(`${cue.theme}-arrive`); return;
        case 'open':
          prompt(`${cue.theme}-open`); return;
        case 'loss':
          musicEnabled = false; stop('bgm'); prompt('loss'); return;
        case 'listen':
          playCurrent(); return;
        default:
          throw new RangeError(`Unknown audio cue: ${cue.type}`);
      }
    }
    return Object.freeze({ handle });
  }
  globalThis.GameAudio = Object.freeze({ createController });
})();
</script>
```

- [ ] **Step 4: 插入连接代码。**

```html
<script id="game-audio-wiring">
(() => {
  const controller = GameAudio.createController(window, (message) => {
    document.getElementById('audio-status').textContent = message;
  }, GameCore.SEASONS);
  window.addEventListener('game:audio', (event) => controller.handle(event.detail));
  document.addEventListener('visibilitychange', () => controller.handle({ type: 'visibility', hidden: document.hidden }));
  window.addEventListener('pagehide', () => controller.handle({ type: 'visibility', hidden: true }));
  window.addEventListener('pageshow', () => controller.handle({ type: 'visibility', hidden: document.hidden }));
})();
</script>
```

- [ ] **Step 5: 运行绿灯并提交。**

```powershell
npm test
npm run test:browser -- --project=desktop-chromium
git add -- index.html tests\audio.test.cjs
git commit -m "feat: connect generated audio and theme music lifecycle" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: 新增 6 个声音生命周期测试通过，现有流程仍通过。这里只证明资源与调用，不代替实际试听。

## Task 6: iPhone / iPad、加载错误、英文内容与交付

**Files:** 扩充 `tests\browser\game.spec.cjs`、`tests\assets.test.cjs`；修改 `README.md`；若回归失败，只修正 `index.html` 中对应的具名区块。

- [ ] **Step 1: 追加英文内容约束。**

在 `tests\assets.test.cjs` 末尾追加：

```javascript
test('runtime UI and prompts are English and do not use live browser speech synthesis', () => {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const prompts = fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8');
  assert.match(html, /<html lang="en">/);
  assert.doesNotMatch(html + prompts, /\p{Script=Han}/u);
  assert.doesNotMatch(html, /speechSynthesis|SpeechSynthesisUtterance/);
});
```

- [ ] **Step 2: 追加视口、错误处理和实际声音连接测试。**

在 `tests\browser\game.spec.cjs` 末尾追加完整代码：

```javascript
async function contained(page) {
  const failures = await page.evaluate(() => {
    const errors = [];
    for (const node of [document.documentElement, document.body, document.querySelector('#app'),
      document.querySelector('#screens'), ...document.querySelectorAll('.screen:not([hidden])')]) {
      if (node.scrollWidth > node.clientWidth + 1 || node.scrollHeight > node.clientHeight + 1) errors.push(`overflow:${node.id || node.tagName}`);
    }
    for (const node of document.querySelectorAll('button, select')) {
      if (!node.getClientRects().length) continue;
      const r = node.getBoundingClientRect();
      if (r.left < -1 || r.top < -1 || r.right > innerWidth + 1 || r.bottom > innerHeight + 1) errors.push(`outside:${node.id || node.dataset.cardId}`);
      if (r.width < 48 || r.height < 48) errors.push(`small:${node.id || node.dataset.cardId}`);
    }
    return errors;
  });
  expect(failures).toEqual([]);
}
for (const [width, height] of [[320, 320], [375, 667], [390, 844], [430, 932], [844, 390],
  [768, 1024], [834, 1194], [1194, 834], [1024, 1366], [507, 1024]]) {
  test(`all screens fit ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height }); await ids(page); await contained(page);
    await win(page); await contained(page);
    await page.locator('#chest-button').tap();
    await expect(page.locator('#app')).toHaveAttribute('data-chest', 'opened');
    await contained(page);
    await page.locator('#win-replay').tap(); await lose(page); await contained(page);
  });
}
test('rotation and theme changes preserve selection; keyboard and reduced motion work', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const [id] = await ids(page);
  const first = page.locator(`[data-card-id="${id}:word"]`);
  await first.focus(); await page.keyboard.press('Enter');
  await page.setViewportSize({ width: 1194, height: 834 });
  await page.locator('#theme').selectOption('winter');
  await expect(first).toHaveAttribute('aria-pressed', 'true');
  await page.locator(`[data-card-id="${id}:image"]`).focus(); await page.keyboard.press('Space');
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await win(page); await page.locator('#chest-button').tap();
  await expect(page.locator('#app')).toHaveAttribute('data-chest', 'opened');
  await expect(page.locator('#effects')).toBeEmpty(); await contained(page);
});
test('mixed results do not end at a combined total of three', async ({ page }) => {
  await wrong(page); await pair(page, (await ids(page))[0], true); await wrong(page);
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await expect(page.locator('#success-count')).toHaveText('1');
  await expect(page.locator('#error-count')).toHaveText('2');
});
test('invalid JSON vocabulary shows an English error and Retry recovers', async ({ page }) => {
  await page.route('**/words.json', (route) => route.fulfill({ status: 200, contentType: 'application/json', body: '[]' }));
  await page.reload();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'error');
  await expect(page.locator('#load-message')).toContainText('Could not load');
  await page.unroute('**/words.json'); await page.locator('#retry').tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await ids(page); await contained(page);
});
test('a missing word picture is visible rather than becoming a broken game card', async ({ page }) => {
  await page.route('**/assets/images/words/cat.svg', (route) => route.abort());
  await page.reload();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'error');
  await expect(page.locator('#retry')).toBeVisible();
  await contained(page);
});
test('blocked media playback is visible and does not block matching', async ({ page }) => {
  await page.addInitScript(() => {
    HTMLMediaElement.prototype.play = function () {
      return Promise.reject(new DOMException('Playback denied', 'NotAllowedError'));
    };
  });
  await page.reload();
  const [id] = await ids(page);
  await page.locator(`[data-card-id="${id}:word"]`).tap();
  await expect(page.locator('#audio-status')).toContainText('Listen');
  await page.locator(`[data-card-id="${id}:image"]`).tap();
  await expect(page.locator('#success-count')).toHaveText('1');
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await contained(page);
});
test('UI reaches generated word audio, theme BGM and mute controls', async ({ page }) => {
  await page.addInitScript(() => {
    window.__audio = [];
    window.Audio = class {
      constructor() { this.src = ''; this.paused = true; this.readyState = 4; this.error = null; this.events = {}; }
      addEventListener(name, listener) { this.events[name] = listener; }
      play() { this.paused = false; window.__audio.push(this.src); this.events.playing?.(); return Promise.resolve(); }
      pause() { this.paused = true; this.events.pause?.(); }
      load() {}
    };
  });
  await page.reload();
  const [id] = await ids(page);
  expect(await page.evaluate(() => window.__audio)).toEqual([]);
  await page.locator(`[data-card-id="${id}:word"]`).tap();
  expect(await page.evaluate(() => window.__audio)).toContain(`assets/audio/voice/word-${id}.wav`);
  await page.locator('#theme').selectOption('winter');
  expect(await page.evaluate(() => window.__audio)).toContain('assets/audio/bgm/winter.wav');
  await page.locator('#mute').tap();
  const count = await page.evaluate(() => window.__audio.length);
  await page.locator('#listen').tap();
  expect(await page.evaluate(() => window.__audio.length)).toBe(count);
  await page.locator('#mute').tap();
  expect(await page.evaluate(() => window.__audio.length)).toBeGreaterThan(count);
});
test('all requested resources stay on the local static origin', async ({ page }) => {
  const remote = [];
  await page.route('**/*', (route) => {
    if (new URL(route.request().url()).origin !== 'http://127.0.0.1:4173') {
      remote.push(route.request().url()); return route.abort();
    }
    return route.continue();
  });
  await page.reload(); await win(page); await page.locator('#chest-button').tap();
  await expect(page.locator('#reward')).toBeVisible();
  expect(remote).toEqual([]);
});
```

- [ ] **Step 3: 运行完整功能回归。**

```powershell
npm run test:all
```

Expected: 引擎、资源、英文约束、声音生命周期和三个浏览器项目全部通过，无屏蔽失败。重点看真实边界，不用“隐藏更多内容”修复溢出。出现失败先保留复现断言，再修复对应逻辑。

这个补充回归阶段不人为制造失败；如果新增断言发现问题，再进行真实的红灯 → 修正 → 绿灯循环。现有实际缺陷可以使最终实现优于本计划中的初稿代码，需同步必要说明。

- [ ] **Step 4: 进行 iPhone / iPad Safari 真机与声音验收。**

本机启动命令：

```powershell
npm start
```

桌面查看：`http://127.0.0.1:4173`。如需真机局域网访问，在确认本地网络可信后由用户允许监听网卡，而不是默认把开发服务暴露到网络。没有接入真机时必须记录“尚未真机验证”，不能将 WebKit 模拟结果写成真机兼容结论。

| 真机项目 | 必须观察到的结果 |
|---|---|
| iPhone Safari 竖屏与横屏 | 所有卡片、计数、主题切换、声音按钮完整可见；没有横纵滚动和底部遮挡。 |
| 刘海、Home Indicator、地址栏伸缩 | `safe-area-inset-*` 与动态视口生效，按钮不落入安全区。 |
| iPad Safari 竖屏、横屏、分屏 | 布局随可用空间变化，不重新抽题或清空选中、成功和错误。 |
| 触控与键盘 | 单击 / 轻点只处理一次，不由 touch 与 click 双重计分；外接键盘可用。 |
| 首次进入与静音 | 首次未交互不播放；Mute 停止三个通道；Listen 不绕过静音。 |
| 四季切换 | 颜色、装饰、当前 BGM 和主题提示变化，已匹配卡与计数不变。 |
| 四种宝箱 | 各有独立入场 / 开箱音效、动画、粒子与英文语音；BGM 音量不会盖住语音。 |
| 开箱中重开、切后台再返回 | 旧声音与回调不干扰新局；返回时不强行自动播放，Listen 可以恢复。 |
| 失败界面 | 原创小熊、失败音效和英文鼓励语音都出现；没有奖励或重新加分。 |
| 减少动态效果 | 不抖动、不漂浮、不运动粒子；仍能完成开箱并看到奖品。 |

可用调试命令依次试听固定主题，不向生产页面加入作弊参数：

```powershell
npm run test:browser -- --project=desktop-chromium --headed --debug -g "random .* theme opens"
```

在 Playwright Inspector 中于开箱步骤前暂停，通过页面实际按钮试听。系统语音的听感、媒体音量、循环接缝和真实 Safari 策略均需要人工听看。

- [ ] **Step 5: 写英文运行与维护说明。**

`README.md` 完整内容：

```markdown
# Word Buddies

An English picture-and-word matching game for early learners. The game uses one HTML page, a separate JSON vocabulary, and local artwork and audio.

## Run

Use Node.js 24. Run `npm ci`, then `npm start`, and open `http://127.0.0.1:4173`.

Serve the folder over HTTP; do not open the HTML directly through a file URL. No backend API, cloud speech service, or external image service is needed.

## Play

Match three words to their pictures. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty.

Each round starts with a random Spring, Summer, Autumn, or Winter theme. The theme selector changes the look and music without resetting progress. The winning chest follows the selected theme. Opening locks that reward's theme; later theme changes do not create additional rewards.

Use Mute and Listen to control sound. Audio starts only after interaction. If playback is blocked, tap Listen to retry. Play again starts a fresh round.

## Assets

Edit `words.json` to maintain the vocabulary. Initial entries use 2–6 lowercase English letters for large, readable cards. Keep word images in `assets\images\words`; each entry names its image and prerecorded pronunciation.

Artwork, reward effects, sound effects and English scripts are original generated assets. Regenerate them with:

- `node tools\generate-images.cjs`
- `node tools\generate-sfx.cjs`
- `powershell.exe -NoProfile -File .\tools\generate-voices.ps1`

Voice generation uses Microsoft Zira Desktop (en-US) on Windows. Players only need the generated WAV files, not that voice installed on their device.

The four BGM tracks were copied from the user-provided Casual Game Music Pack 1.4: Flower-Menu-Loop, Ukulele-Menu-v1-Loop, Banjo-Menu-Loop, and Space-Menu-Loop. Confirm the music pack's distribution permissions before publishing its tracks.

Adding a word requires its JSON entry, an original image, and regenerated pronunciation audio. Reload after changing the vocabulary. Do not add a second vocabulary list to the HTML.

## Development

- Install browsers: `npx playwright install chromium webkit`
- Unit and asset tests: `npm test`
- Browser tests: `npm run test:browser`
- All tests: `npm run test:all`

Browser coverage includes desktop Chromium and iPhone/iPad WebKit profiles, responsive viewport sizes, touch, theme changes, and media failure handling. Emulation does not replace real iPhone/iPad Safari testing.

The layout respects safe areas and reduced motion. Real-device checks should include portrait, landscape, browser chrome changes, iPad split view, and actual audio playback.
```

- [ ] **Step 6: 检查目标文件范围并提交。**

```powershell
git --no-pager diff --check
git --no-pager status --short
git add -- index.html README.md tests\assets.test.cjs tests\browser\game.spec.cjs
git commit -m "test: cover Apple device layouts and complete game lifecycle" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

只提交目标文件，不使用 `git add .`，不覆盖用户在执行期间产生的改动，不自动推送。

## 规格覆盖与执行交接

| 规格 | 实现与验证位置 |
|---|---|
| 单 HTML 入口、外部 JSON、图片统一目录 | Task 1–2、Task 4 HTTP 加载、Task 6 缺失资源与同源检查。 |
| 全英文界面及实际生成的英文语音 | Task 3 台词 / WAV、Task 4 界面、Task 5 播放连接、Task 6 英文约束。 |
| 等待 / 匹配 / 正误计数 / 三次终局 | Task 1 纯逻辑、Task 4 触控流程、Task 6 混合计数。 |
| 开局随机主题、可切换、不重置进度 | Task 1 `setTheme`、Task 4 选择器和固定随机源测试。 |
| 四季宝箱、原创音效与特效 | Task 2–5，四个主题独立验收；开箱锁定奖励且不重复触发。 |
| 指定素材包的 BGM | Task 3 明确复制源 / 目标与哈希核对，Task 5 音乐生命周期。 |
| iPhone / iPad 响应式 | Task 4 安全区与布局，Task 6 WebKit 设备、视口、旋转、分屏与真机清单。 |
| 失败提示、重开、静音和错误恢复 | Task 3 失败素材、Task 4–6 生命周期与降级测试。 |

用户已经要求“设计完成后将其实现出来”，因此计划自审完成后直接进入实现，不再询问是否执行。采用 `executing-plans` 在当前执行会话推进检查点，保持当前模型与 reasoning effort；若后续需要独立审阅，遵守同样的模型偏好。完成时说明真实交付与尚不能验证的真机限制，不把计划、模拟测试或仅存在的音频文件当作实际体验完成。
