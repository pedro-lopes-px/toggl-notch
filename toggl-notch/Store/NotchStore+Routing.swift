import Foundation

extension NotchStore {
    func push(_ route: PanelRoute) {
        routeDirection = .push
        routeStack.append(self.route)
        self.route = route
    }

    func pop() {
        guard let previous = routeStack.popLast() else { return }
        routeDirection = .pop
        route = previous
    }

    func popToHome() {
        routeDirection = .pop
        routeStack.removeAll()
        route = .home
    }

    func navigateFromNavBar(_ target: PanelRoute) {
        popToHome()
        if target != .home {
            push(target)
        }
    }

    func handleEscape() {
        if route == .home {
            collapse()
        } else {
            pop()
        }
    }
}
