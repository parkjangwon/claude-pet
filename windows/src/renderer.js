const CONFIG = {
  randomInterruptIntervalSec: 6,
  smileProbability: 0.30,
  boringProbability: 0.20,
  jumpingProbability: 0.15,
  touchWalkTimeoutSec: 2.5,
  walkSpeed: 400,
  walkTotalDistance: 100,
  mouseFollowSpeed: 60,
  mouseFollowMinDistancePx: 12,
  hungerMax: 100,
  hungerDecayIntervalSec: 300,
  hungerThreshold: 20,
  feedTypingCost: 100,
  feedHungerRestore: 10,
  dialogueDisplaySec: 3.5,
  cpuWorkingPercent: 15,
  cpuIdlePercent: 5
};

const ANIMATIONS = {
  idleDefault: { asset: 'Idle_Default', frames: [500, 100, 100, 100], next: null },
  idleSmile: { asset: 'Idle_Smile', frames: [500, 100, 100, 100], repeat: 2, next: 'idleDefault' },
  idleBoring: { asset: 'Idle_Boring', frames: [500, 100, 100, 100], repeat: 2, next: 'idleDefault' },
  idleJumping: { asset: 'Idle_Jumping', frames: [1, 80, 80, 80, 80, 80, 80], repeat: 1, next: 'idleDefault' },
  idleWalk: { asset: 'Idle_Walk', frames: [70, 70, 70, 70], next: null },
  idleTouch: { asset: 'Idle_Touch', frames: [1, 60, 60, 60, 60], repeat: 1, next: 'idleTouchWalk' },
  idleTouchWalk: { asset: 'Idle_Touch_Walk', frames: [100, 100, 100, 100], next: null },
  idleWorkingPrepare: { asset: 'Idle_Working_Prepare', frames: [1, 70, 70, 80, 80, 80, 80, 70, 70, 50, 50, 150, 300, 80, 80, 80, 500], repeat: 1, next: 'idleWorking' },
  idleWorking: { asset: 'Idle_Working', frames: [30, 30, 30, 30, 30, 30], next: null },
  idleHungry: { asset: 'Idle_Hungry', frames: [600, 100, 100, 100], next: null }
};

const LINES = {
  idle: ['저기... 안녕하세요.', '저.. 여기 있어요..!!', '뭐.. 할 말이 있는데.. 아..없어요.'],
  smile: ['아.. 헤헤..', 'ㄱ..감사합니다.. 어..', 'ㅈ..좋은 것 같아요.. 아마도요.'],
  boring: ['...지루하네요.', '음.. 심심해요.', '뭔가 해야 할 것 같은데..'],
  jumping: ['아.. ㅅ..신나요..!', '점프..? ..해볼게요..!', '야호..?'],
  touch: ['앗..!?', '저...!!', '갑자기요..!?', '으앗..'],
  workingStart: ['아, 일 시작하는군요..', '저... 준비됐어요.', 'ㅇ..열심히 하겠습니다..'],
  working: ['...', '저도 여기 있어요..', 'ㅈ..집중하시는 거죠..?'],
  workingEnd: ['ㅅ..수고하셨어요..', '고생하셨어요.. 정말로요..'],
  hungry: ['저.. 배가 고픈데요..', '밥을.. 혹시.. 주실 수 있나요..', '힘이.. 조금.. 없어요..'],
  fed: ['아.. 감사해요..', '냠.. 맛있어요. 감사합니다.', '어.. 고마워요..!']
};

const sprite = document.getElementById('sprite');
const spriteWrap = document.getElementById('spriteWrap');
const counter = document.getElementById('counter');
const heart = document.getElementById('heart');
const dialogue = document.getElementById('dialogue');
const hud = document.getElementById('hud');

let state;
let current = 'idleDefault';
let frame = 0;
let repeat = 0;
let frameTimer;
let dialogueTimer;
let walkTimer;
let walkDirection = -1;
let isInTransition = false;
let hungerTick;
let cpuAbove = 0;
let cpuBelow = 0;
let lastClick = 0;
let hasNativeKeyboardHook = true;

function imagePath(name) {
  const files = {
    Emoji_Heart: 'emoji_heart.png',
    Idle_Working: 'Idle_Working.png'
  };
  const absolutePath = `${state.assetRoot.replaceAll('\\', '/')}/${name}.imageset/${files[name] || `${name}.png`}`;
  return encodeURI(`file:///${absolutePath.replace(/^\/+/, '')}`);
}

