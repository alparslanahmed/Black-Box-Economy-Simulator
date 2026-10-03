import { X, Mountain } from 'lucide-react';
import type { Snapshot } from '../generated/protocol';
import { art, goodArt, quantity } from '../format';

export default function CellInspector({
  snapshot: s,
  index,
  onClose,
}: {
  snapshot: Snapshot;
  index: number;
  onClose: () => void;
}) {
  const cell = s.cells[index];
  if (!cell) return null;
  return (
    <aside className="inspector panel" aria-label="Selected resource cell">
      <div className="panel-heading">
        <h2>SELECTED TERRAIN</h2>
        <button className="icon-button" aria-label="Close terrain inspector" onClick={onClose}>
          <X size={17} />
        </button>
      </div>
      <div className="cell-heading">
        <Mountain size={24} />
        <div>
          <h3>{['Meadow', 'Forest', 'Rocky ground'][cell.terrain]}</h3>
          <p>
            Cell {index % s.config.map_w}, {Math.floor(index / s.config.map_w)}
          </p>
        </div>
      </div>
      <div className="inspector-content">
        <p className="subtle-copy">
          Local stock is shared by everyone who works here. Harvests and regeneration are resolved
          each day.
        </p>
        {['Berries', 'Game', 'Wood', 'Stone'].map((name, i) => (
          <div className="cell-resource" key={name}>
            <img src={art(goodArt[i])} alt="" />
            <div>
              <h4>
                {name}
                <b>{quantity(cell.stock[i], 2)}</b>
              </h4>
              <div className="flow-track">
                <i style={{ width: (cell.stock[i] / Math.max(1, cell.capacity[i])) * 100 + '%' }} />
              </div>
              <small>
                Capacity {quantity(cell.capacity[i])} · +{quantity(cell.regen[i], 3)} / day
              </small>
            </div>
          </div>
        ))}
        <p className="subtle-copy">
          Stone is finite. Berry regeneration follows your current experiment setting.
        </p>
      </div>
    </aside>
  );
}
