import {
  SessionState,
  SkillInstruction,
  GroupInfo,
  UserInput,
  SessionRequest,
  ChatMessage,
  SessionHistory,
  SDKConfig,
  RetryOptions,
  StopOptions,
  IMClientCallback,
  MiniProgramCallback
} from './types';
import { SessionManager } from './session/SessionManager';
import { WebSocketManager } from './websocket/WebSocketManager';
import { StorageManager } from './storage/StorageManager';
import { Logger } from './utils/Logger';

const DEFAULT_CONFIG: SDKConfig = {
  serverUrl: 'wss://api.opencode.com/skill',
  maxConnections: 5,
  reconnectAttempts: 3,
  reconnectInterval: 1000,
  messageTimeout: 30000,
  storageKey: 'opencode_skill_data'
};

export class OpenCodeSkillSDK {
  private static instance: OpenCodeSkillSDK;
  private config: SDKConfig;
  private sessionManager: SessionManager;
  private logger: Logger;
  private initialized: boolean = false;
  private imCallbacks: IMClientCallback = {};
  private miniProgramCallbacks: MiniProgramCallback = {};

  private constructor() {
    this.config = { ...DEFAULT_CONFIG };
    this.logger = new Logger('OpenCodeSkillSDK');
    this.sessionManager = SessionManager.getInstance(this.config);
  }

  static getInstance(): OpenCodeSkillSDK {
    if (!OpenCodeSkillSDK.instance) {
      OpenCodeSkillSDK.instance = new OpenCodeSkillSDK();
    }
    return OpenCodeSkillSDK.instance;
  }

  async init(config?: Partial<SDKConfig>): Promise<void> {
    if (this.initialized) {
      this.logger.warn('SDK already initialized');
      return;
    }

    if (config) {
      this.config = { ...this.config, ...config };
    }

    this.sessionManager = SessionManager.getInstance(this.config);
    
    this.sessionManager.onStateChange((sessionId, state, data) => {
      this.notifyIMStateChange(sessionId, state, data);
      this.notifyMiniProgramStateChange(sessionId, state, data);
    });

    this.sessionManager.onMessage((sessionId, message) => {
      this.notifyMiniProgramMessage(sessionId, message);
    });

    this.initialized = true;
    this.logger.info('SDK initialized');
  }

  async processInstruction(instruction: SkillInstruction): Promise<void> {
    this.logger.info(`Processing instruction: ${instruction.skillName}`);
    
    if (this.imCallbacks.onInstructionReceived) {
      this.imCallbacks.onInstructionReceived(instruction);
    }
  }

  async processUserInput(input: UserInput): Promise<void> {
    this.logger.info(`Processing user input from: ${input.userId}`);
    
    if (this.imCallbacks.onUserInputReceived) {
      this.imCallbacks.onUserInputReceived(input);
    }
  }

  async processGroupInfo(info: GroupInfo): Promise<void> {
    this.logger.info(`Processing group info: ${info.groupName}`);
    
    if (this.imCallbacks.onGroupInfoReceived) {
      this.imCallbacks.onGroupInfoReceived(info);
    }
  }

  async startSession(request: SessionRequest): Promise<string> {
    this.checkInitialized();
    return this.sessionManager.createSession(request);
  }

  async stopSession(options: StopOptions): Promise<void> {
    this.checkInitialized();
    return this.sessionManager.stopSession(options);
  }

  async closeSession(sessionId: string): Promise<void> {
    this.checkInitialized();
    return this.sessionManager.closeSession(sessionId);
  }

  async retrySession(options: RetryOptions): Promise<void> {
    this.checkInitialized();
    return this.sessionManager.retrySession(options);
  }

  async sendMessage(sessionId: string, content: string): Promise<void> {
    this.checkInitialized();
    return this.sessionManager.continueConversation(sessionId, content);
  }

  async getHistory(sessionId: string): Promise<ChatMessage[]> {
    this.checkInitialized();
    return this.sessionManager.getHistory(sessionId);
  }

  async getAllSessions(): Promise<SessionHistory[]> {
    this.checkInitialized();
    return this.sessionManager.getAllSessions();
  }

  getSessionState(sessionId: string): SessionState | undefined {
    this.checkInitialized();
    return this.sessionManager.getSessionState(sessionId);
  }

  registerIMCallbacks(callbacks: IMClientCallback): void {
    this.imCallbacks = { ...this.imCallbacks, ...callbacks };
    this.logger.info('IM callbacks registered');
  }

  registerMiniProgramCallbacks(callbacks: MiniProgramCallback): void {
    this.miniProgramCallbacks = { ...this.miniProgramCallbacks, ...callbacks };
    this.logger.info('MiniProgram callbacks registered');
  }

  unregisterIMCallbacks(): void {
    this.imCallbacks = {};
  }

  unregisterMiniProgramCallbacks(): void {
    this.miniProgramCallbacks = {};
  }

  async clearHistory(): Promise<void> {
    const storageManager = StorageManager.getInstance(this.config.storageKey);
    await storageManager.clearAll();
    this.logger.info('History cleared');
  }

  async deleteSession(sessionId: string): Promise<void> {
    const storageManager = StorageManager.getInstance(this.config.storageKey);
    await storageManager.deleteSession(sessionId);
    await this.sessionManager.closeSession(sessionId);
    this.logger.info(`Session deleted: ${sessionId}`);
  }

  getConnectionCount(): number {
    const wsManager = WebSocketManager.getInstance(this.config);
    return wsManager.getConnectionCount();
  }

  getMaxConnections(): number {
    return this.config.maxConnections;
  }

  setDebugEnabled(enabled: boolean): void {
    this.logger.setEnabled(enabled);
  }

  private checkInitialized(): void {
    if (!this.initialized) {
      throw new Error('SDK not initialized. Call init() first.');
    }
  }

  private notifyIMStateChange(sessionId: string, state: SessionState, data?: any): void {
    this.logger.debug(`IM notified: ${sessionId} -> ${state}`);
  }

  private notifyMiniProgramStateChange(sessionId: string, state: SessionState, data?: any): void {
    if (this.miniProgramCallbacks.onSessionStateChange) {
      this.miniProgramCallbacks.onSessionStateChange(sessionId, state, data);
    }
  }

  private notifyMiniProgramMessage(sessionId: string, message: ChatMessage): void {
    if (this.miniProgramCallbacks.onMessageReceived) {
      this.miniProgramCallbacks.onMessageReceived(sessionId, message);
    }
  }

  async destroy(): Promise<void> {
    const wsManager = WebSocketManager.getInstance(this.config);
    wsManager.closeAllConnections();
    this.unregisterIMCallbacks();
    this.unregisterMiniProgramCallbacks();
    this.initialized = false;
    this.logger.info('SDK destroyed');
  }
}

export {
  SessionState,
  SkillInstruction,
  GroupInfo,
  UserInput,
  SessionRequest,
  ChatMessage,
  SessionHistory,
  SDKConfig,
  RetryOptions,
  StopOptions,
  IMClientCallback,
  MiniProgramCallback,
  SessionStateCallback,
  MessageCallback
} from './types';

export default OpenCodeSkillSDK;
