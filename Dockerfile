# FalkorDB graph database + FalkorDB Browser, packaged for Railway.
# Upstream image pinned by version and digest (multi-arch index).
FROM falkordb/falkordb:6.0.4@sha256:bef8acb1d8ed9ff8d2ea251767e75c6c05cfa759f7c6bc7e1c122f27d0ea4d7f

# Browser: prefill the login form with the local server, but never sign in
# with the server's password on its own (the password stays a login secret).
ENV FALKORDB_HOST=localhost \
    FALKORDB_PORT=6379 \
    FALKORDB_USERNAME=default \
    FALKORDB_AUTO_CONNECT=false \
    AUTH_TRUST_HOST=true \
    PORT=3000

COPY --chmod=0755 start.sh /usr/local/bin/railway-start.sh

EXPOSE 3000 6379
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