function choose(lines) {
  return lines[Math.floor(Math.random() * lines.length)];
}

function showDialogue(trigger, duration = CONFIG.dialogueDisplaySec) {
  const lines = LINES[trigger];
  if (!lines) return;
  dialogue.textContent = choose(lines);
  dialogue.classList.remove('hidden');
  clearTimeout(dialogueTimer);
  dialogueTimer = setTimeout(() => dialogue.classList.add('hidden'), duration * 1000);
}

function setAnimation(name) {
  clearTimeout(frameTimer);
  clearInterval(walkTimer);
  current = name;
  frame = 0;
  repeat = 0;
  isInTransition = Boolean(ANIMATIONS[name].next);
  sprite.src = imagePath(ANIMATIONS[name].asset);
  renderFrame();
  scheduleFrame();
  if (name === 'idleTouchWalk') startWalk();
}

function renderFrame() {
  const info = ANIMATIONS[current];
  const size = 32 * state.spriteScale;
  const counterHeight = 32 * state.uiScale;
  const spriteBottom = counterHeight;
  const panelBottom = spriteBottom + size + 6 * state.uiScale;
  spriteWrap.style.width = `${size}px`;
  spriteWrap.style.height = `${size}px`;
  spriteWrap.style.bottom = `${spriteBottom}px`;
  sprite.style.width = `${size * info.frames.length}px`;
  sprite.style.transform = `translateX(${-size * frame}px)`;
  spriteWrap.style.transform = `translateX(-50%) scaleX(${(current === 'idleWalk' || current === 'idleTouchWalk') && walkDirection > 0 ? -1 : 1})`;
  counter.style.width = `${size}px`;
  counter.style.left = '50%';
  counter.style.transform = 'translateX(-50%)';
  heart.style.width = `${size * 0.24}px`;
  heart.style.left = '50%';
  heart.style.bottom = `${spriteBottom + size * 0.46}px`;
  heart.style.transform = 'translateX(-50%)';
  dialogue.style.bottom = `${panelBottom}px`;
  hud.style.bottom = `${panelBottom}px`;
}

function scheduleFrame() {
  const info = ANIMATIONS[current];
  frameTimer = setTimeout(() => {
    frame += 1;
    if (frame >= info.frames.length) {
      if (info.next) {
        repeat += 1;
        if (repeat >= info.repeat) {
          setAnimation(info.next);
          return;
        }
      }
      frame = 0;
    }
    renderFrame();
    scheduleFrame();
  }, info.frames[frame]);
}

function triggerHeart() {
  heart.src = imagePath('Emoji_Heart');
  heart.animate([
    { opacity: 0, transform: 'translateX(-50%) translateY(10px) scale(.8)' },
    { opacity: 1, transform: 'translateX(-50%) translateY(-6px) scale(1)', offset: 0.12 },
    { opacity: 0, transform: 'translateX(-50%) translateY(-54px) scale(1.08)' }
  ], { duration: 2900, easing: 'ease-out' });
}

function handleTap() {
  if (isInTransition || !['idleDefault', 'idleWorking'].includes(current)) return;
  triggerHeart();
  showDialogue('smile');
  setAnimation('idleSmile');
}

function handleStrongPress(clientX) {
  if (current === 'idleHungry') return;
  walkDirection = clientX < window.innerWidth / 2 ? 1 : -1;
  showDialogue('touch');
  spriteWrap.animate([
    { transform: `translateX(6px) scaleX(${walkDirection > 0 ? -1 : 1})` },
    { transform: `translateX(-6px) scaleX(${walkDirection > 0 ? -1 : 1})` },
    { transform: `translateX(0) scaleX(${walkDirection > 0 ? -1 : 1})` }
  ], { duration: 180 });
  setAnimation('idleTouch');
}

function startWalk() {
  let moved = 0;
  walkTimer = setInterval(() => {
    const dx = walkDirection * CONFIG.walkSpeed / 60;
    moved += Math.abs(dx);
    window.claudePet.moveBy(dx);
    if (moved >= CONFIG.walkTotalDistance) {
      clearInterval(walkTimer);
      setTimeout(() => {
        if (current === 'idleTouchWalk') setAnimation('idleDefault');
      }, CONFIG.touchWalkTimeoutSec * 1000);
    }
  }, 1000 / 60);
}

