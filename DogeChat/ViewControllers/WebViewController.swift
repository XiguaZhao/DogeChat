//
//  WebViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/20.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate  {
    
    let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        webView.navigationDelegate = self
        
        webView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }
    }
    
    func apply(url: String) {
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
    }
    
    func webView(_ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }


}
