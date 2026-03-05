import webSocket from '@ohos.net.webSocket';
import {
  SkillConfig,
  SkillMessage,
  SessionState,
  MessageListener,
  ConnectionState,
  ConnectionInfo,
  SessionStatus,
  SkillErrorCode,
  DEFAULT_CONFIG
} from '../types/index';
import { Logger } from '../utils/Logger';

const TAG = 'WebSocketManager';

export class WebSocketManager {
  private static instance: WebSocketManager | null = null;
  private static connectionCount: number = 0;

  private socket: webSocket.WebSocket | null = null;
  private config: SkillConfig | null = null;
  private listener: MessageListener | null = null;
  private state: SessionState = {
    status: 'idle',
    groupId: '',
    messageCount: 0,
    lastUpdateTime: Date.now()
  };
  private isConnecting: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = DEFAULT_CONFIG.MAX_RETRIES;
  private reconnectInterval: number = DEFAULT_CONFIG.RECONNECT_INTERVAL;
  private maxConnections: number = DEFAULT_CONFIG.MAX_CONNECTIONS;
  private connectionId: string = '';
  private connections: Map<string, ConnectionInfo> = new Map();
  private heartbeatTimer: number = -1;
  private heartbeatInterval: number = 30000;

  private constructor() {
    this.connectionId = this.generateConnectionId();
  }

  static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  static resetInstance(): void {
    if (WebSocketManager.instance) {
      WebSocketManager.instance.close();
      WebSocketManager.instance = null;
    }
  }

  setConfig(config: SkillConfig): void {
    this.config = config;
    this.maxReconnectAttempts = config.maxRetries ?? DEFAULT_CONFIG.MAX_RETRIES;
    this.maxConnections = config.maxConnections ?? DEFAULT_CONFIG.MAX_CONNECTIONS;
    this.reconnectInterval = config.reconnectInterval ?? DEFAULT_CONFIG.RECONNECT_INTERVAL;
  }

  setListener(listener: MessageListener): void {
    this.listener = listener;
  }

  getConnectionState(): ConnectionState {
    const connectionArray: ConnectionInfo[] = [];
    this.connections.forEach((info) => {
      connectionArray.push(info);
    });

    return {
      connectionCount: WebSocketManager.connectionCount,
      maxConnections: this.maxConnections,
      availableSlots: this.maxConnections - WebSocketManager.connectionCount,
      connections: connectionArray
    };
  }

  canCreateConnection(): boolean {
    return WebSocketManager.connectionCount < this.maxConnections;
  }

  async connect(): Promise<void> {
    if (!this.config) {
      throw new Error('Config not set');
    }

    if (!this.canCreateConnection()) {
      const state = this.getConnectionState();
      throw new Error(`Connection limit reached: ${state.connectionCount}/${state.maxConnections}`);
    }

    if (this.isConnecting) {
      throw new Error('WebSocket is already connecting');
    }

    if (this.socket && this.state.status === 'executing') {
      Logger.info(TAG, 'WebSocket already connected');
      return;
    }

    this.isConnecting = true;
    this.updateState('executing');

    try {
      this.socket = webSocket.createWebSocket();

      this.socket.on('open', (err: Error, value: Object) => {
        if (err) {
          Logger.error(TAG, `WebSocket open error: ${err.message}`);
          this.handleConnectionError(err);
          return;
        }
        Logger.info(TAG, 'WebSocket opened');
        this.isConnecting = false;
        WebSocketManager.connectionCount++;
        this.connectionId = this.generateConnectionId();
        this.connections.set(this.connectionId, {
          connectionId: this.connectionId,
          groupId: this.config?.groupId ?? '',
          createdAt: Date.now(),
          status: 'active'
        });
        this.updateState('executing');
        this.startHeartbeat();
        this.listener?.onStateChange?.(this.state);
      });

      this.socket.on('message', (err: Error, value: webSocket.Message) => {
        if (err) {
          Logger.error(TAG, `Message error: ${err.message}`);
          return;
        }
        Logger.info(TAG, 'Received message');
        this.handleMessage(value);
      });

      this.socket.on('close', (err: Error, value: webSocket.CloseResult) => {
        Logger.info(TAG, `WebSocket closed: ${value?.code}, ${value?.reason}`);
        this.isConnecting = false;
        this.stopHeartbeat();
        WebSocketManager.connectionCount = Math.max(0, WebSocketManager.connectionCount - 1);
        this.connections.delete(this.connectionId);
        this.socket = null;
        if (this.state.status === 'executing') {
          this.updateState('completed');
          this.listener?.onStateChange?.(this.state);
          this.listener?.onComplete?.();
        }
      });

      this.socket.on('error', (err: Error) => {
        Logger.error(TAG, `WebSocket error: ${err.message}`);
        this.handleConnectionError(err);
      });

      const headerMap: Record<string, string> = {};
      if (this.config.headers) {
        Object.keys(this.config.headers).forEach(key => {
          headerMap[key] = this.config!.headers![key];
        });
      }

      await this.socket.connect(this.config.serverUrl, {
        header: headerMap,
        protocol: this.config.protocol ? [this.config.protocol] : undefined
      });

    } catch (error) {
      this.isConnecting = false;
      this.updateState('error', undefined, (error as Error).message);
      throw error;
    }
  }

