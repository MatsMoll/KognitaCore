//
//  DatabaseMigrations.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL

public protocol SoftDeleatableModel: PostgreSQLModel {
    var createdAt: Date? { get set }
    var updatedAt: Date? { get set }
    var deletedAt: Date? { get set }
}

extension SoftDeleatableModel {
    public static var createdAtKey: TimestampKey? { return \Self.createdAt }
    public static var updatedAtKey: TimestampKey? { return \Self.updatedAt }
    public static var deletedAtKey: TimestampKey? { return \Self.deletedAt }
}

final class TestModel: SoftDeleatableModel {
    var id: Int?

    var createdAt: Date?

    var updatedAt: Date?

    var deletedAt: Date?
}

public class DatabaseMigrations {

    public static func migrationConfig() -> MigrationConfig {
        var migrations = MigrationConfig()
        setupTables(&migrations)
        versionBump(&migrations)
        return migrations
    }


    static func setupTables(_ migrations: inout MigrationConfig) {

        migrations.add(migration: Task.ExamSemester.self, database: .psql)
        migrations.add(migration: Subject.ColorClass.self, database: .psql)
        migrations.add(migration: User.Role.self, database: .psql)

        migrations.add(model: User.self, database: .psql)
        migrations.add(model: UserToken.self, database: .psql)
        migrations.add(model: Subject.self, database: .psql)
        migrations.add(model: Topic.self, database: .psql)
        migrations.add(model: Task.self, database: .psql)
        migrations.add(model: MultipleChoiseTask.self, database: .psql)
        migrations.add(model: MultipleChoiseTaskChoise.self, database: .psql)
        migrations.add(model: PracticeSession.self, database: .psql)
        migrations.add(model: PracticeSessionTaskPivot.self, database: .psql)
        migrations.add(model: PracticeSessionTopicPivot.self, database: .psql)
        migrations.add(model: NumberInputTask.self, database: .psql)
        migrations.add(model: FlashCardTask.self, database: .psql)
        migrations.add(model: TaskResult.self, database: .psql)
    }

    static func versionBump(_ migrations: inout MigrationConfig) {
        
    }
}
