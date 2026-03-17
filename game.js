const operations = [
  { exp: "5x1", ans: 5, family: "multiplicaciones", tier: 1 },
  { exp: "5x2", ans: 10, family: "multiplicaciones", tier: 1 },
  { exp: "5x3", ans: 15, family: "multiplicaciones", tier: 1 },
  { exp: "4x1", ans: 4, family: "multiplicaciones", tier: 1 },
  { exp: "4x2", ans: 8, family: "multiplicaciones", tier: 1 },
  { exp: "4x3", ans: 12, family: "multiplicaciones", tier: 1 },
  { exp: "3x1", ans: 3, family: "multiplicaciones", tier: 1 },
  { exp: "3x2", ans: 6, family: "multiplicaciones", tier: 1 },
  { exp: "3x3", ans: 9, family: "multiplicaciones", tier: 1 },
  { exp: "2x3", ans: 6, family: "multiplicaciones", tier: 1 },
  { exp: "2x4", ans: 8, family: "multiplicaciones", tier: 1 },
  { exp: "2x5", ans: 10, family: "multiplicaciones", tier: 1 },
  { exp: "12+12", ans: 24, family: "sumas", tier: 1 },
  { exp: "14+14", ans: 28, family: "sumas", tier: 1 },
  { exp: "13+13", ans: 26, family: "sumas", tier: 1 },
  { exp: "15+15", ans: 30, family: "sumas", tier: 1 },
  { exp: "11+11", ans: 22, family: "sumas", tier: 1 },
  { exp: "16+16", ans: 32, family: "sumas", tier: 1 },
  { exp: "25+25", ans: 50, family: "sumas", tier: 1 },
  { exp: "25+15", ans: 40, family: "sumas", tier: 1 },
  { exp: "58-3", ans: 55, family: "restas", tier: 1 },
  { exp: "69-4", ans: 65, family: "restas", tier: 1 },
  { exp: "77-2", ans: 75, family: "restas", tier: 1 },
  { exp: "86-1", ans: 85, family: "restas", tier: 1 },
  { exp: "90-5", ans: 85, family: "restas", tier: 1 },
  { exp: "18+3", ans: 21, family: "sumas", tier: 1 },
  { exp: "27+4", ans: 31, family: "sumas", tier: 1 },
  { exp: "36+5", ans: 41, family: "sumas", tier: 1 },
  { exp: "24+7", ans: 31, family: "sumas", tier: 1 },
  { exp: "32+9", ans: 41, family: "sumas", tier: 1 },
  { exp: "43+8", ans: 51, family: "sumas", tier: 1 },

  { exp: "4x4", ans: 16, family: "multiplicaciones", tier: 2 },
  { exp: "4x5", ans: 20, family: "multiplicaciones", tier: 2 },
  { exp: "4x6", ans: 24, family: "multiplicaciones", tier: 2 },
  { exp: "3x4", ans: 12, family: "multiplicaciones", tier: 2 },
  { exp: "3x5", ans: 15, family: "multiplicaciones", tier: 2 },
  { exp: "3x6", ans: 18, family: "multiplicaciones", tier: 2 },
  { exp: "3x7", ans: 21, family: "multiplicaciones", tier: 2 },
  { exp: "3x8", ans: 24, family: "multiplicaciones", tier: 2 },
  { exp: "2x6", ans: 12, family: "multiplicaciones", tier: 2 },
  { exp: "2x7", ans: 14, family: "multiplicaciones", tier: 2 },
  { exp: "2x8", ans: 16, family: "multiplicaciones", tier: 2 },
  { exp: "2x9", ans: 18, family: "multiplicaciones", tier: 2 },
  { exp: "2x10", ans: 20, family: "multiplicaciones", tier: 2 },
  { exp: "120-10", ans: 110, family: "restas", tier: 2 },
  { exp: "240-20", ans: 220, family: "restas", tier: 2 },
  { exp: "380-10", ans: 370, family: "restas", tier: 2 },
  { exp: "450-30", ans: 420, family: "restas", tier: 2 },
  { exp: "670-20", ans: 650, family: "restas", tier: 2 },
  { exp: "530-15", ans: 515, family: "restas", tier: 2 },
  { exp: "118+2", ans: 120, family: "sumas", tier: 2 },
  { exp: "127+3", ans: 130, family: "sumas", tier: 2 },
  { exp: "145+5", ans: 150, family: "sumas", tier: 2 },
  { exp: "173+7", ans: 180, family: "sumas", tier: 2 },
  { exp: "126+4", ans: 130, family: "sumas", tier: 2 },
  { exp: "159+1", ans: 160, family: "sumas", tier: 2 },
  { exp: "100+100", ans: 200, family: "sumas", tier: 2 },
  { exp: "120+120", ans: 240, family: "sumas", tier: 2 },
  { exp: "140+140", ans: 280, family: "sumas", tier: 2 },
  { exp: "150+150", ans: 300, family: "sumas", tier: 2 },
  { exp: "130+130", ans: 260, family: "sumas", tier: 2 },
  { exp: "110+110", ans: 220, family: "sumas", tier: 2 },

  { exp: "150+25", ans: 175, family: "sumas", tier: 3 },
  { exp: "125+25", ans: 150, family: "sumas", tier: 3 },
  { exp: "175+25", ans: 200, family: "sumas", tier: 3 },
  { exp: "250+50", ans: 300, family: "sumas", tier: 3 },
  { exp: "225+25", ans: 250, family: "sumas", tier: 3 },
  { exp: "275+25", ans: 300, family: "sumas", tier: 3 },
  { exp: "30+30", ans: 60, family: "sumas", tier: 3 },
  { exp: "35+35", ans: 70, family: "sumas", tier: 3 },
  { exp: "45+45", ans: 90, family: "sumas", tier: 3 },
  { exp: "42+42", ans: 84, family: "sumas", tier: 3 },
  { exp: "23+23", ans: 46, family: "sumas", tier: 3 },
  { exp: "54+54", ans: 108, family: "sumas", tier: 3 },
  { exp: "127-7", ans: 120, family: "restas", tier: 3 },
  { exp: "234-30", ans: 204, family: "restas", tier: 3 },
  { exp: "330-15", ans: 315, family: "restas", tier: 3 },
  { exp: "425-10", ans: 415, family: "restas", tier: 3 },
  { exp: "812-12", ans: 800, family: "restas", tier: 3 },
  { exp: "745-5", ans: 740, family: "restas", tier: 3 },
  { exp: "228-18", ans: 210, family: "restas", tier: 3 },
  { exp: "345-15", ans: 330, family: "restas", tier: 3 },
  { exp: "439-19", ans: 420, family: "restas", tier: 3 },
  { exp: "667-17", ans: 650, family: "restas", tier: 3 },
  { exp: "524-14", ans: 510, family: "restas", tier: 3 },
  { exp: "156-16", ans: 140, family: "restas", tier: 3 },

  { exp: "105+105", ans: 210, family: "sumas", tier: 4 },
  { exp: "106+104", ans: 210, family: "sumas", tier: 4 },
  { exp: "108+102", ans: 210, family: "sumas", tier: 4 },
  { exp: "103+107", ans: 210, family: "sumas", tier: 4 },
  { exp: "104+106", ans: 210, family: "sumas", tier: 4 },
  { exp: "109+101", ans: 210, family: "sumas", tier: 4 },
  { exp: "400+30+20", ans: 450, family: "mixtas", tier: 4 },
  { exp: "200+100+40", ans: 340, family: "mixtas", tier: 4 },
  { exp: "100+100+40", ans: 240, family: "mixtas", tier: 4 },
  { exp: "400+200+10", ans: 610, family: "mixtas", tier: 4 },
  { exp: "500+50+20", ans: 570, family: "mixtas", tier: 4 },
  { exp: "300+30+20", ans: 350, family: "mixtas", tier: 4 }
];

