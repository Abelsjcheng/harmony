# Skill SDK 接口文档

## 概述

本文档描述了用于IM客户端、OpenCode Skill服务端、小程序间交互的鸿蒙ArkTS SDK接口定义。

---

## 1. 执行技能接口

### 接口说明

与Skill服务端建立WebSocket会话连接，接收群组ID和用户输入的Skill指令内容，触发会话开始。该接口支持停止生成、重试、多轮对话等操作。

### 接口名

```typescript
executeSkill(groupId: string, skillContent: string): Promise<SkillSession>
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| chatId | string | 是 | 群组/单聊ID，用于标识当前会话 |
| skillContent | string | 是 | 用户输入的Skill指令内容，即用户发起技能请求的输入 |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| sessionId | string | 会话ID，用于后续对该会话进行操作 |
| status | SessionStatus | 当前会话状态 |

---

## 2. 关闭技能接口

### 接口说明

关闭与Skill服务端的WebSocket会话连接，释放资源。

### 接口名

```typescript
closeSkill(sessionId: string): Promise<boolean>
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 要关闭的会话ID |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| success | boolean | 关闭是否成功 |

---

## 3. 停止技能接口

### 接口说明

停止Skill服务端WebSocket会话的持续回调，中断当前正在进行的回答生成，但保持会话连接。

### 接口名

```typescript
stopSkill(sessionId: string): Promise<boolean>
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 要停止的会话ID |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| success | boolean | 停止操作是否成功 |

---

## 4. 会话状态回调接口

### 接口说明

获取会话状态的实时回调，包括执行中、停止、完成三种状态。通过注册回调函数的方式获取状态变化通知。

### 接口名

```typescript
onSessionStatus(sessionId: string, callback: (status: SessionStatus) => void): void
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 会话ID |
| callback | function | 是 | 状态变更回调函数 |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| status | SessionStatus | 会话状态，枚举值：executing（执行中）、stopped（停止）、completed（完成） |

---

## 5. 重新生成问答接口

### 接口说明

根据当前指令内容重新生成回答，用于用户对回答结果不满意时触发重新回答。

### 接口名

```typescript
regenerateAnswer(sessionId: string): Promise<AnswerResult>
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 会话ID |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| answer | string | 重新生成的回答内容 |
| messageId | string | 消息ID，用于标识该回答 |

---

## 6. 获取当前会话所有历史记录接口

### 接口名

```typescript
getSessionHistory(sessionId: string, persist?: boolean): Promise<Array<ChatMessage>>
```

### 接口说明

获取当前会话的所有历史记录，可选择是否将数据持久化存储到本地。

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 会话ID |
| persist | boolean | 否 | 是否本地持久化存储该数据，默认false |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| messages | Array<ChatMessage> | 历史消息列表，包含用户消息和AI回答 |

---

## 7. 发送消息接口

### 接口说明

发送用户输入的内容，触发会话的持续回答，用于多轮对话场景。

### 接口名

```typescript
sendMessage(sessionId: string, content: string): Promise<boolean>
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 会话ID |
| content | string | 是 | 用户输入的消息内容 |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| success | boolean | 发送是否成功 |

---

## 8. 消息监听接口

### 接口说明

持续获取会话的回答，通过注册监听器的方式实时接收服务端推送的回答内容。

### 接口名

```typescript
onMessage(sessionId: string, listener: (message: StreamMessage) => void): void
```

### 入参

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| sessionId | string | 是 | 会话ID |
| listener | function | 是 | 消息监听回调函数 |

### 出参

| 参数名 | 类型 | 说明 |
|--------|------|------|
| content | string | 回答内容片段 |
| messageId | string | 消息ID |
| isFinished | boolean | 是否已完成回答 |
| timestamp | number | 消息时间戳 |

---

## 数据类型定义

### SessionStatus

| 枚举值 | 说明 |
|--------|------|
| executing | 执行中 |
| stopped | 已停止 |
| completed | 已完成 |

### ChatMessage

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 消息ID |
| role | string | 角色：user（用户）/ assistant（AI） |
| content | string | 消息内容 |
| timestamp | number | 消息时间戳 |

### StreamMessage

| 字段 | 类型 | 说明 |
|------|------|------|
| messageId | string | 消息ID |
| content | string | 回答内容 |
| isFinished | boolean | 是否完成 |
| timestamp | number | 时间戳 |

### SkillSession

| 字段 | 类型 | 说明 |
|------|------|------|
| sessionId | string | 会话ID |
| status | SessionStatus | 会话状态 |
| groupId | string | 群组ID |
| createdAt | number | 创建时间 |
