//
//  DatabaseManager.swift
//  Chst
//
//  Created by Егор Максимов on 09.11.2021.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(with email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child(path).observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}

//MARK: - Account managment
extension DatabaseManager {
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    
    /// Insert new user to interface
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "firstName" : user.firstName,
            "lastName": user.lastName
        ], withCompletionBlock: {error, _ in
            guard error == nil else {
                completion(false)
                return print("Failed to write to database")
            }
            
            self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //append to users dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else {
                    //create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
            
            completion(true)
        })
    }
    
    public func getAllUsers(completion: @escaping(Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}


// MARK: - Sending messages/conversations
extension DatabaseManager {
    
    /// Create a new conversation with targetUserEmail and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = Self.safeEmail(with: currentEmail)
        let reference = database.child(safeEmail)
        reference.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                print("User not found")
                completion(false)
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ],
            ]
            
            let recipinet_newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ],
            ]
            
            //update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipinet_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    //create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipinet_newConversationData])
                }
            })
            
            //update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user -> should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                reference.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversations(name: name,
                                                      conversationID: conversationID,
                                                      firstMessage: firstMessage,
                                                      completion: completion)
                })
            } else {
                // conversation array does not exists -> create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                reference.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversations(name: name,
                                                      conversationID: conversationID,
                                                      firstMessage: firstMessage,
                                                      completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversations(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        {
//            "id": String,
//            "type": text, photo, video,
//            "content": String,
//            "date": Date(),
//            "sender_email": String,
//            "is_read": true/false
//        }
        var message = ""
        
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(with: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        database.child("\(conversationID)").setValue(value, withCompletionBlock: {error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationID = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                          return nil
                      }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationID, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    /// Get all messages with given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString),
                      let type = dictionary["type"] as? String else {
                          return nil
                      }
                
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageID, sentDate: date, kind: .text(content))
            })
            completion(.success(messages))
        })
    }
    
    /// Sends a message with targetConversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        //add new message to messages
        //update sender latest message
        //update recipient latest message
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(with: myEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {[weak self] snapshot in
            
            guard let strongSelf = self else {
                return
            }
            
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
             
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(with: myEmail)
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String: Any]] else {
                        completion(false)
                        return
                    }
                    
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    
                    var targetConversation: [String: Any]?
                    var position = 0
                    
                    for conversationDictionary in currentUserConversations {
                        if let currentID = conversationDictionary["id"] as? String, currentID == conversation {
                            targetConversation = conversationDictionary
                            break
                        }
                        position += 1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConversation = targetConversation else {
                        completion(false)
                        return
                    }
                    currentUserConversations[position] = finalConversation
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        //update latest message for recipient
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String: Any]] else {
                                completion(false)
                                return
                            }
                            
                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            
                            var targetConversation: [String: Any]?
                            var position = 0
                            
                            for conversationDictionary in otherUserConversations {
                                if let currentID = conversationDictionary["id"] as? String, currentID == conversation {
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else {
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            }
        })
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let email: String
    //unsafe to store unencrypted password
    //let password: String
    
    var safeEmail: String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        //egormaximov-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
}
