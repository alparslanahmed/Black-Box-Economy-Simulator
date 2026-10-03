import { useState } from 'react';
import type { DayMetrics, HistoryPage, Snapshot } from '../generated/protocol';
import { GOODS, ROLES } from '../generated/protocol';
import type { CommandInput } from '../useGame';
import { percent } from '../format';

type Series = { name: string; color: string; values: (number | null)[] };
const colors = ['#91ca76', '#de9762', '#7bb8da', '#bba0d6', '#ceb86f', '#a7bab6'];
function Plot({ rows, series, title }: { rows: DayMetrics[]; series: Series[]; title: string }) {
  const values = series.flatMap((s) => s.values).filter((n): n is number => n !== null);
  const max = Math.max(1, ...values),
    min = Math.min(0, ...values),
    span = Math.max(0.001, max - min);
  const x = (i: number) => 40 + (i / Math.max(1, rows.length - 1)) * 430;
  const y = (v: number) => 150 - ((v - min) / span) * 125;
  return (
    <article className="analysis-plot">
      <h3>{title}</h3>
      <div className="chart-legend">
        {series.map((s) => (
          <span key={s.name}>
            <i style={{ background: s.color }} />
            {s.name}
          </span>
        ))}
      </div>
      <svg viewBox="0 0 490 176" role="img" aria-label={title}>
        {[0, 0.5, 1].map((t) => (
          <g key={t}>
            <line x1="40" x2="470" y1={y(min + span * t)} y2={y(min + span * t)} stroke="#34454d" />
            <text x="32" y={y(min + span * t) + 4} textAnchor="end">
              {(min + span * t).toLocaleString(undefined, { maximumFractionDigits: 1 })}
            </text>
          </g>
        ))}
        {series.map((s) => {
          let open = false;
          const d = s.values
            .map((v, i) => {
              if (v === null) {
                open = false;
                return '';
              }
              const prefix = open ? 'L' : 'M';
              open = true;
              return prefix + x(i) + ' ' + y(v);
            })
            .join(' ');
          return <path key={s.name} d={d} fill="none" stroke={s.color} strokeWidth="1.7" />;
        })}
        {[0, 0.5, 1].map((t) => (
          <text key={t} x={40 + 430 * t} y="170" textAnchor="middle">
            {rows.length
              ? Math.round(rows[0].day + (rows[rows.length - 1].day - rows[0].day) * t)
              : 0}
          </text>
        ))}
        {!rows.length && (
          <text x="250" y="90" textAnchor="middle">
            Advance a day to begin
          </text>
        )}
      </svg>
    </article>
  );
}

