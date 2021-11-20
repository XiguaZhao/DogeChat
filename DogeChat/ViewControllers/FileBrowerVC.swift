//
//  FileBrowerVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/6.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class FileBrowerVC: DogeChatViewController {
    
    enum FileType: String {
        case photo = "图片"
        case video = "视频"
        case livePhoto = "Live Photo"
        case draw = "Drawing"
        case track = "歌曲"
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
        let item = UIBarButtonItem(title: FileType.photo.rawValue, style: .plain, target: self, action: #selector(showSheet(sender:)))
        navigationItem.setRightBarButton(item, animated: true)
    }
    
    @objc func showSheet(sender: UIBarButtonItem) {
        let sheet = UIAlertController(title: "请选择文件类型", message: nil, preferredStyle: .actionSheet)
        for type in dirTypes.keys {
            let action = UIAlertAction(title: type.rawValue, style: .default) { _ in
                self.changeToType(type)
                sender.title = type.rawValue
            }
            sheet.addAction(action)
        }
        self.present(sheet, animated: true, completion: nil)
    }
    
    func changeToType(_ type: FileType) {
        nowType = type
        if let urls = self.dirTypes[type] {
            button.setTitle("删除\(urls.count)条数据", for: .normal)
            button.setTitleColor(.blue, for: .normal)
            button.sizeToFit()
        }
    }
    
    @objc func buttonAction(_ sender: UIButton) {
        guard let urls = self.dirTypes[nowType] else { return }

        let alert = UIAlertController(title: "确定删除吗", message: "共\(urls.count)条数据", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
            self.makeDirs()
            self.changeToType(.photo)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

