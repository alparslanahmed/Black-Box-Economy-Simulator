import {
  ArrowUpRight,
  Heart,
  Users,
  X,
  Footprints,
  Moon,
  Hammer,
  Home,
  Baby,
  ChevronRight,
  Crosshair,
} from 'lucide-react';
import { ACTIVITIES, GOODS } from '../generated/protocol';
import type { HouseholdView, PersonView, Snapshot } from '../generated/protocol';
import { art, goodArt, percent, quantity } from '../format';
import { EventIcon } from './Charts';

export default function Inspector({
  snapshot: s,
  household: h,
  person,
  tab,
  onTab,
  onClose,
  onPerson,
  onFocus,
}: {
  snapshot: Snapshot;
  household?: HouseholdView;
  person?: PersonView;
  tab: string;
  onTab: (tab: string) => void;
  onClose: () => void;
  onPerson: (id: number) => void;
  onFocus: () => void;
}) {
  if (!h)
    return (
      <aside className="inspector panel empty-inspector">
        <h2>OBSERVE THE WORLD</h2>
        <img src={art('hut-01')} alt="" />
        <p>Select a household or a person on the map to discover their story.</p>
      </aside>
    );
  const data = h.data;
  const members = s.people.filter((p) =>
    data.members.slice(0, data.member_count).includes(p.data.id),
  );
  const events = h.events;
  const decision = person?.data.last_decision ?? data.last_decision;
  return (
    <aside className="inspector panel" aria-label="Selected household">
      <div className="panel-heading">
        <h2>{person ? 'SELECTED PERSON' : 'SELECTED HOUSEHOLD'}</h2>
        <button className="icon-button" aria-label="Close inspector" onClick={onClose}>
          <X size={17} />
        </button>
      </div>
      <div className="household-card">
        <button
          className="household-portrait"
          onClick={onFocus}
          aria-label="Focus selected household"
        >
          <img
            src={art(
              person
                ? person.stage === 'child' || person.stage === 'infant'
                  ? 'person-child'
                  : person.data.sex === 0
                    ? 'person-man'
                    : 'person-woman'
                : `hut-0${data.hut_variant + 1}`,
            )}
            alt=""
          />
          <Crosshair size={14} />
        </button>
        <div className="household-summary">
          <h3>{person ? person.label : h.name}</h3>
          <p>{person ? `${person.stage} · ${h.name}` : h.role}</p>
          <div className="household-facts">
            <span>
              <Users size={21} />
              <b>
                {data.member_count}
                <small>Members</small>
              </b>
            </span>
            <span className={(person?.data.health ?? data.health) >= 7000 ? 'healthy' : 'hungry'}>
              <Heart size={21} />
              <b>
                {percent(person?.data.health ?? data.health)}
                <small>
                  {(person?.data.health ?? data.health) >= 7000 ? 'Healthy' : 'Needs care'}
                </small>
              </b>
            </span>
          </div>
        </div>
      </div>
      <div className="inspector-tabs" role="tablist">
        {['inventory', 'skills', 'trade', 'details'].map((t) => (
          <button key={t} role="tab" aria-selected={tab === t} onClick={() => onTab(t)}>
            {t}
          </button>
        ))}
      </div>
      <div className="inspector-content">
        {tab === 'inventory' && (
          <>
            <div className="inventory-grid">
              {[...GOODS, '', '', ''].map((good, i) => (
                <div
                  className={`inventory-slot ${good ? '' : 'empty'}`}
                  key={i}
                  title={
                    good
                      ? `${good}: ${quantity(data.inv.qty[i], 3)}${i === 4 ? ` · active condition ${data.spear_durability}/${s.config.spear_durability_max}` : ''}`
                      : undefined
                  }
                >
                  {good && (
                    <>
                      <img src={art(goodArt[i])} alt={good} />
                      <strong>{quantity(data.inv.qty[i])}</strong>
                    </>
                  )}
                </div>
              ))}
            </div>
            <div className="reserve-summary">
              <span>Food reserve</span>
              <strong>
                {quantity(h.food_days)} <small>days</small>
              </strong>
              <div>
                <i style={{ width: `${Math.min(100, h.food_days / 60)}%` }} />
              </div>
            </div>
            <div className="mini-facts">
              <span>
                Food / day <b>{quantity(h.daily_need)}</b>
              </span>
              <span>
                Fuel / day <b>{quantity(h.fuel_need, 2)}</b>
              </span>
            </div>
          </>
        )}
        {tab === 'skills' && (
          <div className="skill-list">
            {['Gathering', 'Hunting', 'Woodworking', 'Stone gathering', 'Crafting'].map(
              (skill, i) => (
                <div className="skill-row" key={skill}>
                  <span>
                    {skill}
                    <b>{((person?.data.skills ?? data.skills)[i] / 10000).toFixed(2)}×</b>
                  </span>
                  <div>
                    <i
                      style={{
                        width: `${((person?.data.skills ?? data.skills)[i] / s.config.skill_max) * 100}%`,
                      }}
                    />
                  </div>
                </div>
              ),
            )}
            <div className="mini-facts">
              <span>
                Risk preference <b>{percent(data.risk_preference)}</b>
              </span>
              <span>
                Trade openness <b>{percent(data.trade_openness)}</b>
              </span>
            </div>
            <p className="subtle-copy">
              Skills grow through practice. A specialization describes past work; it never assigns a
              profession.
            </p>
          </div>
        )}
        {tab === 'trade' && (
          <div className="trade-details">
            <h4>NEIGHBORS' OBSERVED DEMAND</h4>
            {GOODS.map((g, i) => (
              <div className="demand-row" key={g}>
                <img src={art(goodArt[i])} alt="" />
                <span>{g}</span>
                <b>{data.observed_demand[i]}</b>
              </div>
            ))}
            <h4>RECENT EXCHANGES</h4>
            {data.recent_trades
              .filter((r) => r.success && r.gave_qty > 0)
              .sort((a, b) => b.day - a.day)
              .slice(0, 4)
              .map((r, i) => (
                <div className="trade-detail-row" key={i}>
                  <span>
                    {quantity(r.gave_qty)} {GOODS[r.gave_good]} <ArrowUpRight size={12} />{' '}
                    {quantity(r.got_qty)} {GOODS[r.got_good]}
                  </span>
                  <small>
                    Household #{r.partner} · Day {r.day}
                  </small>
                </div>
              ))}
            {!data.recent_trades.some((r) => r.success) && (
              <p className="subtle-copy">
                No exchanges yet. A trade happens only when both households benefit.
              </p>
            )}
          </div>
        )}
        {tab === 'details' && (
          <div className="family-details">
            <h4>PEOPLE IN THIS HOUSEHOLD</h4>
            {members.map((p) => (
              <button
                key={p.data.id}
                className={`member-row ${person?.data.id === p.data.id ? 'selected' : ''}`}
                onClick={() => onPerson(p.data.id)}
              >
                <img
                  src={art(
                    p.stage === 'child' || p.stage === 'infant'
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
                <span>
                  {p.label}
                  <small>
                    {ACTIVITIES[p.data.intent_activity]}{' '}
                    {p.data.pregnant ? '· Expecting a child' : ''}
                  </small>
                </span>
                <ChevronRight size={13} />
              </button>
            ))}
            {person && (
              <>
                <h4>DAILY TIME BUDGET</h4>
                <div className="time-budget">
                  {[
                    [Moon, 'Sleep', person.data.minutes_sleep],
                    [Home, 'Home', person.data.minutes_home],
                    [Footprints, 'Travel', person.data.minutes_travel],
                    [Hammer, 'Work', person.data.minutes_work],
                    [Users, 'Visit', person.data.minutes_visit],
                  ].map(([Icon, label, value]) => {
                    const I = Icon as typeof Moon;
                    return (
                      <span key={String(label)}>
                        <I size={14} />
                        {String(label)}
                        <b>{Number(value)}m</b>
                      </span>
                    );
                  })}
                </div>
                <p className="subtle-copy">
                  Constitution {percent(person.data.constitution)} · Father #{person.data.father_id}{' '}
                  · Mother #{person.data.mother_id}
                  {person.data.spouse_id >= 0 && ` · Spouse #${person.data.spouse_id}`}
                </p>
                {person.data.pregnant && (
                  <p className="pregnancy">
                    <Baby size={16} /> Pregnancy day {person.data.pregnancy_days} of{' '}
                    {s.config.pregnancy_days}
                  </p>
                )}
              </>
            )}
          </div>
        )}
        <section className="recent-activity">
          <h4>{tab === 'skills' ? 'WHY THIS ACTIVITY?' : 'RECENT ACTIVITY'}</h4>
          {tab === 'skills' ? (
            <div className="decision-list">
              {decision.candidates.slice(0, decision.candidate_count).map((c, i) => (
                <details key={i} className={decision.chosen_index === i ? 'chosen' : ''}>
                  <summary>
                    <span>{ACTIVITIES[c.activity]}</span>
                    <b>{c.feasible ? c.total_score.toLocaleString() : 'Unavailable'}</b>
                  </summary>
                  <div>
                    {Object.entries({
                      Food: c.food_need,
                      Fuel: c.fuel_need,
                      Tools: c.tool,
                      Inputs: c.input,
                      Demand: c.trade_demand,
                      Skill: c.skill,
                      Travel: c.travel,
                      Risk: c.risk,
                    }).map(([key, n]) => (
                      <span key={key}>
                        {key}
                        <b>{n}</b>
                      </span>
                    ))}
                  </div>
                </details>
              ))}
            </div>
          ) : (
            <>
              {events.slice(0, 4).map((e, i) => (
                <div className="activity-item" key={i}>
                  <EventIcon event={e} />
                  <p>
                    {e.text.replace(/^Day \d+ — (Household \d+ )?/, '')}
                    <small>Day {e.data.day}</small>
                  </p>
                </div>
              ))}
              {events.length === 0 && (
                <p className="subtle-copy">The household is ready for a new day.</p>
              )}
            </>
          )}
        </section>
      </div>
    </aside>
  );
}
