//
//  QueryBuilder+all.swift
//  KognitaCore
//
//  Created by Mats Mollestad on 30/06/2020.
//

import FluentSQL

extension QueryBuilder {
    public func all<T: FluentKit.Model>(with joined: KeyPath<Model, ParentProperty<Model, T>>) -> EventLoopFuture<[Model]> {
        var models: [Result<Model, Error>] = []
        return self.all { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { modelResult in
                    let model = try modelResult.get()
                    model[keyPath: joined].value = try model.joined(T.self)
                    return model
            }
        }
    }

    public func all<A: FluentKit.Model, B: FluentKit.Model>(with joined: KeyPath<Model, ParentProperty<Model, A>>, _ joinedTwo: KeyPath<Model, OptionalParentProperty<Model, B>>) -> EventLoopFuture<[Model]> {
        var models: [Result<Model, Error>] = []
        return self.all { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { modelResult in
                    let model = try modelResult.get()
                    model[keyPath: joined].value = try model.joined(A.self)
                    model[keyPath: joinedTwo].value = try? model.joined(B.self)
                    return model
            }
        }
    }

    public func all<A: FluentKit.Model, B: FluentKit.Model>(with joined: KeyPath<Model, ParentProperty<Model, A>>, _ joinedTwo: KeyPath<Model, ParentProperty<Model, B>>) -> EventLoopFuture<[Model]> {
        var models: [Result<Model, Error>] = []
        return self.all { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { modelResult in
                    let model = try modelResult.get()
                    model[keyPath: joined].value = try model.joined(A.self)
                    model[keyPath: joinedTwo].value = try model.joined(B.self)
                    return model
            }
        }
    }

    public func all<A: FluentKit.Model, B: FluentKit.Model>(with joined: KeyPath<Model, ParentProperty<Model, A>>, _ joinedTwo: KeyPath<A, ParentProperty<A, B>>) -> EventLoopFuture<[Model]> {
        var models: [Result<Model, Error>] = []
        return self.all { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { modelResult in
                    let model = try modelResult.get()
                    let joinedModel = try model.joined(A.self)
                    model[keyPath: joined].value = joinedModel
                    model[keyPath: joined].value![keyPath: joinedTwo].value = try joinedModel.joined(B.self)
                    return model
            }
        }
    }

    public func all<A: FluentKit.Model, B: FluentKit.Model, C: FluentKit.Model>(with joined: KeyPath<Model, ParentProperty<Model, A>>, _ joinedTwo: KeyPath<Model, ParentProperty<Model, B>>, _ joinedThree: KeyPath<B, ParentProperty<B, C>>) -> EventLoopFuture<[Model]> {
        var models: [Result<Model, Error>] = []
        return self.all { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { modelResult in
                    let model = try modelResult.get()
                    let joinedModel = try model.joined(B.self)
                    model[keyPath: joined].value = try joinedModel.joined(A.self)
                    model[keyPath: joinedTwo].value = joinedModel
                    model[keyPath: joinedTwo].value![keyPath: joinedThree].value = try joinedModel.joined(C.self)
                    return model
            }
        }
    }

    public func all<A: FluentKit.Model, B: FluentKit.Model, C: FluentKit.Model>(with joined: KeyPath<Model, ParentProperty<Model, A>>, _ joinedTwo: KeyPath<Model, ParentProperty<Model, B>>, _ joinedThree: KeyPath<Model, ParentProperty<Model, C>>) -> EventLoopFuture<[Model]> {
        var models: [Result<Model, Error>] = []
        return self.all { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { modelResult in
                    let model = try modelResult.get()
                    model[keyPath: joined].value = try model.joined(A.self)
                    model[keyPath: joinedTwo].value = try model.joined(B.self)
                    model[keyPath: joinedThree].value = try model.joined(C.self)
                    return model
            }
        }
    }
}
