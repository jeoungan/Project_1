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
	const FAR = 78;
	const TILE = 5.2;
	const BEST_KEY = 'go-home-mobile-best';

	let width = 1;
	let height = 1;
	let dpr = 1;
	let pointerStart = null;

	const state = {
		distance: 0,
		time: 0,
		best: readBest(),
		speed: 13.8,
		lane: 0,
		visualLane: 0,
		jumpClock: 99,
		gameOver: false,
		shake: 0,
		deathAlpha: 0,
		nextHazard: 42,
		hazards: [],
		stars: [],
		lastFrame: 0,
	};

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
			// Some mobile privacy modes block storage. Keep the game running.
		}
	}

	function clamp(value, min, max) {
		return Math.max(min, Math.min(max, value));
	}

	function lerp(a, b, t) {
		return a + (b - a) * t;
	}

	function ease(t) {
		return t * t * (3 - 2 * t);
	}

	function rand(seed) {
		const x = Math.sin(seed * 123.4567) * 43758.5453;
		return x - Math.floor(x);
	}

	function minSide() {
		return Math.min(width, height);
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
		state.speed = 13.8;
		state.lane = 0;
		state.visualLane = 0;
		state.jumpClock = 99;
		state.gameOver = false;
		state.shake = 0;
		state.deathAlpha = 0;
		state.nextHazard = 42;
		state.hazards = [];
		state.stars = Array.from({ length: 130 }, (_, i) => ({
			x: rand(i + 3) * 2 - 1,
			y: rand(i + 21),
			size: 0.45 + rand(i + 61) * 1.7,
			twinkle: rand(i + 91) * 30,
		}));
		spawnAhead();
	}

	function horizonY() {
		return height * (width > height ? 0.46 : 0.50);
	}

	function roadHalfNear() {
		return Math.min(width * 0.43, height * 0.74);
	}

	function depthScale(z) {
		const t = clamp(1 - z / FAR, 0, 1);
		return ease(t);
	}

	function edgePoint(edge, z) {
		const s = depthScale(z);
		const half = lerp(width * 0.018, roadHalfNear(), s);
		const y = horizonY() + s * height * 0.62;
		return { x: width * 0.5 + (edge / 2.5) * half, y, s };
	}

	function centerPoint(lane, z) {
		const left = edgePoint(lane - 0.5, z);
		const right = edgePoint(lane + 0.5, z);
		return {
			x: (left.x + right.x) * 0.5,
			y: (left.y + right.y) * 0.5,
			s: left.s,
			w: Math.abs(right.x - left.x),
		};
	}

	function upperWallPoint(side, z) {
		const s = depthScale(z);
		const half = lerp(width * 0.025, Math.min(width * 0.66, height * 1.05), s);
		const y = horizonY() - s * height * 0.34;
		return { x: width * 0.5 + side * half, y, s };
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

	function isJumping() {
		return state.jumpClock < 0.76;
	}

	function jumpHeight() {
		if (!isJumping()) {
			return 0;
		}
		return Math.sin((state.jumpClock / 0.76) * Math.PI);
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

	function makeHazards(at, seed) {
		const roll = rand(seed);
		const lane = LANES[Math.floor(rand(seed + 8) * LANES.length)];
		const neighbor = clamp(lane + (rand(seed + 12) > 0.5 ? 1 : -1), -2, 2);
		if (roll < 0.36) {
			return [{ type: 'gap', at, lane, length: 4.8 }];
		}
		if (roll < 0.74) {
			return [{ type: 'spike', at, lane, phase: rand(seed + 16) * 9 }];
		}
		return [
			{ type: 'movingSpike', at, lane, phase: rand(seed + 22) * 9 },
			{ type: 'spike', at: at + 3.2, lane: neighbor, phase: rand(seed + 29) * 9 },
		];
	}

	function spawnAhead() {
		while (state.nextHazard < state.distance + FAR + 24) {
			const seed = state.nextHazard * 0.81 + state.best * 0.27;
			const spacing = lerp(9.0, 5.4, clamp(state.time / 70, 0, 1)) + rand(seed + 2) * 1.6;
			state.nextHazard += spacing;
			state.hazards.push(...makeHazards(state.nextHazard, seed));
		}
		state.hazards = state.hazards.filter((hazard) => hazard.at > state.distance - 8);
	}

	function hasGap(lane, rowAt) {
		return state.hazards.some((hazard) => (
			hazard.type === 'gap'
			&& hazard.lane === lane
			&& Math.abs(hazard.at - rowAt) < hazard.length * 0.54
		));
	}

	function nearGap(lane, rowAt) {
		return state.hazards.some((hazard) => (
			hazard.type === 'gap'
			&& hazard.lane === lane
			&& hazard.at - rowAt > 0
			&& hazard.at - rowAt < 8.7
		));
	}

	function drawBackground() {
		const gradient = ctx.createLinearGradient(0, 0, 0, height);
		gradient.addColorStop(0, '#00102e');
		gradient.addColorStop(0.54, '#04328f');
		gradient.addColorStop(1, '#000612');
		ctx.fillStyle = gradient;
		ctx.fillRect(0, 0, width, height);

		ctx.save();
		for (const star of state.stars) {
			const sy = (star.y * height + state.distance * (4.8 + star.size * 4)) % height;
			const sx = width * (0.5 + star.x * 0.49);
			ctx.globalAlpha = 0.18 + 0.48 * rand(star.twinkle + Math.floor(state.time * 9));
			ctx.fillStyle = star.size > 1.4 ? '#e9ffff' : '#54dfff';
			ctx.fillRect(sx, sy, star.size, star.size);
		}
		ctx.restore();
	}

	function drawTunnel() {
		const start = Math.floor(state.distance / TILE) * TILE;
		ctx.save();
		for (let i = 20; i >= 0; i -= 1) {
			const rowAt = start + i * TILE;
			const z0 = rowAt - state.distance;
			const z1 = z0 + TILE * 0.92;
			if (z0 < -1 || z0 > FAR) {
				continue;
			}

			for (const side of [-1, 1]) {
				const floor0 = edgePoint(side * 2.64, z0);
				const floor1 = edgePoint(side * 2.64, z1);
				const upper1 = upperWallPoint(side, z1);
				const upper0 = upperWallPoint(side, z0);
				const alpha = 0.18 + floor0.s * 0.22;
				drawPoly(
					[floor0, floor1, upper1, upper0],
					`rgba(6, 58, 156, ${alpha})`,
					`rgba(126, 242, 255, ${0.30 + floor0.s * 0.42})`,
					Math.max(0.7, floor0.s * 2.3),
				);
			}

			if (i % 2 === 0) {
				const ul0 = upperWallPoint(-1, z0);
				const ur0 = upperWallPoint(1, z0);
				const ur1 = upperWallPoint(1, z1);
				const ul1 = upperWallPoint(-1, z1);
				drawPoly(
					[ul0, ul1, ur1, ur0],
					`rgba(2, 26, 74, ${0.10 + ul0.s * 0.16})`,
					`rgba(65, 208, 255, ${0.16 + ul0.s * 0.24})`,
					Math.max(0.6, ul0.s * 1.8),
				);
			}
		}

		ctx.globalAlpha = 0.65;
		ctx.strokeStyle = '#05d9ff';
		ctx.lineWidth = 1.5;
		for (const edge of [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5]) {
			const near = edgePoint(edge, 0);
			const far = edgePoint(edge, FAR);
			ctx.beginPath();
			ctx.moveTo(far.x, far.y);
			ctx.lineTo(near.x, near.y);
			ctx.stroke();
		}
		ctx.restore();
	}

	function drawRoad() {
		const start = Math.floor(state.distance / TILE) * TILE;
		for (let i = 22; i >= 0; i -= 1) {
			const rowAt = start + i * TILE;
			const z0 = rowAt - state.distance;
			const z1 = z0 + TILE * 0.92;
			if (z0 < -1 || z0 > FAR) {
				continue;
			}

			for (const lane of LANES) {
				if (hasGap(lane, rowAt)) {
					continue;
				}
				const p1 = edgePoint(lane - 0.48, z0);
				const p2 = edgePoint(lane + 0.48, z0);
				const p3 = edgePoint(lane + 0.48, z1);
				const p4 = edgePoint(lane - 0.48, z1);
				const warning = nearGap(lane, rowAt);
				const fill = warning ? '#1de5ff' : (i % 2 === 0 ? '#0758d1' : '#0648af');
				const stroke = warning ? '#f3ffff' : '#8ff4ff';
				drawPoly([p1, p2, p3, p4], fill, stroke, Math.max(0.8, p1.s * 2.4));

				ctx.save();
				ctx.globalAlpha = 0.18 + p1.s * 0.16;
				ctx.strokeStyle = '#b7ffff';
				ctx.lineWidth = Math.max(0.5, p1.s * 1.2);
				const cx = lerp(p1.x, p2.x, 0.5);
				const gy = lerp(p1.y, p4.y, 0.52);
				const gw = Math.abs(p2.x - p1.x) * 0.38;
				const gh = Math.max(2, Math.abs(p4.y - p1.y) * 0.14);
				ctx.strokeRect(cx - gw * 0.5, gy - gh * 0.5, gw, gh);
				ctx.restore();
			}
		}
	}

	function drawSpike(hazard) {
		const z = hazard.at - state.distance;
		if (z < -4 || z > FAR) {
			return;
		}
		const moving = hazard.type === 'movingSpike';
		const lane = clamp(hazard.lane + (moving ? Math.sin(state.time * 3.2 + hazard.phase) * 1.25 : 0), -2.2, 2.2);
		const p = centerPoint(lane, z);
		const base = clamp(p.w * 0.84, 10, minSide() * 0.19);
		const tall = base * 1.25;
		const y = p.y - tall * 0.05;

		ctx.save();
		ctx.shadowColor = '#eaffff';
		ctx.shadowBlur = 8 + p.s * 16;
		ctx.fillStyle = '#020717';
		ctx.strokeStyle = '#f4ffff';
		ctx.lineWidth = Math.max(1.2, p.s * 4.2);
		ctx.beginPath();
		ctx.moveTo(p.x, y - tall);
		ctx.lineTo(p.x - base * 0.56, y);
		ctx.lineTo(p.x + base * 0.56, y);
		ctx.closePath();
		ctx.fill();
		ctx.stroke();
		ctx.restore();
	}

	function drawPlayer() {
		const p = centerPoint(state.visualLane, 2.5);
		const jump = jumpHeight();
		const size = clamp(minSide() * 0.105, 34, 82);
		const x = p.x;
		const y = height * 0.84 - jump * height * 0.18;
		const spin = state.distance * 0.13 + jump * 1.7;

		ctx.save();
		ctx.translate(x, y);
		ctx.rotate(spin);
		ctx.shadowColor = '#59ff6f';
		ctx.shadowBlur = 18;
		ctx.fillStyle = '#12b84c';
		ctx.strokeStyle = '#b6ffc0';
		ctx.lineWidth = Math.max(3, size * 0.08);
		ctx.fillRect(-size / 2, -size / 2, size, size);
		ctx.strokeRect(-size / 2, -size / 2, size, size);
		ctx.strokeStyle = '#eaffee';
		ctx.lineWidth = Math.max(1.5, size * 0.04);
		ctx.strokeRect(-size * 0.24, -size * 0.24, size * 0.48, size * 0.48);
		ctx.beginPath();
		ctx.moveTo(-size * 0.34, size * 0.13);
		ctx.lineTo(size * 0.34, -size * 0.17);
		ctx.stroke();
		ctx.restore();
	}

	function drawHud() {
		const hudSize = clamp(minSide() * 0.031, 12, 20);
		ctx.save();
		ctx.font = `800 ${hudSize}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillStyle = '#f4feff';
		ctx.shadowColor = '#00bfff';
		ctx.shadowBlur = 6;
		ctx.fillText(`TIME ${String(Math.floor(state.time)).padStart(3, '0')}`, 14, 26);
		ctx.fillText(`BEST ${String(Math.floor(state.best)).padStart(3, '0')}`, 14, 26 + hudSize * 1.45);
		ctx.fillText(`SPEED ${state.speed.toFixed(1)}`, 14, 26 + hudSize * 2.9);
		ctx.restore();
	}

	function drawGameOver() {
		if (!state.gameOver && state.deathAlpha <= 0.01) {
			return;
		}
		const alpha = state.gameOver ? 0.78 : state.deathAlpha;
		const boxW = Math.min(width * 0.72, 520);
		const boxH = Math.min(height * 0.26, 190);
		const x = (width - boxW) * 0.5;
		const y = height * (width > height ? 0.24 : 0.30);
		const titleSize = clamp(minSide() * 0.055, 22, 42);
		const subSize = clamp(minSide() * 0.038, 16, 28);

		ctx.save();
		ctx.globalAlpha = alpha * 0.46;
		ctx.fillStyle = '#00112d';
		ctx.fillRect(0, 0, width, height);
		ctx.globalAlpha = alpha;
		ctx.shadowColor = '#00baff';
		ctx.shadowBlur = 18;
		ctx.fillStyle = 'rgba(0, 26, 62, 0.92)';
		ctx.strokeStyle = '#75eeff';
		ctx.lineWidth = 2;
		roundedRect(x, y, boxW, boxH, 12);
		ctx.fill();
		ctx.stroke();

		ctx.textAlign = 'center';
		ctx.textBaseline = 'middle';
		ctx.fillStyle = '#f8feff';
		ctx.font = `900 ${titleSize}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillText(`기록: ${Math.floor(state.time)}초 생존`, width / 2, y + boxH * 0.42);
		ctx.font = `800 ${subSize}px system-ui, -apple-system, "Noto Sans KR", sans-serif`;
		ctx.fillText('터치해서 다시 시작', width / 2, y + boxH * 0.68);
		ctx.restore();
	}

	function roundedRect(x, y, w, h, r) {
		ctx.beginPath();
		ctx.moveTo(x + r, y);
		ctx.lineTo(x + w - r, y);
		ctx.quadraticCurveTo(x + w, y, x + w, y + r);
		ctx.lineTo(x + w, y + h - r);
		ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
		ctx.lineTo(x + r, y + h);
		ctx.quadraticCurveTo(x, y + h, x, y + h - r);
		ctx.lineTo(x, y + r);
		ctx.quadraticCurveTo(x, y, x + r, y);
		ctx.closePath();
	}

	function render() {
		ctx.save();
		if (state.shake > 0.01) {
			const amount = state.shake * 7;
			ctx.translate((rand(state.time * 97) - 0.5) * amount, (rand(state.time * 131) - 0.5) * amount);
		}
		drawBackground();
		drawTunnel();
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
		canvas.dataset.gameState = gameStateText();
	}

	function kill() {
		if (state.gameOver) {
			return;
		}
		state.gameOver = true;
		state.deathAlpha = 1;
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
			const moving = hazard.type === 'movingSpike' ? Math.sin(state.time * 3.2 + hazard.phase) * 1.25 : 0;
			if (Math.abs(hazard.lane + moving - state.visualLane) < 0.53 && !airborne) {
				kill();
				return;
			}
		}
	}

	function update(dt) {
		const step = Math.min(dt, 0.04);
		if (state.gameOver) {
			state.shake = Math.max(0, state.shake - step * 2.8);
			render();
			return;
		}
		state.time += step;
		state.speed = 13.8 + Math.min(8.2, state.time * 0.12);
		state.distance += state.speed * step;
		state.jumpClock += step;
		state.visualLane = lerp(state.visualLane, state.lane, Math.min(1, step * 13));
		state.shake = Math.max(0, state.shake - step * 3);
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
		pointerStart = { x: event.clientX, y: event.clientY };
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

	function gameStateText() {
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
	}

	window.render_game_to_text = gameStateText;

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
