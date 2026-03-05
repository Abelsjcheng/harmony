import { SessionManager } from '../core/SessionManager';
import { WebSocketManager } from '../core/WebSocketManager';
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

const TAG = 'SkillSDK';

export class SkillSDK {
  private static instance: SkillSDK | null = null;
  private sessionManager: SessionManager | null = null;
  private currentConfig: SkillConfig | null = null;
  private isInitialized: boolean = false;

  private constructor() {}

  static getInstance(): SkillSDK {
    if (!SkillSDK.instance) {
      SkillSDK.instance = new SkillSDK();
    }
    return SkillSDK.instance;
  }

  async initialize(config: SkillConfig, context: Object): Promise<SkillResponse> {
    try {
      this.currentConfig = config;
      this.sessionManager = new SessionManager();
      await this.sessionManager.initialize(config, context);
      this.isInitialized = true;
      Logger.info(TAG, 'SkillSDK initialized successfully');
      return { success: true };
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Initialize failed: ${err.message}`);
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, err.message);
    }
  }

  async runSkill(groupId: string, instruction: string, options?: SkillSessionOptions): Promise<SkillResponse> {
    if (!this.isInitialized || !this.sessionManager) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SDK not initialized');
    }
    return await this.sessionManager.runSkill(groupId, instruction, options);
  }

  closeSkill(): SkillResponse {
    if (!this.isInitialized || !this.sessionManager) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SDK not initialized');
    }
    const result = this.sessionManager.closeSkill();
    this.isInitialized = false;
    return result;
  }

  stopSkill(options?: StopOptions): SkillResponse {
    if (!this.isInitialized || !this.sessionManager) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SDK not initialized');
    }
    return this.sessionManager.stopSkill(options);
  }

  getState(): SessionState | null {
    if (!this.isInitialized || !this.sessionManager) {
      return null;
    }
    return this.sessionManager.getState();
  }

  async regenerate(options?: RegenerateOptions): Promise<SkillResponse> {
    if (!this.isInitialized || !this.sessionManager) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SDK not initialized');
    }
    return await this.sessionManager.regenerate(options);
  }

  async getSessionMessage(): Promise<SkillMessage[]> {
    if (!this.isInitialized || !this.sessionManager) {
      return [];
    }
    return await this.sessionManager.getSessionMessage();
  }

  async send(content: string, metadata?: Record<string, Object>): Promise<SkillResponse> {
    if (!this.isInitialized || !this.sessionManager) {
      return this.createErrorResponse(SkillErrorCode.NOT_INITIALIZED, 'SDK not initialized');
    }
    return await this.sessionManager.send(content, metadata);
  }

  addMessageListener(listener: MessageListener): void {
    if (!this.isInitialized || !this.sessionManager) {
      throw new Error('SDK not initialized');
    }
    this.sessionManager.addMessageListener(listener);
  }

  removeMessageListener(listener: MessageListener): void {
    if (!this.isInitialized || !this.sessionManager) {
      throw new Error('SDK not initialized');
    }
    this.sessionManager.removeMessageListener(listener);
  }

  clearMessageListeners(): void {
    if (this.sessionManager) {
      this.sessionManager.clearMessageListeners();
    }
  }

  getConnectionState(): ConnectionState | null {
    if (!this.isInitialized || !this.sessionManager) {
      return null;
    }
    return this.sessionManager.getConnectionState();
  }

  isSessionActive(): boolean {
    if (!this.sessionManager) {
      return false;
    }
    return this.sessionManager.isSessionActive();
  }

  async clearHistory(): Promise<void> {
    if (this.sessionManager) {
      await this.sessionManager.clearHistory();
    }
  }

  getCurrentGroupId(): string | null {
    if (!this.sessionManager) {
      return null;
    }
    return this.sessionManager.getCurrentGroupId();
  }

  getCurrentInstruction(): string | null {
    if (!this.sessionManager) {
      return null;
    }
    return this.sessionManager.getCurrentInstruction();
  }

  static reset(): void {
    if (SkillSDK.instance) {
      SkillSDK.instance.closeSkill();
      WebSocketManager.resetInstance();
      SkillSDK.instance = null;
    }
  }

  isSDKInitialized(): boolean {
    return this.isInitialized;
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

export function createSkillSDK(): SkillSDK {
  return SkillSDK.getInstance();
}

export default SkillSDK;