const $ = id => document.getElementById(id);
const gameArea = $("gameArea");
const answerInput = $("answerInput");
const sendBtn = $("sendBtn");
const startBtn = $("startBtn");
const pauseBtn = $("pauseBtn");
const resetBtn = $("resetBtn");
const installBtn = $("installBtn");
const scoreEl = $("score");
const livesEl = $("lives");
const streakEl = $("streak");
const levelEl = $("level");
const bestScoreEl = $("bestScore");
const messageEl = $("message");
const modeSelect = $("modeSelect");
const familySelect = $("familySelect");
const playerModal = $("playerModal");
const playerNameInput = $("playerNameInput");
const savePlayerBtn = $("savePlayerBtn");
const playerNameView = $("playerNameView");
const playerHistory = $("playerHistory");
const keypad = $("keypad");

let activeDrops = [];
let animationId = null;
let spawnTimer = null;
let running = false;
let paused = false;
let score = 0;
let lives = 5;
let streak = 0;
let level = 1;
let bestScore = 0;
let currentPlayer = null;
let profile = null;
let deferredPrompt = null;

let audioCtx = null;
function ensureAudio(){
  if (!audioCtx){
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (Ctx) audioCtx = new Ctx();
  }
  if (audioCtx && audioCtx.state === "suspended"){
    audioCtx.resume();
  }
}
function playTone(kind){
  ensureAudio();
  if (!audioCtx) return;
  const now = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.connect(gain);
  gain.connect(audioCtx.destination);

  if (kind === "hit"){
    osc.type = "sine";
    osc.frequency.setValueAtTime(740, now);
    osc.frequency.exponentialRampToValueAtTime(980, now + 0.12);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.08, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.18);
    osc.start(now);
    osc.stop(now + 0.18);
  } else {
    osc.type = "triangle";
    osc.frequency.setValueAtTime(240, now);
    osc.frequency.exponentialRampToValueAtTime(170, now + 0.18);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.07, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.22);
    osc.start(now);
    osc.stop(now + 0.22);
  }
}


