import { SessionState, SDKConfig, SessionRequest, ChatMessage, SessionStateCallback, MessageCallback, RetryOptions, StopOptions, SkillInstruction, UserInput, GroupInfo } from '../types';
import { WebSocketManager } from '../websocket/WebSocketManager';
import { StorageManager } from '../storage/StorageManager';
import { Logger } from '../utils/Logger';

interface SessionInfo {
  sessionId: string;
  skillId: string;
  state: SessionState;
  userInput?: UserInput;
  groupInfo?: GroupInfo;
  messages: ChatMessage[];
  createdAt: number;
  updatedAt: number;
}

export class SessionManager {
  private static instance: SessionManager;
  private sessions: Map<string, SessionInfo> = new Map();
  private config: SDKConfig;
  private wsManager: WebSocketManager;
  private storageManager: StorageManager;
  private stateCallbacks: Set<SessionStateCallback> = new Set();
  private messageCallbacks: Set<MessageCallback> = new Set();
  private logger: Logger;

  private constructor(config: SDKConfig) {
    this.config = config;
    this.wsManager = WebSocketManager.getInstance(config);
    this.storageManager = StorageManager.getInstance(config.storageKey);
    this.logger = new Logger('SessionManager');
  }

  static getInstance(config: SDKConfig): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager(config);
    }
    return SessionManager.instance;
  }

  async createSession(request: SessionRequest): Promise<string> {
    const sessionId = request.sessionId || this.generateSessionId();
    
    const sessionInfo: SessionInfo = {
      sessionId,
      skillId: request.skillId,
      state: SessionState.CONNECTING,
      userInput: request.userInput,
      groupInfo: request.groupInfo,
      messages: [],
      createdAt: Date.now(),
      updatedAt: Date.now()
    };

    this.sessions.set(sessionId, sessionInfo);
    this.notifyStateChange(sessionId, SessionState.CONNECTING);

    try {
      await this.wsManager.createConnection(sessionId);
      
      this.wsManager.onMessage(sessionId, (data) => {
        this.handleWebSocketMessage(sessionId, data);
      });

      this.wsManager.onStateChange(sessionId, (state) => {
        this.handleWsStateChange(sessionId, state);
      });

      await this.sendInitialMessage(sessionId, request);
      
      this.logger.info(`Session created: ${sessionId}`);
      return sessionId;
    } catch (error) {
      this.logger.error(`Failed to create session: ${error}`);
      this.updateSessionState(sessionId, SessionState.ERROR);
      throw error;
    }
  }

  private async sendInitialMessage(sessionId: string, request: SessionRequest): Promise<void> {
    const userMessage: ChatMessage = {
      messageId: this.generateMessageId(),
      sessionId,
      role: 'user',
      content: request.userInput.content,
      timestamp: Date.now(),
      status: 'sent'
    };

    this.addMessage(sessionId, userMessage);

    await this.wsManager.sendMessage(sessionId, {
      type: 'start',
      sessionId,
      skillId: request.skillId,
      message: userMessage,
      groupInfo: request.groupInfo,
      mode: request.mode || 'single'
    });

    this.updateSessionState(sessionId, SessionState.RUNNING);
  }

  private handleWebSocketMessage(sessionId: string, data: string): void {
    try {
      const parsed = JSON.parse(data);
      
      switch (parsed.type) {
        case 'message':
          this.handleChatMessage(sessionId, parsed);
          break;
        case 'status':
          this.handleStatusUpdate(sessionId, parsed);
          break;
        case 'complete':
          this.handleSessionComplete(sessionId, parsed);
          break;
        case 'error':
          this.handleSessionError(sessionId, parsed);
          break;
        default:
          this.logger.warn(`Unknown message type: ${parsed.type}`);
      }
    } catch (error) {
      this.logger.error(`Failed to parse message: ${error}`);
    }
  }

  private handleChatMessage(sessionId: string, data: any): void {
    const message: ChatMessage = {
      messageId: data.messageId || this.generateMessageId(),
      sessionId,
      role: data.role || 'assistant',
      content: data.content,
      timestamp: data.timestamp || Date.now(),
      status: 'sent'
    };

    this.addMessage(sessionId, message);
    this.notifyMessageReceived(sessionId, message);
  }

  private handleStatusUpdate(sessionId: string, data: any): void {
    if (data.state) {
      this.updateSessionState(sessionId, data.state as SessionState);
    }
  }

  private handleSessionComplete(sessionId: string, data: any): void {
    this.updateSessionState(sessionId, SessionState.COMPLETED);
    this.saveSessionHistory(sessionId);
  }

  private handleSessionError(sessionId: string, data: any): void {
    this.updateSessionState(sessionId, SessionState.ERROR);
    this.logger.error(`Session error: ${data.message}`);
  }

  private handleWsStateChange(sessionId: string, state: SessionState): void {
    if (state === SessionState.CONNECTING) {
      this.updateSessionState(sessionId, SessionState.RUNNING);
    } else if (state === SessionState.ERROR) {
      this.updateSessionState(sessionId, SessionState.ERROR);
    }
  }

  async stopSession(options: StopOptions): Promise<void> {
    const { sessionId, reason } = options;
    
    if (!this.sessions.has(sessionId)) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    try {
      await this.wsManager.sendMessage(sessionId, {
        type: 'stop',
        sessionId,
        reason: reason || 'user_requested'
      });

      this.updateSessionState(sessionId, SessionState.STOPPED);
      this.logger.info(`Session stopped: ${sessionId}`);
    } catch (error) {
      this.logger.error(`Failed to stop session: ${error}`);
      throw error;
    }
  }

  async closeSession(sessionId: string): Promise<void> {
    if (!this.sessions.has(sessionId)) {
      return;
    }

    this.wsManager.closeConnection(sessionId);
    this.updateSessionState(sessionId, SessionState.CLOSED);
    this.sessions.delete(sessionId);
    this.logger.info(`Session closed: ${sessionId}`);
  }

  async retrySession(options: RetryOptions): Promise<void> {
    const { sessionId, messageId, fromIndex } = options;
    
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    try {
      await this.wsManager.sendMessage(sessionId, {
        type: 'retry',
        sessionId,
        messageId,
        fromIndex: fromIndex || session.messages.length
      });

      this.updateSessionState(sessionId, SessionState.RUNNING);
      this.logger.info(`Session retry: ${sessionId}`);
    } catch (error) {
      this.logger.error(`Failed to retry session: ${error}`);
      throw error;
    }
  }

  async continueConversation(sessionId: string, content: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    if (session.state === SessionState.CLOSED || session.state === SessionState.ERROR) {
      throw new Error(`Cannot continue conversation in state: ${session.state}`);
    }

    const message: ChatMessage = {
      messageId: this.generateMessageId(),
      sessionId,
      role: 'user',
      content,
      timestamp: Date.now(),
      status: 'sent'
    };

    this.addMessage(sessionId, message);

    await this.wsManager.sendMessage(sessionId, {
      type: 'message',
      sessionId,
      message
    });

    this.updateSessionState(sessionId, SessionState.RUNNING);
    this.logger.info(`Multi-turn message sent: ${sessionId}`);
  }

  async getHistory(sessionId: string): Promise<ChatMessage[]> {
    const session = this.sessions.get(sessionId);
    if (session) {
      return session.messages;
    }

    const stored = await this.storageManager.getSession(sessionId);
    return stored?.messages || [];
  }

  async getAllSessions(): Promise<SessionInfo[]> {
    const localSessions = Array.from(this.sessions.values());
    const storedSessions = await this.storageManager.getAllSessions();
    
    const sessionMap = new Map<string, SessionInfo>();
    
    for (const session of localSessions) {
      sessionMap.set(session.sessionId, session);
    }
    
    for (const session of storedSessions) {
      if (!sessionMap.has(session.sessionId)) {
        sessionMap.set(session.sessionId, session);
      }
    }
    
    return Array.from(sessionMap.values());
  }

  getSessionState(sessionId: string): SessionState | undefined {
    return this.sessions.get(sessionId)?.state;
  }

  onStateChange(callback: SessionStateCallback): void {
    this.stateCallbacks.add(callback);
  }

  onMessage(callback: MessageCallback): void {
    this.messageCallbacks.add(callback);
  }

  removeStateCallback(callback: SessionStateCallback): void {
    this.stateCallbacks.delete(callback);
  }

  removeMessageCallback(callback: MessageCallback): void {
    this.messageCallbacks.delete(callback);
  }

  private updateSessionState(sessionId: string, state: SessionState): void {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.state = state;
      session.updatedAt = Date.now();
    }
    this.notifyStateChange(sessionId, state);
    
    if (state === SessionState.COMPLETED || state === SessionState.STOPPED || state === SessionState.ERROR) {
      this.saveSessionHistory(sessionId);
    }
  }

  private addMessage(sessionId: string, message: ChatMessage): void {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.messages.push(message);
      session.updatedAt = Date.now();
    }
  }

  private notifyStateChange(sessionId: string, state: SessionState, data?: any): void {
    for (const callback of this.stateCallbacks) {
      try {
        callback(sessionId, state, data);
      } catch (error) {
        this.logger.error(`State callback error: ${error}`);
      }
    }
  }

  private notifyMessageReceived(sessionId: string, message: ChatMessage): void {
    for (const callback of this.messageCallbacks) {
      try {
        callback(sessionId, message);
      } catch (error) {
        this.logger.error(`Message callback error: ${error}`);
      }
    }
  }

  private async saveSessionHistory(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (session) {
      await this.storageManager.saveSession({
        sessionId: session.sessionId,
        skillId: session.skillId,
        messages: session.messages,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        state: session.state
      });
    }
  }

  private generateSessionId(): string {
    return `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
