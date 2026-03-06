# 朋友圈API设计说明文档

## 概述

本文档基于现有朋友圈功能实现，详细说明了朋友圈相关的所有API接口，包括接口说明、用法、字段说明和curl用例。

**接口状态说明：**
- ✅ **正在使用** - 前端和后端都已实现并正在使用
- ⚠️ **已实现未使用** - 后端已实现但前端暂未调用
- ❌ **未实现** - 仅在文档中设计，代码中未实现

## 目录

1. [动态管理接口](#动态管理接口)
2. [交互功能接口](#交互功能接口)
3. [通知管理接口](#通知管理接口)
4. [数据模型说明](#数据模型说明)
5. [WebSocket推送](#websocket推送)

---

## 动态管理接口

### 1.1 发布朋友圈动态 ✅ **正在使用**

**接口地址：** `POST /moment/publish`

**接口说明：** 发布一条新的朋友圈动态，支持文字、图片、视频、位置信息等。

**前端调用位置：** `MomentPublish.vue` - `momentApi.publishMoment()`
**后端实现：** `MomentController.publishMoment()`

**请求头：**
```
Content-Type: application/json
Authorization: Bearer {token}
```

**请求参数：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| content | String | 否 | 文字内容 |
| location | String | 否 | 位置信息 |
| visibility | Integer | 是 | 可见性：0-所有人，1-仅好友，2-私密，3-部分可见，4-不给谁看 |
| allowComment | Integer | 否 | 是否允许评论：0-不允许，1-允许，默认1 |
| remindWho | Array<String> | 否 | 提醒谁看的用户ID列表 |
| visibleToUsers | Array<String> | 否 | 部分可见的用户ID列表（visibility=3时使用） |
| invisibleToUsers | Array<String> | 否 | 不给谁看的用户ID列表（visibility=4时使用） |
| mediaList | Array<Object> | 否 | 媒体文件列表 |

**mediaList对象结构：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mediaType | Integer | 是 | 媒体类型：1-图片，2-视频 |
| mediaUrl | String | 是 | 媒体文件URL |
| thumbnailUrl | String | 否 | 缩略图URL（视频用） |
| width | Integer | 否 | 宽度 |
| height | Integer | 否 | 高度 |
| duration | Integer | 否 | 时长（秒，视频用） |
| fileSize | Long | 否 | 文件大小（字节） |
| sortOrder | Integer | 否 | 排序顺序 |
**请求示例：**
```json
{
  "content": "今天天气真好！@张三 一起出去玩吧",
  "location": "杭州市西湖区",
  "visibility": 1,
  "allowComment": 1,
  "mediaList": [
    {
      "mediaType": 1,
      "mediaUrl": "/static/image/moment/user123_1709876543210.jpg",
      "width": 1080,
      "height": 1920,
      "fileSize": 2048576,
      "sortOrder": 0
    }
  ]
}
```

**响应示例：**
```json
{
  "status": "success",
  "message": "发布成功",
  "momentId": "1234567890123456789"
}
```

**curl用例：**
```bash
curl -X POST "http://localhost:8080/moment/publish" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_token_here" \
  -d '{
    "content": "今天天气真好！",
    "location": "杭州市西湖区",
    "visibility": 1,
    "allowComment": 1,
    "mediaList": [
      {
        "mediaType": 1,
        "mediaUrl": "/static/image/moment/user123_1709876543210.jpg",
        "width": 1080,
        "height": 1920,
        "fileSize": 2048576,
        "sortOrder": 0
      }
    ]
  }'
```

### 1.2 删除朋友圈动态 ✅ **正在使用**

**接口地址：** `DELETE /moment/{momentId}`

**接口说明：** 删除指定的朋友圈动态（软删除）。

**前端调用位置：** `MomentsList.vue` - `momentApi.deleteMoment()`
**后端实现：** `MomentController.deleteMoment()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| momentId | Long | 是 | 动态ID |

**响应示例：**
```json
{
  "status": "success",
  "message": "删除成功"
}
```

**curl用例：**
```bash
curl -X DELETE "http://localhost:8080/moment/1234567890123456789" \
  -H "Authorization: Bearer your_token_here"
```
### 1.3 获取朋友圈时间线 ✅ **正在使用**

**接口地址：** `GET /moment/timeline`

**接口说明：** 获取当前用户的朋友圈时间线，包括自己和好友的动态。

**前端调用位置：** `MomentsList.vue` - `momentApi.getTimeline()`
**后端实现：** `MomentController.getTimeline()`

**查询参数：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | Integer | 否 | 1 | 页码 |
| size | Integer | 否 | 10 | 每页数量 |

**响应示例：**
```json
{
  "status": "success",
  "data": [
    {
      "momentId": "1234567890123456789",
      "userId": "user123",
      "username": "张三",
      "avatarUrl": "/static/avatar/user123.jpg",
      "content": "今天天气真好！",
      "location": "杭州市西湖区",
      "visibility": 1,
      "allowComment": 1,
      "likeCount": 5,
      "commentCount": 3,
      "viewCount": 20,
      "createdTime": "2026-03-05 14:30:00",
      "mediaList": [
        {
          "mediaId": "9876543210987654321",
          "mediaType": 1,
          "mediaUrl": "/static/image/moment/user123_1709876543210.jpg",
          "width": 1080,
          "height": 1920,
          "sortOrder": 0
        }
      ],
      "likeUsers": [
        {
          "userId": "user456",
          "username": "李四",
          "avatarUrl": "/static/avatar/user456.jpg"
        }
      ],
      "comments": [
        {
          "commentId": "1111111111111111111",
          "userId": "user456",
          "username": "李四",
          "avatarUrl": "/static/avatar/user456.jpg",
          "content": "确实不错！",
          "createdTime": "2026-03-05 14:35:00",
          "isMine": false
        }
      ],
      "isLiked": false,
      "isMine": true
    }
  ],
  "page": 1,
  "size": 10,
  "hasMore": true
}
```

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/timeline?page=1&size=10" \
  -H "Authorization: Bearer your_token_here"
```
### 1.4 获取某个用户的朋友圈 ⚠️ **已实现未使用**

**接口地址：** `GET /moment/user/{userId}`

**接口说明：** 获取指定用户的朋友圈动态列表。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.getUserMoments()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| userId | String | 是 | 用户ID |

**查询参数：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | Integer | 否 | 1 | 页码 |
| size | Integer | 否 | 10 | 每页数量 |

**响应示例：** 同时间线接口

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/user/user123?page=1&size=10" \
  -H "Authorization: Bearer your_token_here"
```

### 1.5 获取动态详情 ⚠️ **已实现未使用**

**接口地址：** `GET /moment/{momentId}`

**接口说明：** 获取指定动态的详细信息。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.getMomentDetail()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| momentId | Long | 是 | 动态ID |

**响应示例：** 返回单个动态对象，结构同时间线接口中的data数组元素

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/1234567890123456789" \
  -H "Authorization: Bearer your_token_here"
```

---

## 交互功能接口

### 2.1 点赞/取消点赞 ✅ **正在使用**

**接口地址：** `POST /moment/{momentId}/like`

**接口说明：** 对指定动态进行点赞或取消点赞操作。

**前端调用位置：** `MomentsList.vue` - `momentApi.toggleLike()`
**后端实现：** `MomentController.toggleLike()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| momentId | Long | 是 | 动态ID |

**响应示例：**
```json
{
  "status": "success",
  "action": "like",
  "message": "点赞成功"
}
```

**curl用例：**
```bash
curl -X POST "http://localhost:8080/moment/1234567890123456789/like" \
  -H "Authorization: Bearer your_token_here" \
  -H "Content-Type: application/json" \
  -d '{}'
```
### 2.2 添加评论 ✅ **正在使用**

**接口地址：** `POST /moment/{momentId}/comment`

**接口说明：** 对指定动态添加评论，支持@功能和回复评论。

**前端调用位置：** `MomentsList.vue` - `momentApi.addComment()`
**后端实现：** `MomentController.addComment()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| momentId | Long | 是 | 动态ID |

**请求参数：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| content | String | 是 | 评论内容 |
| mentionedUsers | Array<String> | 否 | 被@的用户ID列表 |
| replyToUserId | String | 否 | 回复的用户ID（回复评论时必填） |
| replyToCommentId | Long | 否 | 回复的评论ID（回复评论时必填） |

**请求示例：**

**场景1：直接评论动态**
```json
{
  "content": "@张三 @李四 你们看看这个",
  "mentionedUsers": ["userId1", "userId2"]
}
```

**场景2：回复某条评论**
```json
{
  "content": "我也觉得不错",
  "replyToUserId": "userId3",
  "replyToCommentId": 789
}
```

**场景3：回复评论并@其他人**
```json
{
  "content": "@张三 你怎么看？",
  "mentionedUsers": ["userId1"],
  "replyToUserId": "userId3",
  "replyToCommentId": 789
}
```

**响应示例：**
```json
{
  "status": "success",
  "message": "评论成功",
  "commentId": "1111111111111111111"
}
```

**curl用例：**
```bash
curl -X POST "http://localhost:8080/moment/1234567890123456789/comment" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_token_here" \
  -d '{
    "content": "@张三 你看看这个",
    "mentionedUsers": ["user123"]
  }'
```
### 2.3 删除评论 ⚠️ **已实现未使用**

**接口地址：** `DELETE /moment/comment/{commentId}`

**接口说明：** 删除指定的评论（评论者或动态发布者可删除）。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.deleteComment()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| commentId | Long | 是 | 评论ID |

**响应示例：**
```json
{
  "status": "success",
  "message": "删除成功"
}
```

**curl用例：**
```bash
curl -X DELETE "http://localhost:8080/moment/comment/1111111111111111111" \
  -H "Authorization: Bearer your_token_here"
```

### 2.4 获取点赞列表 ⚠️ **已实现未使用**

**接口地址：** `GET /moment/{momentId}/likes`

**接口说明：** 获取指定动态的点赞用户列表。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.getLikes()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| momentId | Long | 是 | 动态ID |

**查询参数：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | Integer | 否 | 1 | 页码 |
| size | Integer | 否 | 20 | 每页数量 |

**响应示例：**
```json
{
  "status": "success",
  "data": [
    {
      "userId": "user123",
      "username": "张三",
      "avatarUrl": "/static/avatar/user123.jpg"
    },
    {
      "userId": "user456",
      "username": "李四",
      "avatarUrl": "/static/avatar/user456.jpg"
    }
  ],
  "page": 1,
  "size": 20,
  "hasMore": false
}
```

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/1234567890123456789/likes?page=1&size=20" \
  -H "Authorization: Bearer your_token_here"
```
### 2.5 获取评论列表 ⚠️ **已实现未使用**

**接口地址：** `GET /moment/{momentId}/comments`

**接口说明：** 获取指定动态的评论列表，包含@用户信息。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.getComments()`

**注意：** 当前前端在获取时间线时已包含评论数据，暂未单独调用此接口

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| momentId | Long | 是 | 动态ID |

**查询参数：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | Integer | 否 | 1 | 页码 |
| size | Integer | 否 | 20 | 每页数量 |

**响应示例：**
```json
{
  "status": "success",
  "data": [
    {
      "commentId": "1111111111111111111",
      "momentId": "1234567890123456789",
      "userId": "user123",
      "username": "张三",
      "avatarUrl": "/static/avatar/user123.jpg",
      "replyToUserId": null,
      "replyToUsername": null,
      "replyToCommentId": null,
      "content": "@李四 @王五 你们看看这个",
      "mentionedUsers": ["user456", "user789"],
      "mentionedUserInfos": [
        {
          "userId": "user456",
          "username": "李四",
          "avatarUrl": "/static/avatar/user456.jpg"
        },
        {
          "userId": "user789",
          "username": "王五",
          "avatarUrl": "/static/avatar/user789.jpg"
        }
      ],
      "createdTime": "2026-03-05 14:35:00",
      "isMine": false
    }
  ],
  "page": 1,
  "size": 20,
  "hasMore": false
}
```

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/1234567890123456789/comments?page=1&size=20" \
  -H "Authorization: Bearer your_token_here"
```

---

## 通知管理接口

### 3.1 获取朋友圈通知 ⚠️ **已实现未使用**

**接口地址：** `GET /moment/notifications`

**接口说明：** 获取当前用户的朋友圈相关通知列表。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.getNotifications()`

**查询参数：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | Integer | 否 | 1 | 页码 |
| size | Integer | 否 | 20 | 每页数量 |
**响应示例：**
```json
{
  "status": "success",
  "data": [
    {
      "notificationId": 123,
      "momentId": "1234567890123456789",
      "fromUserId": "user123",
      "fromUsername": "张三",
      "fromAvatarUrl": "/static/avatar/user123.jpg",
      "notificationType": 4,
      "content": "在评论中@了你",
      "isRead": 0,
      "createdTime": "2026-03-05 14:35:00",
      "momentContent": "今天天气真好！",
      "momentFirstImageUrl": "/static/image/moment/user123_1709876543210.jpg"
    }
  ],
  "page": 1,
  "size": 20,
  "hasMore": false
}
```

**通知类型说明：**

| 类型值 | 说明 | 触发条件 |
|--------|------|----------|
| 1 | 点赞通知 | 有人点赞了你的朋友圈 |
| 2 | 评论通知 | 有人评论了你的朋友圈 |
| 3 | 回复通知 | 有人回复了你的评论 |
| 4 | @提醒通知 | 有人在评论中@了你 |

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/notifications?page=1&size=20" \
  -H "Authorization: Bearer your_token_here"
```

### 3.2 标记通知为已读 ⚠️ **已实现未使用**

**接口地址：** `PUT /moment/notifications/{notificationId}/read`

**接口说明：** 标记指定通知为已读状态。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.markNotificationAsRead()`

**路径参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| notificationId | Long | 是 | 通知ID |

**响应示例：**
```json
{
  "status": "success",
  "message": "标记成功"
}
```

**curl用例：**
```bash
curl -X PUT "http://localhost:8080/moment/notifications/123/read" \
  -H "Authorization: Bearer your_token_here" \
  -H "Content-Type: application/json" \
  -d '{}'
```
### 3.3 标记所有通知为已读 ⚠️ **已实现未使用**

**接口地址：** `PUT /moment/notifications/read-all`

**接口说明：** 标记当前用户的所有朋友圈通知为已读状态。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.markAllNotificationsAsRead()`

**响应示例：**
```json
{
  "status": "success",
  "message": "全部标记成功"
}
```

**curl用例：**
```bash
curl -X PUT "http://localhost:8080/moment/notifications/read-all" \
  -H "Authorization: Bearer your_token_here" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### 3.4 获取未读通知数量 ⚠️ **已实现未使用**

**接口地址：** `GET /moment/notifications/unread-count`

**接口说明：** 获取当前用户的未读朋友圈通知数量。

**前端调用位置：** `momentApi.js` 中已定义但前端组件暂未调用
**后端实现：** `MomentController.getUnreadNotificationCount()`

**响应示例：**
```json
{
  "status": "success",
  "count": 5
}
```

**curl用例：**
```bash
curl -X GET "http://localhost:8080/moment/notifications/unread-count" \
  -H "Authorization: Bearer your_token_here"
```

---

## 数据模型说明

### 5.1 朋友圈动态对象 (MomentDTO)

| 字段 | 类型 | 说明 |
|------|------|------|
| momentId | String | 动态ID |
| userId | String | 发布者用户ID |
| username | String | 发布者用户名 |
| avatarUrl | String | 发布者头像URL |
| content | String | 文字内容 |
| location | String | 位置信息 |
| visibility | Integer | 可见性：0-所有人，1-仅好友，2-私密，3-部分可见，4-不给谁看 |
| allowComment | Integer | 是否允许评论：0-不允许，1-允许 |
| likeCount | Integer | 点赞数 |
| commentCount | Integer | 评论数 |
| viewCount | Integer | 浏览数 |
| createdTime | String | 发布时间 |
| mediaList | Array | 媒体文件列表 |
| likeUsers | Array | 点赞用户列表（最多显示前10个） |
| comments | Array | 评论列表（最多显示前10条） |
| isLiked | Boolean | 当前用户是否已点赞 |
| isMine | Boolean | 是否是自己的动态 |

### 5.2 媒体文件对象 (MomentMediaDTO)

| 字段 | 类型 | 说明 |
|------|------|------|
| mediaId | String | 媒体ID |
| mediaType | Integer | 媒体类型：1-图片，2-视频 |
| mediaUrl | String | 媒体文件URL |
| thumbnailUrl | String | 缩略图URL（视频用） |
| width | Integer | 宽度 |
| height | Integer | 高度 |
| duration | Integer | 时长（秒，视频用） |
| fileSize | Long | 文件大小（字节） |
| sortOrder | Integer | 排序顺序 |

### 5.3 评论对象 (MomentCommentDTO)

| 字段 | 类型 | 说明 |
|------|------|------|
| commentId | String | 评论ID |
| momentId | String | 动态ID |
| userId | String | 评论用户ID |
| username | String | 评论用户名 |
| avatarUrl | String | 评论用户头像 |
| replyToUserId | String | 回复的用户ID |
| replyToUsername | String | 回复的用户名 |
| replyToCommentId | String | 回复的评论ID |
| content | String | 评论内容 |
| mentionedUsers | Array<String> | @的用户ID列表 |
| mentionedUserInfos | Array<Object> | @的用户详细信息 |
| createdTime | String | 评论时间 |
| isMine | Boolean | 是否是自己的评论 |
### 5.4 通知对象 (MomentNotificationDTO)

| 字段 | 类型 | 说明 |
|------|------|------|
| notificationId | Long | 通知ID |
| momentId | String | 动态ID |
| fromUserId | String | 触发通知的用户ID |
| fromUsername | String | 触发通知的用户名 |
| fromAvatarUrl | String | 触发通知的用户头像 |
| notificationType | Integer | 通知类型：1-点赞，2-评论，3-回复，4-@提醒 |
| content | String | 通知内容 |
| isRead | Integer | 是否已读：0-未读，1-已读 |
| createdTime | String | 创建时间 |
| momentContent | String | 动态内容摘要 |
| momentFirstImageUrl | String | 动态首图URL |

### 5.5 用户简单信息对象 (UserSimpleDTO)

| 字段 | 类型 | 说明 |
|------|------|------|
| userId | String | 用户ID |
| username | String | 用户名 |
| avatarUrl | String | 头像URL |

---

## WebSocket推送

### 6.1 朋友圈通知推送 ✅ **正在使用**

**推送时机：** 当用户收到朋友圈相关通知时（点赞、评论、回复、@提醒）

**后端实现：** `MomentInteractionServiceImpl.pushMomentNotification()`
**前端接收：** WebSocket连接中接收 `momentNotification` 方法

**推送格式：**
```json
{
  "method": "momentNotification",
  "data": {
    "notificationId": 123,
    "momentId": "1234567890123456789",
    "fromUserId": "user123",
    "fromUsername": "张三",
    "fromAvatarUrl": "/static/avatar/user123.jpg",
    "notificationType": 4,
    "content": "在评论中@了你",
    "createdTime": "2026-03-05 14:35:00"
  }
}
```

### 6.2 通知去重逻辑

后端会自动处理通知去重，确保每个用户只收到一次通知：

- 如果用户既是动态发布者，又被@了，只收到一次通知
- 如果用户既是被回复者，又被@了，只收到一次通知
- 评论者不会收到自己的通知

---

## 错误码说明

### 7.1 通用错误码

| 状态 | 说明 |
|------|------|
| success | 操作成功 |
| fail | 操作失败 |

### 7.2 常见错误信息

| 错误信息 | 说明 | 解决方案 |
|----------|------|----------|
| 动态不存在 | 指定的动态ID不存在或已删除 | 检查动态ID是否正确 |
| 无权删除此动态 | 当前用户不是动态发布者 | 只有动态发布者可以删除动态 |
| 该动态不允许评论 | 动态设置了不允许评论 | 无法对此动态进行评论 |
| 评论不存在 | 指定的评论ID不存在或已删除 | 检查评论ID是否正确 |
| 无权删除此评论 | 当前用户既不是评论者也不是动态发布者 | 只有评论者或动态发布者可以删除评论 |
| 文件不能为空 | 上传文件为空 | 请选择要上传的文件 |
| 文件大小不能超过50MB | 上传文件过大 | 请压缩文件后重新上传 |
| 通知不存在 | 指定的通知ID不存在 | 检查通知ID是否正确 |
| 无权操作此通知 | 当前用户不是通知接收者 | 只能操作自己的通知 |
---

## 接口使用状态总结

### ✅ 正在使用的接口（6个）

1. **POST /moment/publish** - 发布朋友圈动态
2. **DELETE /moment/{momentId}** - 删除朋友圈动态  
3. **GET /moment/timeline** - 获取朋友圈时间线
4. **POST /moment/{momentId}/like** - 点赞/取消点赞
5. **POST /moment/{momentId}/comment** - 添加评论
6. **WebSocket momentNotification** - 朋友圈通知推送

### ⚠️ 已实现未使用的接口（7个）

1. **GET /moment/user/{userId}** - 获取某个用户的朋友圈
2. **GET /moment/{momentId}** - 获取动态详情
3. **DELETE /moment/comment/{commentId}** - 删除评论
4. **GET /moment/{momentId}/likes** - 获取点赞列表
5. **GET /moment/{momentId}/comments** - 获取评论列表
6. **GET /moment/notifications** - 获取朋友圈通知
7. **PUT /moment/notifications/{notificationId}/read** - 标记通知为已读
8. **PUT /moment/notifications/read-all** - 标记所有通知为已读
9. **GET /moment/notifications/unread-count** - 获取未读通知数量

### 📝 特殊说明

- **媒体上传**：前端使用 `/message/uploadImg` 接口上传朋友圈图片
- **评论列表**：前端在获取时间线时已包含评论数据，暂未单独调用评论列表接口
- **通知功能**：后端通知系统已完整实现，包括WebSocket推送，但前端通知UI暂未开发

---

## 数据库表结构

### 8.1 核心表结构

**朋友圈动态表 (tbl_moment)**
```sql
CREATE TABLE `tbl_moment` (
  `moment_id` bigint(20) NOT NULL COMMENT '动态ID',
  `user_id` varchar(255) NOT NULL COMMENT '发布者用户ID',
  `content` text COMMENT '文字内容',
  `location` varchar(255) DEFAULT NULL COMMENT '位置信息',
  `visibility` int(1) NOT NULL DEFAULT '0' COMMENT '可见性：0-所有人可见，1-仅好友可见，2-私密，3-部分可见，4-不给谁看',
  `allow_comment` int(1) NOT NULL DEFAULT '1' COMMENT '是否允许评论：0-不允许，1-允许',
  `remind_who` varchar(1000) DEFAULT NULL COMMENT '提醒谁看（用户ID列表，逗号分隔）',
  `like_count` int(11) NOT NULL DEFAULT '0' COMMENT '点赞数',
  `comment_count` int(11) NOT NULL DEFAULT '0' COMMENT '评论数',
  `view_count` int(11) NOT NULL DEFAULT '0' COMMENT '浏览数',
  `status` int(1) NOT NULL DEFAULT '1' COMMENT '状态：0-已删除，1-正常',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发布时间',
  `updated_time` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`moment_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_created_time` (`created_time`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='朋友圈动态表';
```

**朋友圈评论表 (tbl_moment_comment)**
```sql
CREATE TABLE `tbl_moment_comment` (
  `comment_id` bigint(20) NOT NULL,
  `moment_id` bigint(20) NOT NULL COMMENT '动态ID',
  `user_id` varchar(255) NOT NULL COMMENT '评论用户ID',
  `reply_to_user_id` varchar(255) DEFAULT NULL COMMENT '回复的用户ID',
  `reply_to_comment_id` bigint(20) DEFAULT NULL COMMENT '回复的评论ID',
  `content` text NOT NULL COMMENT '评论内容',
  `mentioned_users` text COMMENT '@的用户ID列表（JSON数组格式）',
  `status` int(1) NOT NULL DEFAULT '1' COMMENT '状态：0-已删除，1-正常',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '评论时间',
  PRIMARY KEY (`comment_id`),
  KEY `idx_moment_id` (`moment_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_reply_to_comment_id` (`reply_to_comment_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='朋友圈评论表';
```

**朋友圈通知表 (tbl_moment_notification)**
```sql
CREATE TABLE `tbl_moment_notification` (
  `notification_id` bigint(20) NOT NULL,
  `user_id` varchar(255) NOT NULL COMMENT '接收通知的用户ID',
  `moment_id` bigint(20) NOT NULL COMMENT '动态ID',
  `from_user_id` varchar(255) NOT NULL COMMENT '触发通知的用户ID',
  `notification_type` int(1) NOT NULL COMMENT '通知类型：1-点赞，2-评论，3-回复评论，4-@提醒',
  `content` varchar(500) DEFAULT NULL COMMENT '通知内容',
  `is_read` int(1) NOT NULL DEFAULT '0' COMMENT '是否已读：0-未读，1-已读',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`notification_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_moment_id` (`moment_id`),
  KEY `idx_is_read` (`is_read`),
  KEY `idx_created_time` (`created_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='朋友圈通知表';
```

---

## 使用注意事项

### 9.1 性能优化建议

1. **分页查询**：所有列表接口都支持分页，建议客户端合理设置页面大小
2. **图片压缩**：上传图片前建议进行适当压缩，提高上传速度
3. **缓存策略**：客户端可以缓存时间线数据，减少重复请求
4. **懒加载**：评论和点赞列表支持懒加载，按需获取数据

### 9.2 安全注意事项

1. **权限验证**：所有接口都需要用户认证，确保token有效性
2. **内容过滤**：客户端应对用户输入进行基本的内容过滤
3. **文件上传**：限制上传文件的类型和大小，防止恶意文件上传
4. **频率限制**：建议对发布动态、评论等操作进行频率限制

### 9.3 兼容性说明

1. **@功能**：mentionedUsers字段为可选，不传则表示没有@任何人
2. **旧版本兼容**：旧版本评论数据不包含mentionedUsers字段，需要做兼容处理
3. **时间格式**：所有时间字段统一使用"yyyy-MM-dd HH:mm:ss"格式
4. **ID格式**：所有ID字段使用Long类型，前端需要使用字符串处理避免精度丢失

---

## 更新日志

**v1.0 (2026-03-05)**
- 完整的朋友圈功能API设计
- 支持动态发布、删除、查看
- 支持点赞、评论、回复功能
- 支持@功能和实时通知推送
- 支持媒体文件上传
- 完善的权限控制和错误处理