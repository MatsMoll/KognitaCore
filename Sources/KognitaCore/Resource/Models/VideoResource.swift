//
//  VideoResource.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 03/01/2021.
//

import FluentKit
import Foundation

extension VideoResource {
    final class DatabaseModel: Model {

        static var schema: String = "VideoResource"

        @DBID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "url")
        var url: String

        @Field(key: "creator")
        var creator: String

        @Field(key: "duration")
        var duration: Int

        init() {}

        init(id: Resource.ID, data: VideoResource.Create.Data) {
            self.id = id
            self.url = data.url
            self.creator = data.creator
            self.duration = data.duration
        }
    }
}

extension VideoResource {
    enum Migrations {
        struct Create: Migration {

            func prepare(on database: Database) -> EventLoopFuture<Void> {
                database.schema(VideoResource.DatabaseModel.schema)
                    .field("id", .uint, .identifier(auto: false), .references(Resource.DatabaseModel.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                    .field("url", .string, .required)
                    .field("creator", .string, .required)
                    .field("duration", .int, .required)
                    .create()
            }

            func revert(on database: Database) -> EventLoopFuture<Void> {
                database.schema(VideoResource.DatabaseModel.schema)
                    .delete()
            }
        }
    }
}
