import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Map,
  Leaf,
  Route,
  Users,
  Settings,
  Mountain,
  Sun,
  Scale,
  Utensils,
  Play,
  Pause,
  SkipForward,
  Plus,
  Minus,
  Crosshair,
  Download,
  FolderOpen,
  CircleHelp,
  X,
  WifiOff,
  Heart,
  Sprout,
  ChevronRight,
} from 'lucide-react';
import { useGame } from './useGame';
import type { ViewState } from './generated/protocol';
import { percent, quantity } from './format';
import Dashboard from './components/Charts';
import CellInspector from './components/CellInspector';
import Inspector from './components/Inspector';
import Minimap from './components/Minimap';
import WorldCanvas from './components/WorldCanvas';
import Explorer from './components/Explorer';
import type { ExplorerPanel } from './components/Explorer';
import type { WorldRenderer } from './world/WorldRenderer';

const initialView: ViewState = {
  overlay: 'overview',
  selected_household: 0,
  selected_person: -1,
  inspector_tab: 'inventory',
  panel: 'overview',
  camera_x: 0,
  camera_y: 0,
  zoom: 1,
};
const layers = [
  { id: 'overview', label: 'Overview', Icon: Map },
  { id: 'resources', label: 'Resources', Icon: Leaf },
  { id: 'trade', label: 'Trade Routes', Icon: Route },
  { id: 'households', label: 'Households', Icon: Users },
  { id: 'specialization', label: 'Specialization', Icon: Settings },
  { id: 'terrain', label: 'Terrain', Icon: Mountain },
  { id: 'food', label: 'Food Security', Icon: Heart },
];
const speeds = [0.25, 1, 5, 20, 100, 1000];

