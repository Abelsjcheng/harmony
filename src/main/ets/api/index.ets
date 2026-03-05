import { SessionManager } from '../core/SessionManager';
import { 
  SkillConfig, 
  SkillMessage, 
  SessionState, 
  SkillResponse, 
  MessageListener 
} from '../types/index';

const TAG = 'SkillSDK';

export class SkillSDK {
  private static instance: SkillSDK | null = null;
  private sessionManager: SessionManager | null = null;
  private currentConfig: SkillConfig | null = null;

  private constructor() {}

  static getInstance(): SkillSDK {
    if (!SkillSDK.instance) {
      SkillSDK.instance = new SkillSDK();
    }
    return SkillSDK.instance;
  }

  async initialize(config: SkillConfig, context: any): Promise<void> {
    this.currentConfig = config;
    this.sessionManager = new SessionManager(config);
    await this.sessionManager.initialize(context);
  }

  async runSkill(groupId: string, instruction: string): Promise<SkillResponse> {
    if (!this.sessionManager) {
      return this.createErrorResponse('SDK not initialized');
    }
    return await this.sessionManager.runSkill(groupId, instruction);
  }

  closeSkill(): SkillResponse {
    if (!this.sessionManager) {
      return this.createErrorResponse('SDK not initialized');
    }
    return this.sessionManager.closeSkill();
  }

  stopSkill(): SkillResponse {
    if (!this.sessionManager) {
      return this.createErrorResponse('SDK not initialized');
    }
    return this.sessionManager.stopSkill();
  }

  getState(): SessionState | null {
    if (!this.sessionManager) {
      return null;
    }
    return this.sessionManager.getState();
  }

  async regenerate(): Promise<SkillResponse> {
    if (!this.sessionManager) {
      return this.createErrorResponse('SDK not initialized');
    }
    return await this.sessionManager.regenerate();
  }

  async getSessionMessage(): Promise<SkillMessage[]> {
    if (!this.sessionManager) {
      return [];
    }
    return await this.sessionManager.getSessionMessage();
  }

  async send(content: string): Promise<SkillResponse> {
    if (!this.sessionManager) {
      return this.createErrorResponse('SDK not initialized');
    }
    return await this.sessionManager.send(content);
  }

  addMessageListener(listener: MessageListener): void {
    if (!this.sessionManager) {
      throw new Error('SDK not initialized');
    }
    this.sessionManager.addMessageListener(listener);
  }

  private createErrorResponse(message: string): SkillResponse {
    return {
      success: false,
      error: {
        code: -999,
        message
      }
    };
  }
}

export default SkillSDK;
