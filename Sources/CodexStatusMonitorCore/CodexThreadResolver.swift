import Darwin
import Foundation

public protocol CodexThreadResolving {
    func resolveThread(for projectDirectory: URL) throws -> CodexThread?
}

public final class CodexThreadResolver: CodexThreadResolving {
    private let databaseURL: URL
    private let sqlite: DynamicSQLite

    public init(paths: CodexPaths = CodexPaths()) {
        self.databaseURL = paths.stateDatabase
        self.sqlite = DynamicSQLite()
    }

    public init(databaseURL: URL, sqlite: DynamicSQLite = DynamicSQLite()) {
        self.databaseURL = databaseURL
        self.sqlite = sqlite
    }

    public func resolveThread(for projectDirectory: URL) throws -> CodexThread? {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw SQLiteError.openFailed("Database does not exist at \(databaseURL.path)")
        }

        let api = try sqlite.api()

        var database: OpaquePointer?
        let openResult = api.open(databaseURL.path, &database, DynamicSQLite.SQLITE_OPEN_READONLY | DynamicSQLite.SQLITE_OPEN_FULLMUTEX, nil)
        guard openResult == SQLITE_OK, let database else {
            defer { _ = api.close(database) }
            throw SQLiteError.openFailed(Self.message(from: database, api: api))
        }
        defer { _ = api.close(database) }

        let query = """
        SELECT id, rollout_path, cwd, updated_at_ms
        FROM threads
        WHERE archived = 0 AND cwd = ?
        ORDER BY updated_at_ms DESC
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard api.prepare(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteError.prepareFailed(Self.message(from: database, api: api))
        }
        defer { _ = api.finalize(statement) }

        let normalizedProjectPath = projectDirectory.standardizedFileURL.path
        let stepResult: Int32 = normalizedProjectPath.withCString { pathPointer in
            let bindResult = api.bindText(statement, 1, pathPointer, -1, nil)
            guard bindResult == SQLITE_OK else {
                return bindResult
            }
            return api.step(statement)
        }
        if stepResult == SQLITE_DONE {
            return nil
        }

        guard stepResult == SQLITE_ROW else {
            throw SQLiteError.stepFailed(Self.message(from: database, api: api))
        }

        guard
            let idCString = api.columnText(statement, 0),
            let rolloutCString = api.columnText(statement, 1),
            let cwdCString = api.columnText(statement, 2)
        else {
            throw SQLiteError.missingColumn("thread fields")
        }

        let id = String(cString: UnsafeRawPointer(idCString).assumingMemoryBound(to: CChar.self))
        let rolloutPath = String(cString: UnsafeRawPointer(rolloutCString).assumingMemoryBound(to: CChar.self))
        let cwd = String(cString: UnsafeRawPointer(cwdCString).assumingMemoryBound(to: CChar.self))

        return CodexThread(
            id: id,
            rolloutPath: URL(fileURLWithPath: rolloutPath),
            cwd: URL(fileURLWithPath: cwd),
            updatedAtMilliseconds: api.columnInt64(statement, 3)
        )
    }

    private static func message(from database: OpaquePointer?, api: DynamicSQLite.API) -> String {
        guard let database, let cMessage = api.errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: cMessage)
    }
}

private let SQLITE_OK: Int32 = 0
private let SQLITE_ROW: Int32 = 100
private let SQLITE_DONE: Int32 = 101
