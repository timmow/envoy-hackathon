FROM envoyproxy/envoy-dev:c949a8144cf3b0162133dde0c489dea8a4078a47

COPY config/simple.yaml /etc/envoy/envoy.yaml
COPY lua/ /usr/local/share/lua/5.1/
