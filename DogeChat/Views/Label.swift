
import UIKit
import YYText

class InsetLabel: UILabel {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets.init(top: Self.verticalPadding, left: Self.horizontalPadding, bottom: Self.verticalPadding, right: Self.horizontalPadding)
        super.drawText(in: rect.inset(by: insets))
    }
}

class Label: YYLabel {
    
    static let verticalPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 16
    static let lineSpacing: CGFloat = 2
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.textContainerInset = UIEdgeInsets.init(top: 0, left: Self.horizontalPadding, bottom: 0, right: Self.horizontalPadding)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
            
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
