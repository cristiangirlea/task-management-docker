FROM redis:latest

# Copy a custom Redis config (if any)
COPY ./redis.conf /usr/local/etc/redis/redis.conf

# Start Redis with the custom configuration if present
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
