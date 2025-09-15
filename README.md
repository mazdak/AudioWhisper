# ContainerManager

ContainerManager is a native macOS menu bar application for listing and managing Apple Containers. It is built with SwiftUI and leverages the Virtualization framework. The menu bar interface shows sample containers, images, volumes, and networks using a placeholder service.

## Development

1. Build the project:
   ```bash
   ./build.sh
   ```
2. Run tests:
   ```bash
   ./run-tests.sh
   ```

The app currently targets macOS and includes a Linux fallback that simply prints a message when run outside macOS.
