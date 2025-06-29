import Flutter
import HealthKitReporter

public class SwiftHealthKitReporterPlugin: NSObject, FlutterPlugin {
    var reporter: HealthKitReporter?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftHealthKitReporterPlugin()
        do {
            instance.reporter = try HealthKitReporter()
            if let reporter = instance.reporter {
                let binaryMessenger = registrar.messenger()
                registerMethodChannel(
                    registrar: registrar,
                    binaryMessenger: binaryMessenger,
                    instance: instance
                )
                try registerEventChannel(
                    binaryMessenger: binaryMessenger,
                    reporter: reporter
                )
            }
        } catch {
            print(error)
        }
    }
    private static func registerMethodChannel(
        registrar: FlutterPluginRegistrar,
        binaryMessenger: FlutterBinaryMessenger,
        instance: SwiftHealthKitReporterPlugin
    ) {
        for method in MethodChannel.allCases {
            let methodChannel = FlutterMethodChannel(
                name: method.rawValue,
                binaryMessenger: binaryMessenger
            )
            registrar.addMethodCallDelegate(instance, channel: methodChannel)
        }
    }
    private static func registerEventChannel(
        binaryMessenger: FlutterBinaryMessenger,
        reporter: HealthKitReporter
    ) throws {
        for event in EventChannel.allCases {
            let eventChannel = FlutterEventChannel(
                name: event.rawValue,
                binaryMessenger: binaryMessenger
            )
            let streamHandler = try StreamHandlerFactory.make(with: reporter, for: event)
            eventChannel.setStreamHandler(streamHandler)
        }
    }
}
