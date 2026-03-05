export enum SessionState {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  RUNNING = 'running',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  COMPLETED = 'completed',
  ERROR = 'error',
  CLOSED = 'closed'
}

export interface SkillInstruction {
  skillId: string;
  skillName: string;
  action: string;
  parameters?: Record<string, any>;
}

export interface GroupInfo {
  groupId: string;
  groupName: string;
  memberCount: number;
  members?: string[];
}

export interface UserInput {
  userId: string;
  userName: string;
  content: string;
  timestamp: number;
  groupId?: string;
}

export interface SessionRequest {
  sessionId?: string;
  skillId: string;
  userInput: UserInput;
  groupInfo?: GroupInfo;
  mode?: 'single' | 'multi';
}

export interface ChatMessage {
  messageId: string;
  sessionId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  status?: 'sending' | 'sent' | 'error';
}

export interface SessionHistory {
  sessionId: string;
  skillId: string;
  messages: ChatMessage[];
  createdAt: number;
  updatedAt: number;
  state: SessionState;
}

export type SessionStateCallback = (sessionId: string, state: SessionState, data?: any) => void;

export type MessageCallback = (sessionId: string, message: ChatMessage) => void;

export interface SDKConfig {
  serverUrl: string;
  maxConnections: number;
  reconnectAttempts: number;
  reconnectInterval: number;
  messageTimeout: number;
  storageKey: string;
}

export interface RetryOptions {
  sessionId: string;
  messageId?: string;
  fromIndex?: number;
}

export interface StopOptions {
  sessionId: string;
  reason?: string;
}

export type IMClientCallback = {
  onInstructionReceived?: (instruction: SkillInstruction) => void;
  onUserInputReceived?: (input: UserInput) => void;
  onGroupInfoReceived?: (info: GroupInfo) => void;
};

export type MiniProgramCallback = {
  onSessionStateChange?: SessionStateCallback;
  onMessageReceived?: MessageCallback;
};
