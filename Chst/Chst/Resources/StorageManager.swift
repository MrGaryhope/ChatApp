//
//  StorageManager.swift
//  Chst
//
//  Created by Егор Максимов on 17.11.2021.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    /// Upload picture to Firebase storage and returns a url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: {metadata, error in
            guard error == nil else {
                //failed
                completion(.failure(StorageErrors.failedToUpload))
                return print("Failed to upload data to Firebase for picture")
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else {
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return print("Failed to get download URL")
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    public func downloadURL(for path: String, completeon: @escaping (Result<URL, Error>) -> Void ) {
        let reference = storage.child(path)
        reference.downloadURL(completion: {url, error in
            guard let url = url, error == nil else {
                return completeon(.failure(StorageErrors.failedToGetDownloadURL))
            }
            completeon(.success(url))
        })
    }
    
    ///Upload image that will be sent in a conversation message
    public func uploadmessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: {metadata, error in
            guard error == nil else {
                //failed
                completion(.failure(StorageErrors.failedToUpload))
                return print("Failed to upload data to Firebase for picture")
            }
            
            self.storage.child("message_images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else {
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return print("Failed to get download URL")
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
}
