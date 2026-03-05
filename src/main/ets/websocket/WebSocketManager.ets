import { SessionState, SDKConfig, ChatMessage } from '../types';
import { Logger } from '../utils/Logger';

interface WebSocketConnection {
  socket: WebSocket;
  sessionId: string;
  createdAt: number;
  lastActiveAt: number;
  reconnectCount: number;
}

export class WebSocketManager {
  private static instance: WebSocketManager;
  private connections: Map<string, WebSocketConnection> = new Map();
  private config: SDKConfig;
  private messageHandlers: Map<string, (data: string) => void> = new Map();
  private stateHandlers: Map<string, (state: SessionState) => void> = new Map();
  private logger: Logger;

  private constructor(config: SDKConfig) {
    this.config = config;
    this.logger = new Logger('WebSocketManager');
  }

  static getInstance(config?: SDKConfig): WebSocketManager {
    if (!WebSocketManager.instance) {
      if (!config) {
        throw new Error('WebSocketManager requires config on first initialization');
      }
      WebSocketManager.instance = new WebSocketManager(config);
    }
    return WebSocketManager.instance;
  }

  getConnectionCount(): number {
    return this.connections.size;
  }

  canCreateConnection(): boolean {
    return this.connections.size < this.config.maxConnections;
  }

  async createConnection(sessionId: string): Promise<void> {
    if (!this.canCreateConnection()) {
      this.logger.error(`Connection limit reached: ${this.config.maxConnections}`);
      throw new Error(`WebSocket connection limit exceeded (max: ${this.config.maxConnections})`);
    }

    if (this.connections.has(sessionId)) {
      this.logger.warn(`Connection already exists for session: ${sessionId}`);
      return;
    }

    const url = `${this.config.serverUrl}/ws?sessionId=${sessionId}`;
    const socket = new WebSocket(url);

    const connection: WebSocketConnection = {
      socket,
      sessionId,
      createdAt: Date.now(),
      lastActiveAt: Date.now(),
      reconnectCount: 0
    };

    this.connections.set(sessionId, connection);
    this.setupSocketHandlers(socket, sessionId);
    this.logger.info(`Connection created for session: ${sessionId}`);
  }

  private setupSocketHandlers(socket: WebSocket, sessionId: string): void {
    socket.onopen = () => {
      this.logger.info(`WebSocket opened for session: ${sessionId}`);
      this.updateState(sessionId, SessionState.CONNECTING);
    };

    socket.onmessage = (event) => {
      this.updateLastActive(sessionId);
      const handler = this.messageHandlers.get(sessionId);
      if (handler) {
        handler(event.data);
      }
    };

    socket.onerror = () => {
      this.logger.error(`WebSocket error for session: ${sessionId}`);
      this.updateState(sessionId, SessionState.ERROR);
    };

    socket.onclose = () => {
      this.logger.info(`WebSocket closed for session: ${sessionId}`);
      this.handleReconnect(sessionId);
    };
  }

  private handleReconnect(sessionId: string): void {
    const connection = this.connections.get(sessionId);
    if (!connection) {
      return;
    }

    if (connection.reconnectCount < this.config.reconnectAttempts) {
      connection.reconnectCount++;
      this.logger.info(`Reconnecting (${connection.reconnectCount}/${this.config.reconnectAttempts})`);
      
      setTimeout(() => {
        this.reconnect(sessionId);
      }, this.config.reconnectInterval * connection.reconnectCount);
    } else {
      this.logger.error('Max reconnect attempts reached');
      this.updateState(sessionId, SessionState.ERROR);
      this.connections.delete(sessionId);
    }
  }

  private reconnect(sessionId: string): void {
    const connection = this.connections.get(sessionId);
    if (!connection) {
      return;
    }

    const url = `${this.config.serverUrl}/ws?sessionId=${sessionId}`;
    const socket = new WebSocket(url);
    connection.socket = socket;
    connection.lastActiveAt = Date.now();
    this.setupSocketHandlers(socket, sessionId);
  }

  sendMessage(sessionId: string, data: any): Promise<void> {
    return new Promise((resolve, reject) => {
      const connection = this.connections.get(sessionId);
      if (!connection) {
        reject(new Error(`No connection found for session: ${sessionId}`));
        return;
      }

      if (connection.socket.readyState !== WebSocket.OPEN) {
        reject(new Error(`WebSocket not ready for session: ${sessionId}`));
        return;
      }

      connection.socket.send(JSON.stringify(data));
      this.updateLastActive(sessionId);
      this.logger.info(`Message sent to session: ${sessionId}`);
      resolve();
    });
  }

  closeConnection(sessionId: string): void {
    const connection = this.connections.get(sessionId);
    if (connection) {
      connection.socket.close();
      this.connections.delete(sessionId);
      this.messageHandlers.delete(sessionId);
      this.stateHandlers.delete(sessionId);
      this.logger.info(`Connection closed for session: ${sessionId}`);
    }
  }

  closeAllConnections(): void {
    for (const sessionId of this.connections.keys()) {
      this.closeConnection(sessionId);
    }
    this.logger.info('All connections closed');
  }

  onMessage(sessionId: string, handler: (data: string) => void): void {
    this.messageHandlers.set(sessionId, handler);
  }

  onStateChange(sessionId: string, handler: (state: SessionState) => void): void {
    this.stateHandlers.set(sessionId, handler);
  }

  private updateState(sessionId: string, state: SessionState): void {
    const handler = this.stateHandlers.get(sessionId);
    if (handler) {
      handler(state);
    }
  }

  private updateLastActive(sessionId: string): void {
    const connection = this.connections.get(sessionId);
    if (connection) {
      connection.lastActiveAt = Date.now();
    }
  }

  getConnection(sessionId: string): WebSocketConnection | undefined {
    return this.connections.get(sessionId);
  }

  getSessionIds(): string[] {
    return Array.from(this.connections.keys());
  }
}
