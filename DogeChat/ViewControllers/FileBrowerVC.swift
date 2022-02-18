//
//  FileBrowerVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/6.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class FileBrowerVC: DogeChatViewController {
    
    enum FileType {
        case photo
        case video
        case livePhoto
        case draw
        case track
        
        func localizedString() -> String {
            switch self {
            case .photo:
                return NSLocalizedString("image", comment: "")
            case .video:
                return NSLocalizedString("video", comment: "")
            case .livePhoto:
                return NSLocalizedString("livePhoto", comment: "")
            case .draw:
                return NSLocalizedString("drawing", comment: "")
            case .track:
                return NSLocalizedString("track", comment: "")
            }
        }
    }
    
    var dirTypes = [FileType: [URL]]()
    var nowType: FileType = .photo
    let button = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        makeDirs()
        changeToType(.photo)
        view.addSubview(button)
        button.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        button.center = self.view.center
    }
    
    func makeDirs() {
        var dirsTypes = [FileType: [URL]]()
        let fm = FileManager.default
        let url = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        if let dirs = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for dirURL in dirs {
                if let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    switch dirURL.lastPathComponent {
                    case photoDir:
                        dirsTypes[.photo] = files
                    case livePhotoDir:
                        dirsTypes[.livePhoto] = files
                    case videoDir:
                        dirsTypes[.video] = files
                    case drawDir:
                        dirsTypes[.draw] = files
                    case tracksDirName:
                        dirsTypes[.track] = files
                    default:
                        break
                    }
                }
            }
        }
        self.dirTypes = dirsTypes
        let item = UIBarButtonItem(title: FileType.photo.localizedString(), style: .plain, target: self, action: #selector(showSheet(sender:)))
        navigationItem.setRightBarButton(item, animated: true)
    }
    
    @objc func showSheet(sender: UIBarButtonItem) {
        let sheet = UIAlertController(title: NSLocalizedString("chooseFileType", comment: ""), message: nil, preferredStyle: .actionSheet)
        let popover = sheet.popoverPresentationController
        popover?.barButtonItem = sender
        for type in dirTypes.keys {
            let action = UIAlertAction(title: type.localizedString(), style: .default) { _ in
                self.changeToType(type)
                sender.title = type.localizedString()
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        self.present(sheet, animated: true, completion: nil)
    }
    
    func changeToType(_ type: FileType) {
        nowType = type
        if let urls = self.dirTypes[type] {
            let localized = NSLocalizedString("deleteSomeData", comment: "")
            button.setTitle(String.localizedStringWithFormat(localized, urls.count), for: .normal)
            button.setTitleColor(UIColor(named: "textColor"), for: .normal)
            button.sizeToFit()
        }
    }
    
    @objc func buttonAction(_ sender: UIButton) {
        guard let urls = self.dirTypes[nowType] else { return }

        let alert = UIAlertController(title: NSLocalizedString("sureDelete", comment: ""), message: String.localizedStringWithFormat(NSLocalizedString("totalDataCount", comment: ""), urls.count), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("confirm", comment: ""), style: .default, handler: { _ in
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
            self.makeDirs()
            self.changeToType(.photo)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

