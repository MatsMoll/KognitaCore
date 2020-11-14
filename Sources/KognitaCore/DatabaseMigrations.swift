//
//  DatabaseMigrations.swift
//  Async
//
//  Created by Mats Mollestad on 12/04/2019.
//

import Vapor
import FluentKit

/// A class adding the different database migrations needed to run the application
public class DatabaseMigrations {

    /// Configs an `Application` with the correct migrations based on the `Enviroment`
    /// - Parameter app: The Application to config
    public static func migrationConfig(_ app: Application) {
        if Environment.get("CLEAN_SETUP_MIGRATIONS")?.lowercased() == "true" {
            setupTables(app.migrations)
            extraDatabase(migrations: app.migrations)
        }
        if Environment.get("VAPOR_MIGRATION")?.lowercased() == "true" {
//            app.migrations.add(User.Login.Log.Create())
//            app.migrations.add(LectureNote.TakingSession.Migrations.Create())
//            app.migrations.add(LectureNote.Migrations.NoteTakingSession())
//            app.migrations.add(LectureNote.RecapSession.Migrations.Create())
//            app.migrations.add(LectureNote.RecapSession.Migrations.CreateAssignedTask())
//            app.migrations.add(Exam.Migrations.Create())
//            app.migrations.add(TaskDatabaseModel.Migrations.ExamParent())
//            app.migrations.add(TaskSession.Pivot.Task.Migrations.Create())
//            app.migrations.add(ExamSession.Migrations.Create())
        }
        if app.environment != .testing {
            versionBump(app.migrations)
        }
    }

    /// Setup all the tables needed
    /// Assumes it is a clean database
    /// - Parameter migrations: The migration config to modify
    static func setupTables(_ migrations: Migrations) {

        migrations.add([
            User.Migrations.Create(),
            User.ResetPassword.Token.Migrations.Create(),
            User.Login.Token.Migrations.Create(),
            User.VerifyEmail.Token.Migrations.Create(),
            User.Login.Log.Create(),

            Subject.Migrations.Create(),
            Topic.Migrations.Create(),
            Subtopic.Migrations.Create(),

            Exam.Migrations.Create(),

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
            LectureNote.TakingSession.Migrations.Create(),
            LectureNote.Migrations.Create(),
            LectureNote.RecapSession.Migrations.Create(),
            LectureNote.RecapSession.Migrations.CreateAssignedTask(),

            TaskSolution.Migrations.Create(),
            TaskSolution.Pivot.Vote.Migrations.Create(),

            TaskSession.Migrations.Create(),
            PracticeSession.Migrations.Create(),
            PracticeSession.Pivot.Task.Migrations.Create(),
            PracticeSession.Pivot.Subtopic.Migrations.Create(),

            SubjectTest.Migrations.Create(),
            SubjectTest.Pivot.Task.Migrations.Create(),
            TestSession.Migrations.Create(),
            TaskSession.Pivot.Task.Migrations.Create(),

            TaskResult.Migrations.Create(),
            TaskSessionAnswer.Migrations.Create(),

            ExamSession.Migrations.Create()
        ])
    }

    static func extraDatabase(migrations: Migrations) {
//        migrations.add(migration: User.UnknownUserMigration.self, database: .psql)
    }

    static func versionBump(_ migrations: Migrations) {
//        migrations.add(migration: User.ViewedNotificationAtMigration.self, database: .psql)
    }
}
