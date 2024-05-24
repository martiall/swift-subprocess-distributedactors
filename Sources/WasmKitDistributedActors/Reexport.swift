@_exported import PluginDistributedActors

import Foundation
func logWasm(_ string: String = "", line: Int = #line, file: StaticString = #file, function: StaticString = #function) {
#if os(WASI)
    try? FileHandle.standardError.write(contentsOf: "[\(file):\(line)](\(function)) \(string)\n".data(using: .utf8)!)
#endif
}