function loadProfiles(){ return JSON.parse(localStorage.getItem("mathRainProfiles") || "{}"); }
function saveProfiles(data){ localStorage.setItem("mathRainProfiles", JSON.stringify(data)); }
function getOrCreateProfile(name){
  const profiles = loadProfiles();
  if (!profiles[name]){
    profiles[name] = { bestScore:0, sessions:0, totalCorrect:0, totalMisses:0, unlockedTier:1, lastMode:"facil" };
    saveProfiles(profiles);
  }
  return profiles[name];
}
function updateProfileField(updater){
  const profiles = loadProfiles();
  const current = profiles[currentPlayer] || getOrCreateProfile(currentPlayer);
  updater(current);
  profiles[currentPlayer] = current;
  saveProfiles(profiles);
  profile = current;
  bestScore = profile.bestScore || 0;
  bestScoreEl.textContent = bestScore;
  renderHistory();
}
function renderHistory(){
  if (!currentPlayer) return;
  const p = getOrCreateProfile(currentPlayer);
  playerNameView.textContent = currentPlayer;
  bestScoreEl.textContent = p.bestScore || 0;
  playerHistory.innerHTML = `
    <strong>Datos guardados</strong><br>
    Récord: ${p.bestScore || 0} puntos<br>
    Sesiones: ${p.sessions || 0}<br>
    Aciertos: ${p.totalCorrect || 0}<br>
    Fallos: ${p.totalMisses || 0}<br>
    Nivel máximo desbloqueado: ${p.unlockedTier || 1}
  `;
}
function setMessage(text){ messageEl.textContent = text; }
function currentMode(){ return modeSelect.value; }
function getCurrentTierLimit(){ return currentMode() !== "niveles" ? 4 : Math.max(1, Math.min(profile?.unlockedTier || 1, 4)); }

function getPool(){
  const family = familySelect.value;
  let pool = operations;
  if (family !== "todas") pool = pool.filter(op => op.family === family);
  if (currentMode() === "facil") pool = pool.filter(op => op.tier <= 1);
  else if (currentMode() === "entrenamiento") pool = pool.filter(op => op.tier <= 2);
  else if (currentMode() === "niveles") pool = pool.filter(op => op.tier <= getCurrentTierLimit());
  return pool;
}
function randomItem(arr){ return arr[Math.floor(Math.random() * arr.length)]; }
function getModeConfig(){
  const mode = currentMode();
  if (mode === "facil") return { speedBase:0.28, lives:7, interval:3300, bonusBurst:false };
  if (mode === "entrenamiento") return { speedBase:0.50, lives:5, interval:2300, bonusBurst:false };
  if (mode === "niveles") return { speedBase:0.46, lives:6, interval:2500, bonusBurst:false };
  return { speedBase:0.82, lives:5, interval:1800, bonusBurst:true };
}

function spawnDrop(){
  if (!running || paused) return;
  const pool = getPool();
  if (!pool.length) return;
  const op = randomItem(pool);
  const el = document.createElement("div");
  el.className = "drop";
  el.textContent = op.exp;
  const areaWidth = gameArea.clientWidth;
  const x = 12 + Math.random() * Math.max(40, areaWidth - 120);
  const y = -40;
  const cfg = getModeConfig();
  const speed = cfg.speedBase + (level - 1) * 0.05 + Math.random() * 0.10;
  el.style.left = `${x}px`;
  el.style.top = `${y}px`;
  gameArea.appendChild(el);
  activeDrops.push({ el, exp: op.exp, ans: op.ans, tier: op.tier, x, y, speed, bornAt: performance.now() });
}

