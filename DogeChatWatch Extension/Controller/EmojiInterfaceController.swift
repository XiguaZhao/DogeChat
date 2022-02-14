//
//  EmojiInterfaceController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/10/17.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import WatchKit

class EmojiInterfaceController: WKInterfaceController {
    
    var emojis = [String]()
    var showingCount = 0
    var fetchCount = 40
    
    let rowID = "emojiRow"
    
    @IBOutlet weak var table: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        NotificationCenter.default.addObserver(self, selector: #selector(selectEmojiAction), name: .selectEmoji, object: nil)
        if let emojis = context as? [String] {
            self.emojis = emojis
        }
    }
    
    override func didAppear() {
        super.didAppear()
        if emojis.isEmpty {
            SocketManager.shared.httpManager.getEmoji { emojis in
                self.emojis = emojis.reduce([], +).map{$0.path}
                self.reloadEmojis()
            }
        } else {
            reloadEmojis()
        }
    }
    
    @objc func selectEmojiAction() {
        self.dismiss()
    }
    func reloadEmojis() {
        if showingCount >= emojis.count {
            return
        }
        let up = showingCount + fetchCount >= self.emojis.count ? self.emojis.count : showingCount + fetchCount
        let emojis = emojis[showingCount..<up]
        syncOnMain {
            let bottom = showingCount/2
            let indexSet = IndexSet(bottom..<Int(ceil(Double(showingCount + emojis.count)/2)))
            table.insertRows(at: indexSet, withRowType: rowID)
            table.scrollToRow(at: showingCount/2+1)
            for index in showingCount..<up {
                let emojiPath = self.emojis[index]
                guard let row = table.rowController(at: index / 2) as? EmojiRowController else { return }
                if index % 2 == 0 {
                    row.leftPath = emojiPath
                } else {
                    row.rightPath = emojiPath
                }
                MediaLoader.shared.requestImage(urlStr: emojiPath, type: .image, syncIfCan: false, imageWidth: .width80, needStaticGif: true, completion: { image, data, _ in
                    let imageView = index % 2 == 0 ? row.leftImageView : row.rightImageView
                    imageView?.setImageData(data)
                }, progress: nil)
            }
        }
        showingCount += emojis.count
        if fetchCount < 60 {
            fetchCount = 60
        }
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        
    }
    
    override func interfaceOffsetDidScrollToBottom() {
        super.interfaceOffsetDidScrollToBottom()
        reloadEmojis()
    }
    
    @IBAction func tapAction(_ sender: Any) {
        let tap = sender as! WKTapGestureRecognizer
        let location = tap.locationInObject()
        let bounds = tap.objectBounds()
        let lineHeight = bounds.height / CGFloat(table.numberOfRows)
        let y = Int(location.y / lineHeight)
        let isLeft = location.x < bounds.width / 2
        let row = table.rowController(at: y) as! EmojiRowController
        let path = isLeft ? row.leftPath : row.rightPath
        NotificationCenter.default.post(name: .selectEmoji, object: path)
    }
}
