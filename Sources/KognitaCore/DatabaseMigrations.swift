//
//  DatabaseMigrations.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import Vapor
import FluentKit

public class DatabaseMigrations {

    public static func migrationConfig(_ app: Application) {
        setupTables(app.migrations)
        extraDatabase(migrations: app.migrations)
        if app.environment != .testing {
            versionBump(app.migrations)
        }
    }

    static func setupTables(_ migrations: Migrations) {

//        migrations.add(migration: TaskDatabaseModel.ExamSemester.self, database: .psql)

        migrations.add([
            User.Migrations.Create(),
            User.ResetPassword.Token.Migrations.Create(),
            User.Login.Token.Migrations.Create(),
            User.VerifyEmail.Token.Migrations.Create(),

            Subject.Migrations.Create(),
            Topic.Migrations.Create(),
            Subtopic.Migrations.Create(),

            User.ActiveSubject.Migrations.Create(),
            User.ModeratorPrivilege.Migrations.Create(),

            TaskDatabaseModel.Migrations.Create(),
            FlashCardTask.Migrations.Create(),
            MultipleChoiceTask.Migrations.Create(),
            MultipleChoiseTaskChoise.Migrations.Create(),

            TaskDiscussion.Migrations.Create(),
            TaskDiscussionResponse.Migrations.Create(),

            TaskAnswer.Migrations.Create(),
            FlashCardAnswer.Migrations.Create(),
            MultipleChoiseTaskAnswer.Migrations.Create(),

            TaskSolution.Migrations.Create(),
            TaskSolution.Pivot.Vote.Migrations.Create(),

            TaskSession.Migrations.Create(),
            PracticeSession.Migrations.Create(),
            PracticeSession.Pivot.Task.Migrations.Create(),
            PracticeSession.Pivot.Subtopic.Migrations.Create(),

            SubjectTest.Migrations.Create(),
            SubjectTest.Pivot.Task.Migrations.Create(),
            TestSession.Migrations.Create(),

            TaskResult.Migrations.Create(),
            TaskSessionAnswer.Migrations.Create()
        ])
    }

    static func extraDatabase(migrations: Migrations) {
//        migrations.add(migration: User.UnknownUserMigration.self, database: .psql)
    }

    static func versionBump(_ migrations: Migrations) {
//        migrations.add(migration: User.ViewedNotificationAtMigration.self, database: .psql)
    }
}
