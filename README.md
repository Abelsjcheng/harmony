# OpenCode Skill SDK for HarmonyOS

基于 HarmonyOS API 20 开发的 ArkTS SDK，用于 IM 客户端、OpenCode Skill 服务端、小程序之间的交互。

## 功能特性

- 从 IM 客户端获取 skill 指令、用户输入、群信息
- 与 skill 服务端建立 WebSocket 会话连接
- 支持停止生成、重试、多轮对话
- 会话状态回调（执行中、停止、完成）
- 会话历史记录本地持久化存储
- WebSocket 连接上限管理

## 安装

```bash
ohpm install @opencode/skill-sdk
```

## 快速开始

### 1. 初始化 SDK

```typescript
import OpenCodeSkillSDK from '@opencode/skill-sdk';

const sdk = OpenCodeSkillSDK.getInstance();

await sdk.init({
  serverUrl: 'wss://your-server.com/skill',
  maxConnections: 5,
  reconnectAttempts: 3,
  reconnectInterval: 1000,
  messageTimeout: 30000,
  storageKey: 'your_storage_key'
});
```

### 2. IM 客户端集成

```typescript
import { SkillInstruction, UserInput, GroupInfo } from '@opencode/skill-sdk';

sdk.registerIMCallbacks({
  onInstructionReceived: (instruction: SkillInstruction) => {
    console.log('收到指令:', instruction);
  },
  onUserInputReceived: (input: UserInput) => {
    console.log('收到用户输入:', input);
  },
  onGroupInfoReceived: (info: GroupInfo) => {
    console.log('收到群信息:', info);
  }
});

await sdk.processInstruction({
  skillId: 'skill_001',
  skillName: 'AI Assistant',
  action: 'chat'
});
```

### 3. 启动会话

```typescript
import { SessionRequest } from '@opencode/skill-sdk';

const sessionId = await sdk.startSession({
  skillId: 'skill_001',
  userInput: {
    userId: 'user_123',
    userName: '张三',
    content: '你好，请帮我写一段代码',
    timestamp: Date.now()
  },
  groupInfo: {
    groupId: 'group_456',
    groupName: '技术交流群',
    memberCount: 50
  },
  mode: 'multi'
});
```

### 4. 小程序多轮对话

```typescript
sdk.registerMiniProgramCallbacks({
  onSessionStateChange: (sessionId, state, data) => {
    console.log(`会话 ${sessionId} 状态变更: ${state}`);
  },
  onMessageReceived: (sessionId, message) => {
    console.log(`收到消息:`, message);
  }
});

await sdk.sendMessage(sessionId, '请继续');
```

### 5. 会话控制

```typescript
await sdk.stopSession({
  sessionId,
  reason: 'user_requested'
});

await sdk.retrySession({
  sessionId,
  messageId: 'msg_123'
});

await sdk.closeSession(sessionId);
```

### 6. 获取历史记录

```typescript
const history = await sdk.getHistory(sessionId);
const allSessions = await sdk.getAllSessions();

await sdk.deleteSession(sessionId);
await sdk.clearHistory();
```

## API 参考

### 会话状态 (SessionState)

| 状态 | 说明 |
|------|------|
| IDLE | 空闲 |
| CONNECTING | 连接中 |
| RUNNING | 执行中 |
| PAUSED | 已暂停 |
| STOPPED | 已停止 |
| COMPLETED | 已完成 |
| ERROR | 错误 |
| CLOSED | 已关闭 |

### 主要方法

| 方法 | 说明 |
|------|------|
| `init(config)` | 初始化 SDK |
| `startSession(request)` | 创建新会话 |
| `stopSession(options)` | 停止会话 |
| `closeSession(sessionId)` | 关闭会话 |
| `retrySession(options)` | 重试会话 |
| `sendMessage(sessionId, content)` | 发送消息（多轮对话） |
| `getHistory(sessionId)` | 获取会话历史 |
| `getAllSessions()` | 获取所有会话 |
| `getSessionState(sessionId)` | 获取会话状态 |
| `deleteSession(sessionId)` | 删除会话 |
| `clearHistory()` | 清空历史记录 |

## 配置选项

```typescript
interface SDKConfig {
  serverUrl: string;          // WebSocket 服务端地址
  maxConnections: number;     // 最大连接数（默认：5）
  reconnectAttempts: number;  // 重连次数（默认：3）
  reconnectInterval: number;  // 重连间隔 ms（默认：1000）
  messageTimeout: number;     // 消息超时 ms（默认：30000）
  storageKey: string;         // 本地存储键名
}
```

## 工程结构

```
src/main/ets/
├── index.ets                 # SDK 主入口
├── types/
│   └── index.ets             # 类型定义
├── websocket/
│   └── WebSocketManager.ets  # WebSocket 连接管理
├── session/
│   └── SessionManager.ets    # 会话管理
├── storage/
│   └── StorageManager.ets    # 本地持久化存储
└── utils/
    └── Logger.ets            # 日志工具
```

## 注意事项

1. 使用前必须调用 `init()` 初始化 SDK
2. WebSocket 连接数受 `maxConnections` 限制
3. 会话历史自动持久化到本地存储
4. 建议在应用退出时调用 `destroy()` 清理资源

## License

MIT