export default function Analytics({
  snapshot: s,
  history,
  send,
}: {
  snapshot: Snapshot;
  history?: HistoryPage;
  send: (c: CommandInput) => void;
}) {
  const [tab, setTab] = useState('Overview');
  const [enabled, setEnabled] = useState([true, true, true, true, true]);
  const rows = history?.items ?? s.history;
  const series = (name: string, read: (m: DayMetrics) => number | null, index = 0): Series => ({
    name,
    color: colors[index % colors.length],
    values: rows.map(read),
  });
  const single = (title: string, read: (m: DayMetrics) => number | null, index = 0) => (
    <Plot key={title} rows={rows} title={title} series={[series(title, read, index)]} />
  );
  return (
    <>
      <div className="analytics-tabs" role="tablist" aria-label="Analytics categories">
        {['Overview', 'Production', 'Trade', 'Barter ratios', 'Specialization', 'People'].map(
          (t) => (
            <button key={t} role="tab" aria-selected={t === tab} onClick={() => setTab(t)}>
              {t}
            </button>
          ),
        )}
      </div>
      <div className="analytics-grid">
        {tab === 'Overview' && (
          <>
            {single('Living people', (m) => m.alive)}
            {single('Food reserve · days', (m) => m.food_days_avg_milli / 1000, 1)}
            {single('Median health · %', (m) => m.median_health / 100, 2)}
          </>
        )}
        {tab === 'Production' && (
          <>
            <div className="series-toggles">
              {GOODS.map((g, i) => (
                <label key={g}>
                  <input
                    type="checkbox"
                    checked={enabled[i]}
                    onChange={() => setEnabled((v) => v.map((on, j) => (j === i ? !on : on)))}
                  />
                  {g}
                </label>
              ))}
            </div>
            <Plot
              title="Goods produced per day · physical units"
              rows={rows}
              series={GOODS.map((g, i) => series(g, (m) => m.produced[i] / 1000, i)).filter(
                (_, i) => enabled[i],
              )}
            />
            {single('Food spoiled · units', (m) => m.food_spoiled / 1000, 1)}
          </>
        )}
        {tab === 'Trade' && (
          <>
            {single('Attempts / day', (m) => m.trade_attempts)}
            {single('Successful barters / day', (m) => m.successful_trades, 1)}
            {single('Success rate · %', (m) => m.trade_success_bp / 100, 2)}
            <div className="statistics-row">
              <span>
                No double coincidence <b>{s.metrics.fail_no_dc}</b>
              </span>
              <span>
                No mutual gain <b>{s.metrics.fail_no_gain}</b>
              </span>
              <span>
                Inventory shortfall <b>{s.metrics.fail_inv}</b>
              </span>
            </div>
          </>
        )}
        {tab === 'Barter ratios' && (
          <>
            <p className="explainer">
              Direct observed medians in berry units. Gaps mean there was no observed direct
              exchange. Households never see these global statistics.
            </p>
            {GOODS.slice(1).map((g, i) =>
              single(
                'Berries per ' + g,
                (m) => (m.berries_per_unit[i + 1] < 0 ? null : m.berries_per_unit[i + 1] / 1000),
                i,
              ),
            )}
          </>
        )}
        {tab === 'Specialization' && (
          <>
            {single('Average labor concentration · %', (m) => m.spec_avg_bp / 100)}
            <Plot
              rows={rows}
              title="Households by inferred role"
              series={ROLES.map((r, i) => series(r, (m) => m.role_counts[i], i))}
            />
            <Plot
              rows={rows}
              title="Average skills · multiplier"
              series={['Gathering', 'Hunting', 'Woodworking', 'Stone', 'Crafting'].map((r, i) =>
                series(r, (m) => m.avg_skill[i] / 10000, i),
              )}
            />
            {single('Households with a spear · %', (m) => m.spear_own_bp / 100, 4)}
          </>
        )}
        {tab === 'People' && (
          <>
            {single('Living people', (m) => m.alive)}
            {single('Births / day', (m) => m.births, 1)}
            {single('Deaths / day', (m) => m.deaths, 2)}
            {single('Marriages / day', (m) => m.marriages, 3)}
            {single('Crude birth rate · per 1000 / year', (m) => m.cbr_milli / 1000, 4)}
            {single('Fertility estimate · children / woman', (m) => m.tfr_milli / 1000)}
            {single('Unmarried eligible people · %', (m) => m.unmarried_marriageable_bp / 100, 2)}
            <div className="statistics-row">
              <span>
                Unmarried{' '}
                <b>
                  {s.metrics.unmarried} ({percent(s.metrics.unmarried_bp)})
                </b>
              </span>
              <span>
                Fertile women <b>{s.metrics.fertile_women}</b>
              </span>
              <span>
                Birth rate window <b>{s.metrics.birth_rate_days} days</b>
              </span>
            </div>
          </>
        )}
      </div>
      <div className="archive-pagination">
        <button className="secondary-button" onClick={() => send({ type: 'history' })}>
          Refresh latest history
        </button>
        <span>
          {rows.length} days · {rows[0]?.day ?? 0}–{rows.at(-1)?.day ?? 0}
        </span>
        <button
          className="secondary-button"
          disabled={!history?.has_more}
          onClick={() => send({ type: 'history', before: history?.before })}
        >
          Earlier days →
        </button>
      </div>
    </>
  );
}
