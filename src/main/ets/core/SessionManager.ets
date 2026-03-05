import { WebSocketManager } from './WebSocketManager';
import { PreferenceStorage } from './storage/PreferenceStorage';
import { 
  SkillConfig, 
  SkillMessage, 
  SessionState, 
  SkillResponse, 
  MessageListener 
} from './types/index';
import { Logger } from './utils/Logger';

const TAG = 'SessionManager';

export class SessionManager {
  private wsManager: WebSocketManager;
  private storage: PreferenceStorage;
  private messageHistory: SkillMessage[] = [];
  private context: any = null;
  private enablePersistence: boolean = false;

  constructor(config: SkillConfig) {
    this.wsManager = new WebSocketManager(config);
    this.storage = PreferenceStorage.getInstance();
    this.enablePersistence = config.enablePersistence ?? false;
    
    this.wsManager.setListener({
      onMessage: (message) => this.handleIncomingMessage(message),
      onError: (error) => Logger.error(TAG, `Session error: ${error.message}`),
      onStateChange: (state) => Logger.info(TAG, `State changed: ${state.status}`)
    });
  }

  async initialize(context: any): Promise<void> {
    this.context = context;
    if (this.enablePersistence) {
      await this.storage.init(context);
    }
  }

  async runSkill(groupId: string, instruction: string): Promise<SkillResponse> {
    try {
      const userMessage: SkillMessage = {
        id: this.generateMessageId(),
        role: 'user',
        content: instruction,
        timestamp: Date.now(),
        type: 'text'
      };

      this.messageHistory.push(userMessage);
      await this.persistMessages();

      await this.wsManager.connect();

      const payload = {
        type: 'run_skill',
        groupId,
        instruction,
        history: this.messageHistory
      };

      await this.wsManager.send(JSON.stringify(payload));

      return {
        success: true,
        data: { sessionId: this.wsManager.getState().sessionId }
      };
    } catch (error) {
      return {
        success: false,
        error: {
          code: -1,
          message: (error as Error).message
        }
      };
    }
  }

  closeSkill(): SkillResponse {
    try {
      this.wsManager.close();
      this.messageHistory = [];
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: {
          code: -1,
          message: (error as Error).message
        }
      };
    }
  }

  stopSkill(): SkillResponse {
    try {
      const payload = {
        type: 'stop_skill',
        action: 'stop_callback'
      };

      this.wsManager.send(JSON.stringify(payload));
      
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: {
          code: -1,
          message: (error as Error).message
        }
      };
    }
  }

  getState(): SessionState {
    return this.wsManager.getState();
  }

  async regenerate(): Promise<SkillResponse> {
    try {
      if (this.messageHistory.length === 0) {
        return {
          success: false,
          error: {
            code: -2,
            message: 'No instruction to regenerate'
          }
        };
      }

      const lastUserMessage = this.messageHistory
        .filter(m => m.role === 'user')
        .pop();

      if (!lastUserMessage) {
        return {
          success: false,
          error: {
            code: -3,
            message: 'No user instruction found'
          }
        };
      }

      const payload = {
        type: 'regenerate',
        instruction: lastUserMessage.content,
        history: this.messageHistory
      };

      await this.wsManager.send(JSON.stringify(payload));

      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: {
          code: -1,
          message: (error as Error).message
        }
      };
    }
  }

  async getSessionMessage(): Promise<SkillMessage[]> {
    if (this.enablePersistence && this.context) {
      const groupId = this.wsManager.getState().groupId;
      if (groupId) {
        const storedMessages = await this.storage.getMessages(groupId);
        if (storedMessages.length > 0) {
          return storedMessages;
        }
      }
    }
    
    return [...this.messageHistory];
  }

  async send(content: string): Promise<SkillResponse> {
    try {
      const message: SkillMessage = {
        id: this.generateMessageId(),
        role: 'user',
        content,
        timestamp: Date.now(),
        type: 'text'
      };

      this.messageHistory.push(message);
      await this.persistMessages();

      const payload = {
        type: 'send',
        content,
        history: this.messageHistory
      };

      await this.wsManager.send(JSON.stringify(payload));

      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: {
          code: -1,
          message: (error as Error).message
        }
      };
    }
  }

  addMessageListener(listener: MessageListener): void {
    this.wsManager.setListener({
      onMessage: (message) => {
        this.handleIncomingMessage(message);
        listener.onMessage(message);
      },
      onError: (error) => {
        listener.onError?.(error);
      },
      onStateChange: (state) => {
        listener.onStateChange?.(state);
      }
    });
  }

  private handleIncomingMessage(message: SkillMessage): void {
    this.messageHistory.push(message);
    this.persistMessages().catch(err => {
      Logger.error(TAG, `Failed to persist message: ${err.message}`);
    });
  }

  private async persistMessages(): Promise<void> {
    if (!this.enablePersistence || !this.context) {
      return;
    }

    const groupId = this.wsManager.getState().groupId;
    if (groupId) {
      await this.storage.saveMessages(groupId, this.messageHistory);
    }
  }

  private generateMessageId(): string {
    return `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }
}
