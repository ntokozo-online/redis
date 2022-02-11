import Vapor
import RediStack

extension Request {
    public var redis: Redis {
        .init(request: self)
    }

    public struct Redis {
        let request: Request
    }
}

extension Request.Redis: RedisClient {

    
    public var eventLoop: EventLoop {
        self.request.eventLoop
    }

    public func logging(to logger: Logger) -> RedisClient {
        self.request.application.redis
            .pool(for: self.eventLoop)
            .logging(to: logger)
    }
    
    public func send<RESPValue>(_ command: RedisCommand<RESPValue>) -> EventLoopFuture<RESPValue> {
        self.request.application.redis
            .pool(for: self.eventLoop)
            .logging(to: self.request.logger)
            .send(command)
    }

    public func send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue> {
        let redisCommand: RedisCommand<RESPValue> = RedisCommand(keyword: command, arguments: arguments)
        return send(redisCommand)
    }
    
    public func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) -> EventLoopFuture<Void> {
        return self.request.application.redis
            .pubsubClient
            .logging(to: self.request.logger)
            .subscribe(to: channels, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }
    
    public func unsubscribe(from channels: [RedisChannelName]) -> EventLoopFuture<Void> {
        return self.request.application.redis
            .pubsubClient
            .logging(to: self.request.logger)
            .unsubscribe(from: channels)
    }
    
    public func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) -> EventLoopFuture<Void> {
        return self.request.application.redis
            .pubsubClient
            .logging(to: self.request.logger)
            .psubscribe(to: patterns, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }
    
    public func punsubscribe(from patterns: [String]) -> EventLoopFuture<Void> {
        return self.request.application.redis
            .pubsubClient
            .logging(to: self.request.logger)
            .punsubscribe(from: patterns)
    }
}
