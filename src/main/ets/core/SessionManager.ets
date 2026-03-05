import { WebSocketManager } from './WebSocketManager';
import { PreferenceStorage } from '../storage/PreferenceStorage';
import {
  SkillConfig,
  SkillMessage,
  SessionState,
  SkillResponse,
  MessageListener,
  ConnectionState,
  SkillErrorCode,
  StopOptions,
  RegenerateOptions,
  SkillSessionOptions
} from '../types/index';
import { Logger } from '../utils/Logger';

const TAG = 'SessionManager';

export class SessionManager {
  private wsManager: WebSocketManager;
  private storage: PreferenceStorage;
  private messageHistory: SkillMessage[] = [];
  private context: Object | null = null;
  private enablePersistence: boolean = false;
  private currentGroupId: string = '';
  private currentInstruction: string = '';
  private isInitialized: boolean = false;
  private listeners: MessageListener[] = [];

  constructor() {
    this.wsManager = WebSocketManager.getInstance();
    this.storage = PreferenceStorage.getInstance();

    this.setupDefaultListener();
  }

  private setupDefaultListener(): void {
    this.wsManager.setListener({
      onMessage: (message: SkillMessage) => this.handleIncomingMessage(message),
      onError: (error: Error) => this.notifyError(error),
      onStateChange: (state: SessionState) => this.notifyStateChange(state),
      onComplete: () => this.notifyComplete()
    });
  }

  async initialize(config: SkillConfig, context: Object): Promise<void> {
    this.currentGroupId = config.groupId;
    this.context = context;
    this.wsManager.setConfig(config);
    this.enablePersistence = config.enablePersistence ?? false;

    if (this.enablePersistence) {
      await this.storage.init(context);
      const storedMessages = await this.storage.getMessages(config.groupId);
      if (storedMessages.length > 0) {
        this.messageHistory = storedMessages;
        Logger.info(TAG, `Loaded ${storedMessages.length} messages from storage`);
      }
    }

    this.isInitialized = true;
    Logger.info(TAG, 'SessionManager initialized');
  }

  async runSkill(groupId: string, instruction: string, options?: SkillSessionOptions): Promise<SkillResponse> {
    if (!this.isInitialized) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SessionManager not initialized');
    }