  private handleConnectionError(err: Error): void {
    this.isConnecting = false;
    this.stopHeartbeat();
    WebSocketManager.connectionCount = Math.max(0, WebSocketManager.connectionCount - 1);
    this.connections.delete(this.connectionId);
    this.updateState('error', undefined, err.message);
    this.listener?.onError?.(err);
    this.listener?.onStateChange?.(this.state);
    this.attemptReconnect();
  }

  private handleMessage(data: webSocket.Message): void {
    try {
      let content: string;
      if (typeof data === 'string') {
        content = data;
      } else if (data instanceof ArrayBuffer) {
        content = new TextDecoder().decode(data);
      } else {
        Logger.error(TAG, 'Unsupported message type');
        return;
      }

      const parsed = JSON.parse(content);

      const message: SkillMessage = {
        id: parsed.id || Date.now().toString(),
        role: parsed.role || 'assistant',
        content: parsed.content || '',
        timestamp: parsed.timestamp || Date.now(),
        type: parsed.type || 'text',
        metadata: parsed.metadata,
        isComplete: parsed.isComplete ?? true,
        errorCode: parsed.errorCode,
        errorMessage: parsed.errorMessage
      };

      this.state.messageCount++;
      this.state.lastUpdateTime = Date.now();
      this.listener?.onMessage(message);
      this.listener?.onStateChange?.(this.state);

      if (message.isComplete) {
        this.updateState('completed');
        this.listener?.onComplete?.();
      }
    } catch (error) {
      Logger.error(TAG, `Failed to parse message: ${(error as Error).message}`);
    }
  }

  async send(message: string): Promise<void> {
    if (!this.socket) {
      throw new Error('WebSocket not connected');
    }

    try {
      await this.socket.send(message);
    } catch (error) {
      Logger.error(TAG, `Send failed: ${(error as Error).message}`);
      throw error;
    }
  }

  close(): void {
    this.stopHeartbeat();
    if (this.socket) {
      this.socket.close((err: Error) => {
        if (err) {
          Logger.error(TAG, `Close error: ${err.message}`);
        }
      });
      this.socket = null;
      WebSocketManager.connectionCount = Math.max(0, WebSocketManager.connectionCount - 1);
      this.connections.delete(this.connectionId);
      this.updateState('idle');
      this.listener?.onStateChange?.(this.state);
    }
  }

  getState(): SessionState {
    return { ...this.state };
  }

  private updateState(status: SessionStatus, sessionId?: string, errorMessage?: string): void {
    this.state = {
      ...this.state,
      status,
      sessionId: sessionId || this.state.sessionId,
      groupId: this.config?.groupId || '',
      lastUpdateTime: Date.now(),
      connectionId: this.connectionId,
      errorCode: status === 'error' ? SkillErrorCode.UNKNOWN_ERROR : undefined,
      errorMessage
    };
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts && this.state.status !== 'stopped') {
      this.reconnectAttempts++;
      const delay = this.reconnectInterval * Math.pow(2, this.reconnectAttempts - 1);
      Logger.info(TAG, `Attempting reconnect ${this.reconnectAttempts}/${this.maxReconnectAttempts} in ${delay}ms`);

      setTimeout(() => {
        this.connect().catch((err) => {
          Logger.error(TAG, `Reconnect failed: ${err.message}`);
        });
      }, delay);
    }
  }

  resetReconnectAttempts(): void {
    this.reconnectAttempts = 0;
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.socket && this.state.status === 'executing') {
        const ping = JSON.stringify({ type: 'ping', timestamp: Date.now() });
        this.send(ping).catch((err) => {
          Logger.error(TAG, `Heartbeat failed: ${err.message}`);
        });
      }
    }, this.heartbeatInterval);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== -1) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = -1;
    }
  }

  private generateConnectionId(): string {
    return `conn_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  async sendRaw(data: string | ArrayBuffer): Promise<void> {
    if (!this.socket) {
      throw new Error('WebSocket not connected');
    }
    await this.socket.send(data);
  }

  isConnected(): boolean {
    return this.socket !== null && this.state.status === 'executing';
  }
}
