import webSocket from '@ohos.net.websocket';
import { SkillConfig, SkillMessage, SessionState, MessageListener } from '../types/index';
import { Logger } from '../utils/Logger';

const TAG = 'WebSocketManager';

export class WebSocketManager {
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
  private maxReconnectAttempts: number = 3;
  private reconnectInterval: number = 3000;

  constructor(config: SkillConfig) {
    this.config = config;
    this.maxReconnectAttempts = config.maxRetries || 3;
  }

  setListener(listener: MessageListener): void {
    this.listener = listener;
  }

  async connect(): Promise<void> {
    if (!this.config || this.isConnecting) {
      throw new Error('WebSocket is connecting or config is null');
    }

    if (this.socket && this.state.status === 'executing') {
      Logger.info(TAG, 'WebSocket already connected');
      return;
    }

    this.isConnecting = true;
    this.updateState('executing');

    try {
      const socketTask = await webSocket.createWebSocket();
      
      socketTask.on('open', () => {
        Logger.info(TAG, 'WebSocket opened');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.socket = socketTask;
        this.updateState('executing');
        this.listener?.onStateChange?.(this.state);
      });

      socketTask.on('message', (data: string | ArrayBuffer) => {
        Logger.info(TAG, 'Received message');
        this.handleMessage(data);
      });

      socketTask.on('close', (code: number, reason: string) => {
        Logger.info(TAG, `WebSocket closed: ${code}, ${reason}`);
        this.isConnecting = false;
        this.socket = null;
        if (this.state.status === 'executing') {
          this.updateState('completed');
          this.listener?.onStateChange?.(this.state);
        }
      });

      socketTask.on('error', (err: Error) => {
        Logger.error(TAG, `WebSocket error: ${err.message}`);
        this.isConnecting = false;
        this.updateState('error', undefined, err.message);
        this.listener?.onError?.(err);
        this.listener?.onStateChange?.(this.state);
        this.attemptReconnect();
      });

      await socketTask.connect(this.config.serverUrl);
    } catch (error) {
      this.isConnecting = false;
      this.updateState('error', undefined, (error as Error).message);
      throw error;
    }
  }

  private handleMessage(data: string | ArrayBuffer): void {
    try {
      const content = typeof data === 'string' ? data : new TextDecoder().decode(data as ArrayBuffer);
      const parsed = JSON.parse(content);
      
      const message: SkillMessage = {
        id: parsed.id || Date.now().toString(),
        role: parsed.role || 'assistant',
        content: parsed.content || '',
        timestamp: parsed.timestamp || Date.now(),
        type: parsed.type || 'text',
        metadata: parsed.metadata
      };

      this.state.messageCount++;
      this.state.lastUpdateTime = Date.now();
      this.listener?.onMessage(message);
      this.listener?.onStateChange?.(this.state);
    } catch (error) {
      Logger.error(TAG, `Failed to parse message: ${(error as Error).message}`);
    }
  }

  send(message: string): Promise<void> {
    if (!this.socket) {
      throw new Error('WebSocket not connected');
    }

    return this.socket.send(message);
  }

  close(): void {
    if (this.socket) {
      this.socket.close();
      this.socket = null;
      this.updateState('idle');
      this.listener?.onStateChange?.(this.state);
    }
  }

  getState(): SessionState {
    return this.state;
  }

  private updateState(status: SessionState['status'], sessionId?: string, errorMessage?: string): void {
    this.state = {
      ...this.state,
      status,
      sessionId: sessionId || this.state.sessionId,
      groupId: this.config?.groupId || '',
      lastUpdateTime: Date.now(),
      errorCode: status === 'error' ? -1 : undefined,
      errorMessage
    };
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts && this.state.status !== 'stopped') {
      this.reconnectAttempts++;
      Logger.info(TAG, `Attempting reconnect ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
      
      setTimeout(() => {
        this.connect().catch(() => {
          Logger.error(TAG, 'Reconnect failed');
        });
      }, this.reconnectInterval);
    }
  }
}
