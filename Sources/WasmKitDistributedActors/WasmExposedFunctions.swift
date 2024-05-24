#if compiler(>=6.0) && os(WASI)
@_expose(wasm, "wasmkit_distributedactors_allocate")
@_cdecl("wasmkit_distributedactors_allocate")
func wasmkit_distributedactors_allocate(_ length: UInt32) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer.allocate(byteCount: Int(length), alignment: MemoryLayout<UInt8>.alignment)
}
    
@_expose(wasm, "wasmkit_distributedactors_free")
@_cdecl("wasmkit_distributedactors_free")
func wasmkit_distributedactors_free(_ ptr: UnsafeRawPointer) {
    ptr.deallocate()
}
#endif