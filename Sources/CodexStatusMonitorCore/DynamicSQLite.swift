import Darwin
import Foundation

public final class DynamicSQLite: @unchecked Sendable {
    public static let SQLITE_OPEN_READONLY: Int32 = 0x00000001
    public static let SQLITE_OPEN_FULLMUTEX: Int32 = 0x00010000

    public struct API: Sendable {
        let open: @convention(c) (UnsafePointer<CChar>?, UnsafeMutablePointer<OpaquePointer?>?, Int32, UnsafePointer<CChar>?) -> Int32
        let close: @convention(c) (OpaquePointer?) -> Int32
        let errmsg: @convention(c) (OpaquePointer?) -> UnsafePointer<CChar>?
        let prepare: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32
        let finalize: @convention(c) (OpaquePointer?) -> Int32
        let bindText: @convention(c) (OpaquePointer?, Int32, UnsafePointer<CChar>?, Int32, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32
        let step: @convention(c) (OpaquePointer?) -> Int32
        let columnText: @convention(c) (OpaquePointer?, Int32) -> UnsafePointer<UInt8>?
        let columnInt64: @convention(c) (OpaquePointer?, Int32) -> Int64
    }

    private var cachedAPI: API?
    private var handle: UnsafeMutableRawPointer?

    public init() {}

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    public func api() throws -> API {
        if let cachedAPI {
            return cachedAPI
        }

        let libraryNames = [
            "/usr/lib/libsqlite3.dylib",
            "/usr/lib/libsqlite3.0.dylib"
        ]

        guard let handle = libraryNames.compactMap({ dlopen($0, RTLD_NOW) }).first else {
            throw SQLiteError.openFailed("Could not load system libsqlite3.")
        }

        self.handle = handle

        let api = API(
            open: try symbol("sqlite3_open_v2", in: handle),
            close: try symbol("sqlite3_close", in: handle),
            errmsg: try symbol("sqlite3_errmsg", in: handle),
            prepare: try symbol("sqlite3_prepare_v2", in: handle),
            finalize: try symbol("sqlite3_finalize", in: handle),
            bindText: try symbol("sqlite3_bind_text", in: handle),
            step: try symbol("sqlite3_step", in: handle),
            columnText: try symbol("sqlite3_column_text", in: handle),
            columnInt64: try symbol("sqlite3_column_int64", in: handle)
        )

        cachedAPI = api
        return api
    }

    private func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer) throws -> T {
        guard let pointer = dlsym(handle, name) else {
            throw SQLiteError.openFailed("Could not load SQLite symbol \(name).")
        }
        return unsafeBitCast(pointer, to: T.self)
    }
}
