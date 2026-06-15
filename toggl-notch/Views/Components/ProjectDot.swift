import SwiftUI

struct ProjectDot: View {
    let color: Color
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

#Preview {
    ProjectDot(color: .green, size: 8)
        .padding()
        .background(.black)
}
