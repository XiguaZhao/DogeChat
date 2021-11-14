//
//  MessageCollectionViewDrawCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

func getPKDrawing(message: Message) -> Any? {
    guard #available(iOS 13, *) else {
        return nil
    }
    if let localURL = message.pkLocalURL, let data = try? Data(contentsOf: localURL), let drawing = try? PKDrawing(data: data) {
        return drawing
    } else if let path = message.pkDataURL, let fileName = path.components(separatedBy: "/").last {
        if let url = fileURLAt(dirName: drawDir, fileName: fileName), let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data) {
            return drawing
        }
    } 
    return nil
}

class MessageCollectionViewDrawCell: MessageCollectionViewBaseCell {
    
    static let cellID = "MessageCollectionViewDrawCell"
    
    var tapGes = UITapGestureRecognizer()
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addPKView()
        if #available(iOS 13.0, *) {
            indicationNeighborView = getPKView()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if #available(iOS 13.0, *) {
            self.getPKView()?.drawing = PKDrawing()
            self.getPKView()?.backgroundColor = .clear
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutForDrawMessage()
        if #available(iOS 13.0, *) {
            self.getPKView()?.setContentOffset(.zero, animated: false)
        }
        layoutIndicatorViewAndMainView()
    }
        
    override func apply(message: Message) {
        super.apply(message: message)
        tapGes.isEnabled = message.messageSender == .ourself
        downloadPKDataIfNeeded()
    }
    
    // PencilKit相关
    func layoutForDrawMessage() {
        guard #available(iOS 13.0, *) else { return }
        guard let pkView = self.getPKView() else { return }
        let rightMargin:CGFloat = 0
        pkView.frame = CGRect(x: 0, y: 0, width: 0.8 * contentView.bounds.width + 20 - rightMargin, height: contentView.bounds.height - 30)
        pkView.contentSize = CGSize(width: pkView.frame.width, height: 2000)
        if let pkDrawing = getPKDrawing(message: message) as? PKDrawing {
            let maxWidth = contentView.bounds.width * 0.8
            if pkDrawing.bounds.maxX > maxWidth {
                let ratio = max(0, maxWidth / pkDrawing.bounds.maxX)
                pkView.drawing = pkDrawing.transformed(using: CGAffineTransform(scaleX: ratio, y: ratio))
                message.drawScale = ratio
            } else {
                pkView.drawing = pkDrawing
            }
        }
    }
    
    func addPKView() {
        if #available(iOS 13.0, *) {
            let pkView = PKCanvasView()
            pkView.backgroundColor = .clear
            if #available(iOS 14.0, *) {
                pkView.drawingPolicy = .anyInput
            }
            pkView.drawingGestureRecognizer.isEnabled = false
            self.contentView.addSubview(pkView)
            tapGes = UITapGestureRecognizer(target: self, action: #selector(pkViewTapAction(_:)))
            contentView.addGestureRecognizer(tapGes)
            tapGes.delegate = self
            setNeedsLayout()
        }
    }
    
    @available(iOS 13.0, *)
    @objc func pkViewTapAction(_ tap: UITapGestureRecognizer) {
        if message.messageSender == .ourself {
            guard let pkView = self.getPKView() else { return }
            delegate?.pkViewTapped(self, pkView: pkView)
        }
    }
    
    @available(iOS 13.0, *)
    func getPKView() -> PKCanvasView? {
        for view in contentView.subviews {
            if view.isKind(of: PKCanvasView.self) {
                return view as? PKCanvasView
            }
        }
        return nil
    }
    func downloadPKDataIfNeeded() {
        guard #available(iOS 13.0, *), let capturedMessage = message else { return }
        let displayBlock: () -> Void = { [weak self] in
            guard let self = self, capturedMessage == self.message else { return }
            self.setNeedsLayout()
        }
        if message.pkLocalURL != nil && message.sendStatus == .fail {
            displayBlock()
        } else if let name = message.pkDataURL?.components(separatedBy: "/").last, fileURLAt(dirName: drawDir, fileName: name) != nil {
            displayBlock()
        } else if let path = message.pkDataURL {
            MediaLoader.shared.requestImage(urlStr: path, type: .draw, cookie: manager.cookie, syncIfCan: true, completion: { [weak self] _, _, localPath in
                capturedMessage.pkLocalURL = localPath
                self?.delegate?.downloadSuccess(message: capturedMessage)
                capturedMessage.isDownloading = false
            }, progress: nil)
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapGes {
            return !tableView!.isEditing
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

}
