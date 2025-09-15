#if os(macOS)
import SwiftUI

@main
struct ContainerManagerApp: App {
    var body: some Scene {
        MenuBarExtra("Containers", systemImage: "shippingbox") {
            ContainerMenuView()
        }
    }
}
#else
@main
struct ContainerManagerApp {
    static func main() {
        print("ContainerManager runs on macOS only.")
    }
}
#endif
