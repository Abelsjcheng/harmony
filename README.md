# Harmony Skill SDK

HarmonyOS ArkTS SDK for skill server interaction with IM clients, OpenCode skill server, and mini-programs.

## Features

- WebSocket-based real-time communication
- Session state management (idle/executing/stopped/completed/error)
- Local persistent storage using Preferences
- Multi-round conversation support
- Retry and reconnection mechanisms
- Connection limit management (configurable max connections)
- Error handling and logging

## Installation

```bash
ohpm install @harmony/skill-sdk
```

## Quick Start

```typescript
import SkillSDK from '@harmony/skill-sdk';
import type { MessageListener } from '@harmony/skill-sdk';

const sdk = SkillSDK.getInstance();

await sdk.initialize({
  groupId: 'group_123',
  userId: 'user_456',
  serverUrl: 'ws://localhost:8080/skill',
  enablePersistence: true,
  maxConnections: 5
}, getContext(this));

sdk.addMessageListener({
  onMessage: (message) => {
    console.info(`${message.role}: ${message.content}`);
  },
  onStateChange: (state) => {
    console.info(`State: ${state.status}`);
  }
});

await sdk.runSkill('group_123', 'Generate a HarmonyOS app');
```

## API Reference

### initialize(config, context)
Initialize the SDK with configuration.

| Parameter | Type | Description |
|-----------|------|-------------|
| config | SkillConfig | Configuration object |
| context | any | Application context |

**SkillConfig Options:**
- `groupId` (required): Group identifier
- `userId` (optional): User identifier
- `serverUrl` (required): WebSocket server URL
- `maxRetries` (optional): Maximum retry attempts (default: 3)
- `timeout` (optional): Connection timeout in ms (default: 30000)
- `enablePersistence` (optional): Enable local storage (default: false)
- `maxConnections` (optional): Maximum concurrent connections (default: 5)

### runSkill(groupId, instruction)
Execute skill and establish WebSocket connection.

| Parameter | Type | Description |
|-----------|------|-------------|
| groupId | string | Group identifier |
| instruction | string | User skill instruction |

**Returns:** `Promise<SkillResponse>`

### closeSkill()
Close WebSocket session connection.

**Returns:** `SkillResponse`

### stopSkill()
Stop skill callback without closing connection.

**Returns:** `SkillResponse`

### getState()
Get current session state.

**Returns:** `SessionState | null`

**SessionState Properties:**
- `status`: 'idle' | 'executing' | 'stopped' | 'completed' | 'error'
- `sessionId`: Session identifier
- `groupId`: Group identifier
- `messageCount`: Number of messages
- `lastUpdateTime`: Last update timestamp
- `errorCode`: Error code (if error)
- `errorMessage`: Error message (if error)

### regenerate()
Regenerate response based on current instruction.

**Returns:** `Promise<SkillResponse>`

### getSessionMessage()
Get all session messages from history (with persistence support).

**Returns:** `Promise<SkillMessage[]>`

### sendMessage(content)
Send user input to trigger continuous response.

| Parameter | Type | Description |
|-----------|------|-------------|
| content | string | Message content |

**Returns:** `Promise<SkillResponse>`

### addMessageListener(listener)
Add message listener for real-time updates.

**MessageListener Interface:**
- `onMessage(message: SkillMessage)`: Called when message received
- `onError?(error: Error)`: Called on error
- `onStateChange?(state: SessionState)`: Called on state change

### getConnectionState()
Get current WebSocket connection state.

**Returns:** `ConnectionState | null`

**ConnectionState Properties:**
- `connectionCount`: Current active connections
- `maxConnections`: Maximum allowed connections
- `availableSlots`: Available connection slots

### reset()
Reset SDK and close all connections.

**Static method**

## Project Structure

```
harmony/
├── src/main/ets/
│   ├── api/index.ets          # SkillSDK main entry
│   ├── core/
│   │   ├── SessionManager.ets # Session management
│   │   └── WebSocketManager.ets # WebSocket connection management
│   ├── storage/
│   │   └── PreferenceStorage.ets # Local persistence
│   ├── types/
│   │   └── index.ets          # Type definitions
│   ├── utils/
│   │   └── Logger.ets         # Logging utility
│   └── index.ets              # Module exports
├── example/
│   └── usage_example.ets      # Usage examples
├── oh-package.json            # Package configuration
└── README.md                  # Documentation
```

## License

Apache-2.0
