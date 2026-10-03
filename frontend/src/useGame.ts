import { useCallback, useEffect, useRef, useState } from 'react';
import { PROTOCOL_VERSION } from './generated/protocol';
import type {
  Command,
  Message,
  Snapshot,
  WorldSummary,
  EventPage,
  HistoryPage,
} from './generated/protocol';

export type CommandInput = Omit<Command, 'request_id'>;

// No simulation runs in the browser. Reconnection obtains the committed world;
// commands with uncertain outcomes are retried with the same idempotency key.
export function useGame() {
  const [snapshot, setSnapshot] = useState<Snapshot>();
  const [connected, setConnected] = useState(false);
  const [error, setError] = useState('');
  const [worlds, setWorlds] = useState<WorldSummary[]>([]);
  const [eventPage, setEventPage] = useState<EventPage>();
  const [history, setHistory] = useState<HistoryPage>();
  const socket = useRef<WebSocket | null>(null);
  const pending = useRef(new Map<string, Command>());
  const latest = useRef<Snapshot | undefined>(undefined);

  useEffect(() => {
    let stopped = false;
    let retry = 0;
    let timer: ReturnType<typeof setTimeout>;
    const connect = () => {
      if (stopped) return;
      const ws = new WebSocket(
        `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws`,
      );
      socket.current = ws;
      ws.onopen = () => {
        if (stopped) {
          ws.close();
          return;
        }
        retry = 0;
        setConnected(true);
        setError('');
        for (const command of pending.current.values()) ws.send(JSON.stringify(command));
      };
      ws.onmessage = ({ data }) => {
        try {
          const message: Message = JSON.parse(data);
          if (message.version !== PROTOCOL_VERSION)
            throw new Error(
              'The server and interface versions do not match. Refresh after updating.',
            );
          if (message.request_id) pending.current.delete(message.request_id);
          switch (message.type) {
            case 'snapshot':
              if (
                !message.snapshot ||
                !Array.isArray(message.snapshot.households) ||
                !Array.isArray(message.snapshot.cells)
              )
                throw new Error('Invalid world snapshot');
              if (latest.current?.world_id !== message.snapshot.world_id) {
                setHistory(undefined);
                setEventPage(undefined);
              }
              latest.current = message.snapshot;
              setSnapshot(message.snapshot);
              break;
            case 'history':
              setHistory(message.history);
              break;
            case 'events':
              setEventPage(message.events);
              break;
            case 'worlds':
              setWorlds(message.worlds ?? []);
              break;
            case 'error':
              setError(message.error ?? 'The command could not be completed.');
              break;
            case 'csv': {
              const url = URL.createObjectURL(
                new Blob([message.csv ?? ''], { type: 'text/csv;charset=utf-8' }),
              );
              const a = document.createElement('a');
              a.href = url;
              a.download = `blackbox-${latest.current?.seed ?? 'world'}-day-${latest.current?.day ?? 0}.csv`;
              a.click();
              setTimeout(() => URL.revokeObjectURL(url), 1000);
              break;
            }
          }
        } catch (cause) {
          setError(cause instanceof Error ? cause.message : 'Could not read the server response.');
        }
      };
      ws.onclose = () => {
        if (stopped) return;
        setConnected(false);
        timer = setTimeout(connect, Math.min(500 * 2 ** retry++, 8000));
      };
      ws.onerror = () => ws.close();
    };
    connect();
    return () => {
      stopped = true;
      clearTimeout(timer);
      socket.current?.close();
    };
  }, []);

  const send = useCallback((input: CommandInput) => {
    if (socket.current?.readyState !== WebSocket.OPEN) {
      setError('Reconnecting to the world. Your last committed progress is saved.');
      return;
    }
    const command: Command = {
      world_id: latest.current?.world_id,
      ...input,
      request_id: crypto.randomUUID(),
    };
    pending.current.set(command.request_id, command);
    socket.current.send(JSON.stringify(command));
  }, []);

  return {
    snapshot,
    connected,
    error,
    clearError: () => setError(''),
    worlds,
    eventPage,
    history,
    send,
  };
}
