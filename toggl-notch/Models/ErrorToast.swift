import Foundation

struct ErrorToast: Identifiable {
    let id = UUID()
    var message: String
    var retryAction: (() -> Void)?
}
