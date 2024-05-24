__attribute__((__import_module__("WasmKitDistributedActorsHost"),__import_name__("wasmkit_distributedactors_inbound_enveloppe")))
extern int wasmkit_distributedactors_inbound_enveloppe(void** ptr);

__attribute__((__import_module__("WasmKitDistributedActorsHost"),__import_name__("wasmkit_distributedactors_outbound_enveloppe")))
extern void wasmkit_distributedactors_outbound_enveloppe(const void* ptr, int length);
