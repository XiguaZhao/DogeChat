//
//  MessageCollectionViewDrawCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

class MessageCollectionViewDrawCell: MessageCollectionViewBaseCell {
    
    static let cellID = "MessageCollectionViewDrawCell"
    
    var tapGes = UITapGestureRecognizer()
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addPKView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if #available(iOS 14.0, *) {
            self.getPKView()?.drawing = PKDrawing()
            self.getPKView()?.backgroundColor = .clear
        } 
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutForDrawMessage()
        if #available(iOS 14.0, *) {
            indicationNeighborView = getPKView()
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
        guard #available(iOS 14.0, *) else { return }
        guard let pkView = self.getPKView() else { return }
        let rightMargin:CGFloat = 0
        pkView.frame = CGRect(x: 0, y: 0, width: 0.8 * contentView.bounds.width + 20 - rightMargin, height: contentView.bounds.height - 30)
        pkView.contentSize = CGSize(width: pkView.frame.width, height: 2000)
        if let pkDrawing = message.pkDrawing as? PKDrawing {
            let maxWidth = contentView.bounds.width * 0.8
            if pkDrawing.bounds.maxX > maxWidth {
                let ratio = message.drawScale ?? max(0, maxWidth / pkDrawing.bounds.maxX)
                pkView.drawing = pkDrawing.transformed(using: CGAffineTransform(scaleX: ratio, y: ratio))
                message.pkViewScale = ratio
            } else {
                if let scale = message.drawScale {
                    pkView.drawing = pkDrawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
                } else {
                    pkView.drawing = pkDrawing
                }
            }
        }
    }
    
    func addPKView() {
        if #available(iOS 14.0, *) {
            let pkView = PKCanvasView()
            pkView.backgroundColor = .clear
            pkView.drawingPolicy = .anyInput
            pkView.isUserInteractionEnabled = false
            self.contentView.addSubview(pkView)
            tapGes = UITapGestureRecognizer(target: self, action: #selector(pkViewTapAction(_:)))
            contentView.addGestureRecognizer(tapGes)
            setNeedsLayout()
        }
    }
    
    @available(iOS 14.0, *)
    @objc func pkViewTapAction(_ tap: UITapGestureRecognizer) {
        if message.messageSender == .ourself {
            guard let pkView = self.getPKView() else { return }
            delegate?.pkViewTapped(self, pkView: pkView)
        }
    }
    
    @available(iOS 14.0, *)
    func getPKView() -> PKCanvasView? {
        for view in contentView.subviews {
            if view.isKind(of: PKCanvasView.self) {
                return view as? PKCanvasView
            }
        }
        return nil
    }
    func downloadPKDataIfNeeded() {
        guard #available(iOS 14.0, *),
              let pkDataStr = message.pkDataURL,
              let pkDataURL = URL(string: url_pre + pkDataStr) else { return }
        if !message.needReDownload, let cachedPKData = ContactsTableViewController.pkDataCache[pkDataStr],
           let pkDrawing = try? PKDrawing(data: cachedPKData as Data) {
            if !message.isDrawing { //正在画的话已经做了实时更新，这里不需要再覆盖缓存
                message.pkDrawing = pkDrawing
            }
            setNeedsLayout()
        } else {
            guard let capturedMessage = self.message else { return }
            session.get(pkDataURL.absoluteString, parameters: nil, headers: nil, progress: nil) { task, data in
                if let downloadedData = data as? Data,
                   let pkDrawing = try? PKDrawing(data: downloadedData) {
                    ContactsTableViewController.pkDataWriteQueue.sync {
                        ContactsTableViewController.pkDataCache[pkDataStr] = downloadedData
                    }
                    capturedMessage.pkDrawing = pkDrawing
                    capturedMessage.needReDownload = false
                    if capturedMessage == self.message {
                        self.setNeedsLayout()
                    }
                }
            } failure: { task, error in
                print(error)
            }
            
        }
    }

}
