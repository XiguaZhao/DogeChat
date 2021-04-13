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

extension ChatRoomViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if scrollBottom {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: UInt64(0.005)*NSEC_PER_SEC)) {
                guard !self.messages.isEmpty else { return }
                self.collectionView.scrollToItem(at: IndexPath(row: self.messages.count - 1, section: 0), at: .bottom, animated: false)
            }
        }
        return messages.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MessageCollectionViewCell.textCellIdentifier, for: indexPath) as? MessageCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let message = messages[indexPath.row]
        cell.indexPath = indexPath
        cell.delegate = self
        cell.cache = cache
        cell.contentSize = self.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: indexPath)
        cell.apply(message: message)
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.view.bounds.width, height: MessageCollectionViewCell.height(for: messages[indexPath.item]))
    }
    
    func insertNewMessageCell(_ messages: [Message]) {
        let filtered = messages.filter { !self.messages.contains($0) }
        DispatchQueue.main.async { [self] in
            var indexPaths: [IndexPath] = []
            for message in filtered {
                if message.messageSender == .ourself {
                    switch message.option {
                    case .toAll:
                        manager.messagesGroup.append(message)
                    case .toOne:
                        manager.messagesSingle.add(message, for: message.receiver)
                    }
                }
                indexPaths.append(IndexPath(row: self.messages.count, section: 0))
                self.messages.append(message)
            }
            collectionView.insertItems(at: indexPaths)
            var scrollToBottom = !collectionView.isDragging
            let contentHeight = collectionView.contentSize.height
            if contentHeight - collectionView.contentOffset.y > self.view.bounds.height {
                scrollToBottom = false
            }
            scrollToBottom = scrollToBottom || (messages.count == 1 && messages[0].messageSender == .ourself)
            if scrollToBottom, let indexPath = indexPaths.last {
                collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else {
            return
        }
        messageInputBar.textView.resignFirstResponder()
    }
    
    func emojiOutBounds(from cell: MessageCollectionViewCell, gesture: UIGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        guard let newIndexPath = collectionView.indexPathForItem(at: point),
              let oldIndexPath = cell.indexPath else { return }
        if let (_emojiInfo, _messageIndex, _) = cell.getIndex(for: gesture),
           let emojiInfo = _emojiInfo,
           let messageIndex = _messageIndex {
            messages[oldIndexPath.item].emojisInfo.remove(at: messageIndex)
            let newPoint = gesture.location(in: collectionView.cellForItem(at: newIndexPath)?.contentView)
            emojiInfo.x = newPoint.x / UIScreen.main.bounds.width
            emojiInfo.y = newPoint.y / MessageCollectionViewCell.height(for: messages[newIndexPath.item])
            messages[newIndexPath.item].emojisInfo.append(emojiInfo)
            needReload(indexPath: [newIndexPath, oldIndexPath], newHeight: 0)
        }
    }
    
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewCell) {
        if let indexPahth = collectionView.indexPath(for: cell) {
            needReload(indexPath: [indexPahth], newHeight: 0)
        }
    }
    
    func needReload(indexPath: [IndexPath], newHeight: CGFloat) {
        collectionView.reloadItems(at: indexPath)
    }
    
}
