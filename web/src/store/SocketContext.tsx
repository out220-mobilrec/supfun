import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuth } from './AuthContext';
import { getToken } from '../lib/api';

interface PresenceEvent {
  userId: string;
  online: boolean;
  at: string;
}
interface PresenceList {
  ok: boolean;
  online: string[];
  self: string;
}

interface SocketContextValue {
  socket: Socket | null;
  connected: boolean;
  onlineUsers: Record<string, boolean>;
  seedOnline: (ids: string[]) => void;
}

const SocketContext = createContext<SocketContextValue | null>(null);

export function SocketProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const socketRef = useRef<Socket | null>(null);
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  const [onlineUsers, setOnlineUsers] = useState<Record<string, boolean>>({});

  useEffect(() => {
    const token = getToken();
    if (!token) return;

    let s: Socket | null = null;
    // Defer creation so React 18 StrictMode's mount/unmount/mount cycle in dev
    // does not open a first WebSocket that is immediately aborted (which makes
    // the Vite proxy log "ws proxy socket error: ECONNABORTED").
    const timer = setTimeout(() => {
      s = io('/chat', {
        path: '/socket.io',
        auth: { token },
        transports: ['websocket', 'polling'],
      });
      socketRef.current = s;
      setSocket(s);

      s.on('connect', () => {
        setConnected(true);
        s?.emit('presence:list', (res: PresenceList) => {
          if (res?.ok) setOnlineUsers(Object.fromEntries(res.online.map((id) => [id, true])));
        });
      });
      s.on('disconnect', () => setConnected(false));
      s.on('connect_error', () => setConnected(false));
      s.on('presence:change', (p: PresenceEvent) => {
        setOnlineUsers((prev) => ({ ...prev, [p.userId]: p.online }));
      });
    }, 0);

    return () => {
      clearTimeout(timer);
      s?.disconnect();
      socketRef.current = null;
      setSocket(null);
      setConnected(false);
      setOnlineUsers({});
    };
  }, [user]);

  const seedOnline = useCallback((ids: string[]) => {
    setOnlineUsers((prev) => {
      const next = { ...prev };
      for (const id of ids) next[id] = true;
      return next;
    });
  }, []);

  return (
    <SocketContext.Provider value={{ socket, connected, onlineUsers, seedOnline }}>
      {children}
    </SocketContext.Provider>
  );
}

export function useSocket(): SocketContextValue {
  const ctx = useContext(SocketContext);
  if (!ctx) throw new Error('useSocket must be used within SocketProvider');
  return ctx;
}

export function useSocketEvent<T>(event: string, handler: (payload: T) => void): void {
  const { socket } = useSocket();
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  useEffect(() => {
    if (!socket) return;
    const cb = (payload: T) => handlerRef.current(payload);
    socket.on(event, cb);
    return () => {
      socket.off(event, cb);
    };
  }, [socket, event]);
}