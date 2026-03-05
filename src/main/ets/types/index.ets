export interface SkillConfig {
  groupId: string;
  userId?: string;
  serverUrl: string;
  maxRetries?: number;
  timeout?: number;
  enablePersistence?: boolean;
}

export interface SkillMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  type?: 'text' | 'image' | 'file';
  metadata?: Record<string, any>;
}

export interface SessionState {
  status: 'idle' | 'executing' | 'stopped' | 'completed' | 'error';
  sessionId?: string;
  groupId: string;
  messageCount: number;
  lastUpdateTime: number;
  errorCode?: number;
  errorMessage?: string;
}

export interface SkillResponse {
  success: boolean;
  data?: any;
  error?: {
    code: number;
    message: string;
  };
}

export interface MessageListener {
  onMessage: (message: SkillMessage) => void;
  onError?: (error: Error) => void;
  onStateChange?: (state: SessionState) => void;
}

export interface SessionOptions {
  autoReconnect?: boolean;
  maxReconnectAttempts?: number;
  reconnectInterval?: number;
}
