import { useState } from 'react';
import {
  Activity,
  ArrowUpRight,
  Users,
  Sprout,
  ArrowLeftRight,
  Heart,
  Hammer,
  Sparkles,
} from 'lucide-react';
import { GOODS, ROLES } from '../generated/protocol';
import type { Snapshot, EventView } from '../generated/protocol';
import { art, goodArt, percent, quantity, roleColors } from '../format';

export function EventIcon({ event }: { event: EventView }) {
  const Icon =
    event.category === 'Trade'
      ? ArrowLeftRight
      : event.category === 'People'
        ? Users
        : event.category === 'Health'
          ? Heart
          : event.category === 'Specialization'
            ? Sparkles
            : event.category === 'Production'
              ? Hammer
              : Sprout;
  return <Icon size={18} className={`event-icon category-${event.category.toLowerCase()}`} />;
}

export function EconomyChart({ snapshot: s }: { snapshot: Snapshot }) {
  const data = s.history;
  const series = [
    {
      key: 'Food reserve',
      color: '#8ac973',
      values: data.map((m) => m.food_days_avg_milli / 1000),
    },
    { key: 'Trade volume', color: '#db975b', values: data.map((m) => m.successful_trades) },
    { key: 'Population', color: '#75b5e6', values: data.map((m) => m.alive) },
  ];
  const max = Math.max(10, ...series.flatMap((line) => line.values));
  const x = (i: number) => 32 + (i / Math.max(1, data.length - 1)) * 430;
  const y = (v: number) => 124 - (v / max) * 103;
  return (
    <>
      <div className="chart-legend">
        {series.map((line) => (
          <span key={line.key}>
            <i style={{ background: line.color }} />
            {line.key}
          </span>
        ))}
      </div>
      <svg
        viewBox="0 0 480 148"
        className="economy-chart"
        role="img"
        aria-label="Historical food reserves, successful trades, and population"
      >
        {[0, 1, 2, 3].map((i) => (
          <g key={i}>
            <line
              x1="32"
              x2="468"
              y1={y((max * i) / 3)}
              y2={y((max * i) / 3)}
              stroke="#30404a"
              strokeOpacity=".55"
            />
            <text x="22" y={y((max * i) / 3) + 4} textAnchor="end">
              {Math.round((max * i) / 3)}
            </text>
          </g>
        ))}
        {[0, 0.25, 0.5, 0.75, 1].map((i) => (
          <g key={i}>
            <line
              x1={32 + 430 * i}
              x2={32 + 430 * i}
              y1="21"
              y2="124"
              stroke="#30404a"
              strokeOpacity=".35"
            />
            <text x={32 + 430 * i} y="143" textAnchor="middle">
              {data.length
                ? Math.round(data[0].day + (data[data.length - 1].day - data[0].day) * i)
                : Math.round(i * 10)}
            </text>
          </g>
        ))}
        {series.map((line) => (
          <polyline
            key={line.key}
            fill="none"
            stroke={line.color}
            strokeWidth="1.8"
            strokeLinejoin="round"
            points={line.values.map((v, i) => `${x(i)},${y(v)}`).join(' ')}
          />
        ))}
        {data.length === 0 && (
          <text x="250" y="72" textAnchor="middle" className="chart-empty">
            Play or step forward to observe the economy
          </text>
        )}
      </svg>
    </>
  );
}

export default function Dashboard({
  snapshot: s,
  onAnalytics,
  onEvents,
  onSelect,
}: {
  snapshot: Snapshot;
  onAnalytics: () => void;
  onEvents: () => void;
  onSelect: (id: number) => void;
}) {
  const [filter, setFilter] = useState('All events');
  const produced = s.metrics.produced;
  const maxProduced = Math.max(1000, ...produced);
  const roles = s.metrics.role_counts;
  const total = Math.max(
    1,
    roles.reduce((sum, n) => sum + n, 0),
  );
  let offset = 0;
  const slices = roles.map((n, i) => {
    const start = offset;
    offset += (n / total) * 100;
    return `${roleColors[i]} ${start}% ${offset}%`;
  });
  const filtered = s.events.filter((e) => filter === 'All events' || e.category === filter);
  return (
    <section className="dashboard panel" aria-label="Economy dashboard">
      <div className="dash-section economy-section">
        <h2>
          <button onClick={onAnalytics} aria-label="Open full analytics">
            ECONOMY OVERVIEW <Activity size={13} />
          </button>
        </h2>
        <EconomyChart snapshot={s} />
      </div>
      <div className="dash-section flow-section">
        <h2>
          RESOURCE FLOW <span>Today</span>
        </h2>
        <div className="resource-flows">
          {GOODS.map((good, i) => (
            <div className="flow-row" key={good}>
              <img src={art(goodArt[i])} alt="" />
              <span title={`${good}: ${quantity(produced[i])}`}>{quantity(produced[i], 0)}</span>
              <div className="flow-track">
                <i
                  style={{
                    width: `${Math.max(0, (produced[i] / maxProduced) * 100)}%`,
                    background: ['#d96e67', '#d59463', '#b79964', '#a4acb9', '#8fbbca'][i],
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="dash-section specialization-section">
        <h2>SPECIALIZATION</h2>
        <div className="specialization-body">
          <div className="donut" style={{ background: `conic-gradient(${slices.join(',')})` }}>
            <div>
              <strong>{s.metrics.alive_households}</strong>
              <span>Households</span>
            </div>
          </div>
          <div className="role-legend">
            {roles.map(
              (n, i) =>
                n > 0 && (
                  <div key={i}>
                    <i style={{ background: roleColors[i] }} />
                    <span>{ROLES[i]}</span>
                    <b>{Math.round((n / total) * 100)}%</b>
                  </div>
                ),
            )}
          </div>
        </div>
      </div>
      <div className="dash-section events-section">
        <h2>
          <button onClick={onEvents}>
            EVENT FEED <ArrowUpRight size={13} />
          </button>
          <select
            aria-label="Filter events"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
          >
            {[
              'All events',
              'People',
              'Trade',
              'Production',
              'Health',
              'Specialization',
              'Scarcity',
            ].map((f) => (
              <option key={f}>{f}</option>
            ))}
          </select>
        </h2>
        <div className="event-list">
          {filtered.slice(0, 5).map((e, i) => (
            <button
              key={`${e.data.day}-${i}`}
              className="event-row"
              title={e.text}
              onClick={() => (e.households.length ? onSelect(e.households[0]) : onEvents())}
            >
              <EventIcon event={e} />
              <span>{e.text.replace(/^Day \d+ — /, '')}</span>
              <time>Day {e.data.day}</time>
            </button>
          ))}
          {!filtered.length && (
            <div className="quiet-empty">
              <Sprout size={24} />
              <span>
                {s.day
                  ? 'No events in this category yet.'
                  : 'A new world. Every story starts somewhere.'}
              </span>
            </div>
          )}
        </div>
        <div className="dashboard-footnote">
          {percent(s.metrics.spear_own_bp)} own tools <span>·</span> {s.total_marriages} marriages{' '}
          <span>·</span> {s.total_deaths} deaths
        </div>
      </div>
    </section>
  );
}
