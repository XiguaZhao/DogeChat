import UIKit
import PhotosUI
import DogeChatNetwork
import SwiftyJSON
import DogeChatUniversal
import CoreLocation

class NewPostVC: DogeChatViewController, PHPickerViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CLLocationManagerDelegate {

    var onPostPublished: ((PostModel) -> Void)?
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // preview of selected images
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        return cv
    }()

    private let locationField: UITextField = {
        let tf = UITextField()
        tf.placeholder = NSLocalizedString("Location (optional)", comment: "")
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let useLocationBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle(NSLocalizedString("Use Current Location", comment: ""), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // visibility: 0-all,1-friends,2-private
    private let visibilityControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: [NSLocalizedString("All", comment: ""), NSLocalizedString("Friends", comment: ""), NSLocalizedString("Private", comment: "")])
        sc.selectedSegmentIndex = 1 // default Friends
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let locationManager = CLLocationManager()

    private var attachedImageURLs: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("New Post", comment: "")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Publish", comment: ""), style: .done, target: self, action: #selector(publishTapped))

        view.addSubview(textView)
        view.addSubview(collectionView)
        view.addSubview(locationField)
        view.addSubview(useLocationBtn)
        view.addSubview(visibilityControl)

        let pickBtn = UIButton(type: .system)
        pickBtn.setTitle(NSLocalizedString("Add Image", comment: ""), for: .normal)
        pickBtn.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 14.0, *) {
            pickBtn.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        } else {
            // Fallback on earlier versions
        }
        view.addSubview(pickBtn)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.heightAnchor.constraint(equalToConstant: 140),

            visibilityControl.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
            visibilityControl.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            visibilityControl.trailingAnchor.constraint(equalTo: textView.trailingAnchor),

            locationField.topAnchor.constraint(equalTo: visibilityControl.bottomAnchor, constant: 8),
            locationField.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            locationField.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -8),
            locationField.heightAnchor.constraint(equalToConstant: 36),

            useLocationBtn.centerYAnchor.constraint(equalTo: locationField.centerYAnchor),
            useLocationBtn.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 8),
            useLocationBtn.trailingAnchor.constraint(equalTo: textView.trailingAnchor),

            pickBtn.topAnchor.constraint(equalTo: locationField.bottomAnchor, constant: 12),
            pickBtn.leadingAnchor.constraint(equalTo: textView.leadingAnchor),

            collectionView.topAnchor.constraint(equalTo: pickBtn.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 120)
        ])

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SelectedImageCell.self, forCellWithReuseIdentifier: SelectedImageCell.reuseIdentifier)

        useLocationBtn.addTarget(self, action: #selector(useCurrentLocation), for: .touchUpInside)
        locationManager.delegate = self
    }

    // MARK: - UICollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return attachedImageURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SelectedImageCell.reuseIdentifier, for: indexPath) as? SelectedImageCell else {
            return UICollectionViewCell()
        }
        let url = attachedImageURLs[indexPath.item]
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            cell.configure(with: img)
        } else {
            cell.configure(with: nil)
        }
        cell.onDelete = { [weak self] in
            guard let self = self else { return }
            if indexPath.item < self.attachedImageURLs.count {
                self.attachedImageURLs.remove(at: indexPath.item)
                self.collectionView.reloadData()
            }
        }
        return cell
    }

    // set item size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }

    @available(iOS 14.0, *)
    @objc func pickImage() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 0 // unlimited
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard !results.isEmpty else { return }
        let group = DispatchGroup()
        var newURLs: [URL] = []
        for (i, res) in results.enumerated() {
            if res.itemProvider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                res.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    defer { group.leave() }
                    if let img = object as? UIImage, let data = img.jpegData(compressionQuality: 0.85) {
                        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("newpost_\(Date().timeIntervalSince1970)_\(i).jpg")
                        do {
                            try data.write(to: tmp)
                            newURLs.append(tmp)
                        } catch {
                        }
                    }
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if !newURLs.isEmpty {
                self.attachedImageURLs.append(contentsOf: newURLs)
                self.collectionView.reloadData()
            }
        }
    }

    @objc func publishTapped() {
        let content = textView.text ?? ""
        guard let http = manager?.httpsManager else { return }
        let visibilityValue = { () -> Int in
            switch visibilityControl.selectedSegmentIndex {
            case 0: return 0
            case 1: return 1
            case 2: return 2
            default: return 1
            }
        }()
        let location = locationField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        if attachedImageURLs.isEmpty {
            publish(content: content, mediaInfos: [], visibility: visibilityValue, location: location)
            return
        }

        var uploadedPaths: [String] = []
        var anyFailed = false
        let dispatchGroup = DispatchGroup()
        for url in attachedImageURLs {
            dispatchGroup.enter()
            http.uploadPhoto(imageUrl: url, type: .photo, size: CGSize(width: 1200, height: 1200), uploadProgress: nil, success: { path in
                uploadedPaths.append(path)
                dispatchGroup.leave()
            }, fail: {
                anyFailed = true
                dispatchGroup.leave()
            })
        }
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if anyFailed {
                let alert = UIAlertController(title: NSLocalizedString("Upload Failed", comment: ""), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }
            self.publish(content: content, mediaInfos: uploadedPaths, visibility: visibilityValue, location: location)
        }
    }

    private func publish(content: String, mediaInfos: [String], visibility: Int, location: String?) {
        guard let http = manager?.httpsManager else { return }
        var params: [String: Any] = ["content": content, "visibility": visibility, "allowComment": 1]
        if let loc = location, !loc.isEmpty {
            params["location"] = loc
        }
        // build mediaList objects
        if !mediaInfos.isEmpty {
            var mediaList: [[String: Any]] = []
            for (i, path) in mediaInfos.enumerated() {
                var mediaObj: [String: Any] = [:]
                mediaObj["mediaType"] = 1
                mediaObj["mediaUrl"] = path
                mediaObj["thumbnailUrl"] = ""
                // attempt to get width/height/filesize from corresponding local file if exists
                if i < attachedImageURLs.count {
                    let fileUrl = attachedImageURLs[i]
                    if let img = UIImage(contentsOfFile: fileUrl.path) {
                        mediaObj["width"] = Int(img.size.width)
                        mediaObj["height"] = Int(img.size.height)
                    }
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fileUrl.path), let size = attrs[.size] as? NSNumber {
                        mediaObj["fileSize"] = size.intValue
                    }
                }
                mediaObj["sortOrder"] = i
                mediaList.append(mediaObj)
            }
            params["mediaList"] = mediaList
        }

        var request = URLRequest(url: URL(string: http.url_pre + "moment/publish")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
        request.setValue("SESSION="+http.cookie, forHTTPHeaderField: "Cookie")
        http.sessionForWatch.dataTask(with: request) { data, response, error in
            guard error == nil, let data = data, let json = try? JSON(data: data) else {
                return
            }
            // expect returned moment JSON
            let item = json["moment"]
            let id = item["momentId"].stringValue
            let uid = item["userId"].stringValue
            let name = item["username"].stringValue
            let avatar = item["avatarUrl"].string
            let content = item["content"].stringValue
            var medias = [PostMedia]()
            for m in item["mediaList"].arrayValue {
                let typeInt = m["mediaType"].intValue
                let media = PostMedia(mediaId: m["mediaId"].string, mediaType: PostMedia.MediaType(rawValue: typeInt) ?? .image, mediaUrl: m["mediaUrl"].stringValue, thumbnailUrl: m["thumbnailUrl"].string, width: m["width"].int, height: m["height"].int, duration: m["duration"].int)
                medias.append(media)
            }
            var likeUsers = [LikeUser]()
            for lu in item["likeUsers"].arrayValue {
                let like = LikeUser(avatarUrl: lu["avatarUrl"].string, username: lu["username"].stringValue, userId: lu["userId"].stringValue)
                likeUsers.append(like)
            }
            let post = PostModel(momentId: id, userId: uid, username: name, avatarUrl: avatar, content: content, location: item["location"].string, visibility: item["visibility"].intValue, createdTime: item["createdTime"].string, mediaList: medias, comments: [], likeUsers: likeUsers, isMine: true)
            DispatchQueue.main.async {
                self.onPostPublished?(post)
                self.navigationController?.popViewController(animated: true)
            }
        }.resume()
    }

    // MARK: - Location
    @objc private func useCurrentLocation() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            let ac = UIAlertController(title: NSLocalizedString("Location Permission Denied", comment: ""), message: NSLocalizedString("Please enable location permissions in Settings.", comment: ""), preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, error in
            if let p = placemarks?.first {
                var name = p.name ?? ""
                if name.isEmpty {
                    if let locality = p.locality, let admin = p.administrativeArea {
                        name = "\(locality) \(admin)"
                    }
                }
                DispatchQueue.main.async {
                    if !name.isEmpty {
                        self.locationField.text = name
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: NSLocalizedString("Location Error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(ac, animated: true)
        }
    }
}

// MARK: - SelectedImageCell
private class SelectedImageCell: UICollectionViewCell {
    static let reuseIdentifier = "SelectedImageCell"
    private let iv: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.layer.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let deleteBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✕", for: .normal)
        b.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        b.layer.cornerRadius = 12
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(iv)
        contentView.addSubview(deleteBtn)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            iv.topAnchor.constraint(equalTo: contentView.topAnchor),
            iv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            deleteBtn.widthAnchor.constraint(equalToConstant: 24),
            deleteBtn.heightAnchor.constraint(equalToConstant: 24),
            deleteBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            deleteBtn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4)
        ])
        deleteBtn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with image: UIImage?) {
        iv.image = image
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}
