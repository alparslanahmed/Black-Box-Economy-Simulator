import { useEffect, useRef, useState } from 'react';
import {
  Download,
  FolderOpen,
  Globe2,
  Search,
  X,
  ArrowUpRight,
  SlidersHorizontal,
  CircleHelp,
  Check,
  Leaf,
} from 'lucide-react';
import type { Snapshot, WorldSummary, EventPage, HistoryPage } from '../generated/protocol';
import { ACTIVITIES, GOODS, ROLES } from '../generated/protocol';
import type { CommandInput } from '../useGame';
import { art, goodArt, percent, quantity, roleColors } from '../format';
import Analytics from './Analytics';
import { EconomyChart, EventIcon } from './Charts';

export type ExplorerPanel =
  | 'people'
  | 'resources'
  | 'trade'
  | 'emergence'
  | 'events'
  | 'settings'
  | 'worlds'
  | 'help'
  | 'analytics';

export default function Explorer({
  panel,
  snapshot: s,
  worlds,
  eventPage,
  history,
  send,
  onClose,
  onPerson,
  onHousehold,
}: {
  panel: ExplorerPanel;
  snapshot: Snapshot;
  worlds: WorldSummary[];
  eventPage?: EventPage;
  history?: HistoryPage;
  send: (command: CommandInput) => void;
  onClose: () => void;
  onPerson: (id: number) => void;
  onHousehold: (id: number) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [search, setSearch] = useState('');
  const [seed, setSeed] = useState(s.seed);
  const [households, setHouseholds] = useState(s.config.household_count);
  const [newTrade, setNewTrade] = useState(true);
  const [regen, setRegen] = useState(10000);
  const [showDead, setShowDead] = useState(false);
  const [eventFilter, setEventFilter] = useState('All');
  useEffect(() => {
    dialog.current?.showModal();
    return () => dialog.current?.close();
  }, []);
  useEffect(() => {
    if (panel === 'worlds') send({ type: 'list_worlds' });
  }, [panel, send]);
  useEffect(() => {
    if (panel === 'events') send({ type: 'events', category: eventFilter });
  }, [panel, eventFilter, send]);
  useEffect(() => {
    if (panel === 'analytics') send({ type: 'history' });
  }, [panel, send]);
  const archive = eventPage?.items ?? [];
  const titles = {
    analytics: 'The economy, over time',
    people: 'The people behind the economy',
    resources: 'A world of finite resources',
    trade: 'Exchange, without a market price',
    emergence: 'Patterns from everyday decisions',
    events: 'The story so far',
    settings: 'Your world, your experiment',
    worlds: 'Saved worlds',
    help: 'Observe. Hypothesize. Let them emerge.',
  };
  return (
    <dialog
      ref={dialog}
      className={`explorer panel explorer-${panel}`}
      onCancel={onClose}
      onClick={(e) => {
        if (e.target === dialog.current) onClose();
      }}
      aria-label={titles[panel]}
    >
      <div className="explorer-inner">
        <header>
          <div>
            <span className="eyebrow">BLACK BOX / {panel}</span>
            <h2>{titles[panel]}</h2>
          </div>
          <button className="icon-button" aria-label="Close dialog" onClick={onClose}>
            <X size={21} />
          </button>
        </header>
        <div className="explorer-body">
          {panel === 'analytics' && <Analytics snapshot={s} history={history} send={send} />}
          {panel === 'people' && (
            <>
              <div className="explorer-toolbar">
                <label className="search-box">
                  <Search size={16} />
                  <input
                    placeholder="Find a person or household…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </label>
                <label className="check-label">
                  <input
                    type="checkbox"
                    checked={showDead}
                    onChange={(e) => setShowDead(e.target.checked)}
                  />{' '}
                  Include ancestors
                </label>
                <span>{s.metrics.alive} living people</span>
              </div>
              <div className="people-grid">
                {s.people
                  .filter(
                    (p) =>
                      (showDead || p.data.alive) &&
                      `${p.label} ${p.data.household}`.toLowerCase().includes(search.toLowerCase()),
                  )
                  .map((p) => (
                    <button
                      key={p.data.id}
                      className="person-card"
                      onClick={() => {
                        onPerson(p.data.id);
                        onClose();
                      }}
                    >
                      <img
                        src={art(
                          p.stage === 'infant' || p.stage === 'child'
                            ? 'person-child'
                            : p.stage === 'elder'
                              ? p.data.sex === 0
                                ? 'person-elder-man'
                                : 'person-elder-woman'
                              : p.data.sex === 0
                                ? 'person-man'
                                : 'person-woman',
                        )}
                        alt=""
                      />
                      <div>
                        <h3>{p.label}</h3>
                        <p>Household #{p.data.household}</p>
                        <span className={p.data.alive ? 'healthy' : 'muted'}>
                          {p.data.alive
                            ? `${percent(p.data.health)} health · ${ACTIVITIES[p.data.intent_activity]}`
                            : 'Deceased'}
                        </span>
                        {p.data.pregnant && <small>Expecting · day {p.data.pregnancy_days}</small>}
                      </div>
                      <ArrowUpRight size={16} />
                    </button>
                  ))}
              </div>
              <div className="statistics-row">
                <span>
                  Births today <b>{s.metrics.births}</b>
                </span>
                <span>
                  Crude birth rate <b>{quantity(s.metrics.cbr_milli, 1)}</b>
                </span>
                <span>
                  Fertility estimate <b>{quantity(s.metrics.tfr_milli, 2)}</b>
                </span>
                <span>
                  Marriageable singles <b>{s.metrics.unmarried_marriageable}</b>
                </span>
              </div>
            </>
          )}
          {panel === 'resources' && (
            <>
              <p className="explainer">
                Production extracts actual local stock. Berries, game and wood regenerate; stone is
                finite. Food spoils at the end of each day.
              </p>
              <div className="resource-cards">
                {['Berries', 'Game', 'Wood', 'Stone'].map((name, i) => (
                  <article key={name}>
                    <img
                      src={art(['berry-bush', 'deer', 'wood-pile', 'stone-deposit'][i])}
                      alt=""
                    />
                    <h3>{name}</h3>
                    <strong>{quantity(s.metrics.resource_stock[i], 0)}</strong>
                    <span>available across the map</span>
                  </article>
                ))}
              </div>
              <h3 className="section-title">Production today</h3>
              <table>
                <thead>
                  <tr>
                    <th>Good</th>
                    <th>Produced</th>
                    <th>Direct ratio to berries</th>
                  </tr>
                </thead>
                <tbody>
                  {GOODS.map((g, i) => (
                    <tr key={g}>
                      <td>
                        <img className="table-good" src={art(goodArt[i])} alt="" />
                        {g}
                      </td>
                      <td>{quantity(s.metrics.produced[i], 3)}</td>
                      <td>
                        {s.metrics.berries_per_unit[i] < 0
                          ? 'No observed exchange'
                          : quantity(s.metrics.berries_per_unit[i], 3)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          )}
          {panel === 'trade' && (
            <>
              <div className="statistics-row">
                <span>
                  Attempts today <b>{s.metrics.trade_attempts}</b>
                </span>
                <span>
                  Successful trades <b>{s.metrics.successful_trades}</b>
                </span>
                <span>
                  Success rate <b>{percent(s.metrics.trade_success_bp)}</b>
                </span>
                <span>
                  Visits today <b>{s.metrics.visits}</b>
                </span>
              </div>
              <p className="explainer">
                Every completed barter must increase both households' direct utility. These are
                observed exchanges, not prices assigned by the simulation.
              </p>
              <table>
                <thead>
                  <tr>
                    <th>Day</th>
                    <th>From</th>
                    <th>Gave</th>
                    <th>Received</th>
                    <th>Partner</th>
                  </tr>
                </thead>
                <tbody>
                  {[...s.exchanges].reverse().map((e, i) => (
                    <tr key={i}>
                      <td>{e.day}</td>
                      <td>
                        <button
                          className="table-link"
                          onClick={() => {
                            onHousehold(e.h0);
                            onClose();
                          }}
                        >
                          Household #{e.h0}
                        </button>
                      </td>
                      <td>
                        {quantity(e.q0)} {GOODS[e.g0]}
                      </td>
                      <td>
                        {quantity(e.q1)} {GOODS[e.g1]}
                      </td>
                      <td>#{e.h1}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {!s.exchanges.length && (
                <div className="large-empty">
                  <Leaf />
                  <h3>No exchanges have happened yet.</h3>
                  <p>
                    Let the world run. Trade starts when nearby households have a reason to visit
                    and mutually useful goods.
                  </p>
                </div>
              )}
            </>
          )}
          {panel === 'emergence' && (
            <>
              <p className="explainer">
                Specializations describe the largest share of work over the last 30 days. No
                household is assigned a job or given a specialization bonus.
              </p>
              <div className="expanded-chart">
                <EconomyChart snapshot={s} />
              </div>
              <div className="role-summary">
                {ROLES.map((r, i) => (
                  <span key={r}>
                    <i style={{ background: roleColors[i] }} />
                    {r}
                    <b>{s.metrics.role_counts[i]}</b>
                  </span>
                ))}
              </div>
              <h3 className="section-title">Most specialized households</h3>
              <table>
                <thead>
                  <tr>
                    <th>Household</th>
                    <th>Observed role</th>
                    <th>Labor concentration</th>
                    <th>Food reserve</th>
                  </tr>
                </thead>
                <tbody>
                  {[...s.households]
                    .filter((h) => h.data.alive)
                    .sort((a, b) => b.data.specialization_bp - a.data.specialization_bp)
                    .map((h) => (
                      <tr key={h.data.id}>
                        <td>
                          <button
                            className="table-link"
                            onClick={() => {
                              onHousehold(h.data.id);
                              onClose();
                            }}
                          >
                            {h.name}
                          </button>
                        </td>
                        <td>{h.role}</td>
                        <td>{percent(h.data.specialization_bp)}</td>
                        <td>{quantity(h.food_days)} days</td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </>
          )}
          {panel === 'events' && (
            <>
              <div className="explorer-toolbar">
                <label className="search-box">
                  <Search size={16} />
                  <input
                    placeholder="Search this page of events…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </label>
                <select
                  aria-label="Event category"
                  value={eventFilter}
                  onChange={(e) => setEventFilter(e.target.value)}
                >
                  {[
                    'All',
                    'People',
                    'Trade',
                    'Production',
                    'Health',
                    'Scarcity',
                    'Specialization',
                  ].map((v) => (
                    <option key={v}>{v}</option>
                  ))}
                </select>
              </div>
              <div className="expanded-events">
                {archive
                  .filter(
                    (e) =>
                      (eventFilter === 'All' || e.category === eventFilter) &&
                      e.text.toLowerCase().includes(search.toLowerCase()),
                  )
                  .map((e, i) => (
                    <div key={i}>
                      <EventIcon event={e} />
                      <p>
                        {e.text}
                        <small>{e.category}</small>
                      </p>
                      <span>Day {e.data.day}</span>
                    </div>
                  ))}
              </div>
              <div className="archive-pagination">
                <button
                  className="secondary-button"
                  onClick={() => send({ type: 'events', category: eventFilter })}
                >
                  Latest events
                </button>
                <span>100 events per page · full saved history</span>
                <button
                  className="secondary-button"
                  disabled={!eventPage?.has_more}
                  onClick={() =>
                    send({ type: 'events', category: eventFilter, before: eventPage?.before })
                  }
                >
                  Older events →
                </button>
              </div>
              {!archive.length && (
                <div className="large-empty">
                  <Leaf />
                  <p>Advance the simulation to begin your world's story.</p>
                </div>
              )}
            </>
          )}
          {panel === 'settings' && (
            <>
              <div className="settings-columns">
                <section>
                  <h3>
                    <SlidersHorizontal size={18} /> Current experiment
                  </h3>
                  <label className="switch-row">
                    <span>
                      Voluntary barter<small>Allow households to exchange goods</small>
                    </span>
                    <input
                      type="checkbox"
                      checked={s.trade_enabled}
                      onChange={(e) => send({ type: 'trade', trade: e.target.checked })}
                    />
                  </label>
                  <label className="field-label">
                    Berry regeneration <span>{Math.round(s.berry_regen_bp / 100)}%</span>
                    <input
                      type="range"
                      min="0"
                      max="20000"
                      step="500"
                      value={s.berry_regen_bp}
                      onChange={(e) =>
                        send({ type: 'regeneration', berry_regen_bp: Number(e.target.value) })
                      }
                    />
                  </label>
                  <button
                    className="secondary-button w-full"
                    onClick={() => send({ type: 'export_csv' })}
                  >
                    <Download size={16} /> Export complete history as CSV
                  </button>
                  <div className="save-note">
                    <Check size={16} />
                    <p>
                      Every completed day is saved automatically. You can close the browser and
                      return to this world.
                    </p>
                  </div>
                  <button
                    className="text-button"
                    onClick={() => {
                      send({ type: 'reset' });
                      onClose();
                    }}
                  >
                    Restart this seed in a new saved world
                  </button>
                </section>
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    send({
                      type: 'new_world',
                      seed,
                      households,
                      trade: newTrade,
                      berry_regen_bp: regen,
                    });
                    onClose();
                  }}
                >
                  <h3>
                    <Globe2 size={18} /> Begin a new world
                  </h3>
                  <label className="field-label">
                    World seed
                    <input
                      required
                      pattern="[0-9]+"
                      value={seed}
                      onChange={(e) => setSeed(e.target.value)}
                    />
                  </label>
                  <label className="field-label">
                    Initial households
                    <input
                      type="number"
                      required
                      min="1"
                      max="1000"
                      value={households}
                      onChange={(e) => setHouseholds(Number(e.target.value))}
                    />
                  </label>
                  <label className="field-label">
                    Berry regeneration (%)
                    <input
                      type="number"
                      min="0"
                      max="1000"
                      value={regen / 100}
                      onChange={(e) => setRegen(Number(e.target.value) * 100)}
                    />
                  </label>
                  <label className="check-label">
                    <input
                      type="checkbox"
                      checked={newTrade}
                      onChange={(e) => setNewTrade(e.target.checked)}
                    />{' '}
                    Enable barter
                  </label>
                  <button className="primary-button w-full" type="submit">
                    <Globe2 size={16} /> Create world
                  </button>
                  <p className="subtle-copy">Your current world stays in Saved Worlds.</p>
                </form>
              </div>
            </>
          )}
          {panel === 'worlds' && (
            <div className="saved-worlds">
              {worlds.map((w) => (
                <article key={w.id}>
                  <Globe2 size={30} />
                  <div>
                    <h3>
                      World {w.seed}
                      {w.id === s.world_id && <span className="current-badge">CURRENT</span>}
                    </h3>
                    <p>
                      Day {w.day} · {w.households} households · {w.people} people
                    </p>
                    <small>{new Date(w.updated_at).toLocaleString()}</small>
                  </div>
                  <button
                    className="secondary-button"
                    disabled={w.id === s.world_id}
                    onClick={() => {
                      send({ type: 'load_world', world_id: w.id });
                      onClose();
                    }}
                  >
                    <FolderOpen size={15} /> Open
                  </button>
                </article>
              ))}
              {!worlds.length && <p className="subtle-copy">Loading saved worlds…</p>}
            </div>
          )}
          {panel === 'help' && (
            <>
              <div className="help-intro">
                <CircleHelp size={30} />
                <p>
                  Watch a small society organize itself through scarcity, geography, skills, tools,
                  family life and direct barter. Click a person or household, then open{' '}
                  <b>Skills</b> to see why they chose an activity.
                </p>
              </div>
              <div className="shortcut-grid">
                {[
                  ['Space', 'Play / pause'],
                  ['0 – 5', 'Simulation speed'],
                  ['W A S D / arrows', 'Pan the map'],
                  ['Scroll', 'Zoom'],
                  ['Drag', 'Move the camera'],
                  ['L', 'Follow selected person'],
                  ['Click hut / person', 'Inspect'],
                  ['Mini map', 'Move across the world'],
                ].map(([key, description]) => (
                  <div key={key}>
                    <kbd>{key}</kbd>
                    <span>{description}</span>
                  </div>
                ))}
              </div>
              <p className="explainer">
                Day length: {s.config.day_minutes} minutes · Year: {s.config.days_per_year} days ·
                Pregnancy: {s.config.pregnancy_days} days. All decisions and economic systems run on
                the server.
              </p>
              <p className="subtle-copy">
                Five goods. No money, global prices, assigned professions or artificial trade bonus.
                New worlds with the same seed and settings produce the same history.
              </p>
            </>
          )}
        </div>
      </div>
    </dialog>
  );
}
