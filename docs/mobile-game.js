(function () {
	'use strict';

	const canvas = document.getElementById('game');
	const fallback = document.getElementById('fallback');
	const ctx = canvas && canvas.getContext ? canvas.getContext('2d', { alpha: false }) : null;

	if (!ctx) {
		if (fallback) {
			fallback.style.display = 'flex';
		}
		return;
	}

	const LANES = [-2, -1, 0, 1, 2];
	const FAR = 72;
	const TILE = 4.8;
	const PLAYER_LANE_Y = 0.84;
	const BEST_KEY = 'go-home-mobile-best';

	function readBest() {
		try {
			return Number(localStorage.getItem(BEST_KEY) || 0);
		} catch (error) {
			return 0;
		}
	}

	function writeBest(value) {
		try {
			localStorage.setItem(BEST_KEY, String(value));
		} catch (error) {
			// Some mobile privacy modes block storage. The run should keep playing.
		}
	}

	const state = {
		distance: 0,
		time: 0,
		best: readBest(),
		speed: 14,
		lane: 0,
		visualLane: 0,
		jumpClock: 999,
		gameOver: false,
		deathFade: 0,
		shake: 0,
		nextHazard: 28,
		hazards: [],
		stars: [],
		lastFrame: 0,
	};

	let width = 1;
	let height = 1;
	let dpr = 1;
	let pointerStart = null;

	function clamp(value, min, max) {
		return Math.max(min, Math.min(max, value));
	}

	function lerp(a, b, t) {
		return a + (b - a) * t;
	}

	function rand(seed) {
		const x = Math.sin(seed * 999.17) * 43758.5453;
		return x - Math.floor(x);
	}

	function resize() {
		const viewport = window.visualViewport;
		width = Math.max(1, Math.round(viewport ? viewport.width : window.innerWidth));
		height = Math.max(1, Math.round(viewport ? viewport.height : window.innerHeight));
		dpr = Math.min(2, window.devicePixelRatio || 1);
		canvas.style.width = `${width}px`;
		canvas.style.height = `${height}px`;
		canvas.width = Math.round(width * dpr);
		canvas.height = Math.round(height * dpr);
		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
	}

	function reset() {
		state.distance = 0;
		state.time = 0;
		state.speed = 14;
		state.lane = 0;
		state.visualLane = 0;
		state.jumpClock = 999;
		state.gameOver = false;
		state.deathFade = 0;
		state.shake = 0;
		state.nextHazard = 28;
		state.hazards = [];
		state.stars = Array.from({ length: 96 }, (_, i) => ({
			x: rand(i + 12) * 2 - 1,
			y: rand(i + 39),
			s: 0.45 + rand(i + 71) * 1.7,
			p: rand(i + 101) * 100,
		}));
		spawnAhead();
	}

	function isJumping() {
		return state.jumpClock < 0.78;
	}

	function jumpHeight() {
		if (!isJumping()) {
			return 0;
		}
		return Math.sin((state.jumpClock / 0.78) * Math.PI);
	}

	function jump() {
		if (!state.gameOver && !isJumping()) {
			state.jumpClock = 0;
		}
	}

	function move(delta) {
		if (!state.gameOver) {
			state.lane = clamp(state.lane + delta, -2, 2);
		}
	}

	function makeHazard(at, seed) {
		const roll = rand(seed);
		const lane = LANES[Math.floor(rand(seed + 4.3) * LANES.length)];
		const secondLane = clamp(lane + (rand(seed + 9.1) > 0.5 ? 1 : -1), -2, 2);
		if (roll < 0.34) {
			return [{ type: 'gap', at, lane, length: 4.6 }];
		}
		if (roll < 0.72) {
			return [{ type: 'spike', at, lane, phase: rand(seed + 13) * 10 }];
		}
		return [
			{ type: 'movingSpike', at, lane, phase: rand(seed + 17) * 10 },
			{ type: 'spike', at: at + 2.8, lane: secondLane, phase: rand(seed + 23) * 10 },
		];
	}

	function spawnAhead() {
		while (state.nextHazard < state.distance + FAR + 18) {
			const seed = state.nextHazard * 0.73 + state.time * 3.1 + state.best;
			const spacing = lerp(7.6, 4.6, clamp(state.time / 55, 0, 1)) + rand(seed + 31) * 1.4;
			state.nextHazard += spacing;
			state.hazards.push(...makeHazard(state.nextHazard, seed));
		}
		state.hazards = state.hazards.filter((hazard) => hazard.at > state.distance - 7);
	}

	function project(lane, z, edge) {
		const t = clamp(1 - z / FAR, 0, 1);
		const curve = t * t * (3 - 2 * t);
		const horizon = height * 0.52;
		const y = horizon + curve * (height * 0.58);
		const spacing = lerp(width * 0.018, width * 0.155, curve);
		const tileHalf = lerp(width * 0.013, width * 0.07, curve);
		const x = width * 0.5 + (lane + edge) * spacing;
		return { x: x + edge * tileHalf, y, scale: curve };
	}

	function pathX(lane, scale) {
		const spacing = lerp(width * 0.018, width * 0.155, scale);
		return width * 0.5 + lane * spacing;
	}

	function rowHasGap(lane, rowAt) {
		return state.hazards.some((hazard) => (
			hazard.type === 'gap'
			&& hazard.lane === lane
			&& Math.abs(hazard.at - rowAt) < hazard.length * 0.56
		));
	}

	function nearGap(lane, rowAt) {
		return state.hazards.some((hazard) => (
			hazard.type === 'gap'
			&& hazard.lane === lane
			&& hazard.at - rowAt > 0
			&& hazard.at - rowAt < 9.2
		));
	}

	function drawPoly(points, fill, stroke, lineWidth) {
		ctx.beginPath();
		ctx.moveTo(points[0].x, points[0].y);
		for (let i = 1; i < points.length; i += 1) {
			ctx.lineTo(points[i].x, points[i].y);
		}
		ctx.closePath();
		ctx.fillStyle = fill;
		ctx.fill();
		if (stroke) {
			ctx.strokeStyle = stroke;
			ctx.lineWidth = lineWidth;
			ctx.stroke();
		}
	}

	function drawBackground() {
		const gradient = ctx.createLinearGradient(0, 0, 0, height);
		gradient.addColorStop(0, '#001236');
		gradient.addColorStop(0.58, '#042f8f');
		gradient.addColorStop(1, '#000916');
		ctx.fillStyle = gradient;
		ctx.fillRect(0, 0, width, height);

		ctx.save();
		ctx.globalAlpha = 0.65;
		ctx.strokeStyle = '#00d7ff';
		ctx.lineWidth = 1;
		for (let i = 0; i < 24; i += 1) {
			const side = i % 2 === 0 ? -1 : 1;
			const x0 = width * 0.5 + side * width * (0.04 + i * 0.018);
			const y0 = height * (0.51 + (i % 5) * 0.015);
			const x1 = width * 0.5 + side * width * (0.54 + (i % 4) * 0.08);
			const y1 = height * (0.78 + (i % 3) * 0.12);
			ctx.globalAlpha = 0.22 + (i % 4) * 0.06;
			ctx.beginPath();
			ctx.moveTo(x0, y0);
			ctx.lineTo(x1, y1);
			ctx.stroke();
		}
		ctx.restore();

		ctx.save();
		for (const star of state.stars) {
			const sy = ((star.y * height + state.distance * (8 + star.s * 6)) % height);
			const sx = width * (0.5 + star.x * 0.48);
			ctx.globalAlpha = 0.35 + 0.45 * rand(star.p + Math.floor(state.time * 8));
			ctx.fillStyle = star.s > 1.5 ? '#e9ffff' : '#59f2ff';
			ctx.fillRect(sx, sy, star.s, star.s);
		}
		ctx.restore();
	}

	function drawRoad() {
		const start = Math.floor(state.distance / TILE) * TILE;
		for (let i = 18; i >= 0; i -= 1) {
			const rowAt = start + i * TILE;
			const z0 = rowAt - state.distance;
			const z1 = z0 + TILE * 0.88;
			if (z0 < -1 || z0 > FAR) {
				continue;
			}
			for (const lane of LANES) {
				if (rowHasGap(lane, rowAt)) {
					continue;
				}
				const p1 = project(lane, z0, -0.48);
				const p2 = project(lane, z0, 0.48);
				const p3 = project(lane, z1, 0.48);
				const p4 = project(lane, z1, -0.48);
				const warning = nearGap(lane, rowAt);
				const fill = warning ? '#20e6ff' : (i % 2 === 0 ? '#064cc3' : '#053b9d');
				const stroke = warning ? '#eaffff' : '#87efff';
				drawPoly([p1, p2, p3, p4], fill, stroke, Math.max(1, 2.1 * p1.scale));

				ctx.save();
				ctx.globalAlpha = 0.22;
				ctx.strokeStyle = '#77ffff';
				ctx.lineWidth = Math.max(0.5, 1.2 * p1.scale);
				const gx1 = lerp(p1.x, p2.x, 0.32);
				const gx2 = lerp(p1.x, p2.x, 0.72);
				ctx.strokeRect(gx1, lerp(p1.y, p4.y, 0.33), gx2 - gx1, Math.max(2, (p4.y - p1.y) * 0.18));
				ctx.restore();
			}
		}
	}

	function drawSpike(hazard) {
		const z = hazard.at - state.distance;
		if (z < -2 || z > FAR) {
			return;
		}
		const p = project(0, z, 0);
		const moving = hazard.type === 'movingSpike';
		const offset = moving ? Math.sin(state.time * 3.3 + hazard.phase) * 1.45 : 0;
		const lane = clamp(hazard.lane + offset, -2.1, 2.1);
		const x = pathX(lane, p.scale);
		const base = lerp(width * 0.03, width * 0.14, p.scale);
		const tall = base * 1.12;
		const y = p.y - tall * 0.12;
		ctx.save();
		ctx.shadowColor = '#eaffff';
		ctx.shadowBlur = 12 * p.scale;
		ctx.fillStyle = '#061125';
		ctx.strokeStyle = '#f4ffff';
		ctx.lineWidth = Math.max(1.2, 4 * p.scale);
		ctx.beginPath();
		ctx.moveTo(x, y - tall);
		ctx.lineTo(x - base * 0.55, y);
		ctx.lineTo(x + base * 0.55, y);
		ctx.closePath();
		ctx.fill();
		ctx.stroke();
		ctx.restore();
	}

	function drawPlayer() {
		const laneT = clamp((state.visualLane + 2) / 4, 0, 1);
		const x = lerp(width * 0.17, width * 0.83, laneT);
		const y = height * PLAYER_LANE_Y - jumpHeight() * height * 0.19;
		const size = Math.max(28, Math.min(width, height) * 0.115);
		const spin = state.distance * 0.12 + jumpHeight() * 1.7;

		ctx.save();
		ctx.translate(x, y);
		ctx.rotate(spin);
		ctx.shadowColor = '#4bff6d';
		ctx.shadowBlur = 18;
		ctx.fillStyle = '#0fb649';
		ctx.strokeStyle = '#8cff9d';
		ctx.lineWidth = Math.max(3, size * 0.08);
		ctx.fillRect(-size / 2, -size / 2, size, size);
		ctx.strokeRect(-size / 2, -size / 2, size, size);
		ctx.strokeStyle = '#ccffd2';
		ctx.lineWidth = Math.max(1.5, size * 0.04);
		ctx.strokeRect(-size * 0.23, -size * 0.23, size * 0.46, size * 0.46);
		ctx.beginPath();
		ctx.moveTo(-size * 0.38, size * 0.14);
		ctx.lineTo(size * 0.38, -size * 0.18);
		ctx.stroke();
		ctx.restore();
	}

	function drawHud() {
		ctx.save();
		ctx.font = `800 ${Math.max(12, width * 0.032)}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillStyle = '#f6fbff';
		ctx.shadowColor = '#00baff';
		ctx.shadowBlur = 8;
		ctx.fillText(`TIME ${String(Math.floor(state.time)).padStart(3, '0')}`, 14, 28);
		ctx.fillText(`BEST ${String(Math.floor(state.best)).padStart(3, '0')}`, 14, 52);
		ctx.font = `800 ${Math.max(10, width * 0.027)}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillText(`SPEED ${state.speed.toFixed(1)}`, 14, 78);
		ctx.restore();
	}

	function drawGameOver() {
		if (!state.gameOver && state.deathFade <= 0) {
			return;
		}
		const alpha = state.gameOver ? 0.76 : state.deathFade * 0.76;
		ctx.save();
		ctx.globalAlpha = alpha;
		ctx.fillStyle = '#00122e';
		ctx.fillRect(0, 0, width, height);
		ctx.globalAlpha = 1;
		ctx.textAlign = 'center';
		ctx.textBaseline = 'middle';
		ctx.shadowColor = '#00aaff';
		ctx.shadowBlur = 14;
		ctx.fillStyle = '#f7feff';
		ctx.font = `900 ${Math.max(28, width * 0.085)}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillText(`기록: ${Math.floor(state.time)}초 생존`, width / 2, height * 0.42);
		ctx.font = `900 ${Math.max(22, width * 0.062)}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillText('터치해서 다시 시작', width / 2, height * 0.5);
		ctx.restore();
	}

	function render() {
		ctx.save();
		const shake = state.shake * 8;
		if (shake > 0.01) {
			ctx.translate((rand(state.time * 99) - 0.5) * shake, (rand(state.time * 121) - 0.5) * shake);
		}
		drawBackground();
		drawRoad();
		for (const hazard of state.hazards) {
			if (hazard.type !== 'gap') {
				drawSpike(hazard);
			}
		}
		drawPlayer();
		ctx.restore();
		drawHud();
		drawGameOver();
	}

	function kill() {
		if (state.gameOver) {
			return;
		}
		state.gameOver = true;
		state.deathFade = 1;
		state.shake = 1;
		if (state.time > state.best) {
			state.best = state.time;
			writeBest(state.best);
		}
	}

	function checkCollision() {
		const playerLane = Math.round(state.visualLane);
		const airborne = jumpHeight() > 0.36;
		for (const hazard of state.hazards) {
			const rel = hazard.at - state.distance;
			if (Math.abs(rel) > 1.25) {
				continue;
			}
			if (hazard.type === 'gap') {
				if (hazard.lane === playerLane && !airborne) {
					kill();
					return;
				}
				continue;
			}
			const movingOffset = hazard.type === 'movingSpike' ? Math.sin(state.time * 3.3 + hazard.phase) * 1.45 : 0;
			const hazardLane = hazard.lane + movingOffset;
			if (Math.abs(hazardLane - state.visualLane) < 0.54 && !airborne) {
				kill();
				return;
			}
		}
	}

	function update(dt) {
		dt = Math.min(dt, 0.04);
		if (state.gameOver) {
			state.shake = Math.max(0, state.shake - dt * 2.7);
			render();
			return;
		}
		state.time += dt;
		state.speed = 14 + Math.min(8, state.time * 0.105);
		state.distance += state.speed * dt;
		state.jumpClock += dt;
		state.visualLane = lerp(state.visualLane, state.lane, Math.min(1, dt * 13));
		state.shake = Math.max(0, state.shake - dt * 3);
		spawnAhead();
		checkCollision();
		render();
	}

	function loop(now) {
		const time = now / 1000;
		const dt = state.lastFrame ? time - state.lastFrame : 1 / 60;
		state.lastFrame = time;
		update(dt);
		requestAnimationFrame(loop);
	}

	function pointerDown(event) {
		pointerStart = { x: event.clientX, y: event.clientY, t: performance.now() };
		event.preventDefault();
	}

	function pointerUp(event) {
		event.preventDefault();
		if (state.gameOver) {
			reset();
			return;
		}
		if (!pointerStart) {
			return;
		}
		const dx = event.clientX - pointerStart.x;
		const dy = event.clientY - pointerStart.y;
		if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 26) {
			move(dx > 0 ? 1 : -1);
		} else if (dy < -24) {
			jump();
		}
		pointerStart = null;
	}

	function keyDown(event) {
		if (event.key === 'r' || event.key === 'R') {
			reset();
		} else if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
			move(-1);
		} else if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
			move(1);
		} else if (event.key === 'ArrowUp' || event.key === 'w' || event.key === 'W' || event.key === ' ') {
			jump();
		}
	}

	window.render_game_to_text = function () {
		return JSON.stringify({
			mode: state.gameOver ? 'gameOver' : 'running',
			time: Number(state.time.toFixed(2)),
			speed: Number(state.speed.toFixed(2)),
			lane: state.lane,
			visualLane: Number(state.visualLane.toFixed(2)),
			hazards: state.hazards.slice(0, 8).map((hazard) => ({
				type: hazard.type,
				lane: hazard.lane,
				rel: Number((hazard.at - state.distance).toFixed(1)),
			})),
		});
	};

	window.advanceTime = function (ms) {
		const steps = Math.max(1, Math.round(ms / (1000 / 60)));
		for (let i = 0; i < steps; i += 1) {
			update(1 / 60);
		}
		return window.render_game_to_text();
	};

	window.addEventListener('resize', resize, { passive: true });
	window.addEventListener('orientationchange', () => setTimeout(resize, 120), { passive: true });
	if (window.visualViewport) {
		window.visualViewport.addEventListener('resize', resize, { passive: true });
		window.visualViewport.addEventListener('scroll', resize, { passive: true });
	}
	canvas.addEventListener('pointerdown', pointerDown, { passive: false });
	canvas.addEventListener('pointerup', pointerUp, { passive: false });
	canvas.addEventListener('pointercancel', () => { pointerStart = null; }, { passive: true });
	window.addEventListener('keydown', keyDown);

	resize();
	reset();
	requestAnimationFrame(loop);
}());
