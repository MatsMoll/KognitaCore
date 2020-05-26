//
//  DatabaseMigrations.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import FluentPostgreSQL

public class DatabaseMigrations {

    public static func migrationConfig(enviroment: Environment) -> MigrationConfig {
        var migrations = MigrationConfig()
        setupTables(&migrations)
        extraDatabase(migrations: &migrations)
        versionBump(&migrations, enviroment: enviroment)
        return migrations
    }

    static func setupTables(_ migrations: inout MigrationConfig) {

        migrations.add(migration: Task.ExamSemester.self, database: .psql)

        migrations.add(model: User.DatabaseModel.self, database: .psql)
        migrations.add(model: User.Login.Token.DatabaseModel.self, database: .psql)
        migrations.add(model: User.ResetPassword.Token.self, database: .psql)
        migrations.add(model: User.VerifyEmail.Token.self, database: .psql)
        migrations.add(model: Subject.DatabaseModel.self, database: .psql)
        migrations.add(model: User.ModeratorPrivilege.self, database: .psql)
        migrations.add(model: User.ActiveSubject.self, database: .psql)
        migrations.add(model: Topic.DatabaseModel.self, database: .psql)
        migrations.add(model: Subtopic.DatabaseModel.self, database: .psql)
        migrations.add(model: Task.self, database: .psql)
        migrations.add(model: TaskDiscussion.DatabaseModel.self, database: .psql)
        migrations.add(model: TaskDiscussionResponse.DatabaseModel.self, database: .psql)
        migrations.add(model: TaskSolution.self, database: .psql)
        migrations.add(model: TaskSolution.Pivot.Vote.self, database: .psql)
        migrations.add(model: MultipleChoiseTask.self, database: .psql)
        migrations.add(model: MultipleChoiseTaskChoise.self, database: .psql)
        migrations.add(model: TaskSession.self, database: .psql)
        migrations.add(model: PracticeSession.DatabaseModel.self, database: .psql)
        migrations.add(model: PracticeSession.Pivot.Task.self, database: .psql)
        migrations.add(model: PracticeSession.Pivot.Subtopic.self, database: .psql)
        migrations.add(model: FlashCardTask.self, database: .psql)
        migrations.add(model: TaskResult.self, database: .psql)
        migrations.add(model: TaskAnswer.self, database: .psql)
        migrations.add(model: MultipleChoiseTaskAnswer.self, database: .psql)
        migrations.add(model: FlashCardAnswer.self, database: .psql)
        migrations.add(model: TestSession.DatabaseModel.self, database: .psql)
        migrations.add(model: SubjectTest.DatabaseModel.self, database: .psql)
        migrations.add(model: SubjectTest.Pivot.Task.self, database: .psql)
        migrations.add(model: TaskSessionAnswer.self, database: .psql)
    }

    static func extraDatabase(migrations: inout MigrationConfig) {
        migrations.add(migration: User.UnknownUserMigration.self, database: .psql)
    }

    static func versionBump(_ migrations: inout MigrationConfig, enviroment: Environment) {
        guard enviroment != .testing else { return }
        migrations.add(migration: User.ViewedNotificationAtMigration.self, database: .psql)
    }
}