export default function App() {
  const { snapshot: s, connected, error, clearError, worlds, eventPage, history, send } = useGame();
  const [view, setView] = useState<ViewState>(initialView);
  const [panel, setPanel] = useState<ExplorerPanel | null>(null);
  const renderer = useRef<WorldRenderer | null>(null);
  const viewRef = useRef(view);
  viewRef.current = view;
  const viewTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const worldID = useRef('');
  const gameRef = useRef(s);
  gameRef.current = s;

  useEffect(() => {
    if (s && s.world_id !== worldID.current) {
      worldID.current = s.world_id;
      clearTimeout(viewTimer.current);
      setView(s.runtime.view);
    }
  }, [s]);
  useEffect(() => () => clearTimeout(viewTimer.current), []);

  const changeView = useCallback(
    (patch: Partial<ViewState>) => {
      const next = { ...viewRef.current, ...patch };
      viewRef.current = next;
      setView(next);
      clearTimeout(viewTimer.current);
      viewTimer.current = setTimeout(() => send({ type: 'view', view: next }), 350);
    },
    [send],
  );
  const selectHousehold = useCallback(
    (id: number) =>
      changeView({ selected_household: id, selected_person: -1, selected_cell: undefined }),
    [changeView],
  );
  const selectPerson = useCallback(
    (id: number) => {
      const p = gameRef.current?.people.find((p) => p.data.id === id);
      if (p)
        changeView({
          selected_household: p.data.household,
          selected_person: id,
          selected_cell: undefined,
          inspector_tab: 'details',
        });
    },
    [changeView],
  );

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, select, textarea, dialog') || panel) return;
      if (e.code === 'Space') {
        e.preventDefault();
        send({ type: gameRef.current?.runtime.paused ? 'play' : 'pause' });
      }
      if (/^[0-5]$/.test(e.key)) send({ type: 'speed', speed: speeds[Number(e.key)] });
      if (e.key.toLowerCase() === 'l') renderer.current?.toggleFollow();
    };
    window.addEventListener('keydown', key);
    return () => window.removeEventListener('keydown', key);
  }, [panel, send]);

  if (!s)
    return (
      <main className="connection-screen">
        <div className="wordmark">
          BLACK BOX<span>ECONOMY SIMULATOR</span>
        </div>
        <span className="loading-ring" />
        <h1>Opening your world</h1>
        <p>{error || 'Connecting to the simulation…'}</p>
        <small>Your progress lives here. Every day, every decision.</small>
      </main>
    );
  const household = s.households.find((h) => h.data.id === view.selected_household);
  const person = s.people.find((p) => p.data.id === view.selected_person);
  const specializationCount = s.metrics.role_counts.slice(1).filter((n) => n > 0).length;

  return (
    <main className="game-shell">
      <WorldCanvas
        snapshot={s}
        view={view}
        onHousehold={selectHousehold}
        onPerson={selectPerson}
        onCell={(i) => changeView({ selected_cell: i })}
        onCamera={changeView}
        rendererRef={renderer}
      />
      <div className="world-vignette" />
      <header className="topbar">
        <button className="wordmark" onClick={() => setPanel('help')} aria-label="About Black Box">
          BLACK BOX<span>ECONOMY SIMULATOR</span>
        </button>
        <nav className="main-nav" aria-label="Explorer">
          <button onClick={() => setPanel('people')}>PEOPLE</button>
          <i />
          <button onClick={() => setPanel('resources')}>RESOURCES</button>
          <i />
          <button onClick={() => setPanel('trade')}>TRADE</button>
          <i />
          <button onClick={() => setPanel('emergence')}>EMERGENCE</button>
        </nav>
        <div className="header-stats">
          <div className="header-stat day-stat">
            <Sun size={32} />
            <div>
              <strong data-testid="day">Day {s.day}</strong>
              <span>Year {s.metrics.year + 1}</span>
            </div>
          </div>
          <div className="header-stat">
            <Users size={27} />
            <div>
              <strong>{s.metrics.alive_households}</strong>
              <span>
                Households<small>({s.metrics.alive} people)</small>
              </span>
            </div>
          </div>
          <div className="header-stat food-stat">
            <Utensils size={28} />
            <div>
              <strong>{quantity(s.metrics.food_days_avg_milli)}</strong>
              <span>
                Avg. Food Reserve<small>(days)</small>
              </span>
            </div>
          </div>
          <div className="header-stat trade-stat">
            <Scale size={30} />
            <div>
              <strong>{percent(s.metrics.trade_success_bp)}</strong>
              <span>
                Trade Success<small>(today)</small>
              </span>
            </div>
          </div>
          <div className="header-stat spec-stat">
            <Settings size={28} />
            <div>
              <strong>{specializationCount}</strong>
              <span>
                Specializations<small>Emerging through work</small>
              </span>
            </div>
          </div>
        </div>
        <div className="motto">
          SMALL PEOPLE
          <br />
          BIG SYSTEMS
        </div>
      </header>

      <aside className="map-nav panel">
        <h2>MAP VIEW</h2>
        {view.overlay === 'resources' && (
          <select
            className="resource-select"
            aria-label="Resource layer"
            value={view.resource_kind ?? 0}
            onChange={(e) => changeView({ resource_kind: Number(e.target.value) })}
          >
            {['Berries', 'Game', 'Wood', 'Stone'].map((name, i) => (
              <option key={name} value={i}>
                {name}
              </option>
            ))}
          </select>
        )}
        <nav aria-label="Map layers">
          {layers.map(({ id, label, Icon }) => (
            <button
              key={id}
              className={view.overlay === id ? 'active' : ''}
              onClick={() => changeView({ overlay: id })}
              aria-label={label}
              title={label}
              aria-pressed={view.overlay === id}
            >
              <Icon size={23} />
              <span>{label}</span>
              {view.overlay === id && <ChevronRight size={13} />}
            </button>
          ))}
        </nav>
      </aside>
      <div className="world-controls panel">
        <button
          className={`play-control ${!s.runtime.paused ? 'playing' : ''}`}
          disabled={!connected}
          onClick={() => send({ type: s.runtime.paused ? 'play' : 'pause' })}
          aria-label={s.runtime.paused ? 'Play simulation' : 'Pause simulation'}
        >
          {s.runtime.paused ? (
            <Play size={15} fill="currentColor" />
          ) : (
            <Pause size={15} fill="currentColor" />
          )}
        </button>
        <button
          className="icon-button"
          disabled={!connected}
          aria-label="Advance one day"
          onClick={() => send({ type: 'step', days: 1 })}
        >
          <SkipForward size={16} />
        </button>
        <div className="control-divider" />
        <select
          aria-label="Simulation speed"
          value={s.runtime.speed}
          onChange={(e) => send({ type: 'speed', speed: Number(e.target.value) })}
        >
          {speeds.map((v) => (
            <option key={v} value={v}>
              {v}× speed
            </option>
          ))}
        </select>
        <span className="sim-status">
          <i className={s.runtime.paused ? 'paused-dot' : ''} />
          {s.runtime.paused ? 'PAUSED' : 'LIVE'}
        </span>
      </div>

      {view.selected_cell !== undefined ? (
        <CellInspector
          snapshot={s}
          index={view.selected_cell}
          onClose={() => changeView({ selected_cell: undefined })}
        />
      ) : (
        <Inspector
          snapshot={s}
          household={household}
          person={person}
          tab={view.inspector_tab}
          onTab={(tab) => changeView({ inspector_tab: tab })}
          onClose={() => changeView({ selected_household: -1, selected_person: -1 })}
          onPerson={selectPerson}
          onFocus={() => household && renderer.current?.focusHousehold(household.data.id)}
        />
      )}
      <Minimap
        snapshot={s}
        selected={view.selected_household}
        onNavigate={(x, y) => renderer.current?.focusMap(x, y)}
        onFit={() => renderer.current?.fitWorld()}
      />
      <div className="world-tools">
        <div className="zoom-tools panel">
          <button aria-label="Zoom out" onClick={() => renderer.current?.zoom(0.8)}>
            <Minus size={16} />
          </button>
          <span>{Math.round(view.zoom * 100)}%</span>
          <button aria-label="Zoom in" onClick={() => renderer.current?.zoom(1.25)}>
            <Plus size={16} />
          </button>
          <button
            aria-label="Focus selected household"
            onClick={() => household && renderer.current?.focusHousehold(household.data.id)}
          >
            <Crosshair size={16} />
          </button>
        </div>
        <div className="utility-tools panel">
          <button
            aria-label="Export CSV"
            title="Export complete CSV history"
            onClick={() => send({ type: 'export_csv' })}
          >
            <Download size={16} />
          </button>
          <button aria-label="Saved worlds" title="Saved worlds" onClick={() => setPanel('worlds')}>
            <FolderOpen size={16} />
          </button>
          <button
            aria-label="World settings"
            title="World settings"
            onClick={() => setPanel('settings')}
          >
            <Settings size={16} />
          </button>
          <button aria-label="Help" title="Help & controls" onClick={() => setPanel('help')}>
            <CircleHelp size={16} />
          </button>
        </div>
      </div>
      <Dashboard
        snapshot={s}
        onAnalytics={() => setPanel('analytics')}
        onEvents={() => setPanel('events')}
        onSelect={selectHousehold}
      />
      <footer className="footer">
        <div>
          <span>BLACK BOX ECONOMY SIMULATOR</span>
          <i />
          v0.2.0
          <i />
          <span>A LIVING WORLD OF HUMAN EXCHANGE</span>
        </div>
        <div className="save-status">
          <i className={connected ? 'connected-dot' : 'offline-dot'} />
          {connected ? 'All progress saved' : 'Reconnecting'}
          <span>Seed {s.seed}</span>
        </div>
        <em>Observe · Hypothesize · Let Them Emerge</em>
      </footer>
      {(!connected || error) && (
        <div className="notification" role="alert">
          {connected ? <Sprout size={18} /> : <WifiOff size={18} />}
          <span>{error || 'Connection lost. Reconnecting to your saved world…'}</span>
          {error && (
            <button aria-label="Dismiss error" onClick={clearError}>
              <X size={16} />
            </button>
          )}
        </div>
      )}
      {panel && (
        <Explorer
          panel={panel}
          snapshot={s}
          worlds={worlds}
          eventPage={eventPage}
          history={history}
          send={send}
          onClose={() => setPanel(null)}
          onPerson={selectPerson}
          onHousehold={(id) => {
            selectHousehold(id);
            renderer.current?.focusHousehold(id);
          }}
        />
      )}
    </main>
  );
}