function updateDifficulty(){
  const mode = currentMode();
  if (mode === "facil") level = 1 + Math.floor(score / 180);
  else if (mode === "niveles") level = Math.max(1, Math.min(4, 1 + Math.floor(score / 120)));
  else level = 1 + Math.floor(score / 120);
  levelEl.textContent = level;
  clearInterval(spawnTimer);
  const cfg = getModeConfig();
  let interval = cfg.interval;
  interval -= Math.min(mode === "facil" ? 700 : 1300, (level - 1) * 120);
  interval -= Math.min(350, streak * 8);
  interval = Math.max(mode === "facil" ? 1200 : 500, interval);
  spawnTimer = setInterval(() => {
    spawnDrop();
    if (cfg.bonusBurst && level > 3 && Math.random() < 0.18) setTimeout(spawnDrop, 250);
    if (cfg.bonusBurst && level > 5 && Math.random() < 0.15) setTimeout(spawnDrop, 500);
  }, interval);
}
function resetState(){
  activeDrops.forEach(d => d.el.remove());
  activeDrops = [];
  score = 0; streak = 0; level = 1;
  lives = getModeConfig().lives;
  scoreEl.textContent = score; livesEl.textContent = lives; streakEl.textContent = streak; levelEl.textContent = level;
  answerInput.value = "";
  setMessage("Pulsa Iniciar para comenzar.");
}
function endGame(){
  running = false; paused = false;
  cancelAnimationFrame(animationId); clearInterval(spawnTimer);
  updateProfileField(p => {
    p.sessions = (p.sessions || 0) + 1;
    p.bestScore = Math.max(p.bestScore || 0, score);
    if (currentMode() === "niveles") p.unlockedTier = Math.max(p.unlockedTier || 1, level);
    p.lastMode = currentMode();
  });
  setMessage(`Fin de la partida. Puntuación: ${score}.`);
}
function animate(){
  if (!running) return;
  const groundY = gameArea.clientHeight - 80;
  activeDrops.forEach(drop => { if (!paused){ drop.y += drop.speed; drop.el.style.top = `${drop.y}px`; } });
  const survivors = [];
  for (const drop of activeDrops){
    if (drop.y >= groundY){
      drop.el.classList.add("miss");
      setTimeout(() => drop.el.remove(), 150);
      lives -= 1; streak = 0;
      livesEl.textContent = lives; streakEl.textContent = streak;
      setMessage(`Se escapó ${drop.exp}. Resultado: ${drop.ans}`);
      playTone("miss");
      updateProfileField(p => { p.totalMisses = (p.totalMisses || 0) + 1; });
    } else survivors.push(drop);
  }
  activeDrops = survivors;
  if (lives <= 0){ endGame(); return; }
  animationId = requestAnimationFrame(animate);
}
function startGame(){
  if (!currentPlayer){ playerModal.classList.add("visible"); playerNameInput.focus(); return; }
  resetState(); running = true; paused = false; pauseBtn.textContent = "Pausa";
  setMessage("¡Empieza la lluvia!");
  updateDifficulty(); spawnDrop(); animationId = requestAnimationFrame(animate); answerInput.focus();
}
function maybeUnlockLevel(){
  if (currentMode() !== "niveles") return;
  const targetTier = Math.max(1, Math.min(4, 1 + Math.floor(score / 120)));
  if (targetTier > (profile?.unlockedTier || 1)){
    updateProfileField(p => { p.unlockedTier = targetTier; });
    setMessage(`🎉 Has desbloqueado el nivel ${targetTier}.`);
  }
}
function checkAnswer(){
  if (!running || paused) return;
  const rawValue = String(answerInput.value || "").trim();
  if (!rawValue) return;
  const value = Number(rawValue.replace(/[^0-9]/g, ""));
  if (!Number.isFinite(value)) return;
  const candidates = activeDrops.filter(d => d.ans === value);
  if (!candidates.length){
    streak = 0; streakEl.textContent = streak;
    setMessage(`No hay ninguna gota con resultado ${value}.`);
    answerInput.value = "";
    playTone("miss");
    updateProfileField(p => { p.totalMisses = (p.totalMisses || 0) + 1; });
    return;
  }
  candidates.sort((a,b) => b.y - a.y);
  const hit = candidates[0];
  hit.el.classList.add("hit");
  setTimeout(() => hit.el.remove(), 130);
  activeDrops = activeDrops.filter(d => d !== hit);
  const responseTimeMs = performance.now() - hit.bornAt;
  let gained = currentMode() === "facil" ? 8 : 10;
  if (responseTimeMs < 2500) gained += 4;
  if (responseTimeMs < 1500) gained += 4;
  streak += 1; gained += Math.min(20, streak);
  score += gained;
  scoreEl.textContent = score; streakEl.textContent = streak;
  setMessage(`✔ ${hit.exp} = ${hit.ans} | +${gained} puntos`);
  answerInput.value = "";
  playTone("hit");
  updateProfileField(p => { p.totalCorrect = (p.totalCorrect || 0) + 1; p.bestScore = Math.max(p.bestScore || 0, score); });
  maybeUnlockLevel(); updateDifficulty();
}
function savePlayer(){
  const name = playerNameInput.value.trim();
  if (!name) return;
  currentPlayer = name;
  profile = getOrCreateProfile(name);
  renderHistory();
  modeSelect.value = profile.lastMode || "facil";
  playerModal.classList.remove("visible");
  setMessage(`Jugador cargado: ${currentPlayer}. Pulsa Iniciar.`);
  answerInput.focus();
}

