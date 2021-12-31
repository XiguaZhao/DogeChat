
import UIKit

class Label: UILabel {
    
    static let verticalPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 16
    static let lineSpacing: CGFloat = 5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets.init(top: Self.verticalPadding, left: Self.horizontalPadding, bottom: Self.verticalPadding, right: Self.horizontalPadding)
        super.drawText(in: rect.inset(by: insets))
    }
        
//    override func display(_ layer: CALayer) {
//        let size = self.bounds.size
//        let scale = UIScreen.main.scale
//        DispatchQueue.global().async {
//            UIGraphicsBeginImageContextWithOptions(size, false, scale)
//            guard let context = UIGraphicsGetCurrentContext() else {
//                return
//            }
//            self.draw(context: context, size: size)
//            let image = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            let contents = image?.cgImage
//            DispatchQueue.main.async {
//                layer.contents = contents
//            }
//        }
//    }
    
    private func draw(context: CGContext, size: CGSize) {
        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        let path = CGMutablePath()
        path.addRect(CGRect(origin: .zero, size: size))
        let attrStr = NSAttributedString(string: self.text ?? "", attributes: [.font : self.font as Any])
        let frameSetter = CTFramesetterCreateWithAttributedString(attrStr)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attrStr.length), path, nil)
        CTFrameDraw(frame, context)
    }
    
}
