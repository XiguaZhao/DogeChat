/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import UserNotifications

class JoinChatViewController: UIViewController {
  let logoImageView = UIImageView()
  let shadowView = UIView()
  let nameTextField = TextField()
  let passwordTextField = TextField()
  let manager = WebSocketManager.shared
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
  }
  @objc func dismissKeyboard() {
    nameTextField.resignFirstResponder()
    passwordTextField.resignFirstResponder()
  }
}

extension JoinChatViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField === textField { passwordTextField.resignFirstResponder() } else { textField.resignFirstResponder() }
    if let username = nameTextField.text, let password = passwordTextField.text {
      login(username: username, password: password)
    }
    return true
  }
  
  func login(username: String, password: String) {
    manager.login(username: username, password: password) { loginResult in
      if loginResult == "登录成功" {
        let contactsTVC = ContactsTableViewController()
        contactsTVC.username = username
        self.navigationController?.pushViewController(contactsTVC, animated: true)
      } else {
        let alert = UIAlertController(title: loginResult, message: "请重新检查输入", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true)
      }
    }
  }
}

class TextField: UITextField {
  
  let padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 8);
  
  override func textRect(forBounds bounds: CGRect) -> CGRect {
    return bounds.inset(by: padding)
  }
  
  override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
    return bounds.inset(by: padding)
  }
  
  override func editingRect(forBounds bounds: CGRect) -> CGRect {
    return bounds.inset(by: padding)
  }
}



