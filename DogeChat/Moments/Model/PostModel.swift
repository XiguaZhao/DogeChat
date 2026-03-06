//
//  PostModel.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/3.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatCommonDefines

struct PostMedia: Codable, Equatable {
	enum MediaType: Int, Codable {
		case image = 1
		case video = 2
	}
	var mediaId: String?
	var mediaType: MediaType
	var mediaUrl: String
	var thumbnailUrl: String?
	var width: Int?
	var height: Int?
	var duration: Int?
}

struct PostComment: Codable, Equatable {
	var commentId: String?
	var userId: String
	var username: String
	var content: String
	var createdTime: String?
	var replyToUserId: String?
	var replyToUsername: String?
	var replyToCommentId: String?
}

struct LikeUser: Codable, Equatable {
	var avatarUrl: String?
	var username: String
	var userId: String
}

struct PostModel: Codable, Equatable {
	var momentId: String
	var userId: String
	var username: String
	var avatarUrl: String?
	var content: String
	var location: String?
	var visibility: Int = 0
	var createdTime: String?
	var mediaList: [PostMedia] = []
	var comments: [PostComment] = []
	var likeUsers: [LikeUser] = []
	// explicit state tracked locally for quick UI toggles
	var isLiked: Bool = false
    let isMine: Bool
	var likeCount: Int { likeUsers.count }
	var commentCount: Int { comments.count }
}

