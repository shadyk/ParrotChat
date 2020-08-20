//
//  Created by Shady
//  All rights reserved.
//

import XCTest
@testable import ParrotChat

extension User{
    func toLocal() -> LocalUser{
        return LocalUser(name: self.name, imageName: self.imageName, lastMessage: self.lastMessage.toLocal())
    }
}

extension Message{
    func toLocal() -> LocalMessage{
        return LocalMessage(body: self.body, date: self.date, isMyMessage: self.isMyMessage)
    }
}

struct LocalUser : Equatable{
    static func == (lhs: LocalUser, rhs: LocalUser) -> Bool {
        return lhs.name == rhs.name
    }
    var name : String
    var imageName : String
    var lastMessage : LocalMessage
}

struct LocalMessage {
    var body : String
    var date : Date
    var isMyMessage : Bool
}

protocol UserStore{
    typealias InsertionCompletion =  (InsertionResult) -> Void
    typealias InsertionResult = Result<Void, Error>

    func insert(user:LocalUser, completion: @escaping InsertionCompletion)
}

class UserSaver {

    let store : UserStore
    typealias InsertionResult = Result<Void, Error>

    init(_ store:UserStore){
        self.store = store
    }

    func save(user:User,completion:@escaping(InsertionResult)->Void){
        store.insert(user: user.toLocal()){result in
            switch result {
            case .success(()):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }

        }
    }


}


class ParrotChatTests: XCTestCase {

    func test_init_doesntInvokeStoreWhenCreated(){

        let (_, store) = makeSUT()
        XCTAssertEqual(store.receivedInvocations.count, 0)
    }

    func test_save_withError(){
        let (sut,store) = makeSUT()

        let exp = expectation(description: "Wait for save completion")

        let anyError =  NSError(domain: "", code: 1, userInfo: nil)
        var receivedError : Error?
        
        sut.save(user:anyUser().model){result in
            if case let Result.failure(error) = result {
                receivedError = error
            }
        }
        exp.fulfill()

        store.completeWithInsertionError(withError: anyError)
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(receivedError! as NSError, anyError)
    }

    func test_save_successfully(){
        let (sut,store) = makeSUT()
        let user = anyUser()
        let exp = expectation(description: "Wait for save completion")

        sut.save(user:user.model){_ in
            exp.fulfill()
        }
        store.completeWithInsertionSuccess(user: user.local)
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(store.receivedInvocations, [.insert(user.local)])
    }



    //HELERPS
    func makeSUT() -> (userSaver:UserSaver, store:UserStoreSpy){
        let store = UserStoreSpy()
        let sut = UserSaver(store)

        return (sut,store)
    }

    func anyUser() -> (model:User,local:LocalUser){
        let model =  User(name: "user name", imageName: "image", lastMessage: Message(body: "body", date: Date(), isMyMessage: true))

        let local =  LocalUser(name: "user name", imageName: "image", lastMessage: LocalMessage(body: "body", date: Date(), isMyMessage: true))
        return(model,local)
    }

    class UserStoreSpy : UserStore{
        enum ReceivedInvocation : Equatable{
            case insert(LocalUser)
        }
        var receivedInvocations = [ReceivedInvocation]()

        private var insertionCompletions = [InsertionCompletion]()

        //MARK: User Store implemention
        func insert(user: LocalUser, completion: @escaping InsertionCompletion)  {
            insertionCompletions.append(completion)
            receivedInvocations.append(.insert(user))
        }

        //MARK: Spy's functions
        func completeWithInsertionError(withError error: Error, at index:Int = 0){
            insertionCompletions[index](.failure(error))
        }

        func completeWithInsertionSuccess(user:LocalUser, at index:Int = 0){
            insertionCompletions[index](.success(()))
        }
    }
}
