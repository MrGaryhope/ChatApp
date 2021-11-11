//
//  RegisterViewController.swift
//  Chst
//
//  Created by Егор Максимов on 07.11.2021.
//

import UIKit
import FirebaseAuth

class RegisterViewController: UIViewController {
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        //        imageView.image = UIImage(named: "Register")
        imageView.image = UIImage(systemName: "person.circle")
        imageView.tintColor = .gray
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        return imageView
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let firstNameField: UITextField = {
        let firstName = UITextField()
        firstName.autocapitalizationType = .none
        firstName.autocorrectionType = .no
        firstName.returnKeyType = .continue
        firstName.layer.cornerRadius = 12
        firstName.layer.borderWidth = 1
        firstName.layer.borderColor =  UIColor.lightGray.cgColor
        firstName.placeholder = "Name"
        firstName.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        firstName.leftViewMode = .always
        firstName.backgroundColor = .white
        
        return firstName
    }()
    
    private let LastNameField: UITextField = {
        let LastName = UITextField()
        LastName.autocapitalizationType = .none
        LastName.autocorrectionType = .no
        LastName.returnKeyType = .continue
        LastName.layer.cornerRadius = 12
        LastName.layer.borderWidth = 1
        LastName.layer.borderColor =  UIColor.lightGray.cgColor
        LastName.placeholder = "Last name"
        LastName.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        LastName.leftViewMode = .always
        LastName.backgroundColor = .white
        
        return LastName
    }()
    
    private let emailField: UITextField = {
        let emailField = UITextField()
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .continue
        emailField.layer.cornerRadius = 12
        emailField.layer.borderWidth = 1
        emailField.layer.borderColor =  UIColor.lightGray.cgColor
        emailField.placeholder = "Email"
        emailField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        emailField.leftViewMode = .always
        emailField.backgroundColor = .white
        
        return emailField
    }()
    
    private let passwordField: UITextField = {
        let passwordField = UITextField()
        passwordField.autocapitalizationType = .none
        passwordField.autocorrectionType = .no
        passwordField.returnKeyType = .done
        passwordField.layer.cornerRadius = 12
        passwordField.layer.borderWidth = 1
        passwordField.layer.borderColor =  UIColor.lightGray.cgColor
        passwordField.placeholder = "Password"
        passwordField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        passwordField.leftViewMode = .always
        passwordField.backgroundColor = .white
        passwordField.isSecureTextEntry = true
        
        return passwordField
    }()
    
    private let registerButton: UIButton = {
        let registerButton = UIButton()
        registerButton.setTitle("Register", for: .normal)
        registerButton.backgroundColor = .link
        registerButton.setTitleColor(.white, for: .normal)
        registerButton.layer.cornerRadius = 12
        registerButton.layer.masksToBounds = true
        registerButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        return registerButton
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Create new account"
        view.backgroundColor = .white
        
        registerButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        emailField.delegate = self
        passwordField .delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(firstNameField)
        scrollView.addSubview(LastNameField)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(registerButton)
        
        imageView.isUserInteractionEnabled = true
        scrollView.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapChangeProfilePic))
        imageView.addGestureRecognizer(gesture)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.frame = view.frame
        
        let size = scrollView .width/3
        
        imageView.frame = CGRect(x: (scrollView.width - size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        
        imageView.layer.cornerRadius = imageView.width/2.0
        
        firstNameField.frame = CGRect(x: 30,
                                      y: imageView.bottom + 10,
                                      width: scrollView.width - 60,
                                      height: 52)
        
        LastNameField.frame = CGRect(x: 30,
                                     y: firstNameField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)
        
        emailField.frame = CGRect(x: 30,
                                  y: LastNameField.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)
        
        registerButton.frame = CGRect(x: 30,
                                      y: passwordField.bottom + 10,
                                      width: scrollView.width - 60,
                                      height: 52)
    }
    
    @objc private func didTapChangeProfilePic () {
        presentPhotoActionSheet()
    }
    
    @objc private func loginButtonTapped () {
        
        firstNameField.resignFirstResponder()
        LastNameField.resignFirstResponder()
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text,
              let password = passwordField.text,
              let firstName = firstNameField.text,
              let lastName = LastNameField.text,
              !email.isEmpty,
              !password.isEmpty,
              !firstName.isEmpty,
              !lastName.isEmpty,
              password.count >= 6 else {
                  alertUserLoginError()
                  return
              }
        
        //Firebase login
        
        DatabaseManager.shared.userExists(with: email, completion: { [weak self] exists in

            guard let strongSelf = self else {
                return
            }

            guard !exists else {
                //user already exists
                strongSelf.alertUserLoginError(message: "Looks like a user account for this email already exists")
                return
            }
            
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password, completion: {authResults, error in
                guard authResults != nil, error == nil else {
                    return print("Error creating user")
                }
                
                DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName, lastName: lastName, email: email))
                
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        })
    }
    
    @objc func alertUserLoginError (message: String = "Please enter all information to create new account.") {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}

extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginButtonTapped()
        }
        
        return true
    }
}

extension RegisterViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func presentPhotoActionSheet() {
        let actionSheet = UIAlertController(title: "Profile Picture", message: "How would you like to select a picture", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actionSheet.addAction(UIAlertAction(title: "Take photo", style: .default, handler: { [weak self] _ in
            self?.presentCamera()
        }))
        actionSheet.addAction(UIAlertAction(title: "Choose photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoPicker()
        }))
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    func presentCamera () {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true, completion: nil)
    }
    
    func presentPhotoPicker () {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        self.imageView.image = selectedImage
        dismiss(animated: true, completion: nil)
    }
}
