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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = UINavigationController(rootViewController: JoinChatViewController())
    window?.makeKeyAndVisible()
    
    let icon = UIApplicationShortcutIcon(type: .add)
    let item = UIApplicationShortcutItem(type: "add", localizedTitle: "添加快捷操作", localizedSubtitle: nil, icon: icon, userInfo: nil)
    if UIApplication.shared.shortcutItems?.count == 0 {
      UIApplication.shared.shortcutItems = [item]
    }
    
    return true
  }
  
  func applicationDidBecomeActive(_ application: UIApplication) {
    if (window?.rootViewController as! UINavigationController).topViewController?.title == "JoinChatVC" { return }
    guard !WebSocketManager.shared.cookie.isEmpty else { return }
    WebSocketManager.shared.connect()
  }
  
  func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    guard let nav = window?.rootViewController as? UINavigationController else { return }
    switch shortcutItem.type {
    case "add":
      if nav.topViewController is SelectShortcutTVC { return }
      nav.pushViewController(SelectShortcutTVC(), animated: true)
    case "contact":
      if !(nav.topViewController is JoinChatViewController) {
        nav.popToRootViewController(animated: true)
      }
      guard let userInfo = shortcutItem.userInfo, let username = userInfo["username"] as? String,
      let password = userInfo["password"] as? String else { return }
      guard let vc = nav.topViewController as? JoinChatViewController else { return }
      vc.login(username: username, password: password)
    default:
      return
    }
  }
      
}

