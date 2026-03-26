/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */
package io.mosip.certify.core.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.Cache;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.cache.RedisCacheManagerBuilderCustomizer;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;


@ConditionalOnProperty(value = "spring.cache.type", havingValue = "redis")
@Configuration
@Slf4j
public class RedisCacheConfig {

    @Value("#{${mosip.certify.cache.expire-in-seconds}}")
    private Map<String, Integer> cacheNamesWithTTLMap;

    @Value("${mosip.certify.cache.redis.key-prefix:}")
    private String cachePrefix;

    @Value("${spring.data.redis.host:}")
    private String redisHost;

    @Value("${spring.data.redis.port:0}")
    private Integer redisPort;

    @Value("${spring.data.redis.ssl.enabled:false}")
    private Boolean redisSslEnabled;

    @Value("${spring.data.redis.username:}")
    private String redisUsername;

    @Bean
    public RedisCacheManagerBuilderCustomizer redisCacheManagerBuilderCustomizer() {
        log.info("Redis cache config loaded. host: {}, port: {}, ssl: {}, usernameConfigured: {}",
                redisHost,
                redisPort,
                redisSslEnabled,
                redisUsername != null && !redisUsername.isBlank());
        return (builder) -> {
            Map<String, RedisCacheConfiguration> configurationMap = new HashMap<>();
            cacheNamesWithTTLMap.forEach((cacheName, ttl) -> {
                RedisCacheConfiguration defaultConfiguration = RedisCacheConfiguration
                                .defaultCacheConfig()
                                .disableCachingNullValues()
                                .entryTtl(Duration.ofSeconds(ttl));
                if (cachePrefix != null && !cachePrefix.isEmpty()) {
                    log.info("Using cache prefix: {}", cachePrefix);
                    defaultConfiguration = defaultConfiguration.prefixCacheNameWith(cachePrefix);
                }
                configurationMap.put(cacheName, defaultConfiguration);
            });
            builder.withInitialCacheConfigurations(configurationMap);
        };
    }

    @Bean
    public CacheErrorHandler cacheErrorHandler() {
        return new CacheErrorHandler() {
            @Override
            public void handleCacheGetError(RuntimeException exception, Cache cache, Object key) {
                log.error("Redis cache GET failed. cache: {}, key: {}, host: {}, port: {}, ssl: {}",
                        cache != null ? cache.getName() : "unknown",
                        key,
                        redisHost,
                        redisPort,
                        redisSslEnabled,
                        exception);
            }

            @Override
            public void handleCachePutError(RuntimeException exception, Cache cache, Object key, Object value) {
                log.error("Redis cache PUT failed. cache: {}, key: {}, host: {}, port: {}, ssl: {}",
                        cache != null ? cache.getName() : "unknown",
                        key,
                        redisHost,
                        redisPort,
                        redisSslEnabled,
                        exception);
            }

            @Override
            public void handleCacheEvictError(RuntimeException exception, Cache cache, Object key) {
                log.error("Redis cache EVICT failed. cache: {}, key: {}, host: {}, port: {}, ssl: {}",
                        cache != null ? cache.getName() : "unknown",
                        key,
                        redisHost,
                        redisPort,
                        redisSslEnabled,
                        exception);
            }

            @Override
            public void handleCacheClearError(RuntimeException exception, Cache cache) {
                log.error("Redis cache CLEAR failed. cache: {}, host: {}, port: {}, ssl: {}",
                        cache != null ? cache.getName() : "unknown",
                        redisHost,
                        redisPort,
                        redisSslEnabled,
                        exception);
            }
        };
    }
}
