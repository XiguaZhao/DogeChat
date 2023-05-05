//
//  ChatRoom+Time.swift
//  DogeChat
//
//  Created by ByteDance on 2023/4/16.
//  Copyright © 2023 Luke Parham. All rights reserved.
//

import DogeChatCommonDefines

extension ChatRoomViewController {
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? TimeHeader {
            assignTimeForLabel(header.label, section: section)
        }
    }
    
    func assignTimeForLabel(_ label: UILabel, section: Int) {
        guard let message = messages.safe_objectAt(section) else { return }
        label.text = DateTranslate.formateTimestamp(message.timestamp, withFormate: "YYYY年MM月dd日 HH:mm")
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let message = messages.safe_objectAt(section) else {
            return 0
        }
        let show = shouldShowTimeForMessage(message)
        message.showTime = show
        let height: CGFloat = show ? 25 : 0
        updateCachedHeight(uuid: message.uuid, header: height, row: nil)
        return height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let message = messages.safe_objectAt(section) else {
            return nil
        }
        guard shouldShowTimeForMessage(message) else {
            message.showTime = false
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TimeHeader.id) as? TimeHeader
        return header
    }
    

    func registerUpdateTime() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                self?.updateTime()
            }
        }
    }
    
    func updateTime() {
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            for visibleIndexPath in visibleIndexPaths {
                if let header = tableView.headerView(forSection: visibleIndexPath.section) as? TimeHeader {
                    assignTimeForLabel(header.label, section: visibleIndexPath.section)
                }
            }
        }
    }
    
    func distanceFromLastShowTime(message: Message) -> (distance: Int, message: Message?) {
        guard let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) else {
            return (0, nil)
        }
        for i in (0..<index).reversed() {
            if messages[i].showTime {
                return (index - i, messages[i])
            }
        }
        return (.max, nil)
    }
    
    func secondsFromLastShowTimeMessage(_ message: Message) -> TimeInterval {
        let lastShow = distanceFromLastShowTime(message: message)
        let lastTime = lastShow.message?.timestamp ?? 0
        let diff = message.timestamp - lastTime
        if String(Int(message.timestamp)).count > 10 {
            return diff / 1000
        }
        return diff
    }
    

}
