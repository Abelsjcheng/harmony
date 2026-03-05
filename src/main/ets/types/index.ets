export type SessionStatus = 'idle' | 'executing' | 'stopped' | 'completed' | 'error';

export type MessageType = 'text' | 'image' | 'file' | 'audio' | 'video' | 'code';

export type MessageRole = 'user' | 'assistant' | 'system';

export interface SkillConfig {
  groupId: string;
  userId?: string;
  serverUrl: string;
  maxRetries?: number;
  timeout?: number;
  enablePersistence?: boolean;
  maxConnections?: number;
  reconnectInterval?: number;
  headers?: Record<string, string>;
  protocol?: string;
}

export interface SkillMessage {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: number;
  type?: MessageType;
  metadata?: Record<string, Object>;
  isComplete?: boolean;
  errorCode?: number;
  errorMessage?: string;
}

export interface SessionState {
  status: SessionStatus;
  sessionId?: string;
  groupId: string;
  messageCount: number;
  lastUpdateTime: number;
  errorCode?: number;
  errorMessage?: string;
  connectionId?: string;
}

export interface SkillResponse {
  success: boolean;
  data?: Record<string, Object>;
  error?: SkillError;
}

export interface SkillError {
  code: number;
  message: string;
  details?: Record<string, Object>;
}

export interface MessageListener {
  onMessage: (message: SkillMessage) => void;
  onError?: (error: Error) => void;
  onStateChange?: (state: SessionState) => void;
  onComplete?: () => void;
}

export interface ConnectionState {
  connectionCount: number;
  maxConnections: number;
  availableSlots: number;
  connections: ConnectionInfo[];
}

export interface ConnectionInfo {
  connectionId: string;
  groupId: string;
  createdAt: number;
  status: 'active' | 'idle' | 'error';
}

export interface WebSocketConfig {
  url: string;
  protocols?: string[];
  headers?: Record<string, string>;
  timeout?: number;
}

export interface SkillEvent {
  type: 'message' | 'state_change' | 'error' | 'complete';
  data: SkillMessage | SessionState | Error;
  timestamp: number;
}

export interface RetryConfig {
  maxRetries: number;
  retryInterval: number;
  exponentialBackoff?: boolean;
  maxRetryInterval?: number;
}

export interface StorageConfig {
  enablePersistence: boolean;
  maxStorageSize?: number;
  expirationTime?: number;
}

export interface SkillSessionOptions {
  groupId: string;
  instruction: string;
  context?: Record<string, Object>;
  metadata?: Record<string, Object>;
}

export interface RegenerateOptions {
  keepHistory?: boolean;
  newInstruction?: string;
}

export interface StopOptions {
  force?: boolean;
  reason?: string;
}

export const SkillErrorCode = {
  SUCCESS: 0,
  UNKNOWN_ERROR: -1,
  NOT_INITIALIZED: -2,
  NO_INSTRUCTION: -3,
  NO_USER_MESSAGE: -4,
  CONNECTION_LIMIT: -5,
  CONNECTION_FAILED: -6,
  SEND_FAILED: -7,
  STORAGE_ERROR: -8,
  TIMEOUT: -9,
  NETWORK_ERROR: -10,
  SERVER_ERROR: -11,
  INVALID_PARAM: -12,
  SESSION_NOT_FOUND: -13,
} as const;

export const DEFAULT_CONFIG = {
  MAX_CONNECTIONS: 5,
  MAX_RETRIES: 3,
  RECONNECT_INTERVAL: 3000,
  TIMEOUT: 30000,
} as const;