function randomInterrupt() {
  if (isInTransition || current !== 'idleDefault') return;
  if (state.hunger <= CONFIG.hungerThreshold) {
    showDialogue('hungry');
    setAnimation('idleHungry');
    return;
  }
  const roll = Math.random();
  if (roll < CONFIG.smileProbability) {
    showDialogue('smile');
    setAnimation('idleSmile');
  } else if (roll < CONFIG.smileProbability + CONFIG.boringProbability) {
    showDialogue('boring');
    setAnimation('idleBoring');
  } else if (roll < CONFIG.smileProbability + CONFIG.boringProbability + CONFIG.jumpingProbability) {
    showDialogue('jumping');
    setAnimation('idleJumping');
  } else if (Math.random() > 0.5) {
    showDialogue('idle');
  }
}

function updateHud() {
  counter.textContent = state.typingCount;
  document.getElementById('affinity').textContent = `Lv.${state.affinityLevel}`;
  document.getElementById('affinityBar').style.width = `${Math.min(100, state.affinityExp * 5)}%`;
  document.getElementById('hungerText').textContent = `${Math.floor(state.hunger)} / 100`;
  document.getElementById('hungerBar').style.width = `${state.hunger}%`;
  document.getElementById('feedButton').disabled = state.typingCount < 100 || state.hunger + 10 > 100;
}

function startHunger() {
  clearInterval(hungerTick);
  hungerTick = setInterval(() => {
    state.hunger = Math.max(0, state.hunger - 1 / CONFIG.hungerDecayIntervalSec);
    window.claudePet.setHunger(state.hunger);
    updateHud();
    if (state.hunger <= CONFIG.hungerThreshold && current === 'idleDefault') {
      showDialogue('hungry');
      setAnimation('idleHungry');
    }
    if (state.hunger > CONFIG.hungerThreshold && current === 'idleHungry') {
      setAnimation('idleDefault');
    }
  }, 1000);
}

window.addEventListener('click', (event) => {
  if (hud.contains(event.target)) return;
  const now = Date.now();
  const doubleClick = now - lastClick < 320;
  lastClick = now;
  if (event.shiftKey || doubleClick) handleStrongPress(event.clientX);
  else handleTap();
});

window.addEventListener('contextmenu', (event) => {
  event.preventDefault();
  hud.classList.toggle('hidden');
  dialogue.classList.add('hidden');
  updateHud();
});

window.addEventListener('keyup', () => {
  if (!hasNativeKeyboardHook) window.claudePet.incrementTyping();
});

document.getElementById('closeHud').addEventListener('click', () => hud.classList.add('hidden'));
document.getElementById('feedButton').addEventListener('click', () => {
  window.claudePet.feed();
  showDialogue('fed');
});
document.getElementById('quit').addEventListener('click', () => window.claudePet.quit());

for (const [id, index] of [['scaleSmall', 0], ['scaleNormal', 1], ['scaleLarge', 2]]) {
  document.getElementById(id).addEventListener('click', () => {
    window.claudePet.setScale(index);
  });
}

window.claudePet.onTypingCount((count) => {
  state.typingCount = count;
  updateHud();
});

window.claudePet.onSettings((next) => {
  state = next;
  updateHud();
  renderFrame();
});

window.claudePet.onClaudeCpu((cpu) => {
  if (cpu > CONFIG.cpuWorkingPercent) {
    cpuAbove += 1;
    cpuBelow = 0;
    if (cpuAbove >= 2 && current === 'idleDefault') setAnimation('idleWorkingPrepare');
  } else if (cpu < CONFIG.cpuIdlePercent) {
    cpuBelow += 1;
    cpuAbove = 0;
    if (cpuBelow >= 3 && current === 'idleWorking') {
      showDialogue('workingEnd');
      setAnimation('idleDefault');
    }
  }
});

window.claudePet.onClaudeRunning((running) => {
  if (!running && current === 'idleWorking') setAnimation('idleDefault');
});

window.claudePet.onKeyboardHookUnavailable(() => {
  hasNativeKeyboardHook = false;
});

(async function boot() {
  state = await window.claudePet.state();
  hasNativeKeyboardHook = state.keyboardHookAvailable;
  updateHud();
  setAnimation('idleDefault');
  startHunger();
  setInterval(randomInterrupt, CONFIG.randomInterruptIntervalSec * 1000);
})();
