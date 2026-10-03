import { useEffect, useRef } from 'react';
import { Expand, ChevronUp } from 'lucide-react';
import type { Snapshot } from '../generated/protocol';

export default function Minimap({
  snapshot: s,
  selected,
  onNavigate,
  onFit,
}: {
  snapshot: Snapshot;
  selected: number;
  onNavigate: (x: number, y: number) => void;
  onFit: () => void;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current!,
      ctx = canvas.getContext('2d')!;
    const size = 240;
    canvas.width = size;
    canvas.height = 152;
    ctx.fillStyle = '#101e25';
    ctx.fillRect(0, 0, size, 152);
    const scale = Math.min(210 / s.config.map_w, 125 / s.config.map_h),
      ox = (size - s.config.map_w * scale) / 2,
      oy = (152 - s.config.map_h * scale) / 2;
    s.cells.forEach((c, i) => {
      ctx.fillStyle = ['#656f43', '#2b4839', '#84816b'][c.terrain];
      ctx.fillRect(
        ox + (i % s.config.map_w) * scale,
        oy + Math.floor(i / s.config.map_w) * scale,
        scale + 0.3,
        scale + 0.3,
      );
    });
    ctx.strokeStyle = '#c6bf8b';
    ctx.lineWidth = 0.7;
    ctx.strokeRect(ox, oy, s.config.map_w * scale, s.config.map_h * scale);
    s.households.forEach((h) => {
      ctx.fillStyle = h.data.id === selected ? '#fff6bf' : '#e2b76b';
      ctx.beginPath();
      ctx.arc(
        ox + h.data.home.x * scale,
        oy + h.data.home.y * scale,
        h.data.id === selected ? 3 : 1.3,
        0,
        Math.PI * 2,
      );
      ctx.fill();
    });
  }, [s, selected]);
  return (
    <div className="minimap panel">
      <button
        className="minimap-map"
        aria-label="Navigate world map"
        onClick={(e) => {
          const rect = ref.current!.getBoundingClientRect();
          const px = ((e.clientX - rect.left) / rect.width) * 240,
            py = ((e.clientY - rect.top) / rect.height) * 152;
          const scale = Math.min(210 / s.config.map_w, 125 / s.config.map_h),
            ox = (240 - s.config.map_w * scale) / 2,
            oy = (152 - s.config.map_h * scale) / 2;
          onNavigate(
            Math.max(0, Math.min(s.config.map_w - 1, (px - ox) / scale)),
            Math.max(0, Math.min(s.config.map_h - 1, (py - oy) / scale)),
          );
        }}
      >
        <canvas ref={ref} />
      </button>
      <div>
        <span>
          World View <ChevronUp size={12} />
        </span>
        <button className="icon-button" aria-label="Fit entire world" onClick={onFit}>
          <Expand size={13} />
        </button>
      </div>
    </div>
  );
}
