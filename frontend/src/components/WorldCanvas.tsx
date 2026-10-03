import { useEffect, useRef, useState } from 'react';
import { WorldRenderer } from '../world/WorldRenderer';
import type { Snapshot, ViewState } from '../generated/protocol';

export default function WorldCanvas({
  snapshot,
  view,
  onHousehold,
  onPerson,
  onCell,
  onCamera,
  rendererRef,
}: {
  snapshot: Snapshot;
  view: ViewState;
  onHousehold: (id: number) => void;
  onPerson: (id: number) => void;
  onCell: (index: number) => void;
  onCamera: (v: Pick<ViewState, 'camera_x' | 'camera_y' | 'zoom'>) => void;
  rendererRef: React.RefObject<WorldRenderer | null>;
}) {
  const host = useRef<HTMLDivElement>(null);
  const callbacks = useRef({ onHousehold, onPerson, onCell, onCamera });
  callbacks.current = { onHousehold, onPerson, onCell, onCamera };
  const [hover, setHover] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const renderer = new WorldRenderer(host.current!, {
      cell: (i) => callbacks.current.onCell(i),
      household: (id) => callbacks.current.onHousehold(id),
      person: (id) => callbacks.current.onPerson(id),
      camera: (v) => callbacks.current.onCamera(v),
      hover: setHover,
      error: setError,
    });
    rendererRef.current = renderer;
    let live = true;
    renderer
      .init()
      .then(() => {
        if (live) setLoading(false);
      })
      .catch((err) => {
        if (live) {
          setLoading(false);
          setError(`World renderer: ${String(err)}`);
        }
      });
    return () => {
      live = false;
      renderer.destroy();
      rendererRef.current = null;
    };
  }, [rendererRef]);
  useEffect(() => {
    rendererRef.current?.update(snapshot, view);
  }, [snapshot, view, rendererRef]);
  return (
    <>
      <div className="world-canvas" ref={host} />
      {hover && <div className="world-tooltip">{hover}</div>}
      {loading && (
        <div className="world-loading">
          <span className="loading-ring" />
          Painting the world…
        </div>
      )}
      {error && <div className="world-error">{error}</div>}
    </>
  );
}