savePlayerBtn.addEventListener("click", savePlayer);
playerNameInput.addEventListener("keydown", e => { if (e.key === "Enter") savePlayer(); });
sendBtn.addEventListener("click", checkAnswer);
answerInput.addEventListener("keydown", e => { if (e.key === "Enter") checkAnswer(); });
startBtn.addEventListener("click", startGame);
pauseBtn.addEventListener("click", () => {
  if (!running) return;
  paused = !paused;
  pauseBtn.textContent = paused ? "Continuar" : "Pausa";
  setMessage(paused ? "Juego en pausa." : "Juego reanudado.");
  if (!paused) answerInput.focus();
});
resetBtn.addEventListener("click", () => {
  running = false; paused = false;
  cancelAnimationFrame(animationId); clearInterval(spawnTimer);
  pauseBtn.textContent = "Pausa";
  resetState();
});
installBtn.addEventListener("click", async () => {
  if (!deferredPrompt){
    setMessage("En iPhone usa Compartir > Añadir a pantalla de inicio.");
    return;
  }
  deferredPrompt.prompt();
  deferredPrompt = null;
});
window.addEventListener("beforeinstallprompt", e => {
  e.preventDefault();
  deferredPrompt = e;
  installBtn.style.display = "inline-block";
});
if ("serviceWorker" in navigator){
  window.addEventListener("load", () => navigator.serviceWorker.register("./sw.js"));
}

answerInput.addEventListener("input", () => {
  answerInput.value = answerInput.value.replace(/[^0-9]/g, "");
});
["click","touchstart","keydown"].forEach(evt => {
  window.addEventListener(evt, () => ensureAudio(), { once: true });
});


if (keypad){
  keypad.addEventListener("click", (e) => {
    const btn = e.target.closest(".key");
    if (!btn) return;
    e.preventDefault();
    ensureAudio();
    playTap();

    const key = btn.dataset.key;
    const action = btn.dataset.action;

    if (typeof key !== "undefined"){
      answerInput.value = String(answerInput.value || "") + key;
      answerInput.focus();
      return;
    }

    if (action === "clear"){
      answerInput.value = "";
      answerInput.focus();
      return;
    }

    if (action === "backspace"){
      answerInput.value = String(answerInput.value || "").slice(0, -1);
      answerInput.focus();
      return;
    }

    if (action === "submit"){
      checkAnswer();
      answerInput.focus();
    }
  });
}

setMessage("Escribe el nombre del jugador para empezar.");
playerModal.classList.add("visible");
playerNameInput.focus();


if (keypad){
  keypad.addEventListener("click", (e) => {
    const btn = e.target.closest(".key");
    if (!btn) return;
    ensureAudio();
    playTap();
    const key = btn.dataset.key;
    const action = btn.dataset.action;

    if (key !== undefined){
      answerInput.value = String(answerInput.value || "") + key;
      answerInput.focus();
      return;
    }
    if (action === "clear"){
      answerInput.value = "";
      answerInput.focus();
      return;
    }
    if (action === "backspace"){
      answerInput.value = String(answerInput.value || "").slice(0, -1);
      answerInput.focus();
      return;
    }
    if (action === "submit"){
      checkAnswer();
      answerInput.focus();
    }
  });
}
