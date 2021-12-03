//
//  FloatWindow.swift
//  FloatingWindow
//
//  Created by 赵锡光 on 2021/1/25.
//

import UIKit
import DogeChatNetwork

private let offsetPush: CGFloat = 5
private let durationPush: TimeInterval = 0.8
private let pushExistTime: TimeInterval = 3
private let durationAlwaysDisplay:  TimeInterval = 0.5

protocol FloatWindowTouchDelegate: AnyObject {
    func tapPush(_ window: FloatWindow!, sender: String, content: String)
    func tapAlwaysDisplay(_ window: FloatWindow!, name: String)
}

class NestedViewController: UIViewController {
    
    weak var window: FloatWindow?
    var type: WindowType!
    var alwaysDisplayType: AlwayDisplayType!
    var pushView: UIView!
    var alwaysDisplayView: UIView!
    var nameLabelPush: UILabel!
    var messageLabelPush: UILabel!
    var nameLabelAlwaysDisplay: UILabel!
    var endLabel: UILabel!
    var timerForTapAlwaysDisplay: Timer?
    weak var delegate: FloatWindowTouchDelegate?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        self.view.addGestureRecognizer(tap)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard type == .alwaysDisplay else { return }
        if let point = touches.first?.location(in: nil) {
            self.window?.center = point
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard type == .alwaysDisplay else { return }
        if var point = touches.first?.location(in: nil) {
            let isLeft = point.x < UIScreen.main.bounds.width / 2
            guard let window = window else { return }
            if isLeft {
                point.x = window.frame.width / 2
            } else {
                point.x = UIScreen.main.bounds.width - window.frame.width / 2
            }
            UIView.animate(withDuration: durationAlwaysDisplay, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear) {
                self.window?.center = point
            } completion: { (finish) in
                
            }

        }
    }
    
    
    
    @objc func tapped(_ tapGesture: UITapGestureRecognizer!) {
        let needCallDelegate = tapGesture != nil
        switch type {
        case .push:
            if var frame = window?.frame {
                frame = CGRect(x: frame.origin.x, y: -(frame.height + offsetPush), width: frame.width, height: frame.height)
                window?.autoDismissPush(endFrame: frame, duration: durationPush)
            }
            if needCallDelegate {
                delegate?.tapPush(window, sender: nameLabelPush.text ?? "", content: messageLabelPush.text ?? "")
            }
        case .alwaysDisplay:
            if needCallDelegate {
                delegate?.tapAlwaysDisplay(window, name: nameLabelAlwaysDisplay.text ?? "")
            }
            if self.alwaysDisplayType == .shouldNotDimiss { break }
            endLabel.isHidden = true
            nameLabelAlwaysDisplay.text = "已结束"
            if timerForTapAlwaysDisplay != nil {
                timerForTapAlwaysDisplay?.invalidate()
                timerForTapAlwaysDisplay = nil
            }
            timerForTapAlwaysDisplay = Timer(timeInterval: 1, repeats: false, block: { [weak self] (_) in
                self?.autoDismissAlwaysDisplay()
            })
            timerForTapAlwaysDisplay?.fire()
        default: break
        }
    }
    
    func autoDismissAlwaysDisplay() {
        UIView.animate(withDuration: durationAlwaysDisplay) {
            self.window?.alpha = 0
        } completion: { (finish) in
            self.window?.isHidden = true
        }

    }
    
    func addPushView() {
        let height = view.frame.size.height
        nameLabelPush = UILabel()
        messageLabelPush = UILabel()
        nameLabelPush.font = UIFont.boldSystemFont(ofSize: 20)
        messageLabelPush.font = UIFont.systemFont(ofSize: nameLabelPush.font.pointSize - 5)
        nameLabelPush.numberOfLines = 1
        messageLabelPush.numberOfLines = 1
        view.addSubview(nameLabelPush)
        view.addSubview(messageLabelPush)
        nameLabelPush.translatesAutoresizingMaskIntoConstraints = false
        messageLabelPush.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabelPush.topAnchor.constraint(equalTo: view.topAnchor, constant: offsetPush),
            nameLabelPush.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: offsetPush * 2),
            nameLabelPush.bottomAnchor.constraint(equalTo: messageLabelPush.topAnchor, constant: -offsetPush),
            NSLayoutConstraint(item: nameLabelPush!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: height / 3)
        ])
        NSLayoutConstraint.activate([
            messageLabelPush.topAnchor.constraint(equalTo: nameLabelPush.bottomAnchor, constant: offsetPush),
            messageLabelPush.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: offsetPush * 2),
            messageLabelPush.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -offsetPush),
            messageLabelPush.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -offsetPush)
        ])
    }
    
    func addAlwaysDisplayView() {
        nameLabelAlwaysDisplay = UILabel()
        endLabel = UILabel()
        nameLabelAlwaysDisplay.adjustsFontSizeToFitWidth = true
        nameLabelAlwaysDisplay.textAlignment = .center
        view.addSubview(nameLabelAlwaysDisplay)
        view.addSubview(endLabel)
        nameLabelAlwaysDisplay.translatesAutoresizingMaskIntoConstraints = false
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabelAlwaysDisplay.text = "赵锡光"
        if self.alwaysDisplayType == .shouldDismiss {
            endLabel.text = "挂断"
        }
        nameLabelAlwaysDisplay.font = .systemFont(ofSize: 15)
        endLabel.font = .systemFont(ofSize: 10)
        NSLayoutConstraint.activate([
            nameLabelAlwaysDisplay.centerXAnchor.constraint(equalTo: endLabel.centerXAnchor),
            nameLabelAlwaysDisplay.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -5),
            nameLabelAlwaysDisplay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameLabelAlwaysDisplay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nameLabelAlwaysDisplay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        NSLayoutConstraint.activate([
            endLabel.centerXAnchor.constraint(equalTo: nameLabelAlwaysDisplay.centerXAnchor),
            endLabel.topAnchor.constraint(equalTo: nameLabelAlwaysDisplay.bottomAnchor, constant: 5)
        ])
    }
    
}