    try {
      this.currentGroupId = groupId;
      this.currentInstruction = instruction;

      const userMessage: SkillMessage = {
        id: this.generateMessageId(),
        role: 'user',
        content: instruction,
        timestamp: Date.now(),
        type: 'text',
        metadata: options?.metadata
      };

      this.messageHistory.push(userMessage);
      await this.persistMessages();

      await this.wsManager.connect();

      const payload = {
        type: 'run_skill',
        groupId,
        instruction,
        history: this.messageHistory,
        context: options?.context,
        metadata: options?.metadata
      };

      await this.wsManager.send(JSON.stringify(payload));

      return {
        success: true,
        data: {
          sessionId: this.wsManager.getState().sessionId,
          connectionId: this.wsManager.getState().connectionId
        }
      };
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `runSkill failed: ${err.message}`);
      return this.createErrorResponse(SkillErrorCode.UNKNOWN_ERROR, err.message);
    }
  }

  closeSkill(): SkillResponse {
    if (!this.isInitialized) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SessionManager not initialized');
    }

    try {
      this.wsManager.close();
      this.messageHistory = [];
      this.currentInstruction = '';
      if (this.enablePersistence && this.currentGroupId) {
        this.storage.clearMessages(this.currentGroupId).catch((err: Error) => {
          Logger.error(TAG, `Failed to clear messages: ${err.message}`);
        });
      }
      this.listeners = [];
      return { success: true };
    } catch (error) {
      const err = error as Error;
      return this.createErrorResponse(SkillErrorCode.UNKNOWN_ERROR, err.message);
    }
  }

  stopSkill(options?: StopOptions): SkillResponse {
    if (!this.isInitialized) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SessionManager not initialized');
    }

    try {
      const payload = {
        type: 'stop_skill',
        action: 'stop_callback',
        force: options?.force ?? false,
        reason: options?.reason
      };

      this.wsManager.send(JSON.stringify(payload));

      return { success: true };
    } catch (error) {
      const err = error as Error;
      return this.createErrorResponse(SkillErrorCode.UNKNOWN_ERROR, err.message);
    }
  }

  getState(): SessionState {
    return this.wsManager.getState();
  }

  async regenerate(options?: RegenerateOptions): Promise<SkillResponse> {
    if (!this.isInitialized) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SessionManager not initialized');
    }

    try {
      const lastUserMessage = this.messageHistory
        .filter(m => m.role === 'user')
        .pop();

      if (!lastUserMessage) {
        return this.createErrorResponse(SkillErrorCode.NO_USER_MESSAGE, 'No user instruction found');
      }

      if (!options?.keepHistory) {
        const lastAssistantIndex = this.messageHistory.length - 1;
        if (lastAssistantIndex >= 0 && this.messageHistory[lastAssistantIndex].role === 'assistant') {
          this.messageHistory.pop();
        }
      }

      const instruction = options?.newInstruction || lastUserMessage.content;
      this.currentInstruction = instruction;

      const payload = {
        type: 'regenerate',
        instruction,
        history: this.messageHistory
      };

      await this.wsManager.send(JSON.stringify(payload));

      return { success: true };
    } catch (error) {
      const err = error as Error;
      return this.createErrorResponse(SkillErrorCode.UNKNOWN_ERROR, err.message);
    }
  }

  async getSessionMessage(): Promise<SkillMessage[]> {
    if (!this.isInitialized) {
      return [];
    }

    if (this.enablePersistence && this.currentGroupId) {
      const storedMessages = await this.storage.getMessages(this.currentGroupId);
      if (storedMessages.length > 0) {
        return storedMessages;
      }
    }

    return [...this.messageHistory];
  }

  async send(content: string, metadata?: Record<string, Object>): Promise<SkillResponse> {
    if (!this.isInitialized) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SessionManager not initialized');
    }

    try {
      const message: SkillMessage = {
        id: this.generateMessageId(),
        role: 'user',
        content,
        timestamp: Date.now(),
        type: 'text',
        metadata
      };

      this.messageHistory.push(message);
      await this.persistMessages();

      const payload = {
        type: 'send',
        content,
        history: this.messageHistory,
        metadata
      };

      await this.wsManager.send(JSON.stringify(payload));

      return { success: true };
    } catch (error) {
      const err = error as Error;
      return this.createErrorResponse(SkillErrorCode.SEND_FAILED, err.message);
    }
  }

  addMessageListener(listener: MessageListener): void {
    this.listeners.push(listener);
  }

  removeMessageListener(listener: MessageListener): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  clearMessageListeners(): void {
    this.listeners = [];
  }

  getConnectionState(): ConnectionState {
    return this.wsManager.getConnectionState();
  }

  isSessionActive(): boolean {
    const state = this.wsManager.getState();
    return state.status === 'executing';
  }

  async clearHistory(): Promise<void> {
    this.messageHistory = [];
    if (this.enablePersistence && this.currentGroupId) {
      await this.storage.clearMessages(this.currentGroupId);
    }
  }

  getCurrentGroupId(): string {
    return this.currentGroupId;
  }

  getCurrentInstruction(): string {
    return this.currentInstruction;
  }

  private handleIncomingMessage(message: SkillMessage): void {
    this.messageHistory.push(message);
    this.persistMessages().catch((err: Error) => {
      Logger.error(TAG, `Failed to persist message: ${err.message}`);
    });

    this.listeners.forEach(listener => {
      try {
        listener.onMessage(message);
      } catch (err) {
        Logger.error(TAG, `Listener onMessage error: ${(err as Error).message}`);
      }
    });
  }

  private notifyError(error: Error): void {
    this.listeners.forEach(listener => {
      try {
        listener.onError?.(error);
      } catch (err) {
        Logger.error(TAG, `Listener onError error: ${(err as Error).message}`);
      }
    });
  }

  private notifyStateChange(state: SessionState): void {
    this.listeners.forEach(listener => {
      try {
        listener.onStateChange?.(state);
      } catch (err) {
        Logger.error(TAG, `Listener onStateChange error: ${(err as Error).message}`);
      }
    });
  }

  private notifyComplete(): void {
    this.listeners.forEach(listener => {
      try {
        listener.onComplete?.();
      } catch (err) {
        Logger.error(TAG, `Listener onComplete error: ${(err as Error).message}`);
      }
    });
  }

  private async persistMessages(): Promise<void> {
    if (!this.enablePersistence || !this.currentGroupId) {
      return;
    }

    await this.storage.saveMessages(this.currentGroupId, this.messageHistory);
  }

  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  private createErrorResponse(code: number, message: string): SkillResponse {
    return {
      success: false,
      error: {
        code,
        message
      }
    };
  }
}
