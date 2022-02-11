import Redis
import Vapor
import Logging
import XCTVapor

class RedisTests: XCTestCase {
    func testApplicationRedis() throws {
        let app = Application()
        defer { app.shutdown() }

        app.redis.configuration = try .init(
            hostname: env("REDIS_HOSTNAME") ?? "localhost",
            port: 6379
        )

        let info = try app.redis.send(command: "INFO", with: []).wait()
        XCTAssertContains(info.string, "redis_version")
    }

    func testRouteHandlerRedis() throws {
        let app = Application()
        defer { app.shutdown() }

        app.redis.configuration = try .init(
            hostname: env("REDIS_HOSTNAME") ?? "localhost",
            port: 6379
        )

        app.get("test") { req in
            req.redis.send(command: "INFO", with: []).map {
                $0.description
            }
        }

        try app.test(.GET, "test") { res in
            XCTAssertContains(res.body.string, "redis_version")
        }
    }
    
    func testInitConfigurationURL() throws {
        let app = Application()
        defer { app.shutdown() }

        let urlStr = URL(string: "redis://name:password@localhost:6379/0")
        
        let redisConfigurations = try RedisConfiguration(url: urlStr!)
        
        XCTAssertEqual(redisConfigurations.password, "password")
        XCTAssertEqual(redisConfigurations.database, 0)
    }
    
    func testCodable() throws {
        let app = Application()
        defer { app.shutdown() }
        app.redis.configuration = try .init(
            hostname: env("REDIS_HOSTNAME") ?? "localhost",
            port: 6379
        )

        struct Hello: Codable {
            var message: String
            var array: [Int]
            var dict: [String: Bool]
        }
        
        let hello = Hello(message: "world", array: [1, 2, 3], dict: ["yes": true, "false": false])
        try app.redis.set("hello", toJSON: hello).wait()
        
        let get = try app.redis.get("hello", asJSON: Hello.self).wait()
        XCTAssertEqual(get?.message, "world")
        XCTAssertEqual(get?.array.first, 1)
        XCTAssertEqual(get?.array.last, 3)
        XCTAssertEqual(get?.dict["yes"], true)
        XCTAssertEqual(get?.dict["false"], false)

        let _ = try app.redis.delete(["hello"]).wait()
    }
    
    func testSessions() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        app.redis.configuration = try .init(
            hostname: env("REDIS_HOSTNAME") ?? "localhost",
            port: 6379
        )

        // Configure sessions.
        app.sessions.use(.redis)
        app.middleware.use(app.sessions.middleware)

        // Setup routes.
        app.get("set", ":value") { req -> HTTPStatus in
            req.session.data["name"] = req.parameters.get("value")
            return .ok
        }
        app.get("get") { req -> String in
            req.session.data["name"] ?? "n/a"
        }
        app.get("del") { req -> HTTPStatus in
            req.session.destroy()
            return .ok
        }

        // Store session id.
        var sessionID: String?
        try app.test(.GET, "/set/vapor") { res in
            sessionID = res.headers.setCookie?["vapor-session"]?.string
            XCTAssertEqual(res.status, .ok)
        }
        XCTAssertFalse(try XCTUnwrap(sessionID).contains("vrs-"), "session token has the redis key prefix!")

        try app.test(.GET, "/get", beforeRequest: { req in
            var cookies = HTTPCookies()
            cookies["vapor-session"] = .init(string: sessionID!)
            req.headers.cookie = cookies
        }) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "vapor")
        }
    }
    
    override class func setUp() {
        XCTAssert(isLoggingConfigured)
    }
}

let isLoggingConfigured: Bool = {
    var env = Environment.testing
    try! LoggingSystem.bootstrap(from: &env)
    return true
}()

func env(_ name: String) -> String? {
    getenv(name).flatMap { String(cString: $0) }
}
