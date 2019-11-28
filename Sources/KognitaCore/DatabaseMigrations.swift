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
        versionBump(&migrations, enviroment: enviroment)
        return migrations
    }


    static func setupTables(_ migrations: inout MigrationConfig) {

        migrations.add(migration: Task.ExamSemester.self,           database: .psql)
        migrations.add(migration: Subject.ColorClass.self,          database: .psql)
        migrations.add(migration: User.Role.self,                   database: .psql)

        migrations.add(model: User.self,                            database: .psql)
        migrations.add(model: UserToken.self,                       database: .psql)
        migrations.add(model: User.ResetPassword.Token.self,        database: .psql)
        migrations.add(model: Subject.self,                         database: .psql)
        migrations.add(model: Topic.self,                           database: .psql)
//        migrations.add(model: Topic.Pivot.Preknowleged.self,        database: .psql)
        migrations.add(model: Subtopic.self,                        database: .psql)
        migrations.add(model: Task.self,                            database: .psql)
        migrations.add(model: TaskSolution.self,                    database: .psql)
        migrations.add(model: MultipleChoiseTask.self,              database: .psql)
        migrations.add(model: MultipleChoiseTaskChoise.self,        database: .psql)
        migrations.add(model: PracticeSession.self,                 database: .psql)
        migrations.add(model: PracticeSession.Pivot.Task.self,      database: .psql)
        migrations.add(model: PracticeSession.Pivot.Subtopic.self,  database: .psql)
        migrations.add(model: NumberInputTask.self,                 database: .psql)
        migrations.add(model: FlashCardTask.self,                   database: .psql)
        migrations.add(model: TaskResult.self,                      database: .psql)
        migrations.add(model: MultipleChoiseTaskAnswer.self,        database: .psql)
        migrations.add(model: FlashCardAnswer.self,                 database: .psql)
//        migrations.add(model: WorkPoints.self,                      database: .psql)
    }

    static func versionBump(_ migrations: inout MigrationConfig, enviroment: Environment) {
        guard enviroment != .testing else { return }
        migrations.add(migration: TaskSolution.ConvertMigration.self, database: .psql)
//        migrations.add(migration: TaskResultWorkPointsMigration.self, database: .psql)
    }
}
