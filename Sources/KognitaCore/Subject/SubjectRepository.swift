//
//  SubjectRepository.swift
//  App
//
//  Created by Mats Mollestad on 02/03/2019.
//

import Vapor
import FluentPostgreSQL

public protocol SubjectRepositoring:
    CreateModelRepository,
    UpdateModelRepository,
    DeleteModelRepository,
    RetriveAllModelsRepository
    where
    Model           == Subject,
    CreateData      == Subject.Create.Data,
    CreateResponse  == Subject.Create.Response,
    UpdateData      == Subject.Edit.Data,
    UpdateResponse  == Subject.Edit.Response,
    ResponseModel   == Subject
{}

extension Subject {
    
    public enum Create {
        public struct Data : Content {
            let name: String
            let colorClass: Subject.ColorClass
            let description: String
            let category: String
        }
        
        public typealias Response = Subject
    }
    
    public typealias Edit = Create
}
