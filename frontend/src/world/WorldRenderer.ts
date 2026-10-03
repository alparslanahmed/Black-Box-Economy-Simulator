import { Application, Assets, Container, Graphics, Matrix, Sprite, Text, Texture } from 'pixi.js';
import type { FederatedPointerEvent } from 'pixi.js';
import type { Snapshot, ViewState } from '../generated/protocol';

const TW = 42;
const TH = 23;
const project = (x: number, y: number) => ({ x: (x - y) * TW, y: (x + y) * TH });
const palette = [0x80928b, 0x8fca70, 0xd99b5b, 0x7aaba1, 0x82a9d4, 0xa487cf];

type Callbacks = {
  household: (id: number) => void;
  cell: (index: number) => void;
  person: (id: number) => void;
  camera: (camera: Pick<ViewState, 'camera_x' | 'camera_y' | 'zoom'>) => void;
  hover: (text: string) => void;
  error: (text: string) => void;
};

// This class only renders snapshots and forwards input. Visual randomness is
// a coordinate hash; it cannot consume the server's PCG state or change play.
export class WorldRenderer {
  private app = new Application();
  private root = new Container();
  private ground = new Container();
  private overlays = new Graphics();
  private paths = new Graphics();
  private objects = new Container();
  private selection = new Graphics();
  private labels = new Container();
  private snapshot?: Snapshot;
  private worldID = '';
  private textures: Record<string, Texture> = {};
  private huts = new Map<number, Sprite>();
  private resourceSprites: { sprite: Sprite; index: number; kind: number }[] = [];
  private walkers = new Map<number, Sprite>();
  private camera = { x: 0, y: 0, zoom: 1 };
  private dragging = false;
  private dragDistance = 0;
  private pointer = { x: 0, y: 0 };
  private ready = false;
  private disposed = false;
  private lastDay = -1;
  private dayReceivedAt = performance.now();
  private progress = 0;
  private followPerson = false;
  private keys = new Set<string>();
  private view?: ViewState;
  private onKeyDown = (e: KeyboardEvent) => {
    if ((e.target as HTMLElement).closest('input, select, textarea, dialog')) return;
    this.keys.add(e.key.toLowerCase());
    if (
      ['a', 'd', 's', 'w', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(
        e.key.toLowerCase(),
      )
    ) {
      e.preventDefault();
      this.followPerson = false;
    }
  };
  private onKeyUp = (e: KeyboardEvent) => {
    this.keys.delete(e.key.toLowerCase());
    if (['a', 'd', 's', 'w', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key))
      this.persistCamera();
  };

  constructor(
    private host: HTMLElement,
    private callbacks: Callbacks,
  ) {}

  async init() {
    await this.app.init({
      resizeTo: this.host,
      background: '#12242a',
      antialias: true,
      autoDensity: true,
      resolution: Math.min(devicePixelRatio, 2),
      preference: 'webgl',
      powerPreference: 'high-performance',
    });
    if (this.disposed) {
      this.app.destroy(true, { children: true });
      return;
    }
    this.host.appendChild(this.app.canvas);
    this.app.canvas.setAttribute(
      'aria-label',
      'Interactive isometric world. Drag to pan, scroll to zoom, click a household or person.',
    );
    this.app.canvas.setAttribute('tabindex', '0');
    this.app.stage.addChild(this.root);
    this.root.addChild(
      this.ground,
      this.overlays,
      this.paths,
      this.objects,
      this.selection,
      this.labels,
    );
    this.objects.sortableChildren = true;
    this.app.stage.eventMode = 'static';
    this.app.stage.hitArea = this.app.screen;
    this.app.stage.on('pointerdown', this.pointerDown);
    this.app.stage.on('globalpointermove', this.pointerMove);
    this.app.stage.on('pointerup', this.pointerUp);
    this.app.stage.on('pointerupoutside', this.pointerUp);
    this.app.stage.on('pointertap', (e: FederatedPointerEvent) => {
      if (this.dragDistance >= 6 || !this.snapshot) return;
      const p = this.root.toLocal(e.global);
      const x = Math.floor((p.x / TW + p.y / TH) / 2);
      const y = Math.floor((p.y / TH - p.x / TW) / 2);
      if (x >= 0 && y >= 0 && x < this.snapshot.config.map_w && y < this.snapshot.config.map_h)
        this.callbacks.cell(y * this.snapshot.config.map_w + x);
    });
    this.app.canvas.addEventListener('wheel', this.wheel, { passive: false });
    this.app.canvas.addEventListener('contextmenu', (e) => e.preventDefault());
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    const names = [
      'terrain-meadow',
      'terrain-forest',
      'terrain-rocky',
      'tree-pine',
      'tree-oak',
      'berry-bush',
      'stone-deposit',
      'deer',
      'wood-pile',
      'hut-01',
      'hut-02',
      'hut-03',
      'person-man',
      'person-woman',
      'person-child',
      'person-elder-man',
      'person-elder-woman',
    ];
    const results = await Promise.allSettled(
      names.map(async (name) => ({
        name,
        texture: await Assets.load<Texture>(`/art/${name}.png`),
      })),
    );
    if (this.disposed) {
      this.app.destroy(true, { children: true });
      return;
    }
    for (const result of results)
      if (result.status === 'fulfilled') this.textures[result.value.name] = result.value.texture;
    if (results.some((r) => r.status === 'rejected'))
      this.callbacks.error(
        'Some world artwork could not be loaded. Refresh when the connection returns.',
      );
    this.ready = true;
    if (this.snapshot) this.update(this.snapshot, this.view ?? this.snapshot.runtime.view);
    this.app.ticker.add(this.tick);
  }

  private hash(x: number, y: number, salt = 0) {
    let n = (Math.imul(x + salt, 374761393) ^ Math.imul(y + 11, 668265263)) >>> 0;
    n = Math.imul(n ^ (n >>> 13), 1274126177) >>> 0;
    return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
  }

  private sprite(name: string, x: number, y: number, width: number) {
    const sprite = new Sprite(this.textures[name] ?? Texture.EMPTY);
    sprite.anchor.set(0.5, 0.89);
    const aspect = sprite.texture.height / Math.max(1, sprite.texture.width);
    sprite.width = width;
    sprite.height = width * aspect;
    sprite.position.set(x, y);
    sprite.zIndex = y;
    return sprite;
  }

  private build(s: Snapshot) {
    this.callbacks.hover('');
    this.ground.removeChildren().forEach((c) => c.destroy());
    this.objects.removeChildren().forEach((c) => c.destroy());
    this.labels.removeChildren().forEach((c) => c.destroy());
    this.huts.clear();
    this.walkers.clear();
    this.resourceSprites = [];
    this.worldID = s.world_id;
    this.lastDay = -1;
    const occupied = new Set(s.households.map((h) => `${h.data.home.x},${h.data.home.y}`));
    const shadow = new Graphics();
    const corners = [
      project(0, 0),
      project(s.config.map_w, 0),
      project(s.config.map_w, s.config.map_h),
      project(0, s.config.map_h),
    ];
    // Deep water frames the playable meadow/forest/rock terrain. It is visual
    // atmosphere outside the simulation grid and cannot create new resources.
    shadow.poly(corners.flatMap((p) => [p.x, p.y + 13])).fill({ color: 0x203a32 });
    this.ground.addChild(shadow);
    for (let y = 0; y < s.config.map_h; y++) {
      for (let x = 0; x < s.config.map_w; x++) {
        const cell = s.cells[y * s.config.map_w + x];
        const p = project(x, y);
        const name = ['terrain-meadow', 'terrain-forest', 'terrain-rocky'][cell.terrain];
        const tex = this.textures[name] ?? Texture.WHITE;
        const tile = new Sprite(tex);
        tile.setFromMatrix(
          new Matrix(TW / tex.width, TH / tex.width, -TW / tex.height, TH / tex.height, p.x, p.y),
        );
        tile.tint = cell.terrain === 1 ? 0xb1c4ad : 0xd5d6b7;
        this.ground.addChild(tile);
        if (occupied.has(`${x},${y}`)) continue;
        // Keep entrances readable without changing resource locations.
        const nearHome = s.households.some(
          (h) => Math.abs(h.data.home.x - x) + Math.abs(h.data.home.y - y) < 2,
        );
        const r = this.hash(x, y);
        const at = project(x + 0.5, y + 0.5);
        at.x += (this.hash(x, y, 7) - 0.5) * 20;
        if (!nearHome && ((cell.terrain === 1 && r < 0.8) || (cell.terrain === 0 && r < 0.13))) {
          const tree = this.sprite(
            r > 0.57 ? 'tree-oak' : 'tree-pine',
            at.x,
            at.y,
            70 + this.hash(x, y, 2) * 40,
          );
          tree.tint = this.hash(x, y, 4) > 0.5 ? 0xd7e3bd : 0xb8cfc2;
          this.objects.addChild(tree);
          this.resourceSprites.push({ sprite: tree, index: y * s.config.map_w + x, kind: 2 });
        } else if (!nearHome && cell.terrain === 2 && r < 0.7) {
          const rock = this.sprite('stone-deposit', at.x, at.y, 65 + r * 30);
          this.objects.addChild(rock);
          this.resourceSprites.push({ sprite: rock, index: y * s.config.map_w + x, kind: 3 });
        } else if (cell.stock[0] > 2800 && r > 0.78) {
          const bush = this.sprite('berry-bush', at.x, at.y, 34 + r * 13);
          this.objects.addChild(bush);
          this.resourceSprites.push({ sprite: bush, index: y * s.config.map_w + x, kind: 0 });
        } else if (!nearHome && cell.stock[1] > 3500 && r > 0.7 && r < 0.74) {
          const deer = this.sprite('deer', at.x, at.y, 27);
          this.objects.addChild(deer);
          this.resourceSprites.push({ sprite: deer, index: y * s.config.map_w + x, kind: 1 });
        } else if (cell.terrain === 1 && r > 0.95) {
          const wood = this.sprite('wood-pile', at.x, at.y, 43);
          this.objects.addChild(wood);
          this.resourceSprites.push({ sprite: wood, index: y * s.config.map_w + x, kind: 2 });
        }
      }
    }
    const focus =
      s.households.find((h) => h.data.id === this.view?.selected_household) ?? s.households[0];
    if (focus) {
      const p = project(focus.data.home.x, focus.data.home.y);
      const savedCamera = s.runtime.view.camera_x !== 0 || s.runtime.view.camera_y !== 0;
      this.camera = {
        x: savedCamera ? s.runtime.view.camera_x : p.x,
        y: savedCamera ? s.runtime.view.camera_y : p.y,
        zoom: s.runtime.view.zoom || 1,
      };
    }
    this.updateCamera();
  }

  update(s: Snapshot, view: ViewState) {
    this.snapshot = s;
    this.view = view;
    if (!this.ready) return;
    if (s.world_id !== this.worldID) this.build(s);
    for (const { sprite, index, kind } of this.resourceSprites) {
      const c = s.cells[index];
      const ratio = c.stock[kind] / Math.max(1, c.capacity[kind]);
      sprite.alpha = 0.25 + 0.75 * Math.min(1, ratio);
      if (kind === 1) sprite.visible = c.stock[kind] > 0;
    }
    if (this.lastDay !== s.day) {
      this.lastDay = s.day;
      this.dayReceivedAt = performance.now();
      this.progress = 0;
    }
    for (const h of s.households) {
      let sprite = this.huts.get(h.data.id);
      if (!sprite) {
        const p = project(h.data.home.x, h.data.home.y);
        sprite = this.sprite(
          `hut-0${h.data.hut_variant + 1}`,
          p.x,
          p.y,
          h.data.hut_variant === 1 ? 99 : 90,
        );
        sprite.eventMode = 'static';
        sprite.cursor = 'pointer';
        sprite.on('pointertap', (e: FederatedPointerEvent) => {
          e.stopPropagation();
          if (this.dragDistance < 6) this.callbacks.household(h.data.id);
        });
        sprite.on('pointerover', () => {
          const current = this.snapshot?.households.find((v) => v.data.id === h.data.id);
          if (current)
            this.callbacks.hover(
              `${current.name} · ${current.data.member_count} people · ${current.role}`,
            );
        });
        sprite.on('pointerout', () => this.callbacks.hover(''));
        this.objects.addChild(sprite);
        this.huts.set(h.data.id, sprite);
      }
      sprite.tint = h.data.alive ? 0xffffff : 0x768078;
      sprite.alpha = view.overlay === 'resources' ? 0.75 : 1;
    }
    const ids = new Set(s.people.filter((p) => p.data.alive).map((p) => p.data.id));
    for (const [id, sprite] of this.walkers)
      if (!ids.has(id)) {
        sprite.destroy();
        this.walkers.delete(id);
      }
    for (const p of s.people) {
      if (!p.data.alive) continue;
      const name =
        p.stage === 'infant' || p.stage === 'child'
          ? 'person-child'
          : p.stage === 'elder'
            ? p.data.sex === 0
              ? 'person-elder-man'
              : 'person-elder-woman'
            : p.data.sex === 0
              ? 'person-man'
              : 'person-woman';
      let sprite = this.walkers.get(p.data.id);
      if (!sprite) {
        sprite = this.sprite(name, 0, 0, p.stage === 'infant' ? 12 : p.stage === 'child' ? 18 : 24);
        sprite.anchor.set(0.5, 0.95);
        sprite.eventMode = 'static';
        sprite.cursor = 'pointer';
        sprite.on('pointertap', (e: FederatedPointerEvent) => {
          e.stopPropagation();
          if (this.dragDistance < 6) this.callbacks.person(p.data.id);
        });
        sprite.on('pointerover', () =>
          this.callbacks.hover(
            this.snapshot?.people.find((v) => v.data.id === p.data.id)?.label ?? '',
          ),
        );
        sprite.on('pointerout', () => this.callbacks.hover(''));
        this.objects.addChild(sprite);
        this.walkers.set(p.data.id, sprite);
      } else if (this.textures[name]) sprite.texture = this.textures[name];
      const width = p.stage === 'infant' ? 12 : p.stage === 'child' ? 18 : 24;
      sprite.width = width;
      sprite.height = (width * sprite.texture.height) / Math.max(1, sprite.texture.width);
    }
    this.drawOverlay();
    this.drawSelection();
    this.drawRoutes();
    this.drawLabels();
  }

  setView(view: ViewState) {
    this.view = view;
    if (this.ready) {
      this.drawOverlay();
      this.drawSelection();
      this.drawRoutes();
      this.drawLabels();
    }
  }

  private drawOverlay() {
    const s = this.snapshot;
    if (!s || !this.view) return;
    const g = this.overlays;
    g.clear();
    if (this.view.overlay === 'resources' || this.view.overlay === 'terrain') {
      for (let y = 0; y < s.config.map_h; y++)
        for (let x = 0; x < s.config.map_w; x++) {
          const cell = s.cells[y * s.config.map_w + x];
          const p = project(x, y);
          const kind =
            this.view.overlay === 'resources'
              ? (this.view.resource_kind ?? 0)
              : cell.terrain === 2
                ? 3
                : cell.terrain === 1
                  ? 2
                  : 0;
          const amount = cell.stock[kind] / Math.max(1, cell.capacity[kind]);
          g.poly([p.x, p.y, p.x + TW, p.y + TH, p.x, p.y + TH * 2, p.x - TW, p.y + TH]).fill({
            color: [0x9bbf47, 0xdfa15e, 0x408d68, 0x9b9fae][kind],
            alpha: this.view.overlay === 'terrain' ? 0.2 : amount * 0.4,
          });
        }
    }
    if (
      this.view.overlay === 'specialization' ||
      this.view.overlay === 'households' ||
      this.view.overlay === 'food'
    ) {
      for (const h of s.households) {
        const p = project(h.data.home.x, h.data.home.y);
        const color =
          this.view.overlay === 'food'
            ? h.food_days > 2000
              ? 0x7fc363
              : h.food_days > 1000
                ? 0xe2b160
                : 0xd46b5d
            : palette[h.data.inferred_role];
        g.ellipse(p.x, p.y + 3, 59, 30)
          .fill({ color, alpha: 0.3 })
          .stroke({ color, alpha: 0.8, width: 1.4 });
      }
    }
  }

  private drawSelection() {
    this.selection.clear();
    if (this.snapshot && this.view?.selected_cell !== undefined) {
      const i = this.view.selected_cell,
        p = project(i % this.snapshot.config.map_w, Math.floor(i / this.snapshot.config.map_w));
      this.selection
        .poly([p.x, p.y, p.x + TW, p.y + TH, p.x, p.y + TH * 2, p.x - TW, p.y + TH])
        .fill({ color: 0xffd699, alpha: 0.15 })
        .stroke({ color: 0xffd699, width: 2 });
      return;
    }
    const h = this.snapshot?.households.find((h) => h.data.id === this.view?.selected_household);
    if (!h) return;
    const p = project(h.data.home.x, h.data.home.y);
    this.selection
      .ellipse(p.x, p.y + 1, 46, 22)
      .fill({ color: 0xf2d19a, alpha: 0.1 })
      .stroke({ color: 0xffe3a6, width: 2, alpha: 0.95 });
    const left = p.x - 42,
      right = p.x + 42,
      top = p.y - 70,
      bottom = p.y + 4;
    for (const [x, y, dx, dy] of [
      [left, top, 1, 1],
      [right, top, -1, 1],
      [left, bottom, 1, -1],
      [right, bottom, -1, -1],
    ])
      this.selection
        .moveTo(x, y + dy * 12)
        .lineTo(x, y)
        .lineTo(x + dx * 12, y)
        .stroke({ color: 0xffe8b8, width: 2.4 });
  }

  private drawRoutes() {
    this.paths.clear();
    const s = this.snapshot;
    if (!s) return;
    const pairs = new Set<string>();
    for (const e of s.exchanges) {
      if (
        s.day - e.day > 30 ||
        (this.view?.overlay !== 'trade' &&
          e.h0 !== this.view?.selected_household &&
          e.h1 !== this.view?.selected_household)
      )
        continue;
      const key = [e.h0, e.h1].sort().join('-');
      if (pairs.has(key)) continue;
      pairs.add(key);
      const a = s.households.find((h) => h.data.id === e.h0),
        b = s.households.find((h) => h.data.id === e.h1);
      if (!a || !b) continue;
      const p = project(a.data.home.x, a.data.home.y),
        q = project(b.data.home.x, b.data.home.y);
      const length = Math.hypot(q.x - p.x, q.y - p.y);
      for (let d = 0; d < length; d += 13) {
        const u = d / length,
          v = Math.min(d + 6, length) / length;
        this.paths
          .moveTo(p.x + (q.x - p.x) * u, p.y + (q.y - p.y) * u)
          .lineTo(p.x + (q.x - p.x) * v, p.y + (q.y - p.y) * v)
          .stroke({ color: 0xffdda0, width: 2, alpha: 0.85 });
      }
    }
  }

  private drawLabels() {
    this.labels.removeChildren().forEach((c) => c.destroy());
    const s = this.snapshot;
    if (!s || !this.view) return;
    if (this.view.overlay === 'households' || this.view.overlay === 'specialization') {
      for (const h of s.households) {
        const p = project(h.data.home.x, h.data.home.y);
        this.label(p.x, p.y + 20, this.view.overlay === 'households' ? h.name : h.role);
      }
    }
    if (this.view.overlay === 'overview' || this.view.overlay === 'resources') {
      const h =
        s.households.find((h) => h.data.id === this.view?.selected_household) ?? s.households[0];
      if (!h) return;
      for (const [kind, name] of [
        [0, 'Berry patch'],
        [2, 'Forest · wood'],
        [3, 'Stone deposit'],
      ] as const) {
        let best = -1,
          score = 0;
        for (let i = 0; i < s.cells.length; i++) {
          const x = i % s.config.map_w,
            y = Math.floor(i / s.config.map_w);
          const d = Math.hypot(x - h.data.home.x, y - h.data.home.y);
          if (d < 3 || d > 8) continue;
          const val = s.cells[i].stock[kind] / (d + 1);
          if (val > score) {
            score = val;
            best = i;
          }
        }
        if (best >= 0) {
          const p = project(best % s.config.map_w, Math.floor(best / s.config.map_w));
          this.label(p.x, p.y - 35, name);
        }
      }
    }
  }

  private label(x: number, y: number, text: string) {
    const label = new Text({
      text,
      style: {
        fontFamily: 'Segoe UI, sans-serif',
        fontSize: 12,
        fill: '#f0f2e7',
        dropShadow: { color: '#000000', blur: 3, distance: 1 },
      },
    });
    const bg = new Graphics()
      .roundRect(-label.width / 2 - 12, -13, label.width + 24, 27, 13)
      .fill({ color: 0x0c1820, alpha: 0.82 })
      .stroke({ color: 0xa2b2a0, alpha: 0.2, width: 1 });
    const group = new Container();
    group.addChild(bg, label);
    label.anchor.set(0.5);
    group.position.set(x, y);
    this.labels.addChild(group);
  }

  private tick = () => {
    const s = this.snapshot;
    if (!s) return;
    if (!s.runtime.paused)
      this.progress = Math.min(
        1,
        (performance.now() - this.dayReceivedAt) / Math.max(80, 1000 / s.runtime.speed),
      );
    const t = this.progress;
    for (const person of s.people) {
      const sprite = this.walkers.get(person.data.id);
      if (!sprite) continue;
      const path = person.view_path;
      if (!path.length) continue;
      let ai = path.length - 1,
        bi = ai;
      for (let i = 1; i < path.length; i++)
        if (t <= person.view_times[i]) {
          ai = i - 1;
          bi = i;
          break;
        }
      const a = path[ai],
        b = path[bi];
      const fraction = Math.min(
        1,
        Math.max(
          0,
          (t - person.view_times[ai]) /
            Math.max(0.000001, person.view_times[bi] - person.view_times[ai]),
        ),
      );
      const p = project(
        (a.x + (b.x - a.x) * fraction) / 1000,
        (a.y + (b.y - a.y) * fraction) / 1000,
      );
      const moving = a.x !== b.x || a.y !== b.y;
      sprite.position.set(
        p.x,
        p.y -
          (moving && !s.runtime.paused
            ? Math.abs(Math.sin(performance.now() / 110 + person.data.id)) * 1.3
            : 0),
      );
      sprite.zIndex = p.y + 3;
      sprite.alpha = b.doing === 0 && !moving ? 0.42 : 1;
      if (this.followPerson && person.data.id === this.view?.selected_person) {
        this.camera.x += (p.x - this.camera.x) * 0.07;
        this.camera.y += (p.y - this.camera.y) * 0.07;
      }
    }
    const speed = 7 / this.camera.zoom;
    if (this.keys.has('a') || this.keys.has('arrowleft')) this.camera.x -= speed;
    if (this.keys.has('d') || this.keys.has('arrowright')) this.camera.x += speed;
    if (this.keys.has('w') || this.keys.has('arrowup')) this.camera.y -= speed;
    if (this.keys.has('s') || this.keys.has('arrowdown')) this.camera.y += speed;
    this.updateCamera();
  };

  private updateCamera() {
    this.root.scale.set(this.camera.zoom);
    this.root.position.set(
      this.app.screen.width / 2 - 62 - this.camera.x * this.camera.zoom,
      this.app.screen.height / 2 - 40 - this.camera.y * this.camera.zoom,
    );
  }
  private persistCamera() {
    this.callbacks.camera({
      camera_x: this.camera.x,
      camera_y: this.camera.y,
      zoom: this.camera.zoom,
    });
  }
  private pointerDown = (e: FederatedPointerEvent) => {
    this.dragging = true;
    this.dragDistance = 0;
    this.pointer = { x: e.global.x, y: e.global.y };
  };
  private pointerMove = (e: FederatedPointerEvent) => {
    if (!this.dragging) return;
    const dx = e.global.x - this.pointer.x,
      dy = e.global.y - this.pointer.y;
    this.dragDistance += Math.abs(dx) + Math.abs(dy);
    this.camera.x -= dx / this.camera.zoom;
    this.camera.y -= dy / this.camera.zoom;
    this.pointer = { x: e.global.x, y: e.global.y };
    this.followPerson = false;
    this.updateCamera();
  };
  private pointerUp = () => {
    if (this.dragging && this.dragDistance > 3) this.persistCamera();
    this.dragging = false;
  };
  private wheel = (e: WheelEvent) => {
    e.preventDefault();
    this.zoom(e.deltaY > 0 ? 0.9 : 1.1);
  };
  zoom(factor: number) {
    this.camera.zoom = Math.max(0.2, Math.min(4, this.camera.zoom * factor));
    this.updateCamera();
    this.persistCamera();
  }
  focusHousehold(id: number) {
    const h = this.snapshot?.households.find((h) => h.data.id === id);
    if (!h) return;
    const p = project(h.data.home.x, h.data.home.y);
    this.camera.x = p.x;
    this.camera.y = p.y;
    this.followPerson = false;
    this.updateCamera();
    this.persistCamera();
  }
  focusMap(x: number, y: number) {
    const p = project(x, y);
    this.camera.x = p.x;
    this.camera.y = p.y;
    this.followPerson = false;
    this.updateCamera();
    this.persistCamera();
  }
  toggleFollow() {
    this.followPerson = !this.followPerson;
  }
  fitWorld() {
    const s = this.snapshot;
    if (!s) return;
    const center = project(s.config.map_w / 2, s.config.map_h / 2);
    this.camera = {
      x: center.x,
      y: center.y,
      zoom: Math.max(
        0.2,
        Math.min(
          (this.app.screen.width - 430) / ((s.config.map_w + s.config.map_h) * TW),
          (this.app.screen.height - 310) / ((s.config.map_w + s.config.map_h) * TH),
        ),
      ),
    };
    this.updateCamera();
    this.persistCamera();
  }

  destroy() {
    this.disposed = true;
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    if (this.ready) {
      this.app.canvas.removeEventListener('wheel', this.wheel);
      this.app.destroy(true, { children: true });
    }
  }
}
