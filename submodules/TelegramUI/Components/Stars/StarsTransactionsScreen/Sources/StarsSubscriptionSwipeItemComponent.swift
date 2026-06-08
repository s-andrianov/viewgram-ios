import Foundation
import UIKit
import Display
import ComponentFlow
import ListSectionComponent
import TelegramPresentationData
import ListItemSwipeOptionContainer

/// Viewgram: wraps an arbitrary list row in a swipe-to-reveal container that
/// exposes a single trailing "Hide" action (styled like the chat-list archive
/// hide button). The hosted `content` is expected to be a
/// `ListSectionComponent.ChildView`; its separator inset and highlight
/// behaviour are forwarded so the row keeps behaving like a normal section item.
final class StarsSubscriptionSwipeItemComponent: Component {
    let theme: PresentationTheme
    let hideTitle: String
    let content: AnyComponent<Empty>
    let hideAction: () -> Void

    init(
        theme: PresentationTheme,
        hideTitle: String,
        content: AnyComponent<Empty>,
        hideAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.hideTitle = hideTitle
        self.content = content
        self.hideAction = hideAction
    }

    static func ==(lhs: StarsSubscriptionSwipeItemComponent, rhs: StarsSubscriptionSwipeItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.hideTitle != rhs.hideTitle {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private let swipeOptionContainer: ListItemSwipeOptionContainer
        private let content = ComponentView<Empty>()

        private var component: StarsSubscriptionSwipeItemComponent?

        var customUpdateIsHighlighted: ((Bool) -> Void)?
        var enumerateSiblings: (((UIView) -> Void) -> Void)?
        private(set) var separatorInset: CGFloat = 0.0

        override init(frame: CGRect) {
            self.swipeOptionContainer = ListItemSwipeOptionContainer(frame: CGRect())

            super.init(frame: frame)

            self.addSubview(self.swipeOptionContainer)

            self.swipeOptionContainer.updateRevealOffset = { [weak self] offset, transition in
                guard let self, let contentView = self.content.view else {
                    return
                }
                transition.setBounds(view: contentView, bounds: CGRect(origin: CGPoint(x: -offset, y: 0.0), size: contentView.bounds.size))
            }
            self.swipeOptionContainer.revealOptionSelected = { [weak self] _, _ in
                guard let self, let component = self.component else {
                    return
                }
                self.swipeOptionContainer.setRevealOptionsOpened(false, animated: true)
                component.hideAction()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: StarsSubscriptionSwipeItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component

            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            let size = contentSize

            if let contentView = self.content.view {
                if contentView.superview == nil {
                    contentView.layer.anchorPoint = CGPoint()
                    self.swipeOptionContainer.addSubview(contentView)
                }
                transition.setPosition(view: contentView, position: CGPoint())
                transition.setBounds(view: contentView, bounds: CGRect(origin: contentView.bounds.origin, size: size))

                if let childView = contentView as? ListSectionComponent.ChildView {
                    self.separatorInset = childView.separatorInset
                    childView.customUpdateIsHighlighted = { [weak self] isHighlighted in
                        self?.customUpdateIsHighlighted?(isHighlighted)
                    }
                    childView.enumerateSiblings = { [weak self] f in
                        self?.enumerateSiblings?(f)
                    }
                }
            }

            let containerFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: self.swipeOptionContainer, frame: containerFrame)
            self.swipeOptionContainer.updateLayout(size: size, leftInset: 0.0, rightInset: 0.0)

            let rightOptions: [ListItemSwipeOptionContainer.Option] = [
                ListItemSwipeOptionContainer.Option(
                    key: 0,
                    title: component.hideTitle,
                    icon: .none,
                    color: component.theme.list.itemDisclosureActions.inactive.fillColor,
                    textColor: component.theme.list.itemDisclosureActions.neutral1.foregroundColor
                )
            ]
            self.swipeOptionContainer.setRevealOptions(([], rightOptions))

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
