import Vapor

extension SubjectTest {
    public enum Enter {
        public struct Request: Decodable {
            let password: String
            let expectedScore: Int?
        }
    }
}