enum WindowType {
    case push
    case alwaysDisplay
}

enum AlwayDisplayType {
    case shouldDismiss
    case shouldNotDimiss
}

class FloatWindow: UIWindow {
    
    let nestedVC: NestedViewController
    let type: WindowType
    let alwayDisplayType: AlwayDisplayType
    var cachedFrame: CGRect?
    private weak var timerForPush: Timer?
    private weak var autoDismissTimer: Timer?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    init(type: WindowType, alwayDisplayType: AlwayDisplayType, delegate: FloatWindowTouchDelegate?) {
        self.type = type
        self.nestedVC = NestedViewController()
        self.alwayDisplayType = alwayDisplayType
        nestedVC.type = type
        nestedVC.alwaysDisplayType = alwayDisplayType
        nestedVC.delegate = delegate
        let size = UIScreen.main.bounds.size
        switch type {
        case .push:
            let offset: CGFloat = 10
            let height: CGFloat = 80
            let frame = CGRect(x: offset, y: -(offset + height), width: size.width - 2 * offset, height: height)
            super.init(frame: frame)
            self.cachedFrame = frame
            self.layer.cornerRadius = 10
            self.layer.masksToBounds = true
            configurePushType()
            let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(swipeUpAction(_:)))
            swipeUp.direction = .up
            self.addGestureRecognizer(swipeUp)
        case .alwaysDisplay:
            let width: CGFloat = 60
            var y = (size.height-width)/2
            if alwayDisplayType == .shouldNotDimiss {
                y += 200
            }
            let frame = CGRect(x: size.width - width, y: y, width: width, height: width)
            super.init(frame: frame)
            self.layer.cornerRadius = width / 2
            self.layer.masksToBounds = true
            configureAlwaysDisplayKind()
        }
        nestedVC.window = self
        self.rootViewController = nestedVC
        self.windowLevel = .init(1000)
    }
    
    @objc func swipeUpAction(_ ges: UISwipeGestureRecognizer) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        autoDismissPush(endFrame: self.cachedFrame!, duration: durationPush)
    }
    
    func configurePushType() {
        self.nestedVC.view.frame = self.frame
        nestedVC.addPushView()
    }
    
    func configureAlwaysDisplayKind() {
        self.nestedVC.view.frame = self.frame
        nestedVC.addAlwaysDisplayView()
    }
    
    func assignValueForPush(sender: String, content: String) {
        nestedVC.nameLabelPush.text = sender
        nestedVC.messageLabelPush.text = content
        if self.isHidden {
            self.isHidden = false
            let oldFrame = self.frame
            let newFrame = CGRect(x: oldFrame.origin.x, y: -oldFrame.origin.y - oldFrame.height + UIApplication.shared.statusBarFrame.height, width: oldFrame.width, height: oldFrame.height)
            UIView.animate(withDuration: durationPush, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveEaseIn) {
                self.frame = newFrame
            } completion: { (finished) in
                self.autoDismissTimer = Timer.scheduledTimer(withTimeInterval: pushExistTime, repeats: false) { [weak self] (_) in
                    self?.autoDismissPush(endFrame: oldFrame, duration: durationPush)
                }
            }
        }
    }
    
    func autoDismissPush(endFrame: CGRect, duration: TimeInterval) {
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveEaseOut) {
            self.frame = endFrame
        } completion: { (_) in
            self.isHidden = true
        }
    }
    
    func assignValueForAlwaysDisplay(name: String) {
        self.makeKeyAndVisible()
        self.isHidden = false
        self.alpha = 0
        nestedVC.nameLabelAlwaysDisplay.text = name
        nestedVC.endLabel.isHidden = false
        UIView.animate(withDuration: durationAlwaysDisplay) {
            self.alpha = 1
        } completion: { (finished) in
            
        }

    }
    
}
